"""
AIW production booking ETL.

Pulls moulded / poured / waste slots from aiw_data.production_data_new
(query.sql already handles shift boundaries, midnight-crossing and the
Foundry Date rollback for shift C — used as-is here, no further date
adjustment) and books them to the same save_consumption_bookings API
used for RBA, minus the RBA pattern-matching step: query.sql already
resolves ComponentID via a join against aiw_data.Component_MapN.

Additive figures (Bentonite / New Sand / LCA / Water) computed by the
same query are sent along with each slot as bentoniteSetPoint /
newSandSetPoint / coalDustSetPoint / waterSetPoint — the exact field
names the API's ConsumptionBooking bean expects (confirmed against
sandman-v2-mod's ConsumptionBooking.java; LCA = coal dust in that
schema). A slot with no matching additive rows inherits the previous
slot's setpoint (forward-fill) rather than sending 0 or leaving it
blank — 0 would falsely claim zero consumption.
"""

import atexit
import json
import os
import tempfile
import time
import warnings
from urllib.parse import quote_plus

import pandas as pd
import requests
from sqlalchemy import create_engine, text
from sshtunnel import SSHTunnelForwarder

warnings.filterwarnings("ignore")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config", "config.json")
if not os.path.exists(CONFIG_PATH):
    # config.json holds real secrets and is gitignored — deployments (Railway) only
    # have the committed template, with secrets supplied via env vars instead.
    CONFIG_PATH = os.path.join(BASE_DIR, "config", "config.example.json")

with open(CONFIG_PATH, "r") as config_file:
    config = json.load(config_file)

# Secrets are overridable via environment variables (used in deployment, e.g. Railway,
# where they're injected as env vars instead of living in this committed file). Local
# runs are unaffected as long as these env vars aren't set — config.json's values apply.
if os.environ.get("DB_PASSWORD"):
    config["database"]["password"] = os.environ["DB_PASSWORD"]
if os.environ.get("API_PASSWORD"):
    config["j_password"] = os.environ["API_PASSWORD"]
if os.environ.get("SSH_PRIVATE_KEY"):
    # The key's contents, not a path — Railway can't reference a local Windows file.
    # Write it out once so sshtunnel can still be pointed at a path.
    key_path = os.path.join(tempfile.gettempdir(), "aiw_ssh_key.pem")
    with open(key_path, "w") as key_file:
        key_file.write(os.environ["SSH_PRIVATE_KEY"])
    os.chmod(key_path, 0o600)
    config["ssh_tunnel"]["ssh_private_key_path"] = key_path

db_config = config["database"]
ssh_config = config["ssh_tunnel"]
SQL_FILE_PATH = os.path.join(BASE_DIR, config["sql_file_path"])
DATA_FREQUENCY = config["data_frequency"]
FOUNDRY_LINE_ID = config["foundry_line_id"]
API_URL = config["api_url"]
LOGIN_URL = config["login_url"]
USERNAME = config["j_username"]
PASSWORD = config["j_password"]
COLUMNS_REQUIRED = config["columns_required"]

# The DB is only reachable through this SSH tunnel — database.host/port in config.json
# is the DB's address as seen FROM the SSH server (often "127.0.0.1"), not a public address.
tunnel = SSHTunnelForwarder(
    (ssh_config["ssh_host"], ssh_config.get("ssh_port", 22)),
    ssh_username=ssh_config["ssh_username"],
    ssh_pkey=ssh_config["ssh_private_key_path"],
    ssh_private_key_password=ssh_config.get("ssh_private_key_password") or None,
    remote_bind_address=(db_config["host"], int(db_config["port"])),
)
tunnel.start()
atexit.register(tunnel.stop)

engine = create_engine(
    f"mysql+pymysql://{quote_plus(db_config['user'])}:{quote_plus(db_config['password'])}"
    f"@127.0.0.1:{tunnel.local_bind_port}/{db_config['database_name']}",
    execution_options={"stream_results": True},
    # Cycles are 30 min apart — a pooled connection idle that long can go stale (dropped
    # by the server or the SSH tunnel) and fail with "Lost connection during query" the
    # next time it's reused. pre_ping tests it with a cheap SELECT 1 first and silently
    # reopens it if dead, instead of handing back a dead connection to the real query.
    pool_pre_ping=True,
)


def fetch_production_data():
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        query = f.read().strip().rstrip(";")

    connection = engine.connect()
    try:
        result = connection.execute(text(query))
        df = pd.DataFrame(result.fetchall(), columns=result.keys())
        print(f"Query returned {len(df)} row(s)")
    finally:
        connection.close()
    return df


def transform(df):
    if df.empty:
        return df

    df = df.copy()

    # Foundry Date already reflects the correct shift-attributed day from SQL — reformat only.
    df["date"] = pd.to_datetime(df["Foundry Date"], format="%d-%m-%Y").dt.strftime("%Y-%m-%d")
    df["shift"] = df["Shift"]
    df["startTime"] = df["Start"].astype(str) + ":00"
    df["endTime"] = df["End"].astype(str) + ":00"

    # ComponentID is already resolved by query.sql's join to Component_MapN. Where that
    # join missed, the query falls back to the raw component name — nothing bookable,
    # so those rows are dropped (and logged) rather than sent with a bad componentId.
    df["componentId"] = pd.to_numeric(df["ComponentID"], errors="coerce")
    unresolved = df[df["componentId"].isna()]
    for component in sorted(unresolved["Component"].dropna().unique()):
        print(f"Skipping unmapped component: {component}")
    df = df.dropna(subset=["componentId"])
    df["componentId"] = df["componentId"].astype(int)

    df["totalMould"] = df["Moulded"].fillna(0).astype(int)
    df["noOfBoxesPoured"] = df["Poured"].fillna(0).astype(int)
    df["unpouredMould"] = (df["totalMould"] - df["noOfBoxesPoured"]).clip(lower=0)

    # Fixed line, same as RBA's booking — ConsumptionBooking.foundryLineId is the
    # actual persisted column; sending it flat skips the transient foundryLine/pkey
    # indirection RBA's payload goes through for the same effect.
    df["foundryLineId"] = FOUNDRY_LINE_ID

    # Bad Batch / No of Batches now come straight from query.sql's per-slot additive
    # batch counts (type='BAD' vs GOOD+BAD total), not derived from Waste.
    df["badBatches"] = pd.to_numeric(df["Bad Batch"], errors="coerce").fillna(0).astype(int)
    df["noOfBatches"] = pd.to_numeric(df["No of Batches"], errors="coerce").fillna(0).astype(int)

    # Additive medians from query.sql — NaN (no additive row fell inside the slot) stays
    # null rather than 0, since 0 would falsely claim zero consumption.
    df["bentoniteSetPoint"] = pd.to_numeric(df["Bentonite"], errors="coerce")
    df["newSandSetPoint"] = pd.to_numeric(df["New Sand"], errors="coerce")
    df["coalDustSetPoint"] = pd.to_numeric(df["LCA"], errors="coerce")
    df["waterSetPoint"] = pd.to_numeric(df["Water"], errors="coerce")

    # A slot with no additive rows inherits the previous slot's setpoint rather than
    # being left blank. Rows are already in chronological order (query.sql's ORDER BY),
    # so a forward-fill carries the last known value forward. The very first row(s) in
    # the query's date window have nothing prior to inherit and stay blank.
    additive_columns = ["bentoniteSetPoint", "newSandSetPoint", "coalDustSetPoint", "waterSetPoint"]
    df[additive_columns] = df[additive_columns].ffill()

    df = df[COLUMNS_REQUIRED]
    # Cast to object before filling with None — on a float64 column, .where(..., None)
    # silently coerces None back to NaN instead of holding it, since a numpy float
    # array has no representation for None.
    df = df.astype(object).where(pd.notna(df), None)
    df = df.replace({None: ""})
    return df


#  Persistent session — login once for the life of the process, not per request
session = requests.Session()
_logged_in = False
_jsessionid = None


def login():
    global _logged_in, _jsessionid
    response = session.post(
        LOGIN_URL, data={"j_username": USERNAME, "j_password": PASSWORD}, timeout=30
    )
    _jsessionid = session.cookies.get("JSESSIONID")
    _logged_in = response.status_code == 200 and bool(_jsessionid)
    if _logged_in:
        print("Login successful!")
    else:
        print(f"Login failed! Status Code: {response.status_code}, Response: {response.text}")
    return _logged_in


def _looks_unauthenticated(response_text):
    # Spring Security serves the login/home page (HTTP 200, not 401/403) when the
    # session isn't actually authenticated — detect that instead of trusting status_code.
    return "<html" in response_text[:500].lower()


def send_data_to_api(records):
    global _logged_in
    if not records:
        print("Nothing to send.")
        return

    print("JSON payload being sent:\n", json.dumps(records, indent=4))

    if not _logged_in and not login():
        return

    def _post_once():
        headers = {
            "Content-Type": "application/json",
            # Force the session cookie regardless of the cookie's Path scoping —
            # requests' automatic cookie jar can silently drop it otherwise.
            "Cookie": f"JSESSIONID={_jsessionid}",
        }
        return session.post(API_URL, json=records, headers=headers, timeout=30)

    response = _post_once()

    # Re-authenticate once if the session turned out to not be authenticated
    if response.status_code in (401, 403) or _looks_unauthenticated(response.text):
        print("Session not authenticated. Re-authenticating and retrying once.")
        if login():
            response = _post_once()

    print("Response Status Code:", response.status_code)
    print("Response Body:", response.text)


def process_data():
    df = fetch_production_data()
    if df.empty:
        print("No production data returned. Skipping this cycle.")
        return

    df = transform(df)
    if df.empty:
        print("No bookable rows after transform (all components unmapped?). Skipping.")
        return

    print(f"Sending {len(df)} record(s) this cycle.")
    send_data_to_api(df.to_dict(orient="records"))
    print(f"Cycle complete: {len(df)} record(s) sent.")


if __name__ == "__main__":
    while True:
        try:
            process_data()
        except Exception as exc:
            print(f"Unexpected error: {exc}")
        time.sleep(DATA_FREQUENCY)
