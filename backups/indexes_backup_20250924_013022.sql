                                                                                  create_statement                                                                                   
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 CREATE INDEX CONCURRENTLY IF NOT EXISTS account_balances_pkey ON account_balances (id);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_balances_available_balance ON account_balances (available_balance);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_balances_balance_covering ON account_balances (id, settled_balance, pending_debit, pending_credit, available_balance, version);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_balances_settlement ON account_balances (last_settlement_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_account_balances_version ON account_balances (id, version);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_account_id ON sub_balances (account_id);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_account_status_created ON sub_balances (account_id, status, created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_amount_covering ON sub_balances (account_id, amount, status, created_at, type);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_batch_update ON sub_balances (id, status);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_created_at ON sub_balances (created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_pending_only ON sub_balances (account_id, created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_settled_only ON sub_balances (account_id, created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_settlement_performance ON sub_balances (account_id, status, created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_status ON sub_balances (status);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_status_account_created ON sub_balances (account_id, status, created_at);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_type ON sub_balances (type);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_type_status ON sub_balances (status, created_at, type);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_balances_volume_analysis ON sub_balances (account_id, status, created_at, type);
 CREATE INDEX CONCURRENTLY IF NOT EXISTS sub_balances_pkey ON sub_balances (id);
(19 rows)

