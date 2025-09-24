-- Migration: Add type column to sub_balances table
-- This migration adds the 'type' column to distinguish between debit and credit transactions

-- Add type column to sub_balances table
ALTER TABLE sub_balances ADD COLUMN type VARCHAR(10) DEFAULT 'debit';

-- Create index on type column for better performance
CREATE INDEX idx_sub_balances_type ON sub_balances(type);

-- Update existing records to have 'debit' type (since all test transactions are debit)
UPDATE sub_balances SET type = 'debit' WHERE type IS NULL;

-- Make type column NOT NULL after setting default values
ALTER TABLE sub_balances ALTER COLUMN type SET NOT NULL;

-- Add check constraint to ensure type is either 'debit' or 'credit'
ALTER TABLE sub_balances ADD CONSTRAINT chk_sub_balances_type CHECK (type IN ('debit', 'credit'));
