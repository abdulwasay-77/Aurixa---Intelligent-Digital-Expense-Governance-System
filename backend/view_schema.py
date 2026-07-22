"""
AURIXA DATABASE SCHEMA VIEWER
Run this to see your complete database structure and all data.
Output is saved to a text file in the project root.
NOT part of the main AURIXA project — standalone utility.
"""

import oracledb
from config import config
from datetime import datetime
import sys
import os

# ============================================================================
# Configuration
# ============================================================================

# All tables in dependency order (for clean display)
TABLES_IN_ORDER = [
    # Level 1: Independent tables
    "CURRENCIES",
    "EXPENSE_CATEGORIES",
    "USERS",
    
    # Level 2: Depend on Level 1
    "USER_PROFILES",
    "USER_PREFERENCES",
    "USER_SECURITY",
    "DIGITAL_WALLETS",
    "FINANCIAL_GOALS",
    "SUBSCRIPTION_VENDORS",
    
    # Level 3: Depend on Level 2
    "SUBSCRIPTIONS",
    "SUBSCRIPTION_USAGE",
    "BILLING_CYCLES",
    "SUBSCRIPTION_HISTORY",
    "PRICE_HISTORY",
    "TRANSACTIONS",
    
    # Level 4: Depend on Level 3
    "RISK_ALERTS",
    "NOTIFICATION_LOG",
    "AI_RECOMMENDATIONS",
    "BEHAVIORAL_SIGNALS",
    "BUDGET_FORECASTS",
    "SPENDING_PATTERNS",
    
    # Level 5: Analytics
    "FINANCIAL_SCORES",
    "MONTHLY_REPORTS",
    "CATEGORY_ANALYTICS",
    "TREND_ANALYSIS",
    "AUDIT_LOG",
]

# Materialized Views
MATERIALIZED_VIEWS = [
    "MV_USER_MONTHLY_SUMMARY",
    "MV_CATEGORY_SPEND",
    "MV_HEALTH_SCORE_TREND",
]

# ============================================================================
# Database Connection
# ============================================================================

def get_connection():
    """Get Oracle connection using config"""
    try:
        conn = oracledb.connect(
            user=config.ORACLE_USER,
            password=config.ORACLE_PASSWORD,
            dsn=config.ORACLE_DSN
        )
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

# ============================================================================
# Helper Functions
# ============================================================================

def safe_truncate(value, max_len=50):
    """Truncate long values for display"""
    if value is None:
        return "NULL"
    if isinstance(value, bytes):
        return f"<BLOB: {len(value)} bytes>"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, str):
        if len(value) > max_len:
            return value[:max_len] + "..."
    return str(value)

def get_table_columns(cursor, table_name):
    """Get column information for a table"""
    try:
        cursor.execute(f"""
            SELECT COLUMN_NAME, DATA_TYPE, NULLABLE, DATA_LENGTH
            FROM USER_TAB_COLUMNS
            WHERE TABLE_NAME = '{table_name}'
            ORDER BY COLUMN_ID
        """)
        return cursor.fetchall()
    except Exception:
        return []

# ============================================================================
# Main Display Function
# ============================================================================

def view_schema(output_file=None):
    """Display complete database schema and all data"""
    
    # Determine output destination
    if output_file:
        f = open(output_file, 'w', encoding='utf-8')
    else:
        f = sys.stdout
    
    def write(text):
        f.write(text + '\n')
    
    write("=" * 80)
    write("AURIXA DATABASE SCHEMA VIEWER")
    write("=" * 80)
    write(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    write(f"User: {config.ORACLE_USER}")
    write(f"DSN: {config.ORACLE_DSN}")
    write("=" * 80)
    
    conn = get_connection()
    if not conn:
        if output_file:
            f.close()
        return
    
    cursor = conn.cursor()
    
    # ========================================================================
    # SECTION 1: TABLES AND STRUCTURE
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("TABLES AND STRUCTURE")
    write("=" * 80)
    
    # Get all tables from the schema
    cursor.execute("""
        SELECT TABLE_NAME 
        FROM USER_TABLES 
        ORDER BY TABLE_NAME
    """)
    all_tables = [row[0] for row in cursor.fetchall()]
    
    total_rows_all = 0
    
    # Show tables in organized order
    for table in TABLES_IN_ORDER:
        if table not in all_tables:
            write(f"\n⚠️ Table '{table}' does not exist yet")
            continue
            
        write(f"\n📋 {table}")
        write("-" * 60)
        
        # Get column info
        columns = get_table_columns(cursor, table)
        if columns:
            write("   COLUMNS:")
            for col in columns:
                col_name = col[0]
                data_type = col[1]
                nullable = "NULL" if col[2] == "Y" else "NOT NULL"
                data_len = col[3]
                len_str = f"({data_len})" if data_len else ""
                write(f"     ├─ {col_name}: {data_type}{len_str} {nullable}")
        
        # Get row count
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        row_count = cursor.fetchone()[0]
        total_rows_all += row_count
        write(f"\n   📊 Rows: {row_count}")
        
        # Show data
        if row_count > 0:
            write(f"\n   DATA:")
            cursor.execute(f"SELECT * FROM {table}")
            rows = cursor.fetchall()
            
            if rows:
                # Get column names
                col_names = [desc[0] for desc in cursor.description]
                write(f"   Columns: {', '.join(col_names)}")
                write("")
                
                # Show ALL rows (no limit)
                for i, row in enumerate(rows, 1):
                    write(f"   Row {i}:")
                    for j, col_name in enumerate(col_names):
                        value = safe_truncate(row[j], max_len=60)
                        write(f"     {col_name}: {value}")
                    write("")
        else:
            write("\n   (Empty table)\n")
    
    # ========================================================================
    # SECTION 2: MATERIALIZED VIEWS
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("MATERIALIZED VIEWS")
    write("=" * 80)
    
    for view in MATERIALIZED_VIEWS:
        write(f"\n📊 {view}")
        write("-" * 60)
        
        try:
            cursor.execute(f"SELECT * FROM {view}")
            rows = cursor.fetchall()
            
            if rows:
                col_names = [desc[0] for desc in cursor.description]
                write(f"   Columns: {', '.join(col_names)}")
                write(f"   Rows: {len(rows)}")
                write("")
                
                for i, row in enumerate(rows, 1):
                    values = [safe_truncate(v, max_len=40) for v in row]
                    write(f"   Row {i:2d}: {', '.join(values)}")
            else:
                write("   (Empty view)")
        except Exception as e:
            write(f"   ⚠️ Error: {e}")
    
    # ========================================================================
    # SECTION 3: SEQUENCES
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("SEQUENCES")
    write("=" * 80)
    
    cursor.execute("""
        SELECT SEQUENCE_NAME, MIN_VALUE, MAX_VALUE, INCREMENT_BY, LAST_NUMBER
        FROM USER_SEQUENCES
        ORDER BY SEQUENCE_NAME
    """)
    sequences = cursor.fetchall()
    
    for seq in sequences:
        seq_name = seq[0]
        min_val = seq[1]
        max_val = seq[2]
        inc_by = seq[3]
        last_num = seq[4]
        write(f"   {seq_name}: min={min_val}, max={max_val}, increment={inc_by}, last={last_num}")
    
    # ========================================================================
    # SECTION 4: TRIGGERS
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("TRIGGERS")
    write("=" * 80)
    
    cursor.execute("""
        SELECT TRIGGER_NAME, TABLE_NAME, TRIGGER_TYPE, TRIGGERING_EVENT, STATUS
        FROM USER_TRIGGERS
        ORDER BY TRIGGER_NAME
    """)
    triggers = cursor.fetchall()
    
    for trig in triggers:
        trig_name = trig[0]
        table_name = trig[1]
        trig_type = trig[2]
        event = trig[3]
        status = trig[4]
        write(f"   {trig_name}: {trig_type} {event} ON {table_name} [{status}]")
    
    # ========================================================================
    # SECTION 5: INDEXES
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("INDEXES")
    write("=" * 80)
    
    cursor.execute("""
        SELECT INDEX_NAME, TABLE_NAME, UNIQUENESS, STATUS
        FROM USER_INDEXES
        WHERE INDEX_NAME NOT LIKE 'SYS%'
        ORDER BY TABLE_NAME, INDEX_NAME
    """)
    indexes = cursor.fetchall()
    
    for idx in indexes:
        idx_name = idx[0]
        table_name = idx[1]
        uniqueness = idx[2]
        status = idx[3]
        write(f"   {idx_name} ON {table_name} [{uniqueness}] [{status}]")
    
    # ========================================================================
    # SUMMARY
    # ========================================================================
    
    write("\n" + "=" * 80)
    write("SUMMARY")
    write("=" * 80)
    write(f"   Tables: {len(all_tables)}")
    write(f"   Materialized Views: {len(MATERIALIZED_VIEWS)}")
    write(f"   Sequences: {len(sequences)}")
    write(f"   Triggers: {len(triggers)}")
    write(f"   Indexes: {len(indexes)}")
    write(f"   Total Rows Across All Tables: {total_rows_all}")
    write("=" * 80)
    
    cursor.close()
    conn.close()
    write("\n✅ Database connection closed")
    
    if output_file:
        f.close()
        print(f"\n✅ Output saved to: {output_file}")

# ============================================================================
# Run
# ============================================================================

if __name__ == "__main__":
    try:
        # Create output filename with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        output_file = os.path.join(project_root, f'aurixa_schema_export_{timestamp}.txt')
        
        print("\n" + "=" * 80)
        print("AURIXA DATABASE SCHEMA VIEWER")
        print("=" * 80)
        print(f"\n📁 Output file: {output_file}")
        print("⏳ Exporting database schema and data...")
        print("   (This may take a moment)\n")
        
        view_schema(output_file)
        
        print(f"\n📄 Complete output saved to:")
        print(f"   {output_file}")
        print("\nYou can open this file in any text editor.")
        
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)