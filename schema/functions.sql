/*
    Investment Banking SQL Dataset Generator
    Scalar / table-valued functions (SQL Server / T-SQL)
*/
USE InvestmentBankingDW;
GO

-- Point-in-time lookup: which surrogate_key was "current" for a business_key
-- on a given date, for any SCD2 dimension. Table-valued so it can be reused
-- against Client, Instrument, Exchange, etc. by passing the table name is
-- not supported directly in T-SQL functions, so each dimension gets its own
-- thin wrapper below, all built on the same predicate pattern.
CREATE OR ALTER FUNCTION dim.fn_ClientAsOf (@BusinessKey INT, @AsOfDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) *
    FROM dim.Client
    WHERE business_key = @BusinessKey
      AND effective_from <= @AsOfDate
      AND (effective_to IS NULL OR effective_to > @AsOfDate)
);
GO

CREATE OR ALTER FUNCTION dim.fn_InstrumentAsOf (@BusinessKey INT, @AsOfDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) *
    FROM dim.Instrument
    WHERE business_key = @BusinessKey
      AND effective_from <= @AsOfDate
      AND (effective_to IS NULL OR effective_to > @AsOfDate)
);
GO

CREATE OR ALTER FUNCTION dim.fn_ClientAdvisorAsOf (@ClientBusinessKey INT, @AsOfDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) *
    FROM dim.ClientAdvisor
    WHERE client_business_key = @ClientBusinessKey
      AND effective_from <= @AsOfDate
      AND (effective_to IS NULL OR effective_to > @AsOfDate)
);
GO

-- Latest price at or before a given date (handles missing-price-on-valuation
-- gaps by walking backwards, i.e. "last observation carried forward").
CREATE OR ALTER FUNCTION fact.fn_LatestPriceAsOf (@InstrumentBusinessKey INT, @AsOfDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) *
    FROM fact.InstrumentPrice
    WHERE instrument_business_key = @InstrumentBusinessKey
      AND price_date <= @AsOfDate
    ORDER BY price_date DESC
);
GO

-- Latest FX rate at or before a given date, same "carry forward" semantics.
CREATE OR ALTER FUNCTION fact.fn_LatestFxRateAsOf (@FromCurrency CHAR(3), @ToCurrency CHAR(3), @AsOfDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (1) *
    FROM fact.ExchangeRate
    WHERE from_currency = @FromCurrency
      AND to_currency = @ToCurrency
      AND rate_date <= @AsOfDate
    ORDER BY rate_date DESC
);
GO

-- Scalar helper: convert an amount between two currencies as of a date.
CREATE OR ALTER FUNCTION fact.fn_ConvertCurrency (
    @Amount DECIMAL(18,4),
    @FromCurrency CHAR(3),
    @ToCurrency CHAR(3),
    @AsOfDate DATE
)
RETURNS DECIMAL(18,4)
AS
BEGIN
    IF @FromCurrency = @ToCurrency
        RETURN @Amount;

    DECLARE @Rate DECIMAL(18,8);

    SELECT TOP (1) @Rate = rate
    FROM fact.ExchangeRate
    WHERE from_currency = @FromCurrency
      AND to_currency = @ToCurrency
      AND rate_date <= @AsOfDate
    ORDER BY rate_date DESC;

    IF @Rate IS NULL
        RETURN NULL;

    RETURN @Amount * @Rate;
END;
GO
