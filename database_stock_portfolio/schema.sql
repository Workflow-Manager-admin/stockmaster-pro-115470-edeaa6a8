-- Stock Portfolio Management Database Schema
-- PostgreSQL version
-- Purpose: Stores user portfolios, stock transactions, investment recommendations, and trading history.

-- Users Table: Holds application user profile info.
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stocks Table: Holds static reference data about stocks.
CREATE TABLE IF NOT EXISTS stocks (
    stock_id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    exchange VARCHAR(50) NOT NULL,
    sector VARCHAR(100),
    isin VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Portfolios Table: Each user has one or more portfolios.
CREATE TABLE IF NOT EXISTS portfolios (
    portfolio_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Holdings Table: Stocks currently held in a portfolio.
CREATE TABLE IF NOT EXISTS holdings (
    holding_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    quantity NUMERIC(18, 4) NOT NULL,
    avg_buy_price NUMERIC(18, 4) NOT NULL,
    latest_market_price NUMERIC(18, 4),
    as_of TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (portfolio_id, stock_id)
);

-- Transactions Table: Buy/sell/order records for stocks/options.
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    order_type VARCHAR(10) CHECK (order_type IN ('BUY', 'SELL', 'SELL_SHORT', 'COVER', 'EXERCISE', 'ASSIGNMENT')),
    quantity NUMERIC(18, 4) NOT NULL,
    price NUMERIC(18, 4) NOT NULL,
    fees NUMERIC(18, 4) DEFAULT 0.0,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT
);

-- Trading History Table: Captures real-time trading activity (could link to Zerodha trades).
CREATE TABLE IF NOT EXISTS trading_history (
    trade_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    trade_type VARCHAR(10) CHECK (trade_type IN ('BUY', 'SELL', 'OPTION_BUY', 'OPTION_SELL')),
    quantity NUMERIC(18, 4) NOT NULL,
    price NUMERIC(18, 4) NOT NULL,
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    external_trade_ref VARCHAR(128) -- Reference to Zerodha or MCP trade
);

-- Investment Recommendations Table: Suggestions for user investments.
CREATE TABLE IF NOT EXISTS recommendations (
    recommendation_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    recommended_action VARCHAR(20) CHECK (recommended_action IN ('BUY', 'SELL', 'HOLD', 'WATCH')),
    target_price NUMERIC(18, 4),
    stop_loss NUMERIC(18, 4),
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    explanation TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Option Contracts Table: Stores stock options data.
CREATE TABLE IF NOT EXISTS option_contracts (
    contract_id SERIAL PRIMARY KEY,
    stock_id INTEGER NOT NULL REFERENCES stocks(stock_id),
    option_type VARCHAR(4) CHECK (option_type IN ('CALL', 'PUT')),
    strike_price NUMERIC(18, 4) NOT NULL,
    expiry_date DATE NOT NULL,
    lot_size INTEGER NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Option Transactions Table: Records transactions for options.
CREATE TABLE IF NOT EXISTS option_transactions (
    option_transaction_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(portfolio_id) ON DELETE CASCADE,
    contract_id INTEGER NOT NULL REFERENCES option_contracts(contract_id),
    order_type VARCHAR(10) CHECK (order_type IN ('BUY', 'SELL')),
    quantity INTEGER NOT NULL,
    price NUMERIC(18, 4) NOT NULL,
    fees NUMERIC(18, 4) DEFAULT 0.0,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT
);

-- Add indexes for performance on key lookup columns.
CREATE INDEX IF NOT EXISTS idx_portfolio_user_id ON portfolios(user_id);
CREATE INDEX IF NOT EXISTS idx_holdings_portfolio ON holdings(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio ON transactions(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_trading_history_portfolio ON trading_history(portfolio_id);

-- View for Current Portfolio Valuation (example).
CREATE OR REPLACE VIEW portfolio_valuation AS
SELECT
    p.portfolio_id,
    p.name AS portfolio_name,
    u.user_id,
    u.email,
    h.stock_id,
    s.symbol,
    h.quantity,
    h.avg_buy_price,
    h.latest_market_price,
    (h.quantity * h.latest_market_price) AS current_value,
    ((h.latest_market_price - h.avg_buy_price) * h.quantity) AS unrealized_pnl
FROM
    holdings h
    JOIN portfolios p ON h.portfolio_id = p.portfolio_id
    JOIN users u ON p.user_id = u.user_id
    JOIN stocks s ON h.stock_id = s.stock_id;


-- Comments for maintainability and documentation.

-- Table: users
COMMENT ON TABLE users IS 'Application users with authentication details.';

-- Table: portfolios
COMMENT ON TABLE portfolios IS 'Each user can have multiple portfolios.';

-- Table: holdings
COMMENT ON TABLE holdings IS 'Current holdings per (portfolio, stock).';

-- Table: transactions
COMMENT ON TABLE transactions IS 'Buy/sell transaction records for stocks.';

-- Table: trading_history
COMMENT ON TABLE trading_history IS 'Executed trades, may be matched to Zerodha/MCP trades.';

-- Table: recommendations
COMMENT ON TABLE recommendations IS 'Investment recommendations for users.';

-- Table: stocks
COMMENT ON TABLE stocks IS 'Reference data for stocks available for trading.';

-- Table: option_contracts
COMMENT ON TABLE option_contracts IS 'Reference details about stock option contracts.';

-- Table: option_transactions
COMMENT ON TABLE option_transactions IS 'Records user trading activity in options.';

-- End of schema.sql
