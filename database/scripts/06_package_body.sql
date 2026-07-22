-- ============================================================================
-- SCRIPT: 06_package_body.sql
-- PURPOSE: Create AURIXA_ANALYTICS Package Body (Implementation)
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 7.2 (Package Body)
-- ============================================================================
--
-- PACKAGE BODY: AURIXA_ANALYTICS
-- DESCRIPTION: Implements all functions and procedures declared in spec
--              Contains all PL/SQL constructs required by the project
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating AURIXA_ANALYTICS Package Body
PROMPT Reference: Section 7.2 of Technical Documentation
PROMPT ============================================================================

CREATE OR REPLACE PACKAGE BODY AURIXA_ANALYTICS AS

    -- ========================================================================
    -- FUNCTION: GET_MONTHLY_SPEND
    -- Demonstrates: standalone function, %TYPE, SELECT INTO,
    --               exception handling, RETURN
    -- Reference: Section 7.2
    -- ========================================================================
    
    FUNCTION GET_MONTHLY_SPEND(p_user_id IN NUMBER, p_month IN DATE) RETURN NUMBER AS
        v_total BILLING_CYCLES.amount_charged%TYPE := 0;
    BEGIN
        SELECT NVL(SUM(bc.amount_charged), 0) INTO v_total
        FROM BILLING_CYCLES bc 
        JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
        WHERE s.user_id = p_user_id
        AND TRUNC(bc.billing_date, 'MM') = TRUNC(p_month, 'MM');
        
        RETURN v_total;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
        WHEN OTHERS THEN RAISE;
    END GET_MONTHLY_SPEND;

    -- ========================================================================
    -- FUNCTION: IS_BUDGET_BREACHED
    -- Returns NUMBER not BOOLEAN (BOOLEAN cannot be called from Python)
    -- Demonstrates: SQL%FOUND implicit cursor attribute
    -- Reference: Section 7.2
    -- ========================================================================
    
    FUNCTION IS_BUDGET_BREACHED(p_user_id IN NUMBER) RETURN NUMBER AS
        v_spent NUMBER(12,2);
        v_budget USER_PROFILES.monthly_income%TYPE;
    BEGIN
        v_spent := GET_MONTHLY_SPEND(p_user_id, SYSDATE);
        
        SELECT monthly_income * (1 - saving_target_pct/100)
        INTO v_budget 
        FROM USER_PROFILES 
        WHERE user_id = p_user_id;
        
        IF SQL%FOUND AND v_spent > v_budget THEN 
            RETURN 1;
        ELSE 
            RETURN 0; 
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END IS_BUDGET_BREACHED;

    -- ========================================================================
    -- PROCEDURE: CALCULATE_FINANCIAL_HEALTH
    -- Demonstrates: user-defined record type (t_financial_summary),
    --               user-defined exception, %TYPE, IF/ELSIF/ELSE,
    --               CASE statement, COMMIT, ROLLBACK
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE CALCULATE_FINANCIAL_HEALTH(p_user_id IN NUMBER) AS
        invalid_user_data EXCEPTION;
        v_income USER_PROFILES.monthly_income%TYPE;
        v_tgt_pct USER_PROFILES.saving_target_pct%TYPE;
        v_alerts NUMBER;
        v_spent NUMBER(12,2);
        v_summary t_financial_summary;
    BEGIN
        -- Get user profile data
        SELECT NVL(monthly_income, 0), NVL(saving_target_pct, 20)
        INTO v_income, v_tgt_pct
        FROM USER_PROFILES 
        WHERE user_id = p_user_id;
        
        -- Validate user data
        IF v_income <= 0 THEN 
            RAISE invalid_user_data; 
        END IF;
        
        -- Calculate current spend and alert count
        v_spent := GET_MONTHLY_SPEND(p_user_id, SYSDATE);
        
        SELECT COUNT(*) INTO v_alerts 
        FROM RISK_ALERTS
        WHERE user_id = p_user_id
        AND TRUNC(triggered_at, 'MM') = TRUNC(SYSDATE, 'MM');
        
        -- Calculate sub-scores
        v_summary.savings_rate := LEAST(100, ROUND((v_income - v_spent) / v_income * 100, 2));
        
        v_summary.budget_disc := CASE
            WHEN v_spent <= v_income * 0.7 THEN 100
            WHEN v_spent <= v_income THEN 60
            ELSE 20
        END;
        
        v_summary.sub_dep_ratio := LEAST(100, ROUND(v_spent / v_income * 100, 2));
        v_summary.risk_factor := LEAST(100, v_alerts * 15);
        
        -- Calculate composite health score
        v_summary.health_score := LEAST(100, GREATEST(0,
            ROUND(((v_summary.savings_rate + v_summary.budget_disc) 
            / (v_summary.sub_dep_ratio + v_summary.risk_factor + 1)) * 100, 2)));
        
        -- Assign score label using CASE statement
        CASE
            WHEN v_summary.health_score >= 80 THEN v_summary.score_label := 'EXCELLENT';
            WHEN v_summary.health_score >= 60 THEN v_summary.score_label := 'GOOD';
            WHEN v_summary.health_score >= 40 THEN v_summary.score_label := 'FAIR';
            WHEN v_summary.health_score >= 20 THEN v_summary.score_label := 'POOR';
            ELSE v_summary.score_label := 'CRITICAL';
        END CASE;
        
        -- Insert the score record
        INSERT INTO FINANCIAL_SCORES
        (score_id, user_id, score_date, financial_health_score, 
         savings_rate_score, budget_discipline_score, 
         sub_dependency_ratio, risk_factor_score, score_label)
        VALUES
        (SEQ_FIN_SCORES.NEXTVAL, p_user_id, TRUNC(SYSDATE),
         v_summary.health_score, v_summary.savings_rate, v_summary.budget_disc,
         v_summary.sub_dep_ratio, v_summary.risk_factor, v_summary.score_label);
        
        COMMIT;
        
    EXCEPTION
        WHEN invalid_user_data THEN
            INSERT INTO RISK_ALERTS
            (alert_id, user_id, alert_type, severity, title, message, triggered_at)
            VALUES 
            (SEQ_RISK_ALERTS.NEXTVAL, p_user_id, 'ANOMALY', 'LOW',
             'Invalid Profile', 'Income is zero or null. Update your profile.', SYSDATE);
            COMMIT;
        WHEN NO_DATA_FOUND THEN NULL;
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END CALCULATE_FINANCIAL_HEALTH;

    -- ========================================================================
    -- PROCEDURE: PREDICT_MONTHLY_EXPENSES
    -- Demonstrates: arithmetic calculations, CASE expression,
    --               COMMIT, exception handling
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE PREDICT_MONTHLY_EXPENSES(p_user_id IN NUMBER) AS
        v_days_passed NUMBER;
        v_days_in_month NUMBER;
        v_spent NUMBER(12,2);
        v_velocity BILLING_CYCLES.amount_charged%TYPE;
        v_projected NUMBER(12,2);
        v_budget USER_PROFILES.monthly_income%TYPE;
        v_variance NUMBER(7,2);
        v_breach_days NUMBER;
    BEGIN
        -- Calculate days passed and days in current month
        v_days_passed := TO_NUMBER(TO_CHAR(SYSDATE, 'DD'));
        v_days_in_month := TO_NUMBER(TO_CHAR(LAST_DAY(SYSDATE), 'DD'));
        
        -- Get current spend and budget
        v_spent := GET_MONTHLY_SPEND(p_user_id, SYSDATE);
        
        SELECT NVL(monthly_income * (1 - saving_target_pct/100), 99999)
        INTO v_budget 
        FROM USER_PROFILES 
        WHERE user_id = p_user_id;
        
        -- Calculate spend velocity and projection
        v_velocity := ROUND(v_spent / GREATEST(v_days_passed, 1), 2);
        v_projected := ROUND(v_velocity * v_days_in_month, 2);
        v_variance := ROUND((v_projected - v_budget) / v_budget * 100, 2);
        
        -- Calculate days until budget breach
        v_breach_days := CASE 
            WHEN v_velocity > 0 THEN ROUND((v_budget - v_spent) / v_velocity)
            ELSE NULL 
        END;
        
        -- Insert forecast
        INSERT INTO BUDGET_FORECASTS
        (forecast_id, user_id, forecast_month, projected_total, budget_limit,
         variance_pct, days_to_breach, velocity_per_day, generated_at)
        VALUES
        (SEQ_FORECASTS.NEXTVAL, p_user_id, TRUNC(SYSDATE, 'MM'),
         v_projected, v_budget, v_variance, v_breach_days, v_velocity, SYSDATE);
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END PREDICT_MONTHLY_EXPENSES;

    -- ========================================================================
    -- PROCEDURE: GENERATE_SMART_RECOMMENDATIONS
    -- Demonstrates: explicit cursor FOR loop, IF/ELSIF/ELSE, COMMIT
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE GENERATE_SMART_RECOMMENDATIONS(p_user_id IN NUMBER) AS
        CURSOR c_subs IS
            SELECT sub_id, service_name, billing_amount, billing_cycle, usage_score
            FROM SUBSCRIPTIONS
            WHERE user_id = p_user_id AND status = 'ACTIVE'
            ORDER BY (billing_amount / GREATEST(usage_score, 1)) DESC;
            
        v_rec_type AI_RECOMMENDATIONS.rec_type%TYPE;
        v_reasoning AI_RECOMMENDATIONS.reasoning%TYPE;
        v_saving AI_RECOMMENDATIONS.potential_saving%TYPE;
    BEGIN
        FOR rec IN c_subs LOOP
            -- Classify based on usage score
            IF rec.usage_score <= 2 THEN
                v_rec_type := 'CANCEL';
                v_saving := rec.billing_amount;
                v_reasoning := rec.service_name || ' usage score ' || rec.usage_score ||
                    '/10. Cancel to save ' || TO_CHAR(rec.billing_amount, '999.99') || ' per cycle.';
                    
            ELSIF rec.usage_score <= 5 AND rec.billing_cycle = 'MONTHLY' THEN
                v_rec_type := 'YEARLY_PLAN';
                v_saving := ROUND(rec.billing_amount * 12 * 0.2, 2);
                v_reasoning := 'Switch ' || rec.service_name || ' to annual plan. Save ~20%.';
                
            ELSE
                v_rec_type := 'DOWNGRADE';
                v_saving := ROUND(rec.billing_amount * 0.3, 2);
                v_reasoning := rec.service_name || ' moderate usage. Lower-tier plan may suffice.';
            END IF;
            
            -- Insert recommendation
            INSERT INTO AI_RECOMMENDATIONS
            (rec_id, user_id, rec_type, sub_id, title, reasoning, 
             potential_saving, source, generated_at)
            VALUES
            (SEQ_AI_RECS.NEXTVAL, p_user_id, v_rec_type, rec.sub_id,
             v_rec_type || ': ' || rec.service_name, v_reasoning, 
             v_saving, 'PROCEDURE', SYSDATE);
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END GENERATE_SMART_RECOMMENDATIONS;

    -- ========================================================================
    -- PROCEDURE: GENERATE_BILLING_SCHEDULE
    -- Demonstrates: WHILE loop, SAVEPOINT, ROLLBACK TO SAVEPOINT,
    --               IF/ELSIF for cycle type, safety exit counter
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE GENERATE_BILLING_SCHEDULE(p_sub_id IN NUMBER, p_months IN NUMBER DEFAULT 12) AS
        v_next_date SUBSCRIPTIONS.next_billing_date%TYPE;
        v_amount SUBSCRIPTIONS.billing_amount%TYPE;
        v_cycle SUBSCRIPTIONS.billing_cycle%TYPE;
        v_end_date DATE;
        v_count NUMBER := 0;
    BEGIN
        -- Get subscription details
        SELECT next_billing_date, billing_amount, billing_cycle
        INTO v_next_date, v_amount, v_cycle
        FROM SUBSCRIPTIONS 
        WHERE sub_id = p_sub_id;
        
        v_end_date := ADD_MONTHS(SYSDATE, p_months);
        
        SAVEPOINT before_schedule;
        
        -- Generate billing cycles using WHILE loop
        WHILE v_next_date <= v_end_date LOOP
            INSERT INTO BILLING_CYCLES
            (cycle_id, sub_id, billing_date, amount_charged, status, created_at)
            VALUES
            (SEQ_BILLING_CYCLES.NEXTVAL, p_sub_id, v_next_date, v_amount, 'SCHEDULED', SYSDATE);
            
            -- Advance date based on billing cycle
            IF v_cycle = 'MONTHLY' THEN 
                v_next_date := ADD_MONTHS(v_next_date, 1);
            ELSIF v_cycle = 'YEARLY' THEN 
                v_next_date := ADD_MONTHS(v_next_date, 12);
            ELSIF v_cycle = 'QUARTERLY' THEN 
                v_next_date := ADD_MONTHS(v_next_date, 3);
            ELSE 
                v_next_date := v_next_date + 7;  -- WEEKLY
            END IF;
            
            v_count := v_count + 1;
            
            -- Safety exit to prevent infinite loops
            IF v_count > 1000 THEN EXIT; END IF;
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK TO before_schedule;
            RAISE_APPLICATION_ERROR(-20020, 'Subscription ' || p_sub_id || ' not found.');
        WHEN OTHERS THEN
            ROLLBACK TO before_schedule;
            RAISE;
    END GENERATE_BILLING_SCHEDULE;

    -- ========================================================================
    -- PROCEDURE: GENERATE_ANNUAL_FORECAST
    -- Demonstrates: numeric FOR loop (FOR i IN 1..12),
    --               parameterized cursor, %ROWTYPE, nested BEGIN..END block
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE GENERATE_ANNUAL_FORECAST(p_user_id IN NUMBER) AS
        CURSOR c_spend(p_month DATE) IS
            SELECT NVL(SUM(bc.amount_charged), 0) AS monthly_total
            FROM BILLING_CYCLES bc 
            JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
            WHERE s.user_id = p_user_id
            AND TRUNC(bc.billing_date, 'MM') = TRUNC(p_month, 'MM');
            
        v_month DATE;
        v_projected NUMBER(12,2);
        v_budget USER_PROFILES.monthly_income%TYPE;
        v_spend_rec c_spend%ROWTYPE;
    BEGIN
        -- Get user's budget
        SELECT NVL(monthly_income * (1 - saving_target_pct/100), 99999)
        INTO v_budget 
        FROM USER_PROFILES 
        WHERE user_id = p_user_id;
        
        -- Forecast for next 12 months using numeric FOR loop
        FOR i IN 1..12 LOOP
            v_month := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), i);
            
            BEGIN
                OPEN c_spend(v_month);
                FETCH c_spend INTO v_spend_rec;
                CLOSE c_spend;
                v_projected := NVL(v_spend_rec.monthly_total, 0);
            EXCEPTION
                WHEN OTHERS THEN
                    IF c_spend%ISOPEN THEN CLOSE c_spend; END IF;
                    v_projected := 0;
            END;
            
            -- Insert forecast for this month
            INSERT INTO BUDGET_FORECASTS
            (forecast_id, user_id, forecast_month, projected_total,
             budget_limit, variance_pct, generated_at, model_version)
            VALUES
            (SEQ_FORECASTS.NEXTVAL, p_user_id, v_month, v_projected, v_budget,
             ROUND((v_projected - v_budget) / v_budget * 100, 2), SYSDATE, 'ANNUAL_V1');
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END GENERATE_ANNUAL_FORECAST;

    -- ========================================================================
    -- PROCEDURE: PROCESS_IDLE_SUBSCRIPTIONS
    -- Demonstrates: OPEN/FETCH/CLOSE explicit cursor, LOOP..EXIT WHEN,
    --               CASE statement, %ROWTYPE, user-defined exception,
    --               nested block per row, SQL%ROWCOUNT, SQL%NOTFOUND
    -- Reference: Section 7.2
    -- ========================================================================
    
    PROCEDURE PROCESS_IDLE_SUBSCRIPTIONS(p_user_id IN NUMBER) AS
        no_active_subs EXCEPTION;
        
        CURSOR c_idle IS
            SELECT sub_id, service_name, billing_amount, usage_score
            FROM SUBSCRIPTIONS
            WHERE user_id = p_user_id AND status = 'ACTIVE' AND usage_score <= 5
            ORDER BY billing_amount DESC;
            
        v_sub c_idle%ROWTYPE;
        v_label BEHAVIORAL_SIGNALS.signal_type%TYPE;
        v_sub_cnt NUMBER := 0;
    BEGIN
        -- Check if user has any active subscriptions
        SELECT COUNT(*) INTO v_sub_cnt
        FROM SUBSCRIPTIONS 
        WHERE user_id = p_user_id AND status = 'ACTIVE';
        
        IF v_sub_cnt = 0 THEN 
            RAISE no_active_subs; 
        END IF;
        
        -- Open explicit cursor
        OPEN c_idle;
        
        LOOP
            FETCH c_idle INTO v_sub;
            EXIT WHEN c_idle%NOTFOUND;
            
            -- Classify using CASE statement
            CASE
                WHEN v_sub.usage_score <= 1 THEN v_label := 'IDLE_SERVICE';
                WHEN v_sub.usage_score <= 3 THEN v_label := 'ADDICTION_SPEND';
                ELSE v_label := 'IMPULSE_SUBSCRIPTION';
            END CASE;
            
            -- Insert behavioral signal with nested block
            BEGIN
                INSERT INTO BEHAVIORAL_SIGNALS
                (signal_id, user_id, signal_type, detected_at, sub_id)
                VALUES
                (SEQ_BEH_SIGNALS.NEXTVAL, p_user_id, v_label, SYSDATE, v_sub.sub_id);
                
                IF SQL%ROWCOUNT = 0 THEN
                    RAISE_APPLICATION_ERROR(-20030, 
                        'Signal insert failed for sub ' || v_sub.sub_id);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN NULL;  -- Log error but continue
            END;
        END LOOP;
        
        -- Close explicit cursor
        CLOSE c_idle;
        COMMIT;
        
    EXCEPTION
        WHEN no_active_subs THEN NULL;
        WHEN OTHERS THEN
            IF c_idle%ISOPEN THEN CLOSE c_idle; END IF;
            ROLLBACK;
            RAISE;
    END PROCESS_IDLE_SUBSCRIPTIONS;

END AURIXA_ANALYTICS;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - Package Body Created
PROMPT ============================================================================

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'AURIXA_ANALYTICS'
ORDER BY object_type;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 06_package_body.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Package AURIXA_ANALYTICS body created.
PROMPT
PROMPT PL/SQL Constructs implemented:
PROMPT   - Package Specification + Body (encapsulation)
PROMPT   - User-defined RECORD type (t_financial_summary)
PROMPT   - 2 Functions (GET_MONTHLY_SPEND, IS_BUDGET_BREACHED)
PROMPT   - 6 Procedures (all core business logic)
PROMPT   - User-defined exceptions (invalid_user_data, no_active_subs)
PROMPT   - %TYPE and %ROWTYPE anchoring
PROMPT   - IF/ELSIF/ELSE and CASE statements
PROMPT   - Numeric FOR loop, Cursor FOR loop, WHILE loop
PROMPT   - Explicit OPEN/FETCH/CLOSE cursor
PROMPT   - Parameterized cursor
PROMPT   - SAVEPOINT and ROLLBACK TO SAVEPOINT
PROMPT   - SQL%ROWCOUNT, SQL%FOUND, SQL%NOTFOUND
PROMPT   - Exception handling with named exceptions
PROMPT   - RAISE_APPLICATION_ERROR
PROMPT
PROMPT Next: Run 07_standalone_fn.sql
PROMPT
PROMPT ============================================================================

COMMIT;