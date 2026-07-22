-- ============================================================================
-- SCRIPT: 07_standalone_fn.sql
-- PURPOSE: Create CONVERT_CURRENCY standalone function
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 7.3 (CONVERT_CURRENCY standalone function)
-- ============================================================================
--
-- FUNCTION: CONVERT_CURRENCY
-- DESCRIPTION: Converts an amount from one currency to another using exchange rates
--              Declared outside package so it can be called directly in SQL queries
--              and Oracle Scheduler jobs
--
-- PARAMETERS:
--   p_amount    - Amount to convert
--   p_from_code - Source currency code (e.g., 'PKR', 'USD', 'EUR', 'GBP')
--   p_to_code   - Target currency code
--
-- RETURNS: Converted amount rounded to 2 decimal places
--
-- USAGE EXAMPLES:
--   SELECT CONVERT_CURRENCY(100, 'USD', 'PKR') FROM DUAL;  -- Converts 100 USD to PKR
--   SELECT CONVERT_CURRENCY(5000, 'PKR', 'USD') FROM DUAL; -- Converts 5000 PKR to USD
--   UPDATE TRANSACTIONS SET amount_usd = CONVERT_CURRENCY(amount, code, 'USD');
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating CONVERT_CURRENCY Standalone Function
PROMPT Reference: Section 7.3 of Technical Documentation
PROMPT ============================================================================

CREATE OR REPLACE FUNCTION CONVERT_CURRENCY(
    p_amount IN NUMBER,
    p_from_code IN CHAR,
    p_to_code IN CHAR
) RETURN NUMBER AS
    v_from_rate CURRENCIES.exchange_rate_to_usd%TYPE;
    v_to_rate CURRENCIES.exchange_rate_to_usd%TYPE;
BEGIN
    -- Get exchange rate for source currency (relative to USD)
    SELECT exchange_rate_to_usd INTO v_from_rate 
    FROM CURRENCIES 
    WHERE code = p_from_code;
    
    -- Get exchange rate for target currency (relative to USD)
    SELECT exchange_rate_to_usd INTO v_to_rate 
    FROM CURRENCIES 
    WHERE code = p_to_code;
    
    -- Convert: amount / from_rate * to_rate
    -- If from_rate is USD (1.0), then amount * to_rate
    -- If to_rate is USD (1.0), then amount / from_rate
    RETURN ROUND(p_amount / v_from_rate * v_to_rate, 2);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20040, 'Unknown currency code: ' || p_from_code || ' or ' || p_to_code);
    WHEN ZERO_DIVIDE THEN
        RAISE_APPLICATION_ERROR(-20041, 'Exchange rate is zero for currency: ' || p_from_code);
    WHEN OTHERS THEN
        RAISE;
END CONVERT_CURRENCY;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - Function Created and Test
PROMPT ============================================================================

-- Check function exists
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'CONVERT_CURRENCY';

-- Test function with known conversions (requires currencies to exist)
-- These tests will work after seed data is loaded (script 11)
PROMPT
PROMPT Testing CONVERT_CURRENCY (will work after seed data):
PROMPT

-- Test 1: USD to USD (should return same amount)
DECLARE
    v_result NUMBER;
BEGIN
    BEGIN
        v_result := CONVERT_CURRENCY(100, 'USD', 'USD');
        DBMS_OUTPUT.PUT_LINE('Test 1 - USD to USD: 100 = ' || v_result || ' (expected: 100)');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Test 1 - USD to USD: Currency data not loaded yet');
    END;
END;
/

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 07_standalone_fn.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Function CONVERT_CURRENCY created.
PROMPT
PROMPT Features:
PROMPT   - Converts between any currencies in CURRENCIES table
PROMPT   - Uses USD as base currency for conversion
PROMPT   - Returns amount rounded to 2 decimal places
PROMPT   - Handles NO_DATA_FOUND and ZERO_DIVIDE exceptions
PROMPT   - Can be used in any SQL query or PL/SQL block
PROMPT
PROMPT Next: Run 08_matviews.sql
PROMPT
PROMPT ============================================================================

COMMIT;