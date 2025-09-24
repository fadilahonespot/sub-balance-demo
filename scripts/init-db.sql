-- Initialize database for sub-balance system

-- Connect to the database (already created by Docker)
\c subbalance;

-- Create account_balances table
CREATE TABLE IF NOT EXISTS account_balances (
    id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settled_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
    pending_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
    pending_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
    available_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 0,
    last_settlement_at TIMESTAMP
);

-- Create sub_balances table
CREATE TABLE IF NOT EXISTS sub_balances (
    id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50) NOT NULL,
    amount DECIMAL(20,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sub_balance_account_status ON sub_balances(account_id, status);
CREATE INDEX IF NOT EXISTS idx_sub_balance_created_at ON sub_balances(created_at);
CREATE INDEX IF NOT EXISTS idx_account_balance_updated_at ON account_balances(updated_at);

-- Insert sample data
INSERT INTO account_balances (id, settled_balance, available_balance) 
VALUES ('ACC001', 1000000, 1000000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO account_balances (id, settled_balance, available_balance) 
VALUES ('ACC002', 500000, 500000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO account_balances (id, settled_balance, available_balance) 
VALUES ('ACC003', 2000000, 2000000)
ON CONFLICT (id) DO NOTHING;
