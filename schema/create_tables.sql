/*
    Investment Banking SQL Dataset Generator
    Table definitions (SQL Server / T-SQL)

    Column naming intentionally uses snake_case to match the Python
    dataclasses in core/models.py 1:1, so generated INSERT scripts and
    CSV/JSON/Parquet exports line up exactly with the physical schema.
*/
USE InvestmentBankingDW;
GO

-- ===========================================================================
-- DIMENSION: Currency (static, no SCD)
-- ===========================================================================
CREATE TABLE dim.Currency (
    currency_id     INT             NOT NULL PRIMARY KEY,
    code            CHAR(3)         NOT NULL UNIQUE,
    name            NVARCHAR(100)   NOT NULL,
    symbol          NVARCHAR(10)    NOT NULL,
    minor_unit      TINYINT         NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: Advisor (static, no SCD -- advisors themselves don't version;
-- their client assignments do, via dim.ClientAdvisor)
-- ===========================================================================
CREATE TABLE dim.Advisor (
    advisor_id      INT             NOT NULL PRIMARY KEY,
    advisor_code    VARCHAR(20)     NOT NULL UNIQUE,
    first_name      NVARCHAR(100)   NOT NULL,
    last_name       NVARCHAR(100)   NOT NULL,
    email           NVARCHAR(200)   NOT NULL,
    hire_date       DATE            NOT NULL,
    region          NVARCHAR(50)    NOT NULL,
    is_active       BIT             NOT NULL DEFAULT 1
);
GO

-- ===========================================================================
-- DIMENSION: Exchange (SCD2)
-- ===========================================================================
CREATE TABLE dim.Exchange (
    surrogate_key   INT             NOT NULL PRIMARY KEY,
    business_key    INT             NOT NULL,
    effective_from  DATE            NOT NULL,
    effective_to    DATE            NULL,
    is_current      BIT             NOT NULL,
    version         INT             NOT NULL,
    mic             VARCHAR(10)     NOT NULL,
    name            NVARCHAR(200)   NOT NULL,
    country         CHAR(2)         NOT NULL,
    currency_code   CHAR(3)         NOT NULL,
    timezone        VARCHAR(50)     NOT NULL,
    status          VARCHAR(20)     NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: Client (SCD2)
-- ===========================================================================
CREATE TABLE dim.Client (
    surrogate_key       INT             NOT NULL PRIMARY KEY,
    business_key        INT             NOT NULL,
    effective_from      DATE            NOT NULL,
    effective_to        DATE            NULL,
    is_current          BIT             NOT NULL,
    version             INT             NOT NULL,
    client_code         VARCHAR(20)     NOT NULL,
    first_name          NVARCHAR(100)   NOT NULL,
    last_name           NVARCHAR(100)   NOT NULL,
    date_of_birth       DATE            NOT NULL,
    country             CHAR(2)         NOT NULL,
    address             NVARCHAR(400)   NOT NULL,
    email                NVARCHAR(200)   NOT NULL,
    phone               VARCHAR(50)     NOT NULL,
    risk_profile        VARCHAR(20)     NOT NULL,
    segment             VARCHAR(20)     NOT NULL,
    net_worth           DECIMAL(18,2)   NOT NULL,
    preferred_currency  CHAR(3)         NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: ClientContact (SCD2)
-- ===========================================================================
CREATE TABLE dim.ClientContact (
    surrogate_key       INT             NOT NULL PRIMARY KEY,
    business_key        INT             NOT NULL,
    effective_from      DATE            NOT NULL,
    effective_to        DATE            NULL,
    is_current          BIT             NOT NULL,
    version              INT             NOT NULL,
    client_business_key INT             NOT NULL,
    contact_type        VARCHAR(20)     NOT NULL,
    contact_name        NVARCHAR(200)   NOT NULL,
    email               NVARCHAR(200)   NOT NULL,
    phone               VARCHAR(50)     NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: ClientAdvisor (SCD2) -- assignment history
-- ===========================================================================
CREATE TABLE dim.ClientAdvisor (
    surrogate_key       INT             NOT NULL PRIMARY KEY,
    business_key        INT             NOT NULL,
    effective_from      DATE            NOT NULL,
    effective_to        DATE            NULL,
    is_current          BIT             NOT NULL,
    version              INT             NOT NULL,
    client_business_key INT             NOT NULL,
    advisor_id          INT             NOT NULL,
    assignment_reason   VARCHAR(50)     NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: InstrumentType (SCD2)
-- ===========================================================================
CREATE TABLE dim.InstrumentType (
    surrogate_key   INT             NOT NULL PRIMARY KEY,
    business_key    INT             NOT NULL,
    effective_from  DATE            NOT NULL,
    effective_to    DATE            NULL,
    is_current      BIT             NOT NULL,
    version         INT             NOT NULL,
    type_code       VARCHAR(20)     NOT NULL,
    type_name       NVARCHAR(50)    NOT NULL,
    asset_class     NVARCHAR(50)    NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: Instrument (SCD2)
-- ===========================================================================
CREATE TABLE dim.Instrument (
    surrogate_key                   INT             NOT NULL PRIMARY KEY,
    business_key                    INT             NOT NULL,
    effective_from                  DATE            NOT NULL,
    effective_to                    DATE            NULL,
    is_current                      BIT             NOT NULL,
    version                         INT             NOT NULL,
    ticker                          VARCHAR(20)     NOT NULL,
    isin                            VARCHAR(20)     NOT NULL,
    name                            NVARCHAR(200)   NOT NULL,
    instrument_type_business_key    INT             NOT NULL,
    instrument_type_name            NVARCHAR(50)    NOT NULL,
    exchange_mic                    VARCHAR(10)     NOT NULL,
    currency_code                   CHAR(3)         NOT NULL,
    sector                          NVARCHAR(50)    NOT NULL,
    industry                        NVARCHAR(50)    NOT NULL,
    status                          VARCHAR(20)     NOT NULL,
    lot_size                        INT             NOT NULL
);
GO

-- ===========================================================================
-- DIMENSION: TransactionType (SCD2)
-- ===========================================================================
CREATE TABLE dim.TransactionType (
    surrogate_key   INT             NOT NULL PRIMARY KEY,
    business_key    INT             NOT NULL,
    effective_from  DATE            NOT NULL,
    effective_to    DATE            NULL,
    is_current      BIT             NOT NULL,
    version         INT             NOT NULL,
    type_code       VARCHAR(20)     NOT NULL,
    description     NVARCHAR(200)   NOT NULL,
    is_credit       BIT             NOT NULL
);
GO

-- ===========================================================================
-- FACT: ExchangeRate
-- ===========================================================================
CREATE TABLE fact.ExchangeRate (
    rate_id         BIGINT          NOT NULL PRIMARY KEY,
    rate_date       DATE            NOT NULL,
    from_currency   CHAR(3)         NOT NULL,
    to_currency     CHAR(3)         NOT NULL,
    rate            DECIMAL(18,8)   NOT NULL,
    source          VARCHAR(20)     NOT NULL
);
GO

-- ===========================================================================
-- FACT: InstrumentPrice
-- ===========================================================================
CREATE TABLE fact.InstrumentPrice (
    price_id                    BIGINT          NOT NULL PRIMARY KEY,
    price_date                  DATE            NOT NULL,
    instrument_business_key     INT             NOT NULL,
    ticker                      VARCHAR(20)     NOT NULL,
    [open]                      DECIMAL(18,4)   NOT NULL,
    high                        DECIMAL(18,4)   NOT NULL,
    low                         DECIMAL(18,4)   NOT NULL,
    [close]                       DECIMAL(18,4)   NOT NULL,
    volume                      BIGINT          NOT NULL,
    is_trading_halt             BIT             NOT NULL DEFAULT 0
);
GO

-- ===========================================================================
-- FACT: Transaction
-- ===========================================================================
CREATE TABLE fact.[Transaction] (
    transaction_id              BIGINT          NOT NULL PRIMARY KEY,
    client_business_key         INT             NOT NULL,
    instrument_business_key     INT             NOT NULL,
    transaction_type            VARCHAR(20)     NOT NULL,
    trade_date                  DATE            NOT NULL,
    settlement_date             DATE            NOT NULL,
    quantity                    DECIMAL(18,4)   NOT NULL,
    price                       DECIMAL(18,4)   NOT NULL,
    currency_code               CHAR(3)         NOT NULL,
    gross_amount                DECIMAL(18,2)   NOT NULL,
    commission                  DECIMAL(18,2)   NOT NULL,
    tax                         DECIMAL(18,2)   NOT NULL,
    brokerage_fee                DECIMAL(18,2)   NOT NULL,
    net_amount                  DECIMAL(18,2)   NOT NULL,
    advisor_id                  INT             NOT NULL,
    is_duplicate_of              BIGINT          NULL,
    notes                       NVARCHAR(400)   NULL
);
GO

-- ===========================================================================
-- FACT: Holding (derived by replaying transactions -- never randomly seeded)
-- ===========================================================================
CREATE TABLE fact.Holding (
    holding_id                  BIGINT          NOT NULL PRIMARY KEY,
    as_of_date                  DATE            NOT NULL,
    client_business_key         INT             NOT NULL,
    instrument_business_key     INT             NOT NULL,
    quantity                    DECIMAL(18,4)   NOT NULL,
    avg_cost                    DECIMAL(18,4)   NOT NULL,
    is_negative_flag            BIT             NOT NULL DEFAULT 0
);
GO

-- ===========================================================================
-- FACT: PortfolioSnapshot
-- ===========================================================================
CREATE TABLE fact.PortfolioSnapshot (
    snapshot_id                 BIGINT          NOT NULL PRIMARY KEY,
    snapshot_date                DATE            NOT NULL,
    client_business_key         INT             NOT NULL,
    total_market_value_usd      DECIMAL(18,2)   NOT NULL,
    total_cost_basis_usd        DECIMAL(18,2)   NOT NULL,
    unrealized_pnl_usd          DECIMAL(18,2)   NOT NULL,
    currency_code               CHAR(3)         NOT NULL,
    is_month_end                BIT             NOT NULL DEFAULT 0
);
GO

-- ===========================================================================
-- FACT: CorporateAction
-- ===========================================================================
CREATE TABLE fact.CorporateAction (
    action_id                   BIGINT          NOT NULL PRIMARY KEY,
    instrument_business_key     INT             NOT NULL,
    ticker                      VARCHAR(20)     NOT NULL,
    action_type                 VARCHAR(30)     NOT NULL,
    ex_date                     DATE            NOT NULL,
    record_date                 DATE            NOT NULL,
    payment_date                DATE            NULL,
    ratio_numerator              DECIMAL(18,6)   NOT NULL,
    ratio_denominator            DECIMAL(18,6)   NOT NULL,
    cash_amount                 DECIMAL(18,4)   NOT NULL,
    details                     NVARCHAR(400)   NULL
);
GO

-- ===========================================================================
-- FACT: Settlement
-- ===========================================================================
CREATE TABLE fact.Settlement (
    settlement_id                BIGINT          NOT NULL PRIMARY KEY,
    transaction_id               BIGINT          NOT NULL,
    expected_settlement_date     DATE            NOT NULL,
    actual_settlement_date       DATE            NULL,
    status                       VARCHAR(20)     NOT NULL
);
GO

-- ===========================================================================
-- FACT: CashLedger
-- ===========================================================================
CREATE TABLE fact.CashLedger (
    ledger_id                     BIGINT          NOT NULL PRIMARY KEY,
    client_business_key           INT             NOT NULL,
    entry_date                    DATE            NOT NULL,
    currency_code                 CHAR(3)         NOT NULL,
    amount                        DECIMAL(18,2)   NOT NULL,
    entry_type                    VARCHAR(30)     NOT NULL,
    reference_transaction_id      BIGINT          NULL,
    description                   NVARCHAR(400)   NULL
);
GO
