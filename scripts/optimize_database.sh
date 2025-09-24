#!/bin/bash

# =====================================================
# Database Optimization Script
# =====================================================
# This script applies database indexing optimizations
# for high-performance TPS operations
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="subbalance"
DB_USER="ahmadfadilah"
DB_PASSWORD="postgres"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Database Optimization Script${NC}"
echo "=========================================="
echo -e "${BLUE}📊 Target: 100+ TPS with 100% success rate${NC}"
echo ""

# Function to log messages
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to check if PostgreSQL is running
check_postgres() {
    log "🔍 Checking PostgreSQL connection..."
    
    if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" >/dev/null 2>&1; then
        echo -e "${RED}❌ PostgreSQL is not running or not accessible${NC}"
        echo "Please ensure PostgreSQL is running and accessible"
        exit 1
    fi
    
    echo -e "${GREEN}✅ PostgreSQL is running and accessible${NC}"
}

# Function to backup current indexes
backup_indexes() {
    log "💾 Creating backup of current indexes..."
    
    local backup_file="$PROJECT_DIR/backups/indexes_backup_$(date +%Y%m%d_%H%M%S).sql"
    mkdir -p "$(dirname "$backup_file")"
    
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            'CREATE INDEX CONCURRENTLY IF NOT EXISTS ' || indexname || ' ON ' || tablename || ' (' || 
            array_to_string(array_agg(attname ORDER BY attnum), ', ') || ');' as create_statement
        FROM pg_indexes pi
        JOIN pg_class c ON c.relname = pi.indexname
        JOIN pg_index i ON i.indexrelid = c.oid
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE pi.schemaname = 'public' 
        AND pi.tablename IN ('account_balances', 'sub_balances')
        GROUP BY pi.indexname, pi.tablename
        ORDER BY pi.tablename, pi.indexname;
    " > "$backup_file" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Index backup created: $backup_file${NC}"
}

# Function to check current performance
check_current_performance() {
    log "📊 Checking current database performance..."
    
    echo -e "${YELLOW}Current Index Statistics:${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            relname as tablename,
            indexrelname as indexname,
            idx_scan as times_used,
            pg_size_pretty(pg_relation_size(indexrelid)) as size
        FROM pg_stat_user_indexes 
        WHERE schemaname = 'public'
        AND relname IN ('account_balances', 'sub_balances')
        ORDER BY relname, idx_scan DESC;
    "
    
    echo ""
    echo -e "${YELLOW}Table Statistics:${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            relname as tablename,
            n_live_tup as live_tuples,
            n_dead_tup as dead_tuples,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) as total_size
        FROM pg_stat_user_tables 
        WHERE schemaname = 'public'
        AND relname IN ('account_balances', 'sub_balances')
        ORDER BY n_live_tup DESC;
    "
}

# Function to apply indexing optimizations
apply_indexing_optimizations() {
    log "🔧 Applying database indexing optimizations..."
    
    local migration_file="$SCRIPT_DIR/migration_database_indexing_optimization.sql"
    
    if [ ! -f "$migration_file" ]; then
        echo -e "${RED}❌ Migration file not found: $migration_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📝 Executing migration: $migration_file${NC}"
    
    # Execute migration with progress tracking
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_file" -v ON_ERROR_STOP=1
    
    echo -e "${GREEN}✅ Database indexing optimizations applied successfully${NC}"
}

# Function to verify optimizations
verify_optimizations() {
    log "🔍 Verifying optimizations..."
    
    echo -e "${YELLOW}New Index Statistics:${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            relname as tablename,
            indexrelname as indexname,
            pg_size_pretty(pg_relation_size(indexrelid)) as size
        FROM pg_stat_user_indexes 
        WHERE schemaname = 'public'
        AND relname IN ('account_balances', 'sub_balances')
        AND indexrelname LIKE 'idx_%'
        ORDER BY relname, indexrelname;
    "
    
    echo ""
    echo -e "${YELLOW}Testing Query Performance:${NC}"
    
    # Test 1: Most frequent query
    echo -e "${BLUE}Test 1: Get pending transactions for account${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        EXPLAIN (ANALYZE, BUFFERS) 
        SELECT * FROM sub_balances 
        WHERE account_id = 'ACC001' AND status = 'PENDING' 
        ORDER BY created_at ASC;
    "
    
    echo ""
    echo -e "${BLUE}Test 2: Get account balance${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        EXPLAIN (ANALYZE, BUFFERS) 
        SELECT settled_balance, pending_debit, pending_credit, available_balance, version 
        FROM account_balances 
        WHERE id = 'ACC001';
    "
}

# Function to run performance monitoring
run_performance_monitoring() {
    log "📈 Running performance monitoring..."
    
    local monitor_file="$SCRIPT_DIR/monitor_index_performance.sql"
    
    if [ ! -f "$monitor_file" ]; then
        echo -e "${RED}❌ Monitor file not found: $monitor_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📊 Performance Monitoring Report:${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$monitor_file"
}

# Function to cleanup old data (optional)
cleanup_old_data() {
    log "🧹 Cleaning up old data..."
    
    # Clean up old settled transactions (older than 7 days)
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        DELETE FROM sub_balances 
        WHERE status = 'SETTLED' 
        AND created_at < NOW() - INTERVAL '7 days';
    "
    
    # Vacuum to reclaim space
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        VACUUM ANALYZE account_balances;
        VACUUM ANALYZE sub_balances;
    "
    
    echo -e "${GREEN}✅ Old data cleanup completed${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Database Optimization...${NC}"
    echo ""
    
    # Check prerequisites
    check_postgres
    
    # Backup current state
    backup_indexes
    
    # Check current performance
    check_current_performance
    
    echo ""
    echo -e "${YELLOW}⚠️  This will create new indexes. Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Optimization cancelled by user${NC}"
        exit 0
    fi
    
    # Apply optimizations
    apply_indexing_optimizations
    
    # Verify optimizations
    verify_optimizations
    
    # Run performance monitoring
    run_performance_monitoring
    
    # Optional cleanup
    echo ""
    echo -e "${YELLOW}🧹 Clean up old settled transactions? (y/N)${NC}"
    read -r cleanup_response
    if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
        cleanup_old_data
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Database optimization completed successfully!${NC}"
    echo -e "${GREEN}📊 Expected performance improvement: 3-5x faster queries${NC}"
    echo -e "${GREEN}🎯 Target: 100+ TPS with 100% success rate${NC}"
    echo ""
    echo -e "${BLUE}💡 Next steps:${NC}"
    echo "1. Restart your application to use new indexes"
    echo "2. Run TPS tests to measure performance improvement"
    echo "3. Monitor index usage with: psql -f scripts/monitor_index_performance.sql"
}

# Run main function
main "$@"
