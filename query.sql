-- ============================================================
-- UPDATED QUERY v2 — production_data_new + Additive Consumption Data New
-- Key fix: replaces per-slot COALESCE(begin_(N-1), …) end-time logic
-- with LAG() window function over _start_dt within each record.
-- This makes end-time calculation ORDER-INDEPENDENT — immune to
-- operator data-entry order errors (8 affected records identified).
--
-- Structural changes vs v1:
--   raw_slots    → simple UNION ALL, one line per slot (includes record id)
--   parsed_slots → computes _start_dt, _foundry_date, Shift per slot
--   prod_slots_raw → assigns _end_dt / End using LAG window function
--   prod_slots   → prod_slots_raw filtered to the last 2 days. Filtering here
--                  (after the window function, not before it) keeps the LAG
--                  partition for each record's full, unfiltered slot set, so a
--                  slot right at the window edge still finds its true next
--                  slot instead of falling back to a shift-boundary default.
--   split_slots … final SELECT → UNCHANGED from original
--
-- Shifts:      A = 08:00–16:00  |  B = 16:00–00:00  |  C = 00:00–08:00
-- Additive:    comp_3÷10 = Bentonite | comp_2 = New Sand
--              comp_5÷10 = LCA       | water÷10 = Water
-- ============================================================

WITH

-- ── Step 0: Unpack all 26 slots into rows ─────────────────────────────────────
-- Simple extraction only — no date arithmetic here.
-- id partitions the window function in Step 2 (slots from same record stay together).
raw_slots AS (
    SELECT id, date_begin, time_begin, time_end, begin_1  AS _b, TRIM(titel_1)  AS _t, moulded_1  AS _m, poured_1  AS _p, waste_1  AS _w FROM aiw_data.production_data_new WHERE COALESCE(moulded_1, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_2,  TRIM(titel_2),  moulded_2,  poured_2,  waste_2  FROM aiw_data.production_data_new WHERE COALESCE(moulded_2, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_3,  TRIM(titel_3),  moulded_3,  poured_3,  waste_3  FROM aiw_data.production_data_new WHERE COALESCE(moulded_3, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_4,  TRIM(titel_4),  moulded_4,  poured_4,  waste_4  FROM aiw_data.production_data_new WHERE COALESCE(moulded_4, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_5,  TRIM(titel_5),  moulded_5,  poured_5,  waste_5  FROM aiw_data.production_data_new WHERE COALESCE(moulded_5, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_6,  TRIM(titel_6),  moulded_6,  poured_6,  waste_6  FROM aiw_data.production_data_new WHERE COALESCE(moulded_6, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_7,  TRIM(titel_7),  moulded_7,  poured_7,  waste_7  FROM aiw_data.production_data_new WHERE COALESCE(moulded_7, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_8,  TRIM(titel_8),  moulded_8,  poured_8,  waste_8  FROM aiw_data.production_data_new WHERE COALESCE(moulded_8, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_9,  TRIM(titel_9),  moulded_9,  poured_9,  waste_9  FROM aiw_data.production_data_new WHERE COALESCE(moulded_9, 0)  > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_10, TRIM(titel_10), moulded_10, poured_10, waste_10 FROM aiw_data.production_data_new WHERE COALESCE(moulded_10, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_11, TRIM(titel_11), moulded_11, poured_11, waste_11 FROM aiw_data.production_data_new WHERE COALESCE(moulded_11, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_12, TRIM(titel_12), moulded_12, poured_12, waste_12 FROM aiw_data.production_data_new WHERE COALESCE(moulded_12, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_13, TRIM(titel_13), moulded_13, poured_13, waste_13 FROM aiw_data.production_data_new WHERE COALESCE(moulded_13, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_14, TRIM(titel_14), moulded_14, poured_14, waste_14 FROM aiw_data.production_data_new WHERE COALESCE(moulded_14, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_15, TRIM(titel_15), moulded_15, poured_15, waste_15 FROM aiw_data.production_data_new WHERE COALESCE(moulded_15, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_16, TRIM(titel_16), moulded_16, poured_16, waste_16 FROM aiw_data.production_data_new WHERE COALESCE(moulded_16, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_17, TRIM(titel_17), moulded_17, poured_17, waste_17 FROM aiw_data.production_data_new WHERE COALESCE(moulded_17, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_18, TRIM(titel_18), moulded_18, poured_18, waste_18 FROM aiw_data.production_data_new WHERE COALESCE(moulded_18, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_19, TRIM(titel_19), moulded_19, poured_19, waste_19 FROM aiw_data.production_data_new WHERE COALESCE(moulded_19, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_20, TRIM(titel_20), moulded_20, poured_20, waste_20 FROM aiw_data.production_data_new WHERE COALESCE(moulded_20, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_21, TRIM(titel_21), moulded_21, poured_21, waste_21 FROM aiw_data.production_data_new WHERE COALESCE(moulded_21, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_22, TRIM(titel_22), moulded_22, poured_22, waste_22 FROM aiw_data.production_data_new WHERE COALESCE(moulded_22, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_23, TRIM(titel_23), moulded_23, poured_23, waste_23 FROM aiw_data.production_data_new WHERE COALESCE(moulded_23, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_24, TRIM(titel_24), moulded_24, poured_24, waste_24 FROM aiw_data.production_data_new WHERE COALESCE(moulded_24, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_25, TRIM(titel_25), moulded_25, poured_25, waste_25 FROM aiw_data.production_data_new WHERE COALESCE(moulded_25, 0) > 0
    UNION ALL SELECT id, date_begin, time_begin, time_end, begin_26, TRIM(titel_26), moulded_26, poured_26, waste_26 FROM aiw_data.production_data_new WHERE COALESCE(moulded_26, 0) > 0
),

-- ── Step 1: Parse actual start datetime per slot ───────────────────────────────
-- Rule: for Shift B records (time_begin hour >= 16), any slot whose begin
-- hour < 8 belongs to the NEXT calendar day (it is a C-shift slot in the
-- same production run that crossed midnight).
parsed_slots AS (
    SELECT
        id,
        date_begin,
        time_begin,
        time_end,
        _b,                              -- raw begin string  e.g. "19:34:22"
        _t   AS `Component`,
        _m   AS `Moulded`,
        _p   AS `Poured`,
        _w   AS `Waste`,

        -- ── Actual start datetime ─────────────────────────────────────────────
        CASE
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
             AND CAST(LEFT(_b,2) AS UNSIGNED) < 8
            THEN DATE_ADD(
                     STR_TO_DATE(CONCAT(date_begin,' ',_b),'%d.%m.%y %H:%i:%s'),
                     INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',_b),'%d.%m.%y %H:%i:%s')
        END  AS _start_dt,

        -- ── Foundry date ──────────────────────────────────────────────────────
        CASE
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END  AS _foundry_date,

        -- ── Shift label ───────────────────────────────────────────────────────
        CASE
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) BETWEEN 8 AND 15 THEN 'A'
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) >= 16              THEN 'B'
            ELSE                                                       'C'
        END  AS `Shift`,

        -- ── Shift sort order ──────────────────────────────────────────────────
        CASE
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) BETWEEN 8 AND 15 THEN 1
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) >= 16              THEN 2
            ELSE                                                       3
        END  AS _shift_order

    FROM raw_slots
),

-- ── Step 2: Assign End time using LAG window function ─────────────────────────
-- PARTITION BY id     → groups all slots that belong to the same DB record
-- ORDER BY _start_dt DESC → latest slot first (standard DISA convention)
-- LAG(_start_dt, 1)   → "previous" row in descending order = the slot whose
--                        start time is next-higher = the correct End for the
--                        current slot.
--
-- Why this fixes the ordering bug:
--   Old approach used COALESCE(begin_(N-1), time_end).  When an operator
--   entered slot N-1 at a later clock time than slot N (swapped), the old
--   code detected hour(begin_(N-1)) < hour(begin_N) and added 1 day,
--   creating a phantom ~23-hour window that split across shift boundaries.
--
--   New approach sorts every slot in the record by its ACTUAL datetime and
--   picks the immediately later slot as the end — regardless of which slot
--   number the operator assigned.  No day is ever added erroneously.
--
-- Kept unfiltered (no date-window filter here) so the LAG partition sees every
-- slot belonging to a record — the 2-day window is applied afterward, in the
-- prod_slots CTE below, so it can never cut a record's slot set in half before
-- LAG runs over it.
-- ──────────────────────────────────────────────────────────────────────────────
prod_slots_raw AS (
    SELECT
        DATE_FORMAT(_foundry_date,'%d-%m-%Y')   AS `Foundry Date`,
        `Shift`,
        `Component`,
        LEFT(_b,5)                               AS `Start`,

        -- ── End display string (HH:MM) ────────────────────────────────────────
        CASE
            WHEN LAG(_b,1) OVER w IS NOT NULL
                THEN LEFT(LAG(_b,1) OVER w, 5)   -- normal: next-later slot's begin
            WHEN time_end IS NOT NULL
                THEN LEFT(time_end,5)             -- last slot: record's end time
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) BETWEEN 8 AND 15 THEN '16:00'
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) >= 16              THEN '00:00'
            ELSE                                                       '08:00'
        END                                      AS `End`,

        `Moulded`,
        `Poured`,
        `Waste`,
        _foundry_date,
        _shift_order,
        _b                                       AS _sort_begin,
        _start_dt,

        -- ── End datetime (used in split_slots and additive JOIN) ──────────────
        CASE
            WHEN LAG(_start_dt,1) OVER w IS NOT NULL
                THEN LAG(_start_dt,1) OVER w      -- normal: next-later slot's _start_dt

            WHEN time_end IS NOT NULL
            THEN
                -- Shift B records: time_end with hour < 8 is on the next calendar day
                CASE
                    WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                     AND CAST(LEFT(time_end,2) AS UNSIGNED) < 8
                    THEN DATE_ADD(
                             STR_TO_DATE(CONCAT(date_begin,' ',time_end),'%d.%m.%y %H:%i:%s'),
                             INTERVAL 1 DAY)
                    ELSE STR_TO_DATE(CONCAT(date_begin,' ',time_end),'%d.%m.%y %H:%i:%s')
                END

            -- Fallback: shift boundary
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) BETWEEN 8 AND 15
                THEN STR_TO_DATE(CONCAT(date_begin,' 16:00:00'),'%d.%m.%y %H:%i:%s')
            WHEN CAST(LEFT(_b,2) AS UNSIGNED) >= 16
                THEN DATE_ADD(
                         STR_TO_DATE(CONCAT(date_begin,' 00:00:00'),'%d.%m.%y %H:%i:%s'),
                         INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' 08:00:00'),'%d.%m.%y %H:%i:%s')
        END                                      AS _end_dt

    FROM parsed_slots
    WINDOW w AS (PARTITION BY id ORDER BY _start_dt DESC)
),

-- ── Step 2.5: Restrict to the last 2 days ─────────────────────────────────────
-- Applied after LAG has already resolved End/_end_dt for every slot (see note
-- on prod_slots_raw above), so this is a pure output filter with no effect on
-- the window-function results themselves.
prod_slots AS (
    SELECT *
    FROM prod_slots_raw
    WHERE _foundry_date >= CURDATE() - INTERVAL 2 DAY
),

-- ── Step 3: Split slots that cross shift boundaries ───────────────────────────
-- Unchanged from original query.
split_slots AS (

    SELECT `Foundry Date`,`Shift`,`Component`,`Start`,`End`,
           `Moulded`,`Poured`,`Waste`,
           _foundry_date, _shift_order, _sort_begin, _start_dt, _end_dt
    FROM prod_slots
    WHERE NOT (HOUR(_start_dt) BETWEEN 8 AND 15
               AND _end_dt > TIMESTAMP(DATE(_start_dt),'16:00:00'))
      AND NOT (HOUR(_start_dt) BETWEEN 0 AND 7
               AND _end_dt > TIMESTAMP(DATE(_start_dt),'08:00:00'))
      AND NOT (HOUR(_start_dt) >= 16
               AND _end_dt > TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))

    UNION ALL

    -- A slot that starts in Shift A and crosses into Shift B ──────────────────
    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y'), 'A', `Component`, `Start`, '16:00',
        ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE(_start_dt),1,_sort_begin,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00')
    FROM prod_slots WHERE HOUR(_start_dt) BETWEEN 8 AND 15 AND _end_dt > TIMESTAMP(DATE(_start_dt),'16:00:00')

    UNION ALL

    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y'), 'B', `Component`, '16:00', `End`,
        `Moulded`-ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Poured` -ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Waste`  -ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE(_start_dt),2,'16:00:00',TIMESTAMP(DATE(_start_dt),'16:00:00'),_end_dt
    FROM prod_slots WHERE HOUR(_start_dt) BETWEEN 8 AND 15 AND _end_dt > TIMESTAMP(DATE(_start_dt),'16:00:00')

    UNION ALL

    -- A slot that starts in Shift B and crosses into Shift C ──────────────────
    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y'), 'B', `Component`, `Start`, '00:00',
        ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE(_start_dt),2,_sort_begin,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00')
    FROM prod_slots WHERE HOUR(_start_dt) >= 16 AND _end_dt > TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00')

    UNION ALL

    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y'), 'C', `Component`, '00:00', `End`,
        `Moulded`-ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Poured` -ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Waste`  -ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE(_start_dt),3,'00:00:00',TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00'),_end_dt
    FROM prod_slots WHERE HOUR(_start_dt) >= 16 AND _end_dt > TIMESTAMP(DATE_ADD(DATE(_start_dt),INTERVAL 1 DAY),'00:00:00')

    UNION ALL

    -- A slot that starts in Shift C and crosses into Shift A ──────────────────
    SELECT DATE_FORMAT(DATE_SUB(DATE(_start_dt),INTERVAL 1 DAY),'%d-%m-%Y'), 'C', `Component`, `Start`, '08:00',
        ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE_SUB(DATE(_start_dt),INTERVAL 1 DAY),3,_sort_begin,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00')
    FROM prod_slots WHERE HOUR(_start_dt) BETWEEN 0 AND 7 AND _end_dt > TIMESTAMP(DATE(_start_dt),'08:00:00')

    UNION ALL

    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y'), 'A', `Component`, '08:00', `End`,
        `Moulded`-ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Poured` -ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        `Waste`  -ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'08:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)),
        DATE(_start_dt),1,'08:00:00',TIMESTAMP(DATE(_start_dt),'08:00:00'),_end_dt
    FROM prod_slots WHERE HOUR(_start_dt) BETWEEN 0 AND 7 AND _end_dt > TIMESTAMP(DATE(_start_dt),'08:00:00')
),

-- ── Step 4: Parse additive table — GOOD rows only, for AVG ───────────────────
-- Unchanged from original query.
additive_parsed AS (
    SELECT
        STR_TO_DATE(mem_date_time, '%d.%m.%Y %H:%i:%s') AS _mem_dt,
        comp_3 / 10  AS bentonite,
        comp_2       AS new_sand,
        comp_5 / 10  AS lca,
        water  / 10  AS water
    FROM aiw_data.`Additive Consumption Data New`
    WHERE type = 'GOOD'
),

-- ── Step 5: Component ID lookup ───────────────────────────────────────────────
-- Unchanged from original query.
component_map AS (
    SELECT
        TRIM(Component)           AS component_name,
        CAST(ComponentID AS CHAR) AS component_id
    FROM aiw_data.Component_MapN
),

-- ── Step 6: Join additive rows to slots + LATERAL batch counts ────────────────
-- Unchanged from original query.
slot_additive AS (
    SELECT
        ps.`Foundry Date`, ps.`Shift`, ps.`Component`,
        COALESCE(cm.component_id, TRIM(ps.`Component`)) AS `ComponentID`,
        ps.`Start`, ps.`End`,
        ps.`Moulded`, ps.`Poured`, ps.`Waste`,
        ps._foundry_date, ps._shift_order, ps._sort_begin,

        ap.bentonite,
        ap.new_sand,
        ap.lca,
        ap.water,

        bc.no_of_batches,
        bc.bad_batches

    FROM split_slots ps

    LEFT JOIN additive_parsed ap
        ON ap._mem_dt BETWEEN ps._start_dt AND ps._end_dt

    LEFT JOIN LATERAL (
        SELECT
            COUNT(*)                                                       AS no_of_batches,
            COALESCE(SUM(CASE WHEN type = 'BAD' THEN 1 ELSE 0 END), 0)   AS bad_batches
        FROM aiw_data.`Additive Consumption Data New`
        WHERE STR_TO_DATE(mem_date_time, '%d.%m.%Y %H:%i:%s')
              BETWEEN ps._start_dt AND ps._end_dt
    ) bc ON TRUE

    LEFT JOIN component_map cm
        ON cm.component_name = TRIM(ps.`Component`)
)

-- ── Step 7: Final SELECT — AVG of GOOD batches + batch counts ────────────────
-- Unchanged from original query.
SELECT
    `Foundry Date`,
    `Shift`,
    `Component`,
    `ComponentID`,
    `Start`,
    `End`,
    `Moulded`,
    `Poured`,
    `Waste`,
    ROUND(AVG(bentonite), 2)    AS `Bentonite`,
    ROUND(AVG(new_sand),  2)    AS `New Sand`,
    ROUND(AVG(lca),       2)    AS `LCA`,
    ROUND(AVG(water),     2)    AS `Water`,
    MAX(no_of_batches)          AS `No of Batches`,
    MAX(bad_batches)            AS `Bad Batch`

FROM slot_additive

GROUP BY
    `Foundry Date`, `Shift`, `Component`, `ComponentID`, `Start`, `End`,
    `Moulded`, `Poured`, `Waste`,
    _foundry_date, _shift_order, _sort_begin

ORDER BY
    _foundry_date  ASC,
    _shift_order   ASC,
    _sort_begin    ASC;
