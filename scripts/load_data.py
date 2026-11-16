import io
import time
import psycopg2
import pandas as pd

# Path to the raw Excel file and local PostgreSQL database
DATA_FILE = 'data/raw/Online Retail.xlsx'
DB_NAME = 'online_retail_analytics'

def load_dataset():
    print(f"Reading {DATA_FILE} into pandas...")
    start_time = time.time()
    df = pd.read_excel(DATA_FILE)
    print(f"Loaded {len(df):,} rows in {time.time() - start_time:.1f} seconds.")

    # Standardize column names to lowercase snake_case for PostgreSQL
    df.columns = [
        'invoice_no',
        'stock_code',
        'description',
        'quantity',
        'invoice_date',
        'unit_price',
        'customer_id',
        'country'
    ]

    # Clean text columns to avoid whitespace issues
    df['invoice_no'] = df['invoice_no'].astype(str).str.strip()
    df['stock_code'] = df['stock_code'].astype(str).str.strip()

    # Convert customer_id to nullable integer so missing IDs become NULL instead of floats
    df['customer_id'] = df['customer_id'].astype('Int64')

    # Connect to local PostgreSQL
    print(f"Connecting to database '{DB_NAME}'...")
    conn = psycopg2.connect(dbname=DB_NAME)
    cur = conn.cursor()

    # Recreate the raw table
    cur.execute("DROP TABLE IF EXISTS raw_retail CASCADE;")
    cur.execute("""
        CREATE TABLE raw_retail (
            invoice_no   VARCHAR(20),
            stock_code   VARCHAR(20),
            description  TEXT,
            quantity     INTEGER,
            invoice_date TIMESTAMP,
            unit_price   NUMERIC(10, 2),
            customer_id  INTEGER,
            country      VARCHAR(100)
        );
    """)
    conn.commit()

    # Fast bulk insert using PostgreSQL COPY (takes ~2 seconds instead of minutes)
    print("Bulk loading records into PostgreSQL...")
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False, na_rep='\\N')
    buffer.seek(0)

    copy_query = """
        COPY raw_retail (
            invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country
        )
        FROM STDIN WITH (FORMAT csv, NULL '\\N', QUOTE '"', ESCAPE '\\');
    """
    cur.copy_expert(copy_query, buffer)
    conn.commit()

    # Verify row count
    cur.execute("SELECT COUNT(*) FROM raw_retail;")
    total_loaded = cur.fetchone()[0]
    print(f"Successfully loaded {total_loaded:,} rows into raw_retail.")

    # Add indexes to speed up future queries
    cur.execute("CREATE INDEX idx_raw_retail_invoice ON raw_retail(invoice_no);")
    cur.execute("CREATE INDEX idx_raw_retail_customer ON raw_retail(customer_id);")
    conn.commit()
    print("Created database indexes on invoice_no and customer_id.")

    cur.close()
    conn.close()

if __name__ == '__main__':
    load_dataset()
