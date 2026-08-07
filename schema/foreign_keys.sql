/*
    Investment Banking SQL Dataset Generator
    Foreign key constraints (SQL Server / T-SQL)

    Note: FKs reference the *business_key* on SCD2 dimensions rather than the
    surrogate_key, since fact rows should always be resolvable to the
    natural entity regardless of which historical version was active at the
    time. Point-in-time joins should filter dim rows by effective_from /
    effective_to (or is_current) rather than relying on the FK alone -- this
    is intentional and mirrors real Type-2 warehouse modelling.
*/
USE InvestmentBankingDW;
GO

--ALTER TABLE dim.ClientContact
--    ADD CONSTRAINT FK_ClientContact_Client
--    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
--GO

--ALTER TABLE dim.ClientAdvisor
--    ADD CONSTRAINT FK_ClientAdvisor_Client
--    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
--GO

ALTER TABLE dim.ClientAdvisor
    ADD CONSTRAINT FK_ClientAdvisor_Advisor
    FOREIGN KEY (advisor_id) REFERENCES dim.Advisor (advisor_id);
GO

ALTER TABLE dim.Instrument
    ADD CONSTRAINT FK_Instrument_Exchange
    FOREIGN KEY (exchange_mic) REFERENCES dim.Exchange (mic);
GO

ALTER TABLE fact.ExchangeRate
    ADD CONSTRAINT FK_ExchangeRate_FromCurrency
    FOREIGN KEY (from_currency) REFERENCES dim.Currency (code);
GO

ALTER TABLE fact.ExchangeRate
    ADD CONSTRAINT FK_ExchangeRate_ToCurrency
    FOREIGN KEY (to_currency) REFERENCES dim.Currency (code);
GO

ALTER TABLE fact.InstrumentPrice
    ADD CONSTRAINT FK_InstrumentPrice_Instrument
    FOREIGN KEY (instrument_business_key) REFERENCES dim.Instrument (business_key);
GO

ALTER TABLE fact.[Transaction]
    ADD CONSTRAINT FK_Transaction_Client
    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
GO

ALTER TABLE fact.[Transaction]
    ADD CONSTRAINT FK_Transaction_Instrument
    FOREIGN KEY (instrument_business_key) REFERENCES dim.Instrument (business_key);
GO

ALTER TABLE fact.[Transaction]
    ADD CONSTRAINT FK_Transaction_Advisor
    FOREIGN KEY (advisor_id) REFERENCES dim.Advisor (advisor_id);
GO

ALTER TABLE fact.[Transaction]
    ADD CONSTRAINT FK_Transaction_Currency
    FOREIGN KEY (currency_code) REFERENCES dim.Currency (code);
GO

ALTER TABLE fact.Holding
    ADD CONSTRAINT FK_Holding_Client
    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
GO

ALTER TABLE fact.Holding
    ADD CONSTRAINT FK_Holding_Instrument
    FOREIGN KEY (instrument_business_key) REFERENCES dim.Instrument (business_key);
GO

ALTER TABLE fact.PortfolioSnapshot
    ADD CONSTRAINT FK_PortfolioSnapshot_Client
    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
GO

ALTER TABLE fact.CorporateAction
    ADD CONSTRAINT FK_CorporateAction_Instrument
    FOREIGN KEY (instrument_business_key) REFERENCES dim.Instrument (business_key);
GO

ALTER TABLE fact.Settlement
    ADD CONSTRAINT FK_Settlement_Transaction
    FOREIGN KEY (transaction_id) REFERENCES fact.[Transaction] (transaction_id);
GO

ALTER TABLE fact.CashLedger
    ADD CONSTRAINT FK_CashLedger_Client
    FOREIGN KEY (client_business_key) REFERENCES dim.Client (business_key);
GO

ALTER TABLE fact.CashLedger
    ADD CONSTRAINT FK_CashLedger_Currency
    FOREIGN KEY (currency_code) REFERENCES dim.Currency (code);
GO
