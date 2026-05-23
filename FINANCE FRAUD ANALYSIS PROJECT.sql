-- ============================================
-- FINANCE FRAUD ANALYSIS PROJECT
-- Datenbank Setup
-- ============================================

CREATE DATABASE IF NOT EXISTS fraud_analysis
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fraud_analysis;

-- Dimension: Kunden
CREATE TABLE dim_customer (
    customer_id   INT            NOT NULL AUTO_INCREMENT,
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    gender        CHAR(1),
    date_of_birth DATE,
    job           VARCHAR(100),
    street        VARCHAR(150),
    city          VARCHAR(100),
    state         CHAR(2),
    lat           DECIMAL(9,6),
    lng           DECIMAL(9,6),
    city_pop      INT,
    PRIMARY KEY (customer_id)
);

-- Dimension: Händler
CREATE TABLE dim_merchant (
    merchant_id   INT            NOT NULL AUTO_INCREMENT,
    merchant_name VARCHAR(150),
    category      VARCHAR(80),
    merch_lat     DECIMAL(9,6),
    merch_lng     DECIMAL(9,6),
    PRIMARY KEY (merchant_id)
);

-- Dimension: Datum/Zeit
CREATE TABLE dim_date (
    date_id    INT  NOT NULL AUTO_INCREMENT,
    full_date  DATETIME,
    year       SMALLINT,
    month      TINYINT,
    day        TINYINT,
    hour       TINYINT,
    weekday    VARCHAR(10),
    is_weekend TINYINT DEFAULT 0,
    PRIMARY KEY (date_id)
);

-- Faktentabelle: Transaktionen
CREATE TABLE fact_transactions (
    transaction_id BIGINT       NOT NULL AUTO_INCREMENT,
    customer_id    INT,
    merchant_id    INT,
    date_id        INT,
    amount         DECIMAL(10,2),
    trans_num      VARCHAR(50),
    is_fraud       TINYINT      DEFAULT 0,
    PRIMARY KEY (transaction_id),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    FOREIGN KEY (merchant_id) REFERENCES dim_merchant(merchant_id),
    FOREIGN KEY (date_id)     REFERENCES dim_date(date_id),
    INDEX idx_fraud     (is_fraud),
    INDEX idx_amount    (amount),
    INDEX idx_date      (date_id)
);


-- ================================================
-- Kategorie 1: Überblick & KPIs
-- ================================================

-- Query 1: Gesamtüberblick
SELECT
    COUNT(*)                                        AS gesamt_transaktionen,
    ROUND(SUM(amount), 2)                           AS gesamtumsatz_usd,
    ROUND(AVG(amount), 2)                           AS durchschnitt_usd,
    ROUND(MAX(amount), 2)                           AS max_transaktion_usd,
    ROUND(MIN(amount), 2)                           AS min_transaktion_usd,
    SUM(is_fraud)                                   AS fraud_transaktionen,
    ROUND(SUM(is_fraud) / COUNT(*) * 100, 2)        AS fraud_quote_pct
FROM fact_transactions;

-- Query 2: Umsatz & Fraud pro Händlerkategorie
SELECT
    m.category                                      AS kategorie,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct,
    ROUND(AVG(f.amount), 2)                         AS avg_betrag_usd
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY m.category;


-- Query 3: Top 10 Händler nach Umsatz
SELECT
    m.merchant_name                                 AS haendler,
    m.category                                      AS kategorie,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category
ORDER BY umsatz_usd DESC
LIMIT 10;

-- Query 4: KPI Zusammenfassung nach Jahr
SELECT
    d.year                                          AS jahr,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    ROUND(AVG(f.amount), 2)                         AS avg_betrag_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;


-- ================================================
-- Kategorie 2 — Fraud Analyse 
-- ================================================

-- Query 5: Fraud nach Händlerkategorie (Top Fraud-Kategorien)
SELECT
    m.category                                          AS kategorie,
    COUNT(*)                                            AS gesamt_transaktionen,
    SUM(f.is_fraud)                                     AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)          AS fraud_quote_pct,
    ROUND(SUM(CASE WHEN f.is_fraud = 1 THEN f.amount ELSE 0 END), 2) AS fraud_schaden_usd
FROM fact_transactions f
JOIN dim_merchant m ON f.merchant_id = m.merchant_id
GROUP BY m.category
ORDER BY fraud_quote_pct DESC;

-- Query 6: Fraud nach Tageszeit (welche Stunde ist gefährlichste?)
SELECT
    d.hour                                              AS stunde,
    COUNT(*)                                            AS gesamt_transaktionen,
    SUM(f.is_fraud)                                     AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)          AS fraud_quote_pct
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.hour
ORDER BY fraud_quote_pct DESC;

-- Query 7: Fraud nach Betragshöhe (in welchem Bereich wird am meisten betrogen?)
SELECT
    CASE
        WHEN amount < 10              THEN '1) Unter 10 USD'
        WHEN amount BETWEEN 10 AND 50  THEN '2) 10 - 50 USD'
        WHEN amount BETWEEN 50 AND 100 THEN '3) 50 - 100 USD'
        WHEN amount BETWEEN 100 AND 500 THEN '4) 100 - 500 USD'
        ELSE                               '5) Über 500 USD'
    END                                                 AS betrag_bereich,
    COUNT(*)                                            AS gesamt_transaktionen,
    SUM(is_fraud)                                       AS fraud_anzahl,
    ROUND(SUM(is_fraud) / COUNT(*) * 100, 2)            AS fraud_quote_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS fraud_schaden_usd
FROM fact_transactions
GROUP BY betrag_bereich
ORDER BY betrag_bereich;

-- Query 8: Fraud Wochenende vs. Werktag
SELECT
    CASE WHEN d.is_weekend = 1 THEN 'Wochenende' ELSE 'Werktag' END AS tag_typ,
    COUNT(*)                                            AS gesamt_transaktionen,
    SUM(f.is_fraud)                                     AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)          AS fraud_quote_pct,
    ROUND(AVG(f.amount), 2)                             AS avg_betrag_usd
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.is_weekend
ORDER BY fraud_quote_pct DESC;


-- ================================================
-- Kategorie 3 — Zeitanalyse:
-- ================================================

-- Query 9: Umsatz pro Monat
SELECT
    d.year                                          AS jahr,
    d.month                                         AS monat,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- Query 10: Umsatz pro Wochentag
SELECT
    d.weekday                                       AS wochentag,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.weekday
ORDER BY transaktionen DESC;

-- Query 11: Transaktionen pro Stunde (Heatmap-Daten)
SELECT
    d.hour                                          AS stunde,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    ROUND(AVG(f.amount), 2)                         AS avg_betrag_usd
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.hour
ORDER BY d.hour;

-- Query 12: Monatlicher Fraud-Trend
SELECT
    d.year                                          AS jahr,
    d.month                                         AS monat,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(CASE WHEN f.is_fraud = 1 THEN f.amount ELSE 0 END), 2) AS fraud_schaden_usd,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct
FROM fact_transactions f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- ================================================
--  Kategorie 4 — Kunden Analyse:
-- ================================================

-- Query 13: Top 10 Kunden nach Umsatz
SELECT
    c.first_name,
    c.last_name,
    c.gender,
    c.job,
    c.city,
    c.state,
    COUNT(*)                                        AS transaktionen,
    ROUND(SUM(f.amount), 2)                         AS umsatz_usd,
    SUM(f.is_fraud)                                 AS fraud_anzahl
FROM fact_transactions f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, 
         c.gender, c.job, c.city, c.state
ORDER BY umsatz_usd DESC
LIMIT 10;

-- Query 14: Fraud nach Geschlecht
SELECT
    c.gender                                        AS geschlecht,
    COUNT(*)                                        AS transaktionen,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct,
    ROUND(AVG(f.amount), 2)                         AS avg_betrag_usd,
    ROUND(SUM(CASE WHEN f.is_fraud = 1 THEN f.amount ELSE 0 END), 2) AS fraud_schaden_usd
FROM fact_transactions f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.gender;

-- Query 15: Fraud nach Altersgruppe
SELECT
    CASE
        WHEN TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE()) < 25 THEN '1) Unter 25'
        WHEN TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE()) BETWEEN 25 AND 34 THEN '2) 25-34'
        WHEN TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE()) BETWEEN 35 AND 44 THEN '3) 35-44'
        WHEN TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE()) BETWEEN 45 AND 54 THEN '4) 45-54'
        WHEN TIMESTAMPDIFF(YEAR, c.date_of_birth, CURDATE()) BETWEEN 55 AND 64 THEN '5) 55-64'
        ELSE '6) 65+'
    END                                             AS altersgruppe,
    COUNT(*)                                        AS transaktionen,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct,
    ROUND(AVG(f.amount), 2)                         AS avg_betrag_usd
FROM fact_transactions f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY altersgruppe
ORDER BY altersgruppe;

-- Query 16: Top 10 Berufe mit höchstem Fraud-Schaden
SELECT
    c.job                                           AS beruf,
    COUNT(*)                                        AS transaktionen,
    SUM(f.is_fraud)                                 AS fraud_anzahl,
    ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2)      AS fraud_quote_pct,
    ROUND(SUM(CASE WHEN f.is_fraud = 1 THEN f.amount ELSE 0 END), 2) AS fraud_schaden_usd
FROM fact_transactions f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.job
ORDER BY fraud_schaden_usd DESC
LIMIT 10;


-- ================================================
-- Kategorie 5 — die fortgeschrittenen Queries mit Window Functions & CTEs
-- ================================================

-- Query 17: Ranking der Kategorien nach Umsatz (Window Function)
SELECT
    kategorie,
    umsatz_usd,
    transaktionen,
    fraud_quote_pct,
    RANK() OVER (ORDER BY umsatz_usd DESC)          AS umsatz_rang,
    RANK() OVER (ORDER BY fraud_quote_pct DESC)     AS fraud_rang
FROM (
    SELECT
        m.category                                  AS kategorie,
        ROUND(SUM(f.amount), 2)                     AS umsatz_usd,
        COUNT(*)                                    AS transaktionen,
        ROUND(SUM(f.is_fraud) / COUNT(*) * 100, 2) AS fraud_quote_pct
    FROM fact_transactions f
    JOIN dim_merchant m ON f.merchant_id = m.merchant_id
    GROUP BY m.category
) basis
ORDER BY umsatz_rang;

-- Query 18: Monatlicher gleitender Durchschnitt (Moving Average)
SELECT
    jahr,
    monat,
    umsatz_usd,
    ROUND(AVG(umsatz_usd) OVER (
        ORDER BY jahr, monat
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                           AS gleitender_avg_3monate,
    fraud_anzahl,
    ROUND(AVG(fraud_anzahl) OVER (
        ORDER BY jahr, monat
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0)                                           AS gleitender_avg_fraud
FROM (
    SELECT
        d.year                                      AS jahr,
        d.month                                     AS monat,
        ROUND(SUM(f.amount), 2)                     AS umsatz_usd,
        SUM(f.is_fraud)                             AS fraud_anzahl
    FROM fact_transactions f
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY d.year, d.month
) monatsdaten
ORDER BY jahr, monat;

-- Query 19: Kumulative Summe des Umsatzes pro Jahr (Running Total)
SELECT
    jahr,
    monat,
    umsatz_usd,
    SUM(umsatz_usd) OVER (
        PARTITION BY jahr
        ORDER BY monat
        ROWS UNBOUNDED PRECEDING
    )                                               AS kumulativer_umsatz,
    ROUND(umsatz_usd / SUM(umsatz_usd) OVER (
        PARTITION BY jahr
    ) * 100, 2)                                     AS anteil_am_jahresumsatz_pct
FROM (
    SELECT
        d.year                                      AS jahr,
        d.month                                     AS monat,
        ROUND(SUM(f.amount), 2)                     AS umsatz_usd
    FROM fact_transactions f
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY d.year, d.month
) basis
ORDER BY jahr, monat;

-- Query 20: Anomalie-Erkennung mit CTE (Transaktionen über 3x dem Durchschnitt)
WITH kategorie_stats AS (
    SELECT
        m.category                                  AS kategorie,
        AVG(f.amount)                               AS avg_betrag,
        STDDEV(f.amount)                            AS stddev_betrag
    FROM fact_transactions f
    JOIN dim_merchant m ON f.merchant_id = m.merchant_id
    GROUP BY m.category
),
anomalien AS (
    SELECT
        f.transaction_id,
        m.category                                  AS kategorie,
        f.amount,
        f.is_fraud,
        ks.avg_betrag,
        ks.stddev_betrag,
        ROUND((f.amount - ks.avg_betrag) / ks.stddev_betrag, 2) AS z_score
    FROM fact_transactions f
    JOIN dim_merchant m ON f.merchant_id = m.merchant_id
    JOIN kategorie_stats ks ON m.category = ks.kategorie
    WHERE f.amount > ks.avg_betrag + (3 * ks.stddev_betrag)
)
SELECT
    kategorie,
    COUNT(*)                                        AS anomalie_transaktionen,
    SUM(is_fraud)                                   AS davon_fraud,
    ROUND(SUM(is_fraud) / COUNT(*) * 100, 2)        AS fraud_quote_pct,
    ROUND(AVG(amount), 2)                           AS avg_anomalie_betrag,
    ROUND(MAX(z_score), 2)                          AS max_z_score
FROM anomalien
GROUP BY kategorie
ORDER BY anomalie_transaktionen DESC;