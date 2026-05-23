import pymysql
from pymysql.err import OperationalError

# Verbindung anpassen
USER = "root"
PASSWORD = "Odilehardy1994@"  # dein MySQL Passwort
HOST = "127.0.0.1"
PORT = 3306
DB = "fraud_analysis"

BATCH_SIZE = 50_000


def log(message):
    print(message, flush=True)


conn = pymysql.connect(
    host="127.0.0.1",
    user="root",
    password="Odilehardy1994@",
    database="fraud_analysis",
    port=3306,
    connect_timeout=60,
    read_timeout=3600,
    write_timeout=3600,
)
cursor = conn.cursor()


def execute_step(description, sql):
    log(description)
    cursor.execute(sql)
    conn.commit()
    return cursor.rowcount


def ensure_index(table, index_name, columns):
    cursor.execute(
        """
        SELECT COUNT(*)
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = %s
          AND INDEX_NAME = %s
        """,
        (table, index_name),
    )
    if cursor.fetchone()[0]:
        return

    columns_sql = ", ".join(columns)
    log(f"    Lege Index {index_name} auf {table} an...")
    cursor.execute(f"ALTER TABLE {table} ADD INDEX {index_name} ({columns_sql})")
    conn.commit()


try:
    log("Verbindung OK - starte Transform...")

    cursor.execute("SET SESSION wait_timeout = 3600")
    cursor.execute("SET SESSION interactive_timeout = 3600")
    cursor.execute("SET SESSION net_read_timeout = 3600")
    cursor.execute("SET SESSION net_write_timeout = 3600")
    cursor.execute("SET SESSION lock_wait_timeout = 30")

    log("\n[0/4] Tabellen leeren...")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
    for table in ["fact_transactions", "dim_customer", "dim_merchant", "dim_date"]:
        log(f"    Leere {table}...")
        cursor.execute(f"TRUNCATE TABLE {table}")
        log(f"    {table} geleert")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
    conn.commit()

    log("\nLege Indexe fuer schnellere Joins an...")
    ensure_index("staging_transactions", "idx_staging_customer", ["first_name", "last_name", "street"])
    ensure_index("staging_transactions", "idx_staging_merchant", ["merchant", "category"])
    ensure_index("staging_transactions", "idx_staging_datetime", ["trans_datetime"])
    ensure_index("staging_transactions", "idx_staging_trans_num", ["trans_num"])
    ensure_index("dim_customer", "idx_dim_customer_lookup", ["first_name", "last_name", "street"])
    ensure_index("dim_merchant", "idx_dim_merchant_lookup", ["merchant_name", "category"])
    ensure_index("dim_date", "idx_dim_date_full_date", ["full_date"])

    log("\n[1/4] Fuelle dim_customer...")
    inserted = execute_step(
        "    Schreibe dim_customer...",
        """
        INSERT INTO dim_customer
            (first_name, last_name, gender, date_of_birth, job, street, city, state, lat, lng, city_pop)
        SELECT
            first_name,
            last_name,
            MIN(gender),
            STR_TO_DATE(MIN(dob), '%Y-%m-%d'),
            MIN(job),
            street,
            MIN(city),
            MIN(state),
            MIN(lat),
            MIN(lng),
            MIN(city_pop)
        FROM staging_transactions
        GROUP BY first_name, last_name, street
        """,
    )
    log(f"    dim_customer: {inserted:,} Zeilen eingefuegt")

    log("\n[2/4] Fuelle dim_merchant...")
    inserted = execute_step(
        "    Schreibe dim_merchant...",
        """
        INSERT INTO dim_merchant (merchant_name, category, merch_lat, merch_lng)
        SELECT
            merchant,
            category,
            AVG(merch_lat),
            AVG(merch_lng)
        FROM staging_transactions
        GROUP BY merchant, category
        """,
    )
    log(f"    dim_merchant: {inserted:,} Zeilen eingefuegt")

    log("\n[3/4] Fuelle dim_date...")
    inserted = execute_step(
        "    Schreibe dim_date...",
        """
        INSERT INTO dim_date (full_date, year, month, day, hour, weekday, is_weekend)
        SELECT
            full_date,
            YEAR(full_date),
            MONTH(full_date),
            DAY(full_date),
            HOUR(full_date),
            DAYNAME(full_date),
            IF(DAYOFWEEK(full_date) IN (1,7), 1, 0)
        FROM (
            SELECT DISTINCT STR_TO_DATE(trans_datetime, '%Y-%m-%d %H:%i:%s') AS full_date
            FROM staging_transactions
        ) dates
        """,
    )
    log(f"    dim_date: {inserted:,} Zeilen eingefuegt")

    log("\n[4/4] Fuelle fact_transactions in Batches...")
    cursor.execute("SELECT COUNT(*) FROM staging_transactions")
    total_staging_rows = cursor.fetchone()[0]
    total_inserted = 0

    for offset in range(0, total_staging_rows, BATCH_SIZE):
        batch_end = min(offset + BATCH_SIZE, total_staging_rows)
        log(f"    Batch {offset + 1:,} bis {batch_end:,}...")
        try:
            cursor.execute(
                """
                INSERT INTO fact_transactions
                    (customer_id, merchant_id, date_id, amount, trans_num, is_fraud)
                SELECT
                    c.customer_id,
                    m.merchant_id,
                    d.date_id,
                    s.amt,
                    s.trans_num,
                    s.is_fraud
                FROM (
                    SELECT *
                    FROM staging_transactions
                    ORDER BY trans_num
                    LIMIT %s OFFSET %s
                ) s
                JOIN dim_customer c ON s.first_name = c.first_name
                                   AND s.last_name  = c.last_name
                                   AND s.street     = c.street
                JOIN dim_merchant m ON s.merchant   = m.merchant_name
                                   AND s.category   = m.category
                JOIN dim_date     d ON STR_TO_DATE(s.trans_datetime, '%%Y-%%m-%%d %%H:%%i:%%s') = d.full_date
                """,
                (BATCH_SIZE, offset),
            )
            conn.commit()
            total_inserted += cursor.rowcount
        except OperationalError:
            conn.rollback()
            raise

    log(f"    fact_transactions: {total_inserted:,} Zeilen eingefuegt")

    log("\nAbschlusskontrolle")
    for table in ["dim_customer", "dim_merchant", "dim_date", "fact_transactions"]:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        log(f"    {table:<25} {count:>10,} Zeilen")

    log("\nTransform erfolgreich abgeschlossen!")
finally:
    cursor.close()
    conn.close()
