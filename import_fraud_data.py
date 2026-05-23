import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.exc import OperationalError

# ── Verbindung anpassen ──────────────────────────────────────
USER     = "root"
PASSWORD = "Odilehardy1994@"   # dein MySQL Passwort hier
HOST     = "127.0.0.1"
PORT     = 3306
DB       = "fraud_analysis"
CSV_PATH = r"C:\Projekt Ordner\Credit Fraud Dataset\fraudTrain.csv" # Pfad anpassen
# ─────────────────────────────────────────────────────────────

csv_file = Path(CSV_PATH)
if not csv_file.exists():
    raise FileNotFoundError(
        f"CSV-Datei nicht gefunden: {csv_file}\n"
        "Bitte lade fraudTrain.csv herunter und passe CSV_PATH im Skript an."
    )

connection_url = URL.create(
    "mysql+pymysql",
    username="root",
    password="Odilehardy1994@",
    host="127.0.0.1",
    port=3306,
    database="fraud_analysis",
)
engine = create_engine(connection_url)

try:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
except OperationalError as exc:
    raise SystemExit(
        "MySQL-Anmeldung fehlgeschlagen.\n"
        f"User/Host: {USER}@{HOST}:{PORT}\n"
        "Bitte pruefe USER, PASSWORD und ob der MySQL-User Zugriff auf die Datenbank hat.\n"
        f"Originalfehler: {exc.orig}"
    ) from exc

print("Starte Import...")

chunk_size = 50_000
total = 0
columns = [
    "trans_datetime","cc_num","merchant","category","amt",
    "first_name","last_name","gender","street","city","state",
    "zip","lat","lng","city_pop","job","dob","trans_num",
    "unix_time","merch_lat","merch_lng","is_fraud"
]

for i, chunk in enumerate(pd.read_csv(CSV_PATH, chunksize=chunk_size, index_col=0)):

    chunk.columns = columns

    chunk.to_sql(
        name      = "staging_transactions",
        con       = engine,
        if_exists = "append",
        index     = False,
        method    = "multi"
    )

    total += len(chunk)
    print(f"  Chunk {i+1} importiert → {total:,} Zeilen gesamt")

print(f"\nFertig! {total:,} Zeilen erfolgreich importiert.")


import pymysql

# ── Verbindung anpassen ──────────────────────────────────────
USER     = "root"
PASSWORD = "dein_passwort"    # dein MySQL Passwort
HOST     = "127.0.0.1"
PORT     = 3306
DB       = "fraud_analysis"
# ─────────────────────────────────────────────────────────────

conn = pymysql.connect(
    host=HOST, user=USER, password=PASSWORD,
    database=DB, port=PORT,
    connect_timeout=600,
    read_timeout=600,
    write_timeout=600
)
cursor = conn.cursor()

print("Verbindung OK — starte Transform...")

# ── 1. dim_customer ──────────────────────────────────────────
print("\n[1/3] Fülle dim_customer...")
cursor.execute("""
    INSERT INTO dim_customer 
        (first_name, last_name, gender, date_of_birth, job, street, city, state, lat, lng, city_pop)
    SELECT DISTINCT
        first_name, last_name, gender,
        STR_TO_DATE(dob, '%Y-%m-%d'),
        job, street, city, state, lat, lng, city_pop
    FROM staging_transactions
""")
conn.commit()
print(f"    dim_customer: {cursor.rowcount:,} Zeilen eingefügt")

# ── 2. dim_merchant ──────────────────────────────────────────
print("\n[2/3] Fülle dim_merchant...")
cursor.execute("""
    INSERT INTO dim_merchant (merchant_name, category, merch_lat, merch_lng)
    SELECT DISTINCT merchant, category, merch_lat, merch_lng
    FROM staging_transactions
""")
conn.commit()
print(f"    dim_merchant: {cursor.rowcount:,} Zeilen eingefügt")

# ── 3. dim_date ───────────────────────────────────────────────
print("\n[3/3] Fülle dim_date...")
cursor.execute("""
    INSERT INTO dim_date (full_date, year, month, day, hour, weekday, is_weekend)
    SELECT DISTINCT
        STR_TO_DATE(trans_datetime, '%Y-%m-%d %H:%i:%s'),
        YEAR(STR_TO_DATE(trans_datetime,   '%Y-%m-%d %H:%i:%s')),
        MONTH(STR_TO_DATE(trans_datetime,  '%Y-%m-%d %H:%i:%s')),
        DAY(STR_TO_DATE(trans_datetime,    '%Y-%m-%d %H:%i:%s')),
        HOUR(STR_TO_DATE(trans_datetime,   '%Y-%m-%d %H:%i:%s')),
        DAYNAME(STR_TO_DATE(trans_datetime,'%Y-%m-%d %H:%i:%s')),
        IF(DAYOFWEEK(STR_TO_DATE(trans_datetime,'%Y-%m-%d %H:%i:%s')) IN (1,7), 1, 0)
    FROM staging_transactions
""")
conn.commit()
print(f"    dim_date: {cursor.rowcount:,} Zeilen eingefügt")

# ── 4. fact_transactions ──────────────────────────────────────
print("\nFülle fact_transactions (dauert länger)...")
cursor.execute("""
    INSERT INTO fact_transactions 
        (customer_id, merchant_id, date_id, amount, trans_num, is_fraud)
    SELECT
        c.customer_id,
        m.merchant_id,
        d.date_id,
        s.amt,
        s.trans_num,
        s.is_fraud
    FROM staging_transactions s
    JOIN dim_customer c ON s.first_name = c.first_name 
                       AND s.last_name  = c.last_name 
                       AND s.street     = c.street
    JOIN dim_merchant m ON s.merchant   = m.merchant_name 
                       AND s.category   = m.category
    JOIN dim_date     d ON STR_TO_DATE(s.trans_datetime, '%Y-%m-%d %H:%i:%s') = d.full_date
""")
conn.commit()
print(f"    fact_transactions: {cursor.rowcount:,} Zeilen eingefügt")

# ── Abschlusskontrolle ────────────────────────────────────────
print("\n── Abschlusskontrolle ──────────────────")
for tabelle in ["dim_customer","dim_merchant","dim_date","fact_transactions"]:
    cursor.execute(f"SELECT COUNT(*) FROM {tabelle}")
    count = cursor.fetchone()[0]
    print(f"  {tabelle:<25} {count:>10,} Zeilen")

cursor.close()
conn.close()
print("\nTransform abgeschlossen!")