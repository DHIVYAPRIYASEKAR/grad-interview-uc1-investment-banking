# Investment Banking SQL Interview Assignment

**Repository:** [`jibin-pradeepkumar/grad-interview-uc1-investment-banking`](https://github.com/jibin-pradeepkumar/grad-interview-uc1-investment-banking) (branch: `master`)
**Role:** SQL / Data Engineer — Wealth Management Platform (Graduate Interview, UC1)
**Database engine:** SQL Server (`InvestmentBankingDW`)
**Duration:** 2.5–3 hours
**Tools allowed:** SQL Server Management Studio / Azure Data Studio / `sqlcmd`, pen and paper for scratch logic. No AI code-generation tools.

---

## 1. Introduction

This repository contains everything needed to stand up a realistic wealth
management database on SQL Server: the full DDL (`schema/`) and a
pre-generated data load (`sql/insert_data.sql`). It is **not** a toy schema —
it mirrors how a real custody/booking system is built:

- History is tracked properly — advisor assignments, client profiles and
  instrument reference data all use **Slowly Changing Dimension Type 2
  (SCD2)**, so the same client or instrument can have multiple time-bound
  versions.
- **Holdings are not a fact you can just read at face value** — `fact.Holding`
  is a monthly snapshot that should agree with replaying every transaction
  in trade-date order. A handful of rows do **not** agree with that replay —
  that's intentional.
- The data contains **realistic operational noise**: duplicate transactions,
  missing prices, missing FX rates, late settlements, negative holdings, and
  other reconciliation breaks a production system would actually surface.
  Finding and correctly handling these is part of the assessment, not a bug
  in the dataset.

Read every question carefully. Several are ambiguous on purpose — part of
what we're evaluating is whether you ask the right clarifying questions
about business rules (e.g. "as of" semantics, rounding, which FX leg to
use) before writing a query that quietly gives a plausible-looking wrong
answer.

---

## 2. Getting Set Up: Fork, Clone, and Run Locally

### 2.1 Fork the repository

1. Go to the repository: `https://github.com/jibin-pradeepkumar/grad-interview-uc1-investment-banking`.
2. Click **Fork** (top right) and fork it into your own GitHub account.
3. Clone **your fork** — not the upstream repo — to your machine:

   ```bash
   git clone https://github.com/<your-github-username>/grad-interview-uc1-investment-banking.git
   cd grad-interview-uc1-investment-banking
   ```

4. Add the original repository as an `upstream` remote, so you can pull in
   any updates the interviewer pushes later:

   ```bash
   git remote add upstream https://github.com/jibin-pradeepkumar/grad-interview-uc1-investment-banking.git
   git remote -v
   ```

### 2.2 Prerequisites

You need a local (or containerized) SQL Server instance. Pick one:

- **SQL Server Developer Edition** (free) — [download here](https://www.microsoft.com/en-us/sql-server/sql-server-downloads), or
- **Docker** (fastest option, works on Mac/Linux/Windows):

  ```bash
  docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong!Passw0rd" \
    -p 1433:1433 --name sql-interview -d mcr.microsoft.com/mssql/server:2022-latest
  ```

Plus a client to run `.sql` scripts: **Azure Data Studio**, **SQL Server
Management Studio (SSMS)**, or the `sqlcmd` command-line tool.

### 2.3 Run the schema scripts, in order

The `schema/` folder must be run **in this exact order** — later scripts
depend on objects created by earlier ones:

| Order | Script | What it creates |
|---|---|---|
| 1 | `schema/create_database.sql` | The `InvestmentBankingDW` database and the `dim`, `fact`, `rpt` schemas |
| 2 | `schema/create_tables.sql` | All 17 dimension and fact tables |
| 3 | `schema/foreign_keys.sql` | Referential integrity constraints between tables |
| 4 | `schema/indexes.sql` | Performance indexes on point-in-time and fact-table access patterns |
| 5 | `schema/views.sql` | Reporting views (`dim.vw_Current*`, `rpt.vw_Latest*`, `rpt.vw_ClientAUM`, `rpt.vw_SuspectedDuplicateTransactions`, `rpt.vw_LateSettlements`) |
| 6 | `schema/functions.sql` | Point-in-time / carry-forward lookup functions (see Section 3.3) |
| 7 | `schema/stored_procedures.sql` | Reusable procedures for the harder replay-based questions |

**Using `sqlcmd`** (run from the repository root, adjust host/credentials as needed):

```bash
for f in schema/create_database.sql schema/create_tables.sql schema/foreign_keys.sql \
         schema/indexes.sql schema/views.sql schema/functions.sql schema/stored_procedures.sql; do
  sqlcmd -S localhost,1433 -U sa -P 'YourStrong!Passw0rd' -i "$f"
done
```

**Using Azure Data Studio / SSMS:** open each file in the order above,
connect to your local instance, and click *Run* / *Execute* for each one.

### 2.4 Load the data

Once the schema exists, load the pre-generated dataset:

```bash
sqlcmd -S localhost,1433 -U sa -P 'YourStrong!Passw0rd' -i sql/insert_data.sql
```

This script is large (it loads roughly 420,000 rows across 17 tables,
including ~127K instrument prices, ~169K holding snapshots, ~52K portfolio
snapshots, and ~20K transactions) — it can take a few minutes depending on
your machine.

### 2.5 Verify your setup

Run this quick sanity check before you start answering questions:

```sql
USE InvestmentBankingDW;
SELECT 'dim.Client' AS tbl, COUNT(*) AS row_count FROM dim.Client
UNION ALL SELECT 'dim.Instrument', COUNT(*) FROM dim.Instrument
UNION ALL SELECT 'fact.[Transaction]', COUNT(*) FROM fact.[Transaction]
UNION ALL SELECT 'fact.Holding', COUNT(*) FROM fact.Holding
UNION ALL SELECT 'fact.InstrumentPrice', COUNT(*) FROM fact.InstrumentPrice;
```

You should see non-zero counts for every row (roughly: 118 client versions,
288 instrument versions, ~20,071 transactions, ~169,116 holdings, ~127,352
prices). If any table is empty, re-check that every script in Section 2.3
ran without error before loading `sql/insert_data.sql`.

### 2.6 Create your feature branch

Once your local database is loaded and verified, create a feature branch in
**your fork** to work in:

```bash
git checkout -b feature/<your-github-username>-uc1-answers
```

Example: `feature/jsmith-uc1-answers`.

---

## 3. Background: Data Model Overview

The schema is organized into three SQL Server schemas: `dim` (dimensions),
`fact` (transactional/measurable data), and `rpt` (reporting views/procs).

### 3.1 Dimension tables (`dim`)

| Table | SCD2? | Purpose |
|---|---|---|
| `dim.Currency` | No | Reference list of the 10 currencies traded on the platform (code, name, symbol, minor unit). |
| `dim.Advisor` | No | Relationship advisors. Static identity data (name, region, hire date) — an advisor's *assignment* to a client is what changes, not the advisor record itself. |
| `dim.Exchange` | **Yes** | The 15 stock exchanges instruments trade on. Versioned to capture renames, status changes and exchange-level restructuring events. |
| `dim.Client` | **Yes** | Client demographic and profile data: name, DOB, country, address, risk profile, segment, net worth, preferred currency. A new version is created whenever a client's profile is refreshed. |
| `dim.ClientContact` | **Yes** | Client contact details (name/email/phone), versioned independently of the core client profile. |
| `dim.ClientAdvisor` | **Yes** | **The advisor assignment history.** One row per period a given advisor served a given client. This is the table that answers "who was this client's advisor on date X" and "how many times did this client's advisor change." |
| `dim.InstrumentType` | **Yes** | Asset class taxonomy: Equity, ETF, Bond, Mutual Fund, REIT, Commodity, Derivative. |
| `dim.Instrument` | **Yes** | The tradable universe (288 rows / versions across ~250 distinct instruments): ticker, ISIN, name, type, listing exchange, currency, sector, industry, lot size, and lifecycle `status` (`ACTIVE` / `DELISTED`). New versions capture ticker changes, exchange migrations, and delistings. |
| `dim.TransactionType` | **Yes** | The 10 transaction types (BUY, SELL, DIVIDEND, BONUS, TRANSFER_IN, TRANSFER_OUT, INTEREST, FEE, SPLIT, RIGHTS) and whether each is a cash credit or debit. |

**Every SCD2 table shares the same four tracking columns:**
`effective_from`, `effective_to` (exclusive, `NULL` = still open), `is_current`,
`version` — plus a `business_key` (the stable natural identifier for the
entity) distinct from `surrogate_key` (the unique physical row id). Any
query that needs "the version of X that was true on date D" must filter on
`effective_from <= D AND (effective_to IS NULL OR D < effective_to)` —
**never** on `is_current` alone unless D is today.

### 3.2 Fact tables (`fact`)

| Table | Grain | Row count in the loaded dataset | Purpose |
|---|---|---|---|
| `fact.ExchangeRate` | one row per currency pair per trading day | ~9,849 | Daily FX rates, both directions, vs. USD. Not every day is populated for every pair — missing days are intentional. |
| `fact.InstrumentPrice` | one row per instrument per trading day | ~127,352 | Daily OHLCV (`[open]`, `high`, `low`, `[close]`, `volume`). Delisted instruments stop generating prices at their delisting date. An `is_trading_halt` flag and intentionally missing days are included. |
| `fact.[Transaction]` | one row per trade/cash event | ~20,071 | The core ledger: client, instrument, type, trade date, settlement date, quantity, price, currency, commission/tax/brokerage fees, net amount, and `advisor_id` — the advisor of record **at the time of the trade**. |
| `fact.Holding` | one row per client/instrument/month-end | ~169,116 | **Derived, not authoritative on its own.** A handful of rows have been deliberately corrupted (wrong quantity, or flipped negative via `is_negative_flag`) to simulate reconciliation breaks. |
| `fact.PortfolioSnapshot` | one row per client per trading day | ~52,300 | Daily and month-end (`is_month_end`) total market value, cost basis and unrealized P&L in USD. |
| `fact.CorporateAction` | one row per event | ~77 | Stock splits, bonus issues, rights issues, dividends, mergers, delistings, ticker changes and exchange migrations. |
| `fact.Settlement` | one row per transaction | ~20,071 | Expected vs. actual settlement date and status (`PENDING`/`SETTLED`/`LATE`/`FAILED`). |
| `fact.CashLedger` | one row per cash-impacting transaction | ~20,071 | Debit/credit cash movements per client, per currency. |

`[Transaction]` and `[close]`/`[open]` are bracketed in the DDL because
`TRANSACTION`, `OPEN` and `CLOSE` are reserved words in T-SQL — remember the
brackets (or double quotes with `QUOTED_IDENTIFIER` off) when referencing
them directly.

### 3.3 Pre-built views, functions and procedures you may use

You're welcome to use these, or write your own equivalent logic if you'd
rather demonstrate you understand what's underneath them:

- **Views:** `dim.vw_CurrentClient`, `dim.vw_CurrentInstrument`, `dim.vw_CurrentClientAdvisor`, `dim.vw_CurrentExchange` — latest version of each SCD2 dimension. `rpt.vw_LatestInstrumentPrice`, `rpt.vw_LatestHolding` — most recent row per instrument / per client-instrument. `rpt.vw_ClientAUM` — latest holdings × latest prices, by currency (not yet converted to USD). `rpt.vw_SuspectedDuplicateTransactions`, `rpt.vw_LateSettlements` — pre-built reconciliation exception views.
- **Functions:** `dim.fn_ClientAsOf(@BusinessKey, @AsOfDate)`, `dim.fn_InstrumentAsOf(...)`, `dim.fn_ClientAdvisorAsOf(...)` — point-in-time SCD2 lookups. `fact.fn_LatestPriceAsOf(...)`, `fact.fn_LatestFxRateAsOf(...)`, `fact.fn_ConvertCurrency(...)` — carry-forward price/FX lookups and currency conversion.
- **Stored procedures:** `rpt.usp_ReconstructHoldingsAsOf`, `rpt.usp_FifoRealizedPnl`, `rpt.usp_ApplyCorporateActionAdjustment` — for the harder replay-based questions.

---

## 4. Instructions

- Answer every question with a single, runnable T-SQL query (CTEs and
  temp tables are fine; avoid procedural cursors unless a question
  genuinely requires lot-by-lot matching, e.g. Q6).
- State any assumption you make directly above the query, in a one-line
  SQL comment.
- Where a question says "as of a date," your query must be parameterized
  or clearly show how to change the date — do not hard-code logic that
  only works for one specific value by coincidence.
- Partial credit is given for correct logic even if the exact numeric
  answer is off due to a misread column; full credit requires the query to
  actually run against the loaded database.

---

## 5. Assignment — Part A: Query Questions

### Q1. Client portfolio value as of 31-Dec-2025 (in USD)
Return each client's total portfolio value as of **31-Dec-2025**, converted
to USD.
**Requires:** latest holding as of the date, latest price on or before the
date, FX conversion to USD, aggregation to one row per client.

### Q2. Clients with more than two advisor changes in 2025
Find clients whose advisor changed **more than twice** during calendar year
2025.

### Q3. Instruments whose sector changed while a client still held them
Find instruments where the sector classification changed **while a client
had an open position** in that instrument (i.e. the sector change date falls
between the client's position open and close dates).

### Q4. Clients who transacted after their KYC/profile had expired
Find clients who made a transaction **after** their KYC/profile review was
due to have expired (i.e. after the effective window of their last approved
client profile version had lapsed, with no newer version on file at the
time of the trade).

### Q5. Portfolios containing delisted instruments
Find every client currently holding a position in an instrument whose
current status is `DELISTED`.

### Q6. Realized P&L (FIFO)
Calculate realized profit/loss for every SELL transaction using **FIFO**
lot matching against prior BUY transactions for the same client and
instrument.
*(This is intentionally the hardest query on the assessment — it is a
strong differentiator. See `rpt.usp_FifoRealizedPnl` for one reference
implementation pattern, but write your own.)*

### Q7. Top 10 gainers over the last 90 trading days
Return the top 10 instruments by percentage price change over the trailing
90 trading days (as of the latest date in the dataset).

### Q8. Stale prices
Find every instrument with **no price update in the last five trading days**
(as of the latest date in the dataset).

### Q9. Clients with negative holdings
Identify every client/instrument combination with a negative holding
quantity. This should never legitimately happen — flag it as a data
integrity exception.

### Q10. Circular transfers
Detect circular transfer chains: Client A → Client B → Client A (a
`TRANSFER_OUT` from A matched with a `TRANSFER_IN` to B, followed by a
`TRANSFER_OUT` from B matched with a `TRANSFER_IN` back to A, for the same
instrument within a reasonable time window).

### Q11. Advisor AUM trend, month over month
For each advisor, calculate total client AUM (in USD) at each month-end,
and the month-over-month percentage change.

### Q12. Clients who bought ahead of a 15% price spike
Find clients who purchased an instrument within **seven days before** that
instrument's price rose by 15% or more.

### Q13. Weighted average purchase price
For each client/instrument holding, calculate the weighted average purchase
price based on all BUY (and TRANSFER_IN) transactions to date.

### Q14. Rank advisors by annual portfolio growth
Rank advisors by the aggregate percentage growth in their book of clients'
portfolio value from the first to the last day of the year.

### Q15. Advisor switch followed by portfolio decline
Find clients who switched advisors and then experienced a **decline of more
than 20%** in portfolio value within the following 90 days.

---

## 6. Assignment — Part B: Business Case

### Scenario

A global wealth management firm manages investment portfolios for its
clients. Each client is assigned a Relationship Advisor. Advisors may
change over time due to internal restructuring or client requests. The
organization stores advisor history using **Slowly Changing Dimension Type 2
(SCD2)** — this is `dim.ClientAdvisor` in the loaded database.

During **August 2025**, client **C001** changed advisors.

### What the finance department needs

Using the schema described in Section 3, write the SQL required to produce
the following four deliverables. State any assumptions about "as of" and
"latest available" semantics explicitly.

1. **Transaction commissions earned by each advisor during August 2025.**
   Each transaction must be attributed to whichever advisor was actually
   responsible for the client **on the transaction's trade date** — not
   simply the client's advisor today. For a client like C001 whose advisor
   changed mid-month, commissions before and after the change must be
   correctly split between the outgoing and incoming advisor.

2. **Client portfolio value as of 31-Aug-2025**, for every client.

3. **Portfolio valuation methodology.** Your solution must use:
   - the **latest available market price on or before 31-Aug-2025** for
     each held instrument (not the price exactly on that date, which may
     not exist for every instrument), and
   - the **latest available FX rate on or before 31-Aug-2025** to convert
     each position into a single reporting currency.

4. **Reporting currency.** All portfolio values must be reported in **USD**,
   regardless of the instrument's or client's native/preferred currency.

### Deliverable

One SQL script per numbered item above (4 scripts total), each clearly
commented with the business question it answers, plus a short written
paragraph (5–10 sentences) explaining how your solution handles the
mid-month advisor change for C001 specifically, and what would break in a
naive `is_current = 1` join instead.

---

## 7. Submitting Your Answers

All answer scripts go in a **new top-level folder in your fork**, named
`answers/`, organized like this:

```
grad-interview-uc1-investment-banking/
├── schema/                          (unchanged — do not edit)
├── sql/                             (unchanged — do not edit)
└── answers/
    └── <your-github-username>/
        ├── part_a/
        │   ├── q01_portfolio_value_usd.sql
        │   ├── q02_advisor_changes_2025.sql
        │   ├── q03_sector_change_while_held.sql
        │   ├── q04_kyc_expired_transactions.sql
        │   ├── q05_delisted_holdings.sql
        │   ├── q06_fifo_realized_pnl.sql
        │   ├── q07_top_10_gainers_90d.sql
        │   ├── q08_stale_prices.sql
        │   ├── q09_negative_holdings.sql
        │   ├── q10_circular_transfers.sql
        │   ├── q11_advisor_aum_trend.sql
        │   ├── q12_pre_spike_purchases.sql
        │   ├── q13_weighted_avg_purchase_price.sql
        │   ├── q14_advisor_growth_ranking.sql
        │   └── q15_advisor_switch_decline.sql
        ├── part_b/
        │   ├── b1_advisor_commissions_aug2025.sql
        │   ├── b2_portfolio_value_31aug2025.sql
        │   ├── b3_valuation_methodology_notes.md   (short written explanation, item 3 in Section 6)
        │   └── b4_usd_reporting_check.sql
        └── README.md                                (your assumptions log, one line per question)
```

**Steps to submit:**

1. Make sure your work is committed on your feature branch
   (`feature/<your-github-username>-uc1-answers`, created in Section 2.6),
   under `answers/<your-github-username>/` exactly as laid out above.
2. Do **not** modify anything under `schema/` or `sql/` — those are the
   fixed inputs everyone is graded against.
3. Push your branch to **your fork**:

   ```bash
   git add answers/<your-github-username>/
   git commit -m "Add UC1 SQL interview answers"
   git push origin feature/<your-github-username>-uc1-answers
   ```

4. Open a **Pull Request from your fork's feature branch into
   `jibin-pradeepkumar/grad-interview-uc1-investment-banking:master`**.
   Title the PR `UC1 Answers — <your name>`.
5. In the PR description, paste the output (row count / sample rows) of the
   verification query from Section 2.5, confirming your local database
   loaded correctly, plus a one-line status per question (answered /
   partially answered / skipped).

---
 
Good luck.
