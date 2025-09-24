                                         create_statement                                          
---------------------------------------------------------------------------------------------------
 CREATE INDEX CONCURRENTLY IF NOT EXISTS account_balances_pkey ON account_balances (id);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_account_id ON sub_balances (account_id);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_created_at ON sub_balances (created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_status ON sub_balances (status);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_type ON sub_balances (type);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS sub_balances_pkey ON sub_balances (id);
(6 rows)

