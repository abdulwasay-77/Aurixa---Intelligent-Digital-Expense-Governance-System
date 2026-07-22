-- ============================================================================
-- SCRIPT: 05_package_spec.sql
-- PURPOSE: Create AURIXA_ANALYTICS Package Specification (Public Interface)
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 7.1 (Package Specification)
-- ============================================================================
--
-- PACKAGE: AURIXA_ANALYTICS
-- DESCRIPTION: All core business logic for AURIXA platform
--              This is the BRAIN of AURIXA as per Golden Rule:
--              "Oracle computes. Python narrates. Flutter displays."
--
-- PUBLIC INTERFACE:
--   TYPE t_financial_summary  - Record type for financial health scores
--   FUNCTION GET_MONTHLY_SPEND - Returns total spend for a user/month
--   FUNCTION IS_BUDGET_BREACHED - Returns 1 if budget exceeded, else 0
--   PROCEDURE CALCULATE_FINANCIAL_HEALTH - Computes 0-100 health score
--   PROCEDURE PREDICT_MONTHLY_EXPENSES - Spend velocity forecasting
--   PROCEDURE GENERATE_SMART_RECOMMENDATIONS - AI-style recommendations
--   PROCEDURE GENERATE_BILLING_SCHEDULE - Creates future billing cycles
--   PROCEDURE GENERATE_ANNUAL_FORECAST - 12-month spending projection
--   PROCEDURE PROCESS_IDLE_SUBSCRIPTIONS - Detects low-usage subscriptions
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating AURIXA_ANALYTICS Package Specification
PROMPT Reference: Section 7.1 of Technical Documentation
PROMPT ============================================================================

CREATE OR REPLACE PACKAGE AURIXA_ANALYTICS AS

    -- ========================================================================
    -- USER-DEFINED RECORD TYPE
    -- Groups all financial health sub-scores into one composite type
    -- Reference: Section 7.1, used in CALCULATE_FINANCIAL_HEALTH
    -- ========================================================================
    
    TYPE t_financial_summary IS RECORD (
        health_score        NUMBER(5,2),    -- Composite score 0-100
        score_label         VARCHAR2(20),   -- EXCELLENT/GOOD/FAIR/POOR/CRITICAL
        savings_rate        NUMBER(5,2),    -- Savings rate sub-score
        budget_disc         NUMBER(5,2),    -- Budget discipline sub-score
        sub_dep_ratio       NUMBER(5,2),    -- Subscription dependency ratio
        risk_factor         NUMBER(5,2),    -- Risk factor sub-score
        days_to_breach      NUMBER          -- Days until budget exceeds limit
    );
    
    -- ========================================================================
    -- FUNCTIONS (Return values usable from Python via python-oracledb)
    -- Note: Return NUMBER not BOOLEAN because BOOLEAN cannot be called from Python
    -- Reference: Section 7.1
    -- ========================================================================
    
    -- FUNCTION 1: GET_MONTHLY_SPEND
    -- Description: Returns total subscription spend for a specific user and month
    -- Parameters:
    --   p_user_id - User identifier
    --   p_month   - Month to calculate spend for (DATE, truncated to month)
    -- Returns: Total amount spent on subscriptions for that month
    -- Example: SELECT AURIXA_ANALYTICS.GET_MONTHLY_SPEND(1, SYSDATE) FROM DUAL;
    
    FUNCTION GET_MONTHLY_SPEND(p_user_id IN NUMBER, p_month IN DATE) RETURN NUMBER;
    
    -- FUNCTION 2: IS_BUDGET_BREACHED
    -- Description: Checks if user has exceeded their monthly budget
    -- Parameters:
    --   p_user_id - User identifier
    -- Returns: 1 if budget breached, 0 if within budget
    -- Note: Returns NUMBER because Oracle BOOLEAN cannot be used in SQL directly
    
    FUNCTION IS_BUDGET_BREACHED(p_user_id IN NUMBER) RETURN NUMBER;
    
    -- ========================================================================
    -- PROCEDURES
    -- Reference: Section 7.1
    -- ========================================================================
    
    -- PROCEDURE 1: CALCULATE_FINANCIAL_HEALTH
    -- Description: Computes daily financial health score (0-100) for a user
    --              Uses four sub-scores: savings rate, budget discipline,
    --              subscription dependency ratio, and risk factor
    -- Parameters:
    --   p_user_id - User identifier
    -- Called by: JOB_DAILY_HEALTH_SCORE (Section 9)
    -- Writes to: FINANCIAL_SCORES table
    
    PROCEDURE CALCULATE_FINANCIAL_HEALTH(p_user_id IN NUMBER);
    
    -- PROCEDURE 2: PREDICT_MONTHLY_EXPENSES
    -- Description: Uses spend velocity to forecast month-end total and breach date
    -- Parameters:
    --   p_user_id - User identifier
    -- Called by: JOB_NIGHTLY_FORECAST (Section 9)
    -- Writes to: BUDGET_FORECASTS table
    
    PROCEDURE PREDICT_MONTHLY_EXPENSES(p_user_id IN NUMBER);
    
    -- PROCEDURE 3: GENERATE_SMART_RECOMMENDATIONS
    -- Description: Analyzes active subscriptions and generates optimization suggestions
    --              Types: CANCEL, DOWNGRADE, YEARLY_PLAN, CONSOLIDATE, ALTERNATIVE
    -- Parameters:
    --   p_user_id - User identifier
    -- Called by: JOB_WEEKLY_RECOMMENDATIONS (Section 9)
    -- Writes to: AI_RECOMMENDATIONS table
    
    PROCEDURE GENERATE_SMART_RECOMMENDATIONS(p_user_id IN NUMBER);
    
    -- PROCEDURE 4: GENERATE_BILLING_SCHEDULE
    -- Description: Pre-generates future billing cycles for a subscription
    --              Uses WHILE loop to create entries up to p_months ahead
    -- Parameters:
    --   p_sub_id  - Subscription identifier
    --   p_months  - Number of months to generate (default: 12)
    -- Called by: POST /subscriptions endpoint after subscription creation
    -- Writes to: BILLING_CYCLES table
    
    PROCEDURE GENERATE_BILLING_SCHEDULE(p_sub_id IN NUMBER, p_months IN NUMBER DEFAULT 12);
    
    -- PROCEDURE 5: GENERATE_ANNUAL_FORECAST
    -- Description: Projects spending for next 12 months using historical data
    -- Parameters:
    --   p_user_id - User identifier
    -- Called by: JOB_ANNUAL_FORECAST (Section 9) - 1st of each month
    -- Writes to: BUDGET_FORECASTS table with model_version='ANNUAL_V1'
    
    PROCEDURE GENERATE_ANNUAL_FORECAST(p_user_id IN NUMBER);
    
    -- PROCEDURE 6: PROCESS_IDLE_SUBSCRIPTIONS
    -- Description: Identifies low-usage subscriptions and creates behavioral signals
    --              Uses OPEN/FETCH/CLOSE cursor pattern with CASE classification
    -- Parameters:
    --   p_user_id - User identifier
    -- Called by: JOB_IDLE_DETECTION (Section 9) - Every Monday
    -- Writes to: BEHAVIORAL_SIGNALS table
    
    PROCEDURE PROCESS_IDLE_SUBSCRIPTIONS(p_user_id IN NUMBER);

END AURIXA_ANALYTICS;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - Package Specification Created
PROMPT ============================================================================

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'AURIXA_ANALYTICS'
AND object_type IN ('PACKAGE', 'PACKAGE BODY');

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 05_package_spec.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Package AURIXA_ANALYTICS specification created.
PROMPT
PROMPT Public interface includes:
PROMPT   - 1 Type (t_financial_summary)
PROMPT   - 2 Functions (GET_MONTHLY_SPEND, IS_BUDGET_BREACHED)
PROMPT   - 7 Procedures (all core business logic)
PROMPT
PROMPT Next: Run 06_package_body.sql (implementation)
PROMPT
PROMPT ============================================================================

COMMIT;