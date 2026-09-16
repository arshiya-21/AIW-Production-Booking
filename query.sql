-- ============================================================
-- SELECT: aiw_data.production_data_new  +  aiw_data.`Additive Consumption Data New`
-- Output: Foundry Date | Shift | Component | ComponentID | Start | End |
--         Moulded | Poured | Waste |
--         Bentonite | New Sand | LCA | Water  ← AVG of GOOD additive rows
--                                               whose mem_date_time falls
--                                               within the slot [Start, End]
--         No of Batches                        ← COUNT of ALL rows (GOOD+BAD)
--         Bad Batch                            ← COUNT of type='BAD' rows
--
-- Shifts:      A = 08:00–16:00  |  B = 16:00–00:00  |  C = 00:00–08:00
-- End-time:    Slot 1 → time_end  |  Slot N → COALESCE(begin_(N-1), time_end)
-- Additive:    comp_3÷10 = Bentonite | comp_2 = New Sand (no division)
--              comp_5÷10 = LCA       | water÷10  = Water
-- ============================================================

WITH prod_slots AS (
-- ── Step 1: Unpack every slot row and attach _start_dt / _end_dt ────────────
    SELECT
        `Foundry Date`, `Shift`, `Component`, `Start`, `End`,
        `Moulded`, `Poured`, `Waste`,
        _foundry_date, _shift_order, _sort_begin,
        _start_dt, _end_dt
    FROM (

    -- ── Slot 1 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_1,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_1)                                AS `Component`,
        LEFT(begin_1,5)                              AS `Start`,
        CASE
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16
             AND CAST(LEFT(time_end,2) AS UNSIGNED) < 8
            THEN LEFT(time_end,5)
            WHEN time_end IS NULL
              OR CAST(LEFT(time_end,2) AS UNSIGNED) < CAST(LEFT(begin_1,2) AS UNSIGNED)
            THEN CASE
                    WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
                     AND CAST(LEFT(begin_1,2) AS UNSIGNED) < 16 THEN '16:00'
                    WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16 THEN '00:00'
                    ELSE                                              '08:00'
                 END
            ELSE LEFT(time_end,5)
        END                                          AS `End`,
        moulded_1  AS `Moulded`, poured_1 AS `Poured`, waste_1 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_1,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_1                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_1),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16
             AND CAST(LEFT(time_end,2) AS UNSIGNED) < 8
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',time_end),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            WHEN time_end IS NOT NULL
             AND CAST(LEFT(time_end,2) AS UNSIGNED) >= CAST(LEFT(begin_1,2) AS UNSIGNED)
            THEN STR_TO_DATE(CONCAT(date_begin,' ',time_end),'%d.%m.%y %H:%i:%s')
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_1,2) AS UNSIGNED) < 16
            THEN STR_TO_DATE(CONCAT(date_begin,' 16:00:00'),'%d.%m.%y %H:%i:%s')
            WHEN CAST(LEFT(begin_1,2) AS UNSIGNED) >= 16
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' 00:00:00'),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' 08:00:00'),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_1,0) > 0

    UNION ALL

    -- ── Slot 2 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_2,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_2)                                AS `Component`,
        LEFT(begin_2,5)                              AS `Start`,
        COALESCE(LEFT(begin_1,5), LEFT(time_end,5)) AS `End`,
        moulded_2  AS `Moulded`, poured_2 AS `Poured`, waste_2 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_2,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_2,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_2                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_2),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_1,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_2,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_1,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_1,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_2,0) > 0

    UNION ALL

    -- ── Slot 3 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_3,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_3)                                AS `Component`,
        LEFT(begin_3,5)                              AS `Start`,
        COALESCE(LEFT(begin_2,5), LEFT(time_end,5)) AS `End`,
        moulded_3  AS `Moulded`, poured_3 AS `Poured`, waste_3 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_3,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_3,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_3                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_3),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_2,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_3,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_2,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_2,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_3,0) > 0

    UNION ALL

    -- ── Slot 4 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_4,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_4)                                AS `Component`,
        LEFT(begin_4,5)                              AS `Start`,
        COALESCE(LEFT(begin_3,5), LEFT(time_end,5)) AS `End`,
        moulded_4  AS `Moulded`, poured_4 AS `Poured`, waste_4 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_4,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_4,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_4                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_4),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_3,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_4,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_3,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_3,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_4,0) > 0

    UNION ALL

    -- ── Slot 5 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_5,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_5)                                AS `Component`,
        LEFT(begin_5,5)                              AS `Start`,
        COALESCE(LEFT(begin_4,5), LEFT(time_end,5)) AS `End`,
        moulded_5  AS `Moulded`, poured_5 AS `Poured`, waste_5 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_5,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_5,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_5                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_5),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_4,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_5,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_4,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_4,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_5,0) > 0

    UNION ALL

    -- ── Slot 6 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_6,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_6)                                AS `Component`,
        LEFT(begin_6,5)                              AS `Start`,
        COALESCE(LEFT(begin_5,5), LEFT(time_end,5)) AS `End`,
        moulded_6  AS `Moulded`, poured_6 AS `Poured`, waste_6 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_6,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_6,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_6                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_6),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_5,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_6,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_5,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_5,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_6,0) > 0

    UNION ALL

    -- ── Slot 7 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_7,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_7)                                AS `Component`,
        LEFT(begin_7,5)                              AS `Start`,
        COALESCE(LEFT(begin_6,5), LEFT(time_end,5)) AS `End`,
        moulded_7  AS `Moulded`, poured_7 AS `Poured`, waste_7 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_7,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_7,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_7                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_7),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_6,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_7,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_6,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_6,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_7,0) > 0

    UNION ALL

    -- ── Slot 8 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_8,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_8)                                AS `Component`,
        LEFT(begin_8,5)                              AS `Start`,
        COALESCE(LEFT(begin_7,5), LEFT(time_end,5)) AS `End`,
        moulded_8  AS `Moulded`, poured_8 AS `Poured`, waste_8 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_8,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_8,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_8                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_8),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_7,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_8,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_7,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_7,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_8,0) > 0

    UNION ALL

    -- ── Slot 9 ───────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_9,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_9)                                AS `Component`,
        LEFT(begin_9,5)                              AS `Start`,
        COALESCE(LEFT(begin_8,5), LEFT(time_end,5)) AS `End`,
        moulded_9  AS `Moulded`, poured_9 AS `Poured`, waste_9 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_9,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_9,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_9                                      AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_9),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_8,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_9,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_8,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_8,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_9,0) > 0

    UNION ALL

    -- ── Slot 10 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_10,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_10)                               AS `Component`,
        LEFT(begin_10,5)                             AS `Start`,
        COALESCE(LEFT(begin_9,5), LEFT(time_end,5)) AS `End`,
        moulded_10 AS `Moulded`, poured_10 AS `Poured`, waste_10 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_10,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_10,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_10                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_10),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_9,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_10,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_9,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_9,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_10,0) > 0

    UNION ALL

    -- ── Slot 11 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_11,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_11)                               AS `Component`,
        LEFT(begin_11,5)                             AS `Start`,
        COALESCE(LEFT(begin_10,5),LEFT(time_end,5)) AS `End`,
        moulded_11 AS `Moulded`, poured_11 AS `Poured`, waste_11 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_11,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_11,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_11                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_11),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_10,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_11,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_10,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_10,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_11,0) > 0

    UNION ALL

    -- ── Slot 12 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_12,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_12)                               AS `Component`,
        LEFT(begin_12,5)                             AS `Start`,
        COALESCE(LEFT(begin_11,5),LEFT(time_end,5)) AS `End`,
        moulded_12 AS `Moulded`, poured_12 AS `Poured`, waste_12 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_12,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_12,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_12                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_12),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_11,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_12,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_11,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_11,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_12,0) > 0

    UNION ALL

    -- ── Slot 13 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_13,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_13)                               AS `Component`,
        LEFT(begin_13,5)                             AS `Start`,
        COALESCE(LEFT(begin_12,5),LEFT(time_end,5)) AS `End`,
        moulded_13 AS `Moulded`, poured_13 AS `Poured`, waste_13 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_13,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_13,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_13                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_13),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_12,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_13,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_12,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_12,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_13,0) > 0

    UNION ALL

    -- ── Slot 14 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_14,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_14)                               AS `Component`,
        LEFT(begin_14,5)                             AS `Start`,
        COALESCE(LEFT(begin_13,5),LEFT(time_end,5)) AS `End`,
        moulded_14 AS `Moulded`, poured_14 AS `Poured`, waste_14 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_14,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_14,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_14                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_14),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_13,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_14,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_13,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_13,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_14,0) > 0

    UNION ALL

    -- ── Slot 15 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_15,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_15)                               AS `Component`,
        LEFT(begin_15,5)                             AS `Start`,
        COALESCE(LEFT(begin_14,5),LEFT(time_end,5)) AS `End`,
        moulded_15 AS `Moulded`, poured_15 AS `Poured`, waste_15 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_15,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_15,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_15                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_15),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_14,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_15,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_14,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_14,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_15,0) > 0

    UNION ALL

    -- ── Slot 16 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_16,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_16)                               AS `Component`,
        LEFT(begin_16,5)                             AS `Start`,
        COALESCE(LEFT(begin_15,5),LEFT(time_end,5)) AS `End`,
        moulded_16 AS `Moulded`, poured_16 AS `Poured`, waste_16 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_16,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_16,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_16                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_16),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_15,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_16,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_15,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_15,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_16,0) > 0

    UNION ALL

    -- ── Slot 17 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_17,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_17)                               AS `Component`,
        LEFT(begin_17,5)                             AS `Start`,
        COALESCE(LEFT(begin_16,5),LEFT(time_end,5)) AS `End`,
        moulded_17 AS `Moulded`, poured_17 AS `Poured`, waste_17 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_17,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_17,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_17                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_17),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_16,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_17,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_16,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_16,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_17,0) > 0

    UNION ALL

    -- ── Slot 18 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_18,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_18)                               AS `Component`,
        LEFT(begin_18,5)                             AS `Start`,
        COALESCE(LEFT(begin_17,5),LEFT(time_end,5)) AS `End`,
        moulded_18 AS `Moulded`, poured_18 AS `Poured`, waste_18 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_18,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_18,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_18                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_18),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_17,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_18,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_17,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_17,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_18,0) > 0

    UNION ALL

    -- ── Slot 19 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_19,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_19)                               AS `Component`,
        LEFT(begin_19,5)                             AS `Start`,
        COALESCE(LEFT(begin_18,5),LEFT(time_end,5)) AS `End`,
        moulded_19 AS `Moulded`, poured_19 AS `Poured`, waste_19 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_19,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_19,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_19                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_19),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_18,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_19,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_18,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_18,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_19,0) > 0

    UNION ALL

    -- ── Slot 20 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_20,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_20)                               AS `Component`,
        LEFT(begin_20,5)                             AS `Start`,
        COALESCE(LEFT(begin_19,5),LEFT(time_end,5)) AS `End`,
        moulded_20 AS `Moulded`, poured_20 AS `Poured`, waste_20 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_20,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_20,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_20                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_20),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_19,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_20,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_19,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_19,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_20,0) > 0

    UNION ALL

    -- ── Slot 21 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_21,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_21)                               AS `Component`,
        LEFT(begin_21,5)                             AS `Start`,
        COALESCE(LEFT(begin_20,5),LEFT(time_end,5)) AS `End`,
        moulded_21 AS `Moulded`, poured_21 AS `Poured`, waste_21 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_21,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_21,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_21                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_21),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_20,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_21,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_20,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_20,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_21,0) > 0

    UNION ALL

    -- ── Slot 22 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_22,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_22)                               AS `Component`,
        LEFT(begin_22,5)                             AS `Start`,
        COALESCE(LEFT(begin_21,5),LEFT(time_end,5)) AS `End`,
        moulded_22 AS `Moulded`, poured_22 AS `Poured`, waste_22 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_22,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_22,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_22                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_22),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_21,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_22,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_21,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_21,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_22,0) > 0

    UNION ALL

    -- ── Slot 23 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_23,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_23)                               AS `Component`,
        LEFT(begin_23,5)                             AS `Start`,
        COALESCE(LEFT(begin_22,5),LEFT(time_end,5)) AS `End`,
        moulded_23 AS `Moulded`, poured_23 AS `Poured`, waste_23 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_23,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_23,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_23                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_23),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_22,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_23,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_22,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_22,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_23,0) > 0

    UNION ALL

    -- ── Slot 24 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_24,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_24)                               AS `Component`,
        LEFT(begin_24,5)                             AS `Start`,
        COALESCE(LEFT(begin_23,5),LEFT(time_end,5)) AS `End`,
        moulded_24 AS `Moulded`, poured_24 AS `Poured`, waste_24 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_24,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_24,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_24                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_24),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_23,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_24,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_23,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_23,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_24,0) > 0

    UNION ALL

    -- ── Slot 25 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_25,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_25)                               AS `Component`,
        LEFT(begin_25,5)                             AS `Start`,
        COALESCE(LEFT(begin_24,5),LEFT(time_end,5)) AS `End`,
        moulded_25 AS `Moulded`, poured_25 AS `Poured`, waste_25 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_25,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_25,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_25                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_25),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_24,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_25,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_24,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_24,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_25,0) > 0

    UNION ALL

    -- ── Slot 26 ──────────────────────────────────────────────────────────────
    SELECT
        DATE_FORMAT(
            CASE
                WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 8
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
                THEN STR_TO_DATE(date_begin,'%d.%m.%y')
                ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
            END,'%d-%m-%Y')                         AS `Foundry Date`,
        CASE
            WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_26,2) AS UNSIGNED) < 16 THEN 'A'
            WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 16  THEN 'B'
            ELSE 'C'
        END                                          AS `Shift`,
        TRIM(titel_26)                               AS `Component`,
        LEFT(begin_26,5)                             AS `Start`,
        COALESCE(LEFT(begin_25,5),LEFT(time_end,5)) AS `End`,
        moulded_26 AS `Moulded`, poured_26 AS `Poured`, waste_26 AS `Waste`,
        CASE
            WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 8
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            WHEN CAST(LEFT(time_begin,2) AS UNSIGNED) >= 16
            THEN STR_TO_DATE(date_begin,'%d.%m.%y')
            ELSE DATE_SUB(STR_TO_DATE(date_begin,'%d.%m.%y'), INTERVAL 1 DAY)
        END                                          AS _foundry_date,
        CASE
            WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 8
             AND CAST(LEFT(begin_26,2) AS UNSIGNED) < 16 THEN 1
            WHEN CAST(LEFT(begin_26,2) AS UNSIGNED) >= 16  THEN 2
            ELSE 3
        END                                          AS _shift_order,
        begin_26                                     AS _sort_begin,
        STR_TO_DATE(CONCAT(date_begin,' ',begin_26),'%d.%m.%y %H:%i:%s')
                                                     AS _start_dt,
        CASE
            WHEN CAST(LEFT(COALESCE(begin_25,time_end),2) AS UNSIGNED) < CAST(LEFT(begin_26,2) AS UNSIGNED)
            THEN DATE_ADD(STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_25,time_end)),'%d.%m.%y %H:%i:%s'), INTERVAL 1 DAY)
            ELSE STR_TO_DATE(CONCAT(date_begin,' ',COALESCE(begin_25,time_end)),'%d.%m.%y %H:%i:%s')
        END                                          AS _end_dt
    FROM aiw_data.production_data_new
    WHERE COALESCE(moulded_26,0) > 0

    ) AS t
    WHERE _foundry_date >= CURDATE() - INTERVAL 2 DAY
),

-- ── Step 2: Split slots that cross shift boundaries ───────────────────────────
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

    SELECT DATE_FORMAT(DATE(_start_dt),'%d-%m-%Y') AS `Foundry Date`, 'A' AS `Shift`,
        `Component`, `Start`, '16:00' AS `End`,
        ROUND(`Moulded`*TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)) AS `Moulded`,
        ROUND(`Poured` *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)) AS `Poured`,
        ROUND(`Waste`  *TIMESTAMPDIFF(MINUTE,_start_dt,TIMESTAMP(DATE(_start_dt),'16:00:00'))/NULLIF(TIMESTAMPDIFF(MINUTE,_start_dt,_end_dt),0)) AS `Waste`,
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

-- ── Step 3: Parse additive table — GOOD rows only, for AVG ───────────────────
additive_parsed AS (
    SELECT
        STR_TO_DATE(mem_date_time, '%d.%m.%Y %H:%i:%s') AS _mem_dt,
        comp_3 / 10  AS bentonite,   -- Bentonite Kg/batch
        comp_2       AS new_sand,    -- New Sand  Kg/batch
        comp_5 / 10  AS lca,         -- LCA       Kg/batch
        water  / 10  AS water        -- Water     Ltr/batch
    FROM aiw_data.`Additive Consumption Data New`
    WHERE type = 'GOOD'
),

-- ── Step 3.5: Component ID lookup ────────────────────────────────────────────
component_map AS (
    SELECT
        TRIM(Component)           AS component_name,
        CAST(ComponentID AS CHAR) AS component_id
    FROM aiw_data.Component_MapN
),

-- ── Step 4: Join additive rows to slots + LATERAL batch counts ────────────────
-- Window functions (ROW_NUMBER, COUNT OVER) removed — no longer needed for AVG
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

        -- ── Batch counts (GOOD + BAD) via LATERAL — no Cartesian risk ────────
        bc.no_of_batches,
        bc.bad_batches

    FROM split_slots ps

    -- GOOD additive rows for AVG
    LEFT JOIN additive_parsed ap
        ON ap._mem_dt BETWEEN ps._start_dt AND ps._end_dt

    -- Counts from raw table so BAD rows are included
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

-- ── Step 5: Final SELECT — AVG of GOOD batches + batch counts ────────────────
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
    ROUND(AVG(bentonite), 2)    AS `Bentonite`,   -- AVG of GOOD batches in slot
    ROUND(AVG(new_sand),  2)    AS `New Sand`,
    ROUND(AVG(lca),       2)    AS `LCA`,
    ROUND(AVG(water),     2)    AS `Water`,
    MAX(no_of_batches)          AS `No of Batches`, -- total GOOD + BAD in slot
    MAX(bad_batches)            AS `Bad Batch`       -- only type='BAD' in slot

FROM slot_additive

GROUP BY
    `Foundry Date`, `Shift`, `Component`, `ComponentID`, `Start`, `End`,
    `Moulded`, `Poured`, `Waste`,
    _foundry_date, _shift_order, _sort_begin

ORDER BY
    _foundry_date  ASC,
    _shift_order   ASC,
    _sort_begin    ASC;