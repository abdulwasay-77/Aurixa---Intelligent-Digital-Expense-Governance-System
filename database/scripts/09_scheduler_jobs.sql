-- ============================================================================
-- SCRIPT: 09_scheduler_jobs.sql
-- PURPOSE: Create 7 Oracle Scheduler Jobs for automated background tasks
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 9 (Oracle Scheduler Jobs)
-- ============================================================================
--
-- SCHEDULER JOBS:
-- 1. JOB_DAILY_HEALTH_SCORE    - Daily 00:30 - Calculate financial health scores
-- 2. JOB_NIGHTLY_FORECAST      - Nightly 01:00 - Predict monthly expenses
-- 3. JOB_WEEKLY_RECOMMENDATIONS - Sunday 02:00 - Generate AI recommendations
-- 4. JOB_REFRESH_MVS           - Nightly 03:00 - Refresh materialized views
-- 5. JOB_BILLING_SCAN          - Daily 08:00 - Create scheduled billing cycles
-- 6. JOB_IDLE_DETECTION        - Monday 06:00 - Detect idle subscriptions
-- 7. JOB_ANNUAL_FORECAST       - 1st of month 04:00 - Generate annual forecast
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating 7 Oracle Scheduler Jobs for AURIXA
PROMPT Reference: Section 9 of Technical Documentation
PROMPT ============================================================================

-- ============================================================================
-- JOB 1: JOB_DAILY_HEALTH_SCORE
-- Schedule: Daily at 00:30
-- Purpose: Calculate financial health score for all active users
-- Calls: AURIXA_ANALYTICS.CALCULATE_FINANCIAL_HEALTH
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_DAILY_HEALTH_SCORE...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_DAILY_HEALTH_SCORE',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR u IN (SELECT user_id FROM USERS WHERE status = ''ACTIVE'') LOOP
                AURIXA_ANALYTICS.CALCULATE_FINANCIAL_HEALTH(u.user_id);
            END LOOP;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=30',
        enabled => TRUE,
        comments => 'Daily financial health score calculation for all active users'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_DAILY_HEALTH_SCORE created');
END;
/

-- ============================================================================
-- JOB 2: JOB_NIGHTLY_FORECAST
-- Schedule: Nightly at 01:00
-- Purpose: Predict monthly expenses using spend velocity
-- Calls: AURIXA_ANALYTICS.PREDICT_MONTHLY_EXPENSES
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_NIGHTLY_FORECAST...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_NIGHTLY_FORECAST',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR u IN (SELECT user_id FROM USERS WHERE status = ''ACTIVE'') LOOP
                AURIXA_ANALYTICS.PREDICT_MONTHLY_EXPENSES(u.user_id);
            END LOOP;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=1; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Nightly expense forecast using spend velocity'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_NIGHTLY_FORECAST created');
END;
/

-- ============================================================================
-- JOB 3: JOB_WEEKLY_RECOMMENDATIONS
-- Schedule: Every Sunday at 02:00
-- Purpose: Generate smart recommendations for all users
-- Calls: AURIXA_ANALYTICS.GENERATE_SMART_RECOMMENDATIONS
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_WEEKLY_RECOMMENDATIONS...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_WEEKLY_RECOMMENDATIONS',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR u IN (SELECT user_id FROM USERS WHERE status = ''ACTIVE'') LOOP
                AURIXA_ANALYTICS.GENERATE_SMART_RECOMMENDATIONS(u.user_id);
            END LOOP;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=2; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Weekly AI-style recommendations for all active users'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_WEEKLY_RECOMMENDATIONS created');
END;
/

-- ============================================================================
-- JOB 4: JOB_REFRESH_MVS
-- Schedule: Nightly at 03:00
-- Purpose: Refresh all materialized views
-- Calls: DBMS_MVIEW.REFRESH
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_REFRESH_MVS...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_REFRESH_MVS',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            DBMS_MVIEW.REFRESH(''MV_USER_MONTHLY_SUMMARY'', ''C'');
            DBMS_MVIEW.REFRESH(''MV_CATEGORY_SPEND'', ''C'');
            DBMS_MVIEW.REFRESH(''MV_HEALTH_SCORE_TREND'', ''C'');
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Nightly refresh of all AURIXA materialized views'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_REFRESH_MVS created');
END;
/

-- ============================================================================
-- JOB 5: JOB_BILLING_SCAN
-- Schedule: Daily at 08:00
-- Purpose: Find subscriptions with next_billing_date = today and create billing cycles
-- Calls: Direct INSERT into BILLING_CYCLES
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_BILLING_SCAN...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_BILLING_SCAN',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR sub IN (SELECT sub_id, billing_amount, next_billing_date 
                        FROM SUBSCRIPTIONS 
                        WHERE status = ''ACTIVE'' 
                        AND TRUNC(next_billing_date) = TRUNC(SYSDATE)) 
            LOOP
                INSERT INTO BILLING_CYCLES
                (cycle_id, sub_id, billing_date, amount_charged, status, created_at)
                VALUES
                (SEQ_BILLING_CYCLES.NEXTVAL, sub.sub_id, sub.next_billing_date, 
                 sub.billing_amount, ''SCHEDULED'', SYSDATE);
            END LOOP;
            COMMIT;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=8; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Daily scan to create billing cycles for subscriptions due today'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_BILLING_SCAN created');
END;
/

-- ============================================================================
-- JOB 6: JOB_IDLE_DETECTION
-- Schedule: Every Monday at 06:00
-- Purpose: Detect idle subscriptions and create behavioral signals
-- Calls: AURIXA_ANALYTICS.PROCESS_IDLE_SUBSCRIPTIONS
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_IDLE_DETECTION...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_IDLE_DETECTION',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR u IN (SELECT user_id FROM USERS WHERE status = ''ACTIVE'') LOOP
                AURIXA_ANALYTICS.PROCESS_IDLE_SUBSCRIPTIONS(u.user_id);
            END LOOP;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=MON; BYHOUR=6; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Weekly detection of idle and low-usage subscriptions'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_IDLE_DETECTION created');
END;
/

-- ============================================================================
-- JOB 7: JOB_ANNUAL_FORECAST
-- Schedule: 1st day of each month at 04:00
-- Purpose: Generate 12-month spending forecast
-- Calls: AURIXA_ANALYTICS.GENERATE_ANNUAL_FORECAST
-- Reference: Section 9
-- ============================================================================

PROMPT Creating JOB_ANNUAL_FORECAST...

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_ANNUAL_FORECAST',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN
            FOR u IN (SELECT user_id FROM USERS WHERE status = ''ACTIVE'') LOOP
                AURIXA_ANALYTICS.GENERATE_ANNUAL_FORECAST(u.user_id);
            END LOOP;
        END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=4; BYMINUTE=0',
        enabled => TRUE,
        comments => 'Monthly generation of 12-month spending forecast'
    );
    DBMS_OUTPUT.PUT_LINE('✓ JOB_ANNUAL_FORECAST created');
END;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - All Scheduler Jobs Created
PROMPT ============================================================================

SELECT job_name, enabled, state, last_start_date, next_run_date
FROM user_scheduler_jobs
ORDER BY job_name;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 09_scheduler_jobs.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Scheduler Jobs created (7):
PROMPT   1. JOB_DAILY_HEALTH_SCORE    - Daily 00:30 - Health scores
PROMPT   2. JOB_NIGHTLY_FORECAST      - Daily 01:00 - Spend forecast
PROMPT   3. JOB_WEEKLY_RECOMMENDATIONS - Sunday 02:00 - AI recommendations
PROMPT   4. JOB_REFRESH_MVS           - Daily 03:00 - Refresh views
PROMPT   5. JOB_BILLING_SCAN          - Daily 08:00 - Create billing cycles
PROMPT   6. JOB_IDLE_DETECTION        - Monday 06:00 - Idle detection
PROMPT   7. JOB_ANNUAL_FORECAST       - 1st of month 04:00 - 12-month forecast
PROMPT
PROMPT All jobs are ENABLED and will run automatically on schedule.
PROMPT
PROMPT Next: Run 10_indexes.sql
PROMPT
PROMPT ============================================================================

COMMIT;