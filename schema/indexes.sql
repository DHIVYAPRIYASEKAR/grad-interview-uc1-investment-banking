/*
    Investment Banking SQL Dataset Generator
    Performance indexes (SQL Server / T-SQL)
*/
USE InvestmentBankingDW;
GO

-- Point-in-time SCD2 lookups
CREATE INDEX IX_Client_BusinessKey_Effective ON dim.Client (business_key, effective_from, effective_to) INCLUDE (is_current);
CREATE INDEX IX_ClientAdvisor_BusinessKey_Effective ON dim.ClientAdvisor (client_business_key, effective_from, effective_to);
CREATE INDEX IX_Instrument_BusinessKey_Effective ON dim.Instrument (business_key, effective_from, effective_to);
CREATE INDEX IX_Exchange_BusinessKey_Effective ON dim.Exchange (business_key, effective_from, effective_to);
GO

-- Fact table access patterns
CREATE INDEX IX_Transaction_Client_TradeDate ON fact.[Transaction] (client_business_key, trade_date) INCLUDE (instrument_business_key, quantity, price, transaction_type);
CREATE INDEX IX_Transaction_Instrument_TradeDate ON fact.[Transaction] (instrument_business_key, trade_date);
CREATE INDEX IX_Transaction_SettlementDate ON fact.[Transaction] (settlement_date);
CREATE INDEX IX_Transaction_Advisor ON fact.[Transaction] (advisor_id, trade_date);

CREATE INDEX IX_InstrumentPrice_Instrument_Date ON fact.InstrumentPrice (instrument_business_key, price_date) INCLUDE ([close], volume);
CREATE INDEX IX_InstrumentPrice_Date ON fact.InstrumentPrice (price_date);

CREATE INDEX IX_ExchangeRate_Pair_Date ON fact.ExchangeRate (from_currency, to_currency, rate_date);

CREATE INDEX IX_Holding_Client_Date ON fact.Holding (client_business_key, as_of_date) INCLUDE (instrument_business_key, quantity);
CREATE INDEX IX_Holding_Instrument_Date ON fact.Holding (instrument_business_key, as_of_date);

CREATE INDEX IX_PortfolioSnapshot_Client_Date ON fact.PortfolioSnapshot (client_business_key, snapshot_date);

CREATE INDEX IX_CorporateAction_Instrument_ExDate ON fact.CorporateAction (instrument_business_key, ex_date);

CREATE INDEX IX_Settlement_Status ON fact.Settlement (status, expected_settlement_date);

CREATE INDEX IX_CashLedger_Client_Date ON fact.CashLedger (client_business_key, entry_date);
GO
