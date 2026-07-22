-- ============================================================================
-- SCRIPT: 02_sequences.sql
-- PURPOSE: Create all 26 sequences for AURIXA tables
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 5 (Oracle Sequences)
-- ============================================================================
--
-- INSTRUCTIONS:
-- 1. Connect to Oracle as C##AURIXA (NOT SYSTEM)
-- 2. Run this entire script (F5 in SQL Developer)
-- 3. Verify all 26 sequences are created
--
-- NOTE: Each sequence starts at 1, increments by 1
--       NOCACHE and NOCYCLE prevent gaps and cycling
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating 26 Sequences for AURIXA Tables
PROMPT Reference: Section 5 of Technical Documentation
PROMPT ============================================================================

-- ============================================================================
-- User Domain Sequences (4 sequences)
-- ============================================================================

CREATE SEQUENCE SEQ_USERS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USER_PROFILES START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USER_PREFS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USER_SECURITY START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Finance Domain Sequences (5 sequences)
-- ============================================================================

CREATE SEQUENCE SEQ_CURRENCIES START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_WALLETS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CATEGORIES START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_TRANSACTIONS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_FIN_GOALS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PRICE_HISTORY START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Subscription Domain Sequences (5 sequences)
-- ============================================================================

CREATE SEQUENCE SEQ_VENDORS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_SUBSCRIPTIONS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_SUB_USAGE START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BILLING_CYCLES START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_SUB_HISTORY START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Intelligence Domain Sequences (6 sequences)
-- ============================================================================

CREATE SEQUENCE SEQ_RISK_ALERTS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_AI_RECS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BEH_SIGNALS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_FORECASTS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_NOTIF_LOG START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_SPEND_PATTERNS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Analytics Domain Sequences (6 sequences)
-- ============================================================================

CREATE SEQUENCE SEQ_FIN_SCORES START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_MONTHLY_RPT START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CAT_ANALYTICS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_TREND_ANALYSIS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_AUDIT_LOG START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================================
-- Total: 26 sequences (4+5+5+6+6 = 26)
-- ============================================================================

PROMPT 
PROMPT ============================================================================
PROMPT VERIFICATION - All Sequences Created
PROMPT ============================================================================

SELECT sequence_name, min_value, max_value, increment_by, cycle_flag, cache_size
FROM user_sequences
ORDER BY sequence_name;

PROMPT 
PROMPT ============================================================================
PROMPT ✅ SCRIPT 02_sequences.sql COMPLETED
PROMPT ============================================================================
PROMPT 
PROMPT Total sequences created: 26
PROMPT 
PROMPT Next: Run 03_tables.sql
PROMPT 
PROMPT ============================================================================

COMMIT;