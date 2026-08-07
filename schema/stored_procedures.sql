/*
    Investment Banking SQL Dataset Generator
    Stored procedures (SQL Server / T-SQL)
*/
USE InvestmentBankingDW;
GO

-- Reconstruct a client's holdings as of an arbitrary historical date by
-- replaying every transaction up to and including that date. This is the
-- canonical "point-in-time portfolio reconstruction" interview scenario.
CREATE OR ALTER PROCEDURE rpt.usp_ReconstructHoldingsAsOf
    @ClientBusinessKey INT,
    @AsOfDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.instrument_business_key,
        i.ticker,
        SUM(
            CASE t.transaction_type
                WHEN 'BUY'          THEN  t.quantity
                WHEN 'TRANSFER_IN'  THEN  t.quantity
                WHEN 'BONUS'        THEN  t.quantity
                WHEN 'SELL'         THEN -t.quantity
                WHEN 'TRANSFER_OUT' THEN -t.quantity
                ELSE 0
            END
        ) AS quantity_held
    FROM fact.[Transaction] t
    CROSS APPLY dim.fn_InstrumentAsOf(t.[instrument_business_key], @AsOfDate) i  
    WHERE t.client_business_key = @ClientBusinessKey
      AND t.trade_date <= @AsOfDate
    GROUP BY t.instrument_business_key, i.ticker
    HAVING SUM(
        CASE t.transaction_type
            WHEN 'BUY'          THEN  t.quantity
            WHEN 'TRANSFER_IN'  THEN  t.quantity
            WHEN 'BONUS'        THEN  t.quantity
            WHEN 'SELL'         THEN -t.quantity
            WHEN 'TRANSFER_OUT' THEN -t.quantity
            ELSE 0
        END
    ) <> 0;
END;
GO

-- Compute FIFO realized P&L for a client/instrument pair between two dates.
CREATE OR ALTER PROCEDURE rpt.usp_FifoRealizedPnl
    @ClientBusinessKey INT,
    @InstrumentBusinessKey INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Lots TABLE (
        lot_id INT IDENTITY(1,1),
        trade_date DATE,
        quantity DECIMAL(18,4),
        remaining_quantity DECIMAL(18,4),
        price DECIMAL(18,4)
    );

    INSERT INTO @Lots (trade_date, quantity, remaining_quantity, price)
    SELECT trade_date, quantity, quantity, price
    FROM fact.[Transaction]
    WHERE client_business_key = @ClientBusinessKey
      AND instrument_business_key = @InstrumentBusinessKey
      AND transaction_type = 'BUY'
      AND trade_date <= @EndDate
    ORDER BY trade_date;

    DECLARE @RealizedPnl TABLE (
        sell_transaction_id BIGINT,
        sell_date DATE,
        quantity_matched DECIMAL(18,4),
        cost_basis DECIMAL(18,4),
        proceeds DECIMAL(18,4),
        realized_pnl DECIMAL(18,4)
    );

    DECLARE @SellId BIGINT, @SellDate DATE, @SellQty DECIMAL(18,4), @SellPrice DECIMAL(18,4);

    DECLARE sell_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT transaction_id, trade_date, quantity, price
        FROM fact.[Transaction]
        WHERE client_business_key = @ClientBusinessKey
          AND instrument_business_key = @InstrumentBusinessKey
          AND transaction_type = 'SELL'
          AND trade_date BETWEEN @StartDate AND @EndDate
        ORDER BY trade_date;

    OPEN sell_cursor;
    FETCH NEXT FROM sell_cursor INTO @SellId, @SellDate, @SellQty, @SellPrice;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @Remaining DECIMAL(18,4) = @SellQty;
        DECLARE @CostBasis DECIMAL(18,4) = 0;

        WHILE @Remaining > 0
        BEGIN
            DECLARE @LotId INT, @LotRemaining DECIMAL(18,4), @LotPrice DECIMAL(18,4);

            SELECT TOP (1) @LotId = lot_id, @LotRemaining = remaining_quantity, @LotPrice = price
            FROM @Lots
            WHERE remaining_quantity > 0
            ORDER BY trade_date, lot_id;

            IF @LotId IS NULL BREAK;

            DECLARE @Matched DECIMAL(18,4) = CASE WHEN @LotRemaining <= @Remaining THEN @LotRemaining ELSE @Remaining END;

            UPDATE @Lots SET remaining_quantity = remaining_quantity - @Matched WHERE lot_id = @LotId;
            SET @CostBasis += @Matched * @LotPrice;
            SET @Remaining -= @Matched;
        END;

        INSERT INTO @RealizedPnl (sell_transaction_id, sell_date, quantity_matched, cost_basis, proceeds, realized_pnl)
        VALUES (
            @SellId, @SellDate, @SellQty - @Remaining, @CostBasis, (@SellQty - @Remaining) * @SellPrice,
            (@SellQty - @Remaining) * @SellPrice - @CostBasis
        );

        FETCH NEXT FROM sell_cursor INTO @SellId, @SellDate, @SellQty, @SellPrice;
    END;

    CLOSE sell_cursor;
    DEALLOCATE sell_cursor;

    SELECT * FROM @RealizedPnl ORDER BY sell_date;
END;
GO

-- Apply a stock split / bonus ratio adjustment to historical holdings and
-- prices for an instrument, as of the corporate action's ex-date.
CREATE OR ALTER PROCEDURE rpt.usp_ApplyCorporateActionAdjustment
    @ActionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InstrumentBusinessKey INT, @ExDate DATE, @Num DECIMAL(18,6), @Den DECIMAL(18,6), @ActionType VARCHAR(30);

    SELECT
        @InstrumentBusinessKey = instrument_business_key,
        @ExDate = ex_date,
        @Num = ratio_numerator,
        @Den = ratio_denominator,
        @ActionType = action_type
    FROM fact.CorporateAction
    WHERE action_id = @ActionId;

    IF @ActionType NOT IN ('STOCK_SPLIT', 'BONUS')
    BEGIN
        RAISERROR('Only STOCK_SPLIT and BONUS actions support ratio adjustment.', 16, 1);
        RETURN;
    END

    -- Preview the adjusted historical prices (pre-ex-date), read-only.
    SELECT
        price_date,
        [close] AS original_close,
        [close] * (@Den / @Num) AS split_adjusted_close
    FROM fact.InstrumentPrice
    WHERE instrument_business_key = @InstrumentBusinessKey
      AND price_date < @ExDate
    ORDER BY price_date;
END;
GO
