-- =====================================================
-- Database Index Performance Monitoring
-- =====================================================
-- Run this script to monitor index usage and performance
-- =====================================================

-- =====================================================
-- 1. INDEX USAGE STATISTICS
-- =====================================================

SELECT 
    'Index Usage Statistics' as report_type,
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    CASE 
        WHEN idx_scan = 0 THEN '❌ UNUSED'
        WHEN idx_scan < 100 THEN '⚠️ LOW USAGE'
        WHEN idx_scan < 1000 THEN '✅ MODERATE USAGE'
        ELSE '🚀 HIGH USAGE'
    END as usage_status
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- =====================================================
-- 2. INDEX SIZES
-- =====================================================

SELECT 
    'Index Sizes' as report_type,
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    pg_relation_size(indexrelid) as size_bytes
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- =====================================================
-- 3. TABLE STATISTICS
-- =====================================================

SELECT 
    'Table Statistics' as report_type,
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- =====================================================
-- 4. SLOW QUERY IDENTIFICATION
-- =====================================================

-- Check for missing indexes (if pg_stat_statements is enabled)
/*
SELECT 
    'Slow Queries' as report_type,
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%sub_balances%' OR query LIKE '%account_balances%'
ORDER BY mean_time DESC
LIMIT 10;
*/

-- =====================================================
-- 5. INDEX EFFICIENCY ANALYSIS
-- =====================================================

SELECT 
    'Index Efficiency' as report_type,
    i.schemaname,
    i.tablename,
    i.indexname,
    i.idx_scan,
    i.idx_tup_read,
    i.idx_tup_fetch,
    CASE 
        WHEN i.idx_scan = 0 THEN 0
        ELSE ROUND((i.idx_tup_fetch::numeric / i.idx_tup_read::numeric) * 100, 2)
    END as efficiency_percentage,
    CASE 
        WHEN i.idx_scan = 0 THEN '❌ UNUSED'
        WHEN (i.idx_tup_fetch::numeric / i.idx_tup_read::numeric) > 0.8 THEN '🚀 EXCELLENT'
        WHEN (i.idx_tup_fetch::numeric / i.idx_tup_read::numeric) > 0.6 THEN '✅ GOOD'
        WHEN (i.idx_tup_fetch::numeric / i.idx_tup_read::numeric) > 0.4 THEN '⚠️ FAIR'
        ELSE '❌ POOR'
    END as efficiency_status
FROM pg_stat_user_indexes i
WHERE i.schemaname = 'public'
ORDER BY efficiency_percentage DESC;

-- =====================================================
-- 6. PERFORMANCE TEST QUERIES
-- =====================================================

-- Test 1: Most frequent query - Get pending transactions
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT * FROM sub_balances 
WHERE account_id = 'ACC001' AND status = 'PENDING' 
ORDER BY created_at ASC;

-- Test 2: Account balance query
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT settled_balance, pending_debit, pending_credit, available_balance, version 
FROM account_balances 
WHERE id = 'ACC001';

-- Test 3: Settlement worker batch query
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT * FROM sub_balances 
WHERE status = 'PENDING' 
ORDER BY account_id, created_at ASC 
LIMIT 200;

-- =====================================================
-- 7. RECOMMENDATIONS
-- =====================================================

-- Check for duplicate or redundant indexes
SELECT 
    'Duplicate Indexes' as report_type,
    t.relname as table_name,
    array_agg(i.relname) as index_names,
    count(*) as index_count
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
WHERE t.relkind = 'r'
AND t.relname IN ('account_balances', 'sub_balances')
GROUP BY t.relname
HAVING count(*) > 1;

-- =====================================================
-- MONITORING COMPLETED
-- =====================================================
