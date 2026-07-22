-- ============================================================================
-- SCRIPT: 10_indexes.sql
-- PURPOSE: Create all indexes for AURIXA performance optimization
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- REFERENCE: Section 10 (Indexing Strategy)
-- ============================================================================
--
-- INDEX STRATEGY:
-- All indexes target the most frequent AURIXA queries:
--   - User-scoped lookups (user_id foreign keys)
--   - Date-range billing queries (billing_date, txn_date)
--   - Status filters (status, is_read, is_anomaly)
--   - Email and unique constraint lookups
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating Indexes for AURIXA
PROMPT Reference: Section 10 of Technical Documentation
PROMPT ============================================================================

-- ============================================================================
-- USER DOMAIN INDEXES
-- Target: Login by email, user profile lookups
-- ============================================================================

PROMPT Creating User Domain indexes...

CREATE INDEX IDX_USERS_EMAIL ON USERS(email);
CREATE INDEX IDX_USER_PROFILES_UID ON USER_PROFILES(user_id);
CREATE INDEX IDX_USER_PREFS_UID ON USER_PREFERENCES(user_id);
CREATE INDEX IDX_USER_SECURITY_UID ON USER_SECURITY(user_id);

PROMPT ✓ User Domain indexes created (4 indexes)

-- ============================================================================
-- FINANCE DOMAIN INDEXES
-- Target: Transaction lookups by user, date, category, anomaly flag
-- ============================================================================

PROMPT Creating Finance Domain indexes...

CREATE INDEX IDX_WALLETS_USER ON DIGITAL_WALLETS(user_id);
CREATE INDEX IDX_WALLETS_CURRENCY ON DIGITAL_WALLETS(currency_id);

CREATE INDEX IDX_TXN_USER_DATE ON TRANSACTIONS(user_id, txn_date);
CREATE INDEX IDX_TXN_CATEGORY ON TRANSACTIONS(category_id);
CREATE INDEX IDX_TXN_WALLET ON TRANSACTIONS(wallet_id);
CREATE INDEX IDX_TXN_ANOMALY ON TRANSACTIONS(is_anomaly);
CREATE INDEX IDX_TXN_RECURRING ON TRANSACTIONS(is_recurring);

CREATE INDEX IDX_GOALS_USER ON FINANCIAL_GOALS(user_id);
CREATE INDEX IDX_GOALS_STATUS ON FINANCIAL_GOALS(status);

CREATE INDEX IDX_PRICE_HISTORY_SUB ON PRICE_HISTORY(subscription_id);
CREATE INDEX IDX_PRICE_HISTORY_DATE ON PRICE_HISTORY(effective_date);

PROMPT ✓ Finance Domain indexes created (10 indexes)

-- ============================================================================
-- SUBSCRIPTION DOMAIN INDEXES
-- Target: Subscription lookups by user, status, next billing date
-- ============================================================================

PROMPT Creating Subscription Domain indexes...

CREATE INDEX IDX_SUBS_USER_ID ON SUBSCRIPTIONS(user_id);
CREATE INDEX IDX_SUBS_STATUS ON SUBSCRIPTIONS(status);
CREATE INDEX IDX_SUBS_NEXT_BILLING ON SUBSCRIPTIONS(next_billing_date);
CREATE INDEX IDX_SUBS_VENDOR ON SUBSCRIPTIONS(vendor_id);
CREATE INDEX IDX_SUBS_CATEGORY ON SUBSCRIPTIONS(category_id);
CREATE INDEX IDX_SUBS_CURRENCY ON SUBSCRIPTIONS(currency_id);

CREATE INDEX IDX_BILLING_SUB_DATE ON BILLING_CYCLES(sub_id, billing_date);
CREATE INDEX IDX_BILLING_STATUS ON BILLING_CYCLES(status);
CREATE INDEX IDX_BILLING_DATE ON BILLING_CYCLES(billing_date);

CREATE INDEX IDX_SUB_USAGE_SUB ON SUBSCRIPTION_USAGE(sub_id);
CREATE INDEX IDX_SUB_USAGE_DATE ON SUBSCRIPTION_USAGE(log_date);

CREATE INDEX IDX_SUB_HISTORY_SUB ON SUBSCRIPTION_HISTORY(sub_id);
CREATE INDEX IDX_SUB_HISTORY_DATE ON SUBSCRIPTION_HISTORY(performed_at);

CREATE INDEX IDX_VENDORS_CATEGORY ON SUBSCRIPTION_VENDORS(category_id);
CREATE INDEX IDX_VENDORS_NAME ON SUBSCRIPTION_VENDORS(vendor_name);

PROMPT ✓ Subscription Domain indexes created (14 indexes)

-- ============================================================================
-- INTELLIGENCE DOMAIN INDEXES
-- Target: Alert and recommendation queries by user, read status, type
-- ============================================================================

PROMPT Creating Intelligence Domain indexes...

CREATE INDEX IDX_ALERTS_USER_READ ON RISK_ALERTS(user_id, is_read);
CREATE INDEX IDX_ALERTS_SEVERITY ON RISK_ALERTS(severity);
CREATE INDEX IDX_ALERTS_TYPE ON RISK_ALERTS(alert_type);
CREATE INDEX IDX_ALERTS_TRIGGERED ON RISK_ALERTS(triggered_at);

CREATE INDEX IDX_RECS_USER_TYPE ON AI_RECOMMENDATIONS(user_id, rec_type);
CREATE INDEX IDX_RECS_ACTIONED ON AI_RECOMMENDATIONS(is_actioned);
CREATE INDEX IDX_RECS_SAVING ON AI_RECOMMENDATIONS(potential_saving DESC);

CREATE INDEX IDX_SIGNALS_USER ON BEHAVIORAL_SIGNALS(user_id);
CREATE INDEX IDX_SIGNALS_TYPE ON BEHAVIORAL_SIGNALS(signal_type);
CREATE INDEX IDX_SIGNALS_RESOLVED ON BEHAVIORAL_SIGNALS(resolved);

CREATE INDEX IDX_FORECASTS_USER_MONTH ON BUDGET_FORECASTS(user_id, forecast_month);
CREATE INDEX IDX_FORECASTS_BREACH ON BUDGET_FORECASTS(days_to_breach);

CREATE INDEX IDX_NOTIF_USER ON NOTIFICATION_LOG(user_id);
CREATE INDEX IDX_NOTIF_STATUS ON NOTIFICATION_LOG(status);

CREATE INDEX IDX_SPEND_PATTERNS_USER_MONTH ON SPENDING_PATTERNS(user_id, pattern_month);
CREATE INDEX IDX_SPEND_PATTERNS_CATEGORY ON SPENDING_PATTERNS(category_id);

PROMPT ✓ Intelligence Domain indexes created (14 indexes)

-- ============================================================================
-- ANALYTICS DOMAIN INDEXES
-- Target: Score lookups by date, audit log by table and date
-- ============================================================================

PROMPT Creating Analytics Domain indexes...

CREATE INDEX IDX_FIN_SCORES_USER_DATE ON FINANCIAL_SCORES(user_id, score_date);
CREATE INDEX IDX_FIN_SCORES_LABEL ON FINANCIAL_SCORES(score_label);

CREATE INDEX IDX_MONTHLY_RPT_USER_DATE ON MONTHLY_REPORTS(user_id, report_month);

CREATE INDEX IDX_CAT_ANALYTICS_USER_MONTH ON CATEGORY_ANALYTICS(user_id, analytics_month);
CREATE INDEX IDX_CAT_ANALYTICS_CATEGORY ON CATEGORY_ANALYTICS(category_id);
CREATE INDEX IDX_CAT_ANALYTICS_DOMINANT ON CATEGORY_ANALYTICS(is_dominant);

CREATE INDEX IDX_TREND_USER_METRIC_MONTH ON TREND_ANALYSIS(user_id, metric_name, metric_month);

CREATE INDEX IDX_AUDIT_TABLE_DATE ON AUDIT_LOG(table_name, performed_at);
CREATE INDEX IDX_AUDIT_USER_DATE ON AUDIT_LOG(user_id, performed_at);
CREATE INDEX IDX_AUDIT_OPERATION ON AUDIT_LOG(operation);

PROMPT ✓ Analytics Domain indexes created (9 indexes)

-- ============================================================================
-- TOTAL INDEX COUNT
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - All Indexes Created
PROMPT ============================================================================

SELECT index_name, table_name, uniqueness, status
FROM user_indexes
WHERE index_name NOT LIKE 'SYS%'
AND index_name NOT LIKE 'BIN$%'
ORDER BY table_name, index_name;

PROMPT
PROMPT ============================================================================
PROMPT Index Count by Table
PROMPT ============================================================================

SELECT table_name, COUNT(*) AS index_count
FROM user_indexes
WHERE index_name NOT LIKE 'SYS%'
AND index_name NOT LIKE 'BIN$%'
GROUP BY table_name
ORDER BY table_name;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 10_indexes.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Indexes created summary:
PROMPT   - User Domain:        4 indexes
PROMPT   - Finance Domain:    10 indexes
PROMPT   - Subscription Domain: 14 indexes
PROMPT   - Intelligence Domain: 14 indexes
PROMPT   - Analytics Domain:   9 indexes
PROMPT   ----------------------------------------
PROMPT   TOTAL:               51 indexes
PROMPT
PROMPT Next: Run 11_seed_data.sql (final script)
PROMPT
PROMPT ============================================================================

COMMIT;