# 💳 Credit Card Fraud Analysis
### Finance Data Analytics Project | MySQL • Python • Power BI

## 📸 Dashboard Screenshots

![Executive Summary](dashboard_page1.(Executive Summary).png)
![Fraud Analyse](dashboard_page2. (Fraud Analyse).png)
![Zeitanalyse](dashboard_page3.pn(Zeitanalyse).png)
![Kunden & Geografie](dashboard_page4.(Kunden Geografie).png)
---

## 📋 Projektübersicht

Analyse von **1,3 Millionen Kreditkartentransaktionen** zur Erkennung 
von Betrugsmustern und Geschäftseinblicken im Finanzbereich.

**Zeitraum:** Januar 2019 – Juni 2020  
**Datensatz:** [Kaggle - Credit Card Fraud Detection](https://www.kaggle.com/datasets/kartik2112/fraud-detection)

---

## 🎯 Wichtigste Erkenntnisse

- 🚨 **Fraud-Quote:** 0,58% aller Transaktionen sind betrügerisch
- 💰 **Fraud-Schaden:** $3,99 Millionen Gesamtschaden
- ⏰ **Risikoreichste Zeit:** 22-23 Uhr (Fraud-Quote > 2,8%)
- 🛒 **Risikoreichste Kategorie:** Online Shopping (1,76%)
- 👴 **Risikoreichste Altersgruppe:** 65+ Jahre (0,75%)
- 🌍 **Top Bundesstaat:** Texas ($6,8 Mio. Umsatz)
- 💳 **Hochrisiko-Transaktionen:** Über $500 → 23,34% Fraud-Quote

---

## 🛠️ Tools & Technologien

| Tool | Verwendung |
|------|-----------|
| **Python** | ETL-Pipeline, Datenimport |
| **Pandas** | Datentransformation |
| **SQLAlchemy** | Datenbankverbindung |
| **MySQL** | Datenbankdesign, SQL-Analyse |
| **Power BI** | Dashboard, Datenvisualisierung |

---

## 🏗️ Projektarchitektur

CSV Rohdaten (1,3 Mio. Zeilen)
↓
Python ETL Pipeline
↓
MySQL Datenbank (Star-Schema)
├── fact_transactions
├── dim_customer
├── dim_merchant
└── dim_date
↓
Power BI Dashboard (4 Seiten)

---

## 📊 Dashboard Seiten

| Seite | Inhalt |
|-------|--------|
| **Executive Summary** | KPIs, Umsatz & Fraud-Überblick |
| **Fraud Analyse** | Fraud-Muster nach Zeit, Betrag, Kategorie |
| **Zeitanalyse** | Trends, saisonale Muster |
| **Kunden & Geografie** | Demografie, Top-Bundesstaaten |

---

## 🗄️ SQL Analyse

20 professionelle SQL-Queries in 5 Kategorien:
- Überblick & KPIs
- Fraud Analyse
- Zeitanalyse
- Kunden Analyse
- Window Functions & CTEs

---

## 📁 Projektstruktur

credit-fraud-analysis/
│
├── sql/
│   └── fraud_analysis_queries.sql
│
├── python/
│   ├── import_fraud_data.py
│   └── transform_star_schema.py
│
├── screenshots/
│   ├── dashboard_page1.png
│   ├── dashboard_page2.png
│   ├── dashboard_page3.png
│   └── dashboard_page4.png
│
└── README.md

---

## 👤 Autor

**Boris Petamba**  
Data Analyst  
[LinkedIn](#) | [GitHub](https://github.com/Borisy-94)


