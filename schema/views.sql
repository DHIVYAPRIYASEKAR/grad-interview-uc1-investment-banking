/*
    Investment Banking SQL Dataset Generator
    Reporting views (SQL Server / T-SQL)
*/
USE InvestmentBankingDW;
GO

-- Current-version convenience views over every SCD2 dimension
CREATE OR ALTER VIEW dim.vw_CurrentClient AS
SELECT * FROM dim.Client WHERE is_current = 1;
GO

CREATE OR ALTER VIEW dim.vw_CurrentInstrument AS
SELECT * FROM dim.Instrument WHERE is_current = 1;
GO

CREATE OR ALTER VIEW dim.vw_CurrentClientAdvisor AS
SELECT * FROM dim.ClientAdvisor WHERE is_current = 1;
GO

CREATE OR ALTER VIEW dim.vw_CurrentExchange AS
SELECT * FROM dim.Exchange WHERE is_current = 1;
GO

-- Latest available price per instrument as of "today" (max price_date)
CREATE OR ALTER VIEW rpt.vw_LatestInstrumentPrice AS
SELECT p.*
FROM fact.InstrumentPrice p
INNER JOIN (
    SELECT instrument_business_key, MAX(price_date) AS max_date
    FROM fact.InstrumentPrice
    GROUP BY instrument_business_key
) latest
    ON latest.instrument_business_key = p.instrument_business_key
   AND latest.max_date = p.price_date;
GO

-- Latest holding snapshot per client/instrument
CREATE OR ALTER VIEW rpt.vw_LatestHolding AS
SELECT h.*
FROM fact.Holding h
INNER JOIN (
    SELECT client_business_key, instrument_business_key, MAX(as_of_date) AS max_date
    FROM fact.Holding
    GROUP BY client_business_key, instrument_business_key
) latest
    ON latest.client_business_key = h.client_business_key
   AND latest.instrument_business_key = h.instrument_business_key
   AND latest.max_date = h.as_of_date
WHERE h.quantity <> 0;
GO

-- Client AUM (assets under management) using latest holdings x latest prices
CREATE OR ALTER VIEW rpt.vw_ClientAUM AS
SELECT
    h.client_business_key,
    SUM(h.quantity * p.[close]) AS market_value_local,
    i.currency_code
FROM rpt.vw_LatestHolding h
INNER JOIN dim.vw_CurrentInstrument i ON i.business_key = h.instrument_business_key
INNER JOIN rpt.vw_LatestInstrumentPrice p ON p.instrument_business_key = h.instrument_business_key
GROUP BY h.client_business_key, i.currency_code;
GO

-- Duplicate transaction candidates (same client/instrument/date/qty/price)
CREATE OR ALTER VIEW rpt.vw_SuspectedDuplicateTransactions AS
SELECT
    t1.transaction_id AS transaction_id_a,
    t2.transaction_id AS transaction_id_b,
    t1.client_business_key,
    t1.instrument_business_key,
    t1.trade_date,
    t1.quantity,
    t1.price
FROM fact.[Transaction] t1
INNER JOIN fact.[Transaction] t2
    ON t1.client_business_key = t2.client_business_key
   AND t1.instrument_business_key = t2.instrument_business_key
   AND t1.trade_date = t2.trade_date
   AND t1.quantity = t2.quantity
   AND t1.price = t2.price
   AND t1.transaction_type = t2.transaction_type
   AND t1.transaction_id < t2.transaction_id;
GO

-- Late-settling transactions
CREATE OR ALTER VIEW rpt.vw_LateSettlements AS
SELECT s.*, t.client_business_key, t.instrument_business_key, t.trade_date
FROM fact.Settlement s
INNER JOIN fact.[Transaction] t ON t.transaction_id = s.transaction_id
WHERE s.status = 'LATE'
   OR (s.actual_settlement_date IS NOT NULL AND s.actual_settlement_date > s.expected_settlement_date);
GO
