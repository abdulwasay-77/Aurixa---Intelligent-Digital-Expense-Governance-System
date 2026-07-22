-- ============================================================================
-- SCRIPT: 03_tables.sql (CORRECTED - No Forward References)
-- PURPOSE: Create all 26 tables for AURIXA in PROPER foreign key order
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- ============================================================================
--
-- TABLE CREATION ORDER (No table references another that doesn't exist yet):
-- 1. Independent tables (no FKs) → 2. Parent tables → 3. Child tables
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Creating 26 Tables for AURIXA (Corrected Order)
PROMPT ============================================================================

-- ============================================================================
-- LEVEL 1: NO FOREIGN KEY DEPENDENCIES
-- ============================================================================

PROMPT Creating Level 1 tables (no dependencies)...

CREATE TABLE CURRENCIES (
    currency_id          NUMBER          PRIMARY KEY,
    code                 CHAR(3)         UNIQUE NOT NULL,
    name                 VARCHAR2(50)    NOT NULL,
    symbol               VARCHAR2(5)     NOT NULL,
    exchange_rate_to_usd NUMBER(12,6)    NOT NULL,
    rate_updated_at      TIMESTAMP       DEFAULT SYSDATE
);

CREATE TABLE EXPENSE_CATEGORIES (
    category_id     NUMBER          PRIMARY KEY,
    name            VARCHAR2(80)    UNIQUE NOT NULL,
    icon_code       VARCHAR2(50),
    color_hex       CHAR(6),
    is_system       CHAR(1)         DEFAULT 'Y',
    CONSTRAINT chk_is_system CHECK (is_system IN ('Y', 'N'))
);

CREATE TABLE USERS (
    user_id         NUMBER          PRIMARY KEY,
    email           VARCHAR2(255)   UNIQUE NOT NULL,
    password_hash   VARCHAR2(255)   NOT NULL,
    full_name       VARCHAR2(150)   NOT NULL,
    phone           VARCHAR2(20)    UNIQUE,
    status          VARCHAR2(20)    DEFAULT 'ACTIVE',
    created_at      TIMESTAMP       DEFAULT SYSDATE,
    last_login      TIMESTAMP,
    CONSTRAINT chk_user_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED'))
);

PROMPT ✓ Level 1 tables created (3 tables)

-- ============================================================================
-- LEVEL 2: DEPENDS ONLY ON LEVEL 1
-- ============================================================================

PROMPT Creating Level 2 tables...

CREATE TABLE USER_PROFILES (
    profile_id          NUMBER          PRIMARY KEY,
    user_id             NUMBER          NOT NULL,
    monthly_income      NUMBER(12,2)    NOT NULL,
    saving_target_pct   NUMBER(5,2)     DEFAULT 20,
    risk_tolerance      VARCHAR2(20)    DEFAULT 'MEDIUM',
    lifestyle_category  VARCHAR2(50),
    base_currency_id    NUMBER          NOT NULL,
    updated_at          TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_profiles_currency FOREIGN KEY (base_currency_id) REFERENCES CURRENCIES(currency_id),
    CONSTRAINT chk_risk_tolerance CHECK (risk_tolerance IN ('LOW', 'MEDIUM', 'HIGH'))
);

CREATE TABLE USER_PREFERENCES (
    pref_id                 NUMBER          PRIMARY KEY,
    user_id                 NUMBER          NOT NULL,
    notif_budget_alert      CHAR(1)         DEFAULT 'Y',
    notif_billing_reminder  CHAR(1)         DEFAULT 'Y',
    notif_anomaly           CHAR(1)         DEFAULT 'Y',
    theme                   VARCHAR2(10)    DEFAULT 'DARK',
    dashboard_layout        VARCHAR2(20)    DEFAULT 'DEFAULT',
    biometric_enabled       CHAR(1)         DEFAULT 'N',
    biometric_enrolled_at   TIMESTAMP,
    CONSTRAINT fk_prefs_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT chk_biometric CHECK (biometric_enabled IN ('Y', 'N'))
);

CREATE TABLE USER_SECURITY (
    security_id           NUMBER          PRIMARY KEY,
    user_id               NUMBER          NOT NULL,
    refresh_token_hash    VARCHAR2(255),
    token_expires_at      TIMESTAMP,
    failed_login_count    NUMBER          DEFAULT 0,
    locked_until          TIMESTAMP,
    last_password_change  TIMESTAMP,
    CONSTRAINT fk_security_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

CREATE TABLE DIGITAL_WALLETS (
    wallet_id       NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    currency_id     NUMBER          NOT NULL,
    balance         NUMBER(14,2)    DEFAULT 0 NOT NULL,
    wallet_type     VARCHAR2(30)    DEFAULT 'PRIMARY',
    created_at      TIMESTAMP       DEFAULT SYSDATE,
    is_active       CHAR(1)         DEFAULT 'Y',
    CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_wallet_currency FOREIGN KEY (currency_id) REFERENCES CURRENCIES(currency_id),
    CONSTRAINT chk_wallet_active CHECK (is_active IN ('Y', 'N'))
);

CREATE TABLE FINANCIAL_GOALS (
    goal_id         NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    goal_name       VARCHAR2(150)   NOT NULL,
    target_amount   NUMBER(14,2)    NOT NULL,
    current_amount  NUMBER(14,2)    DEFAULT 0,
    currency_id     NUMBER          NOT NULL,
    deadline        DATE,
    status          VARCHAR2(20)    DEFAULT 'ACTIVE',
    CONSTRAINT fk_goal_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_goal_currency FOREIGN KEY (currency_id) REFERENCES CURRENCIES(currency_id)
);

CREATE TABLE SUBSCRIPTION_VENDORS (
    vendor_id       NUMBER          PRIMARY KEY,
    vendor_name     VARCHAR2(100)   UNIQUE NOT NULL,
    category_id     NUMBER,
    website_url     VARCHAR2(255),
    logo_url        VARCHAR2(255),
    country_code    CHAR(2),
    CONSTRAINT fk_vendor_category FOREIGN KEY (category_id) REFERENCES EXPENSE_CATEGORIES(category_id)
);

PROMPT ✓ Level 2 tables created (7 tables)

-- ============================================================================
-- LEVEL 3: DEPENDS ON LEVEL 1 & 2
-- ============================================================================

PROMPT Creating Level 3 tables...

CREATE TABLE SUBSCRIPTIONS (
    sub_id              NUMBER          PRIMARY KEY,
    user_id             NUMBER          NOT NULL,
    vendor_id           NUMBER,
    category_id         NUMBER          NOT NULL,
    currency_id         NUMBER          NOT NULL,
    service_name        VARCHAR2(150)   NOT NULL,
    billing_amount      NUMBER(10,2)    NOT NULL,
    billing_cycle       VARCHAR2(20)    NOT NULL,
    next_billing_date   DATE            NOT NULL,
    start_date          DATE            NOT NULL,
    usage_score         NUMBER(3)       DEFAULT 5,
    status              VARCHAR2(20)    DEFAULT 'ACTIVE',
    notes               VARCHAR2(500),
    created_at          TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_sub_vendor FOREIGN KEY (vendor_id) REFERENCES SUBSCRIPTION_VENDORS(vendor_id),
    CONSTRAINT fk_sub_category FOREIGN KEY (category_id) REFERENCES EXPENSE_CATEGORIES(category_id),
    CONSTRAINT fk_sub_currency FOREIGN KEY (currency_id) REFERENCES CURRENCIES(currency_id),
    CONSTRAINT chk_billing_cycle CHECK (billing_cycle IN ('MONTHLY', 'YEARLY', 'WEEKLY', 'QUARTERLY')),
    CONSTRAINT chk_sub_status CHECK (status IN ('ACTIVE', 'PAUSED', 'CANCELLED')),
    CONSTRAINT chk_usage_score CHECK (usage_score BETWEEN 1 AND 10)
);

CREATE TABLE SUBSCRIPTION_USAGE (
    usage_id        NUMBER          PRIMARY KEY,
    sub_id          NUMBER          NOT NULL,
    log_date        DATE            NOT NULL,
    used_today      CHAR(1)         DEFAULT 'N',
    session_minutes NUMBER          DEFAULT 0,
    CONSTRAINT fk_usage_sub FOREIGN KEY (sub_id) REFERENCES SUBSCRIPTIONS(sub_id),
    CONSTRAINT chk_used_today CHECK (used_today IN ('Y', 'N'))
);

CREATE TABLE BILLING_CYCLES (
    cycle_id        NUMBER          PRIMARY KEY,
    sub_id          NUMBER          NOT NULL,
    billing_date    DATE            NOT NULL,
    amount_charged  NUMBER(10,2)    NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'PAID',
    payment_method  VARCHAR2(50),
    created_at      TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_billing_sub FOREIGN KEY (sub_id) REFERENCES SUBSCRIPTIONS(sub_id),
    CONSTRAINT chk_billing_status CHECK (status IN ('PAID', 'MISSED', 'REFUNDED', 'SCHEDULED'))
);

CREATE TABLE SUBSCRIPTION_HISTORY (
    history_id      NUMBER          PRIMARY KEY,
    sub_id          NUMBER          NOT NULL,
    action          VARCHAR2(30)    NOT NULL,
    performed_at    TIMESTAMP       DEFAULT SYSDATE,
    performed_by    VARCHAR2(30)    DEFAULT 'USER',
    notes           VARCHAR2(500),
    CONSTRAINT fk_history_sub FOREIGN KEY (sub_id) REFERENCES SUBSCRIPTIONS(sub_id)
);

CREATE TABLE PRICE_HISTORY (
    price_history_id NUMBER        PRIMARY KEY,
    subscription_id  NUMBER        NOT NULL,
    old_price        NUMBER(10,2)  NOT NULL,
    new_price        NUMBER(10,2)  NOT NULL,
    change_pct       NUMBER(7,2),
    effective_date   DATE          NOT NULL,
    detected_at      TIMESTAMP     DEFAULT SYSDATE,
    CONSTRAINT fk_price_sub FOREIGN KEY (subscription_id) REFERENCES SUBSCRIPTIONS(sub_id)
);

CREATE TABLE TRANSACTIONS (
    txn_id          NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    wallet_id       NUMBER          NOT NULL,
    category_id     NUMBER,
    subscription_id NUMBER,
    amount          NUMBER(12,2)    NOT NULL,
    currency_id     NUMBER          NOT NULL,
    amount_usd      NUMBER(12,2),
    txn_type        VARCHAR2(20)    NOT NULL,
    description     VARCHAR2(255),
    txn_date        TIMESTAMP       DEFAULT SYSDATE,
    is_recurring    CHAR(1)         DEFAULT 'N',
    is_anomaly      CHAR(1)         DEFAULT 'N',
    CONSTRAINT fk_txn_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_txn_wallet FOREIGN KEY (wallet_id) REFERENCES DIGITAL_WALLETS(wallet_id),
    CONSTRAINT fk_txn_category FOREIGN KEY (category_id) REFERENCES EXPENSE_CATEGORIES(category_id),
    CONSTRAINT fk_txn_subscription FOREIGN KEY (subscription_id) REFERENCES SUBSCRIPTIONS(sub_id),
    CONSTRAINT fk_txn_currency FOREIGN KEY (currency_id) REFERENCES CURRENCIES(currency_id),
    CONSTRAINT chk_txn_type CHECK (txn_type IN ('DEBIT', 'CREDIT', 'REFUND'))
);

PROMPT ✓ Level 3 tables created (7 tables)

-- ============================================================================
-- LEVEL 4: DEPENDS ON LEVEL 3
-- ============================================================================

PROMPT Creating Level 4 tables...

CREATE TABLE RISK_ALERTS (
    alert_id        NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    alert_type      VARCHAR2(50)    NOT NULL,
    severity        VARCHAR2(10)    DEFAULT 'MEDIUM',
    title           VARCHAR2(200)   NOT NULL,
    message         VARCHAR2(1000)  NOT NULL,
    related_sub_id  NUMBER,
    related_txn_id  NUMBER,
    is_read         CHAR(1)         DEFAULT 'N',
    triggered_at    TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_alert_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_alert_sub FOREIGN KEY (related_sub_id) REFERENCES SUBSCRIPTIONS(sub_id),
    CONSTRAINT fk_alert_txn FOREIGN KEY (related_txn_id) REFERENCES TRANSACTIONS(txn_id),
    CONSTRAINT chk_alert_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
);

CREATE TABLE NOTIFICATION_LOG (
    notif_id        NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    alert_id        NUMBER,
    channel         VARCHAR2(20)    NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'SENT',
    sent_at         TIMESTAMP       DEFAULT SYSDATE,
    delivered_at    TIMESTAMP,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_notif_alert FOREIGN KEY (alert_id) REFERENCES RISK_ALERTS(alert_id)
);

CREATE TABLE AI_RECOMMENDATIONS (
    rec_id            NUMBER          PRIMARY KEY,
    user_id           NUMBER          NOT NULL,
    rec_type          VARCHAR2(50)    NOT NULL,
    sub_id            NUMBER,
    title             VARCHAR2(200)   NOT NULL,
    reasoning         VARCHAR2(2000)  NOT NULL,
    potential_saving  NUMBER(10,2),
    saving_currency_id NUMBER,
    confidence_score  NUMBER(5,2),
    source            VARCHAR2(20)    DEFAULT 'PROCEDURE',
    is_actioned       CHAR(1)         DEFAULT 'N',
    generated_at      TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_rec_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_rec_sub FOREIGN KEY (sub_id) REFERENCES SUBSCRIPTIONS(sub_id),
    CONSTRAINT fk_rec_currency FOREIGN KEY (saving_currency_id) REFERENCES CURRENCIES(currency_id)
);

CREATE TABLE BEHAVIORAL_SIGNALS (
    signal_id       NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    signal_type     VARCHAR2(50)    NOT NULL,
    detected_at     TIMESTAMP       DEFAULT SYSDATE,
    sub_id          NUMBER,
    evidence_json   CLOB,
    resolved        CHAR(1)         DEFAULT 'N',
    CONSTRAINT fk_signal_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_signal_sub FOREIGN KEY (sub_id) REFERENCES SUBSCRIPTIONS(sub_id)
);

CREATE TABLE BUDGET_FORECASTS (
    forecast_id       NUMBER          PRIMARY KEY,
    user_id           NUMBER          NOT NULL,
    forecast_month    DATE            NOT NULL,
    projected_total   NUMBER(12,2)    NOT NULL,
    budget_limit      NUMBER(12,2)    NOT NULL,
    variance_pct      NUMBER(7,2),
    days_to_breach    NUMBER,
    velocity_per_day  NUMBER(10,2),
    generated_at      TIMESTAMP       DEFAULT SYSDATE,
    model_version     VARCHAR2(50),
    CONSTRAINT fk_forecast_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

CREATE TABLE SPENDING_PATTERNS (
    pattern_id      NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    category_id     NUMBER          NOT NULL,
    pattern_month   DATE            NOT NULL,
    total_spent     NUMBER(12,2)    NOT NULL,
    txn_count       NUMBER          NOT NULL,
    avg_txn_amount  NUMBER(10,2),
    mom_change_pct  NUMBER(7,2),
    CONSTRAINT fk_pattern_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_pattern_category FOREIGN KEY (category_id) REFERENCES EXPENSE_CATEGORIES(category_id)
);

PROMPT ✓ Level 4 tables created (7 tables)

-- ============================================================================
-- LEVEL 5: FINAL ANALYTICS TABLES
-- ============================================================================

PROMPT Creating Level 5 tables...

CREATE TABLE FINANCIAL_SCORES (
    score_id                 NUMBER          PRIMARY KEY,
    user_id                  NUMBER          NOT NULL,
    score_date               DATE            NOT NULL,
    financial_health_score   NUMBER(5,2)     NOT NULL,
    savings_rate_score       NUMBER(5,2),
    budget_discipline_score  NUMBER(5,2),
    sub_dependency_ratio     NUMBER(5,2),
    risk_factor_score        NUMBER(5,2),
    score_label              VARCHAR2(20),
    CONSTRAINT fk_score_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

CREATE TABLE MONTHLY_REPORTS (
    report_id           NUMBER          PRIMARY KEY,
    user_id             NUMBER          NOT NULL,
    report_month        DATE            NOT NULL,
    total_income        NUMBER(14,2),
    total_spent         NUMBER(14,2)    NOT NULL,
    total_subscriptions NUMBER(14,2),
    total_savings       NUMBER(14,2),
    active_sub_count    NUMBER,
    new_subs            NUMBER,
    cancelled_subs      NUMBER,
    generated_at        TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

CREATE TABLE CATEGORY_ANALYTICS (
    analytics_id        NUMBER          PRIMARY KEY,
    user_id             NUMBER          NOT NULL,
    category_id         NUMBER          NOT NULL,
    analytics_month     DATE            NOT NULL,
    total_amount        NUMBER(12,2)    NOT NULL,
    pct_of_total_spend  NUMBER(5,2),
    is_dominant         CHAR(1)         DEFAULT 'N',
    CONSTRAINT fk_cat_analytics_user FOREIGN KEY (user_id) REFERENCES USERS(user_id),
    CONSTRAINT fk_cat_analytics_category FOREIGN KEY (category_id) REFERENCES EXPENSE_CATEGORIES(category_id)
);

CREATE TABLE TREND_ANALYSIS (
    trend_id        NUMBER          PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    metric_name     VARCHAR2(100)   NOT NULL,
    metric_month    DATE            NOT NULL,
    metric_value    NUMBER(14,2)    NOT NULL,
    trend_direction VARCHAR2(10),
    pct_change      NUMBER(7,2),
    CONSTRAINT fk_trend_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

CREATE TABLE AUDIT_LOG (
    log_id          NUMBER          PRIMARY KEY,
    user_id         NUMBER,
    table_name      VARCHAR2(100)   NOT NULL,
    operation       VARCHAR2(10)    NOT NULL,
    record_id       NUMBER,
    old_values      CLOB,
    new_values      CLOB,
    performed_at    TIMESTAMP       DEFAULT SYSDATE,
    ip_address      VARCHAR2(45),
    session_id      VARCHAR2(100),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

PROMPT ✓ Level 5 tables created (5 tables)

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - All Tables Created
PROMPT ============================================================================

SELECT table_name, status
FROM user_tables
ORDER BY table_name;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SCRIPT 03_tables.sql COMPLETED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Total tables created: 26
PROMPT
PROMPT Next: Run 04_triggers.sql
PROMPT
PROMPT ============================================================================

COMMIT;