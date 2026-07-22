-- ============================================================================
-- SCRIPT: 04_triggers.sql
-- PURPOSE: Create all 5 triggers for AURIXA
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 6 (Oracle Triggers)
-- ============================================================================
--
-- TRIGGERS:
-- 1. TRG_USERS_PK        - Auto-assign PK and timestamp on insert
-- 2. TRG_AFTER_PAYMENT   - Budget check after billing cycle insert
-- 3. TRG_PRICE_CHANGE    - Detect and log subscription price increases
-- 4. TRG_SUB_CANCELLED   - Archive cancellation with verification
-- 5. TRG_AUDIT_WRITER    - Universal append-only audit trail
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating 5 Triggers for AURIXA
PROMPT Reference: Section 6 of Technical Documentation
PROMPT ============================================================================

-- ============================================================================
-- TRIGGER 1: TRG_USERS_PK
-- Purpose: Auto-assign primary key and timestamp on user insert
-- Reference: Section 6.1
-- ============================================================================

PROMPT Creating TRG_USERS_PK...

CREATE OR REPLACE TRIGGER TRG_USERS_PK
BEFORE INSERT ON USERS
FOR EACH ROW
BEGIN
    :NEW.user_id := SEQ_USERS.NEXTVAL;
    :NEW.created_at := SYSDATE;
END;
/

PROMPT ✓ TRG_USERS_PK created

-- ============================================================================
-- TRIGGER 2: TRG_AFTER_PAYMENT
-- Purpose: Check budget after billing cycle insert, create alert if exceeded
-- Reference: Section 6.2
-- ============================================================================

PROMPT Creating TRG_AFTER_PAYMENT...

CREATE OR REPLACE TRIGGER TRG_AFTER_PAYMENT
AFTER INSERT ON BILLING_CYCLES
FOR EACH ROW
DECLARE
    v_user_id USERS.user_id%TYPE;
    v_total_spent BILLING_CYCLES.amount_charged%TYPE;
    v_budget_limit USER_PROFILES.monthly_income%TYPE;
BEGIN
    -- Get user_id from subscription
    SELECT s.user_id INTO v_user_id
    FROM SUBSCRIPTIONS s WHERE s.sub_id = :NEW.sub_id;
    
    -- Calculate total spent this month
    SELECT NVL(SUM(bc.amount_charged),0) INTO v_total_spent
    FROM BILLING_CYCLES bc 
    JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
    WHERE s.user_id = v_user_id
    AND TRUNC(bc.billing_date,'MM') = TRUNC(SYSDATE,'MM');
    
    -- Get user's budget limit (income minus savings target)
    SELECT NVL(monthly_income * (1 - saving_target_pct/100), 99999)
    INTO v_budget_limit
    FROM USER_PROFILES WHERE user_id = v_user_id;
    
    -- Check if budget is exceeded
    IF v_total_spent > v_budget_limit THEN
        INSERT INTO RISK_ALERTS
        (alert_id, user_id, alert_type, severity, title, message, triggered_at)
        VALUES
        (SEQ_RISK_ALERTS.NEXTVAL, v_user_id, 'BUDGET_BREACH', 'HIGH',
         'Budget Limit Exceeded',
         'Subscription spend exceeded monthly budget. Total: ' || TO_CHAR(v_total_spent, '999,999.00'),
         SYSDATE);
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN NULL;
    WHEN OTHERS THEN RAISE;
END;
/

PROMPT ✓ TRG_AFTER_PAYMENT created

-- ============================================================================
-- TRIGGER 3: TRG_PRICE_CHANGE
-- Purpose: Detect and log subscription price increases, create alert
-- Reference: Section 6.3
-- ============================================================================

PROMPT Creating TRG_PRICE_CHANGE...

CREATE OR REPLACE TRIGGER TRG_PRICE_CHANGE
BEFORE UPDATE OF billing_amount ON SUBSCRIPTIONS
FOR EACH ROW
WHEN (OLD.billing_amount != NEW.billing_amount)
DECLARE
    v_change_pct NUMBER(7,2);
BEGIN
    -- Calculate percentage change
    v_change_pct := ROUND((:NEW.billing_amount - :OLD.billing_amount) 
                          / :OLD.billing_amount * 100, 2);
    
    -- Log to price history
    INSERT INTO PRICE_HISTORY
    (price_history_id, subscription_id, old_price, new_price, 
     change_pct, effective_date, detected_at)
    VALUES
    (SEQ_PRICE_HISTORY.NEXTVAL, :OLD.sub_id, :OLD.billing_amount,
     :NEW.billing_amount, v_change_pct, SYSDATE, SYSDATE);
    
    -- Create alert for price increase only (positive change)
    IF v_change_pct > 0 THEN
        INSERT INTO RISK_ALERTS
        (alert_id, user_id, alert_type, severity, title, message, 
         related_sub_id, triggered_at)
        VALUES
        (SEQ_RISK_ALERTS.NEXTVAL, :OLD.user_id, 'PRICE_CHANGE', 'MEDIUM',
         'Subscription Price Increased',
         :OLD.service_name || ' increased by ' || TO_CHAR(v_change_pct, '999.99') || '%.',
         :OLD.sub_id, SYSDATE);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN RAISE;
END;
/

PROMPT ✓ TRG_PRICE_CHANGE created

-- ============================================================================
-- TRIGGER 4: TRG_SUB_CANCELLED
-- Purpose: Archive cancellation to history with SQL%ROWCOUNT verification
-- Reference: Section 6.4
-- ============================================================================

PROMPT Creating TRG_SUB_CANCELLED...

CREATE OR REPLACE TRIGGER TRG_SUB_CANCELLED
AFTER UPDATE OF status ON SUBSCRIPTIONS
FOR EACH ROW
WHEN (NEW.status = 'CANCELLED' AND OLD.status != 'CANCELLED')
BEGIN
    -- Insert into subscription history
    INSERT INTO SUBSCRIPTION_HISTORY
    (history_id, sub_id, action, performed_at, performed_by)
    VALUES
    (SEQ_SUB_HISTORY.NEXTVAL, :NEW.sub_id, 'CANCELLED', SYSDATE, 'USER');
    
    -- Verify insert succeeded
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 
            'History insert failed for sub_id=' || TO_CHAR(:NEW.sub_id));
    END IF;
END;
/

PROMPT ✓ TRG_SUB_CANCELLED created

-- ============================================================================
-- TRIGGER 5: TRG_AUDIT_WRITER
-- Purpose: Universal append-only audit trail for SUBSCRIPTIONS table
-- Reference: Section 6.5
-- ============================================================================

PROMPT Creating TRG_AUDIT_WRITER...

CREATE OR REPLACE TRIGGER TRG_AUDIT_WRITER
AFTER INSERT OR UPDATE OR DELETE ON SUBSCRIPTIONS
FOR EACH ROW
DECLARE
    v_op VARCHAR2(10);
    v_uid USERS.user_id%TYPE;
    v_rec_id SUBSCRIPTIONS.sub_id%TYPE;
BEGIN
    -- Determine operation type
    IF INSERTING THEN 
        v_op := 'INSERT';
    ELSIF UPDATING THEN 
        v_op := 'UPDATE';
    ELSE 
        v_op := 'DELETE'; 
    END IF;
    
    -- Get user_id (works for INSERT, UPDATE, DELETE)
    v_uid := CASE WHEN DELETING THEN :OLD.user_id ELSE :NEW.user_id END;
    v_rec_id := CASE WHEN DELETING THEN :OLD.sub_id ELSE :NEW.sub_id END;
    
    -- Insert audit record
    INSERT INTO AUDIT_LOG
    (log_id, user_id, table_name, operation, record_id, performed_at)
    VALUES
    (SEQ_AUDIT_LOG.NEXTVAL, v_uid, 'SUBSCRIPTIONS', v_op, v_rec_id, SYSDATE);
END;
/

PROMPT ✓ TRG_AUDIT_WRITER created

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - All Triggers Created
PROMPT ============================================================================

SELECT trigger_name, status, table_name
FROM user_triggers
ORDER BY trigger_name;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 04_triggers.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Triggers created (5):
PROMPT   1. TRG_USERS_PK        - Auto PK for USERS
PROMPT   2. TRG_AFTER_PAYMENT   - Budget breach detection
PROMPT   3. TRG_PRICE_CHANGE    - Price increase tracking
PROMPT   4. TRG_SUB_CANCELLED   - Cancellation archive
PROMPT   5. TRG_AUDIT_WRITER    - Audit trail for SUBSCRIPTIONS
PROMPT
PROMPT Next: Run 05_package_spec.sql
PROMPT
PROMPT ============================================================================

COMMIT;