-- ============================================================================
-- SCRIPT: 08_matviews.sql
-- PURPOSE: Create 3 materialized views for AURIXA
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 8 (Materialized Views)
-- ============================================================================
--
-- MATERIALIZED VIEWS:
-- 1. MV_USER_MONTHLY_SUMMARY - Dashboard home screen data
-- 2. MV_CATEGORY_SPEND       - BehaviorLens donut and bar charts
-- 3. MV_HEALTH_SCORE_TREND   - ScoreCore 6-month trend line
--
-- REFRESH: Complete refresh on demand (scheduled nightly by JOB_REFRESH_MVS)
-- PURPOSE: Pre-compute heavy aggregations for fast dashboard queries
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating 3 Materialized Views for AURIXA
PROMPT Reference: Section 8 of Technical Documentation
PROMPT ============================================================================

-- ============================================================================
-- MATERIALIZED VIEW 1: MV_USER_MONTHLY_SUMMARY
-- Purpose: Dashboard home screen - shows monthly subscription spend summary
-- Reference: Section 8.1
-- ============================================================================

PROMPT Creating MV_USER_MONTHLY_SUMMARY...

CREATE MATERIALIZED VIEW MV_USER_MONTHLY_SUMMARY
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    s.user_id,
    TRUNC(bc.billing_date, 'MM') AS report_month,
    SUM(bc.amount_charged) AS total_subscription_spend,
    COUNT(DISTINCT bc.sub_id) AS active_sub_count,
    AVG(bc.amount_charged) AS avg_subscription_cost
FROM BILLING_CYCLES bc 
JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
GROUP BY s.user_id, TRUNC(bc.billing_date, 'MM');

PROMPT ✓ MV_USER_MONTHLY_SUMMARY created

-- ============================================================================
-- MATERIALIZED VIEW 2: MV_CATEGORY_SPEND
-- Purpose: BehaviorLens - category breakdown for donut and bar charts
-- Reference: Section 8.2
-- ============================================================================

PROMPT Creating MV_CATEGORY_SPEND...

CREATE MATERIALIZED VIEW MV_CATEGORY_SPEND
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    s.user_id, 
    s.category_id, 
    ec.name AS category_name,
    TRUNC(bc.billing_date, 'MM') AS spend_month,
    SUM(bc.amount_charged) AS total_amount,
    COUNT(bc.cycle_id) AS payment_count
FROM BILLING_CYCLES bc
JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
JOIN EXPENSE_CATEGORIES ec ON s.category_id = ec.category_id
GROUP BY s.user_id, s.category_id, ec.name, TRUNC(bc.billing_date, 'MM');

PROMPT ✓ MV_CATEGORY_SPEND created

-- ============================================================================
-- MATERIALIZED VIEW 3: MV_HEALTH_SCORE_TREND
-- Purpose: ScoreCore - 6-month health score trend line
-- Reference: Section 8.3
-- ============================================================================

PROMPT Creating MV_HEALTH_SCORE_TREND...

CREATE MATERIALIZED VIEW MV_HEALTH_SCORE_TREND
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    user_id,
    TRUNC(score_date, 'MM') AS score_month,
    ROUND(AVG(financial_health_score), 2) AS avg_score,
    MAX(financial_health_score) AS peak_score,
    MIN(financial_health_score) AS low_score
FROM FINANCIAL_SCORES
WHERE score_date >= ADD_MONTHS(SYSDATE, -6)
GROUP BY user_id, TRUNC(score_date, 'MM');

PROMPT ✓ MV_HEALTH_SCORE_TREND created

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - All Materialized Views Created
PROMPT ============================================================================

SELECT mview_name, refresh_mode, refresh_method, last_refresh_date
FROM user_mviews
ORDER BY mview_name;

PROMPT
PROMPT ============================================================================
PROMPT View Definitions
PROMPT ============================================================================

-- View 1: MV_USER_MONTHLY_SUMMARY structure
PROMPT MV_USER_MONTHLY_SUMMARY columns:
SELECT column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'MV_USER_MONTHLY_SUMMARY'
ORDER BY column_id;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 08_matviews.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Materialized Views created (3):
PROMPT   1. MV_USER_MONTHLY_SUMMARY  - Monthly spend summary for dashboard
PROMPT   2. MV_CATEGORY_SPEND        - Category spending for BehaviorLens
PROMPT   3. MV_HEALTH_SCORE_TREND    - 6-month health trend for ScoreCore
PROMPT
PROMPT Note: All views are empty until data is loaded.
PROMPT       They will be refreshed nightly by JOB_REFRESH_MVS (script 09)
PROMPT
PROMPT Next: Run 09_scheduler_jobs.sql
PROMPT
PROMPT ============================================================================

COMMIT;