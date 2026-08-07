/*
    Investment Banking SQL Dataset Generator
    Database + schema bootstrap script (SQL Server / T-SQL)
*/
IF DB_ID(N'InvestmentBankingDW') IS NULL
BEGIN
    CREATE DATABASE InvestmentBankingDW;
END
GO

USE InvestmentBankingDW;
GO

IF SCHEMA_ID(N'dim') IS NULL EXEC('CREATE SCHEMA dim');
GO
IF SCHEMA_ID(N'fact') IS NULL EXEC('CREATE SCHEMA fact');
GO
IF SCHEMA_ID(N'rpt') IS NULL EXEC('CREATE SCHEMA rpt');
GO
