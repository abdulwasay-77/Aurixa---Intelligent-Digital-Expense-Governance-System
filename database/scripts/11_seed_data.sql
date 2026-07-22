-- ============================================================================
-- SCRIPT: 11_seed_data.sql
-- PURPOSE: Insert reference seed data for AURIXA
-- AUTHOR:  AURIXA Database Setup
-- VERSION: 2.2
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT ============================================================================
PROMPT Inserting Seed Data for AURIXA
PROMPT ============================================================================

-- ============================================================================
-- SECTION 11.1: CURRENCIES
-- ============================================================================

PROMPT Inserting CURRENCIES...

DELETE FROM CURRENCIES WHERE code IN ('PKR', 'USD', 'EUR', 'GBP');

INSERT INTO CURRENCIES (currency_id, code, name, symbol, exchange_rate_to_usd, rate_updated_at)
VALUES (SEQ_CURRENCIES.NEXTVAL, 'PKR', 'Pakistani Rupee', 'Rs', 0.003591, SYSDATE);

INSERT INTO CURRENCIES (currency_id, code, name, symbol, exchange_rate_to_usd, rate_updated_at)
VALUES (SEQ_CURRENCIES.NEXTVAL, 'USD', 'US Dollar', '$', 1.000000, SYSDATE);

INSERT INTO CURRENCIES (currency_id, code, name, symbol, exchange_rate_to_usd, rate_updated_at)
VALUES (SEQ_CURRENCIES.NEXTVAL, 'EUR', 'Euro', '€', 1.085000, SYSDATE);

INSERT INTO CURRENCIES (currency_id, code, name, symbol, exchange_rate_to_usd, rate_updated_at)
VALUES (SEQ_CURRENCIES.NEXTVAL, 'GBP', 'British Pound', '£', 1.270000, SYSDATE);

COMMIT;

-- ============================================================================
-- SECTION 11.2: EXPENSE_CATEGORIES
-- ============================================================================

PROMPT Inserting EXPENSE_CATEGORIES...

DELETE FROM EXPENSE_CATEGORIES WHERE is_system = 'Y';

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Streaming', 'play_circle', 'E50914', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Music', 'music_note', '1DB954', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'SaaS Tools', 'build', '0078D4', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Gaming', 'sports_esports', '7B2FBE', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Cloud Storage', 'cloud', 'F4900C', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Security VPN', 'shield', '22C55E', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Utilities', 'bolt', 'EAB308', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'News Reading', 'menu_book', '6B7280', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'AI Tools', 'auto_awesome', '8B5CF6', 'Y');

INSERT INTO EXPENSE_CATEGORIES (category_id, name, icon_code, color_hex, is_system)
VALUES (SEQ_CATEGORIES.NEXTVAL, 'Fitness Health', 'fitness_center', 'EF4444', 'Y');

COMMIT;

-- ============================================================================
-- SECTION 11.3: SUBSCRIPTION_VENDORS
-- ============================================================================

PROMPT Inserting SUBSCRIPTION_VENDORS...

DELETE FROM SUBSCRIPTION_VENDORS WHERE vendor_name IN (
    'Netflix', 'Spotify', 'YouTube Premium', 'Amazon Prime', 
    'Adobe Creative Cloud', 'Microsoft 365', 'GitHub Pro', 
    'ChatGPT Plus', 'Steam', 'Google One', 'Dropbox', 'NordVPN'
);

DECLARE
    v_streaming NUMBER;
    v_music NUMBER;
    v_saas NUMBER;
    v_gaming NUMBER;
    v_cloud NUMBER;
    v_security NUMBER;
    v_ai NUMBER;
BEGIN
    SELECT category_id INTO v_streaming FROM EXPENSE_CATEGORIES WHERE name = 'Streaming';
    SELECT category_id INTO v_music FROM EXPENSE_CATEGORIES WHERE name = 'Music';
    SELECT category_id INTO v_saas FROM EXPENSE_CATEGORIES WHERE name = 'SaaS Tools';
    SELECT category_id INTO v_gaming FROM EXPENSE_CATEGORIES WHERE name = 'Gaming';
    SELECT category_id INTO v_cloud FROM EXPENSE_CATEGORIES WHERE name = 'Cloud Storage';
    SELECT category_id INTO v_security FROM EXPENSE_CATEGORIES WHERE name = 'Security VPN';
    SELECT category_id INTO v_ai FROM EXPENSE_CATEGORIES WHERE name = 'AI Tools';

    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Netflix', v_streaming, 'netflix.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Spotify', v_music, 'spotify.com', 'SE');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'YouTube Premium', v_streaming, 'youtube.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Amazon Prime', v_streaming, 'amazon.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Adobe Creative Cloud', v_saas, 'adobe.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Microsoft 365', v_saas, 'microsoft.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'GitHub Pro', v_saas, 'github.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'ChatGPT Plus', v_ai, 'openai.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Steam', v_gaming, 'store.steampowered.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Google One', v_cloud, 'one.google.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'Dropbox', v_cloud, 'dropbox.com', 'US');
    
    INSERT INTO SUBSCRIPTION_VENDORS (vendor_id, vendor_name, category_id, website_url, country_code)
    VALUES (SEQ_VENDORS.NEXTVAL, 'NordVPN', v_security, 'nordvpn.com', 'PA');
    
    COMMIT;
END;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT VERIFICATION - Seed Data Loaded
PROMPT ============================================================================

PROMPT
PROMPT --- CURRENCIES ---
SELECT currency_id, code, name, symbol, exchange_rate_to_usd FROM CURRENCIES;

PROMPT
PROMPT --- EXPENSE_CATEGORIES ---
SELECT category_id, name, icon_code, color_hex, is_system FROM EXPENSE_CATEGORIES ORDER BY category_id;

PROMPT
PROMPT --- SUBSCRIPTION_VENDORS ---
SELECT v.vendor_id, v.vendor_name, ec.name AS category, v.country_code
FROM SUBSCRIPTION_VENDORS v
JOIN EXPENSE_CATEGORIES ec ON v.category_id = ec.category_id
ORDER BY ec.name, v.vendor_name;

PROMPT
PROMPT ============================================================================
PROMPT ✅ SEED DATA LOADED SUCCESSFULLY
PROMPT ============================================================================
PROMPT
PROMPT Summary:
PROMPT   CURRENCIES: 4 records
PROMPT   EXPENSE_CATEGORIES: 10 records
PROMPT   SUBSCRIPTION_VENDORS: 12 records
PROMPT
PROMPT ============================================================================
PROMPT 🎉 DATABASE SETUP COMPLETE! 🎉
PROMPT ============================================================================

COMMIT;