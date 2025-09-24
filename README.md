# Sub-Balance System Demo

Implementasi sistem sub-balance untuk optimasi TPS dengan multi-layer validation, Redis atomic operations, dan background settlement.

## Fitur

- **Multi-Layer Validation**: Quick validation + Redis counter + Background settlement
- **Redis Atomic Operations**: Atomic script untuk mencegah race condition
- **Optimistic Locking**: Tidak ada lock pada request path
- **Background Settlement**: Batch processing setiap 5 detik
- **Eventual Consistency**: Balance update dengan delay 5 detik
- **High TPS**: Target 10+ transaksi/detik
- **Redis Failure Handling**: Automatic fallback ke database lock ketika Redis mati
- **Circuit Breaker**: Pattern untuk mencegah cascade failure
- **Health Monitoring**: Continuous Redis health check dengan auto-recovery
- **Data Consistency**: Automatic validation dan repair untuk menjaga data integrity
- **Graceful Degradation**: Sistem tetap berjalan meskipun Redis mati

## Arsitektur

```
Request → Quick Validation → Redis Atomic → Insert Sub-Balance → Success Response
                                                                    ↓
Background Worker → Settlement → Update Main Balance → Clear Redis Counter
```

## Quick Start

```bash
# Clone dan setup
git clone <repository>
cd sub-balance-demo

# Setup environment dan dependencies
make setup

# Start aplikasi
make run

# Jalankan test TPS performance
make test                    # 1 account
make test-multi-simple      # 5 accounts

# Lihat semua available commands
make help
```

## Available Commands

### Main Commands
```bash
make setup          # Setup environment dan dependencies
make build          # Build aplikasi
make run            # Start aplikasi
make test           # Run comprehensive TPS performance tests
make clean          # Clean build artifacts
```

### Testing Commands
```bash
# Single Account Testing
make test           # Comprehensive TPS test (1 account)
make test-simple    # Simple TPS test (1 account)

# Multi-Account Testing  
make test-multi-simple  # TPS test dengan 5 accounts
make setup-multi        # Setup 5 test accounts
make reset-multi        # Reset semua test accounts

# Redis Failure Testing
make test-redis-failure      # Simulated Redis failure test
make test-redis-failure-real # Real Redis failure test

# Database Optimization
make optimize-db     # Optimize database dengan indexing
make monitor-db      # Monitor database performance
```

### Utility Commands
```bash
make help           # Show all available commands
make health         # Check application health
make logs           # View application logs
make docker-up      # Start Docker services
make docker-down    # Stop Docker services
```

## Setup

### Prerequisites

- Go 1.21+
- PostgreSQL
- Redis
- Docker & Docker Compose (recommended)

### Environment Variables

```bash
export DATABASE_URL="postgres://user:password@localhost:5432/subbalance?sslmode=disable"
export REDIS_URL="localhost:6379"
export PORT="8082"
```

### Installation

```bash
cd sub-balance-demo
make setup    # Setup environment dan dependencies
make run      # Start aplikasi
```

## API Endpoints

### 1. Process Transaction

```bash
POST /api/v1/transaction
Content-Type: application/json

{
  "account_id": "ACC001",
  "amount": "10000",
  "type": "debit"
}
```

Response:
```json
{
  "success": true,
  "message": "Transaksi berhasil diproses",
  "account_id": "ACC001",
  "amount": "10000",
  "type": "debit",
  "status": "PENDING",
  "timestamp": "2024-01-01T10:00:00Z"
}
```

### 2. Get Balance

```bash
GET /api/v1/balance/ACC001
```

Response:
```json
{
  "account_id": "ACC001",
  "settled_balance": "100000",
  "pending_debit": "0",
  "pending_credit": "0",
  "available_balance": "100000",
  "last_updated": "2024-01-01T10:00:00Z"
}
```

### 3. Get Pending Transactions

```bash
GET /api/v1/pending/ACC001
```

Response:
```json
{
  "account_id": "ACC001",
  "count": 5,
  "total": "50000",
  "items": [...]
}
```

### 4. Health Check

```bash
GET /api/v1/health
```

## Testing

### Quick Start Testing

```bash
# Setup environment dan dependencies
make setup

# Start aplikasi
make run

# Jalankan test TPS performance (1 account)
make test

# Jalankan test TPS performance (5 accounts)
make test-multi-simple
```

### Available Test Commands

#### 1. Single Account Testing

```bash
# Test TPS performance dengan 1 account (comprehensive report)
make test

# Test TPS performance dengan 1 account (simple)
make test-simple

# Setup test account
make test-setup

# Check test account status
make test-status

# Reset test account balance
make test-reset

# Clean test data
make test-clean
```

#### 2. Multi-Account Testing

```bash
# Test TPS performance dengan 5 accounts (comprehensive)
make test-multi

# Test TPS performance dengan 5 accounts (simple, precise timing)
make test-multi-simple

# Setup 5 test accounts
make setup-multi

# Reset semua 5 test accounts
make reset-multi

# Check status semua 5 test accounts
make status-multi
```

#### 3. Redis Failure Testing

```bash
# Test Redis failure dan recovery (simulated)
make test-redis-failure

# Test Redis failure dan recovery (real - stops/starts Redis)
make test-redis-failure-real
```

#### 4. Database Optimization Testing

```bash
# Optimize database dengan advanced indexing
make optimize-db

# Monitor database index performance
make monitor-db
```

### Test Scenarios

#### Single Account TPS Test
- **Scenarios**: 10, 30, 50, 100 TPS
- **Duration**: 10 detik per scenario
- **Account**: ACC001
- **Report**: Comprehensive markdown report dengan balance integrity check

#### Multi-Account TPS Test
- **Scenarios**: 10, 20, 30, 50, 100, 200, 300 TPS
- **Duration**: 10 detik per scenario
- **Accounts**: MULTI001, MULTI002, MULTI003, MULTI004, MULTI005
- **Load Distribution**: Equal distribution across 5 accounts
- **Report**: Detailed comparison table dengan performance metrics

#### Redis Failure Test
- **Timeline**:
  - T+0s: Transaction 1 → Redis OK → Sub-balance created
  - T+2s: Transaction 2 → Redis MATI → Fallback to DB lock
  - T+3s: Worker runs → Settlement + Redis recovery
  - T+30s: Data consistency check
- **Validation**: Data integrity, fallback mechanism, recovery process

### Test Reports

Semua test menghasilkan report dalam format Markdown di folder `reports/`:

- **Single Account**: `tps_comprehensive_report_YYYYMMDD_HHMMSS.md`
- **Multi-Account**: `multi_account_simple_report_YYYYMMDD_HHMMSS.md`
- **Redis Failure**: `redis_failure_recovery_report_YYYYMMDD_HHMMSS.md`

### Test Results Interpretation

#### TPS Performance
- **Excellent (🟢)**: Success rate ≥ 90%
- **Good (🟡)**: Success rate ≥ 70%
- **Poor (🔴)**: Success rate < 70%

#### Balance Integrity
- **Passed**: Final balance matches expected calculation
- **Failed**: Balance discrepancy detected

#### Redis Failure Handling
- **Passed**: All transactions processed, data integrity maintained
- **Failed**: Data loss or corruption detected

### Troubleshooting Tests

```bash
# Check server health
make health

# Check detailed health
make health-detailed

# Check pending transactions
make pending

# View application logs
make logs

# View database logs
make logs-db

# View Redis logs
make logs-redis
```

## Examples

### Example 1: Basic TPS Testing

```bash
# Setup dan start aplikasi
make setup
make run

# Test TPS dengan 1 account
make test

# Hasil: Report di reports/tps_comprehensive_report_*.md
# - Scenarios: 10, 30, 50, 100 TPS
# - Duration: 10 detik per scenario
# - Balance integrity check
```

### Example 2: Multi-Account Load Testing

```bash
# Setup 5 test accounts
make setup-multi

# Test TPS dengan 5 accounts
make test-multi-simple

# Hasil: Report di reports/multi_account_simple_report_*.md
# - Scenarios: 10, 20, 30, 50, 100, 200, 300 TPS
# - Load distribution across 5 accounts
# - Performance comparison table
```

### Example 3: Redis Failure Testing

```bash
# Test Redis failure scenario
make test-redis-failure

# Hasil: Report di reports/redis_failure_recovery_report_*.md
# - Timeline: T+0s, T+2s, T+3s, T+30s
# - Fallback mechanism validation
# - Data integrity verification
```

### Example 4: Database Optimization

```bash
# Optimize database dengan indexing
make optimize-db

# Monitor performance
make monitor-db

# Test performance improvement
make test-multi-simple
```

### Example 5: Development Workflow

```bash
# Complete development setup
make dev-setup

# Start dengan auto-reload
make dev

# Run tests
make test
make test-multi-simple

# Check health
make health-detailed

# View logs
make logs
```

## Database Schema

### account_balances

```sql
CREATE TABLE account_balances (
    id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    settled_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
    pending_debit DECIMAL(20,2) NOT NULL DEFAULT 0,
    pending_credit DECIMAL(20,2) NOT NULL DEFAULT 0,
    available_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 0,
    last_settlement_at TIMESTAMP
);
```

### sub_balances

```sql
CREATE TABLE sub_balances (
    id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50) NOT NULL,
    amount DECIMAL(20,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (account_id) REFERENCES account_balances(id),
    INDEX idx_sub_balance_account_status (account_id, status),
    INDEX idx_sub_balance_created_at (created_at)
);
```

## Testing

### Load Testing

```bash
# Install hey
go install github.com/rakyll/hey@latest

# Test dengan 100 concurrent requests
hey -n 1000 -c 100 -m POST -H "Content-Type: application/json" \
  -d '{"account_id":"ACC001","amount":"1000","type":"debit"}' \
  http://localhost:8082/api/v1/transaction
```

### Manual Testing

```bash
# 1. Create account balance
curl -X POST http://localhost:8082/api/v1/transaction \
  -H "Content-Type: application/json" \
  -d '{"account_id":"ACC001","amount":"100000","type":"credit"}'

# 2. Check balance
curl http://localhost:8082/api/v1/balance/ACC001

# 3. Make multiple transactions
for i in {1..10}; do
  curl -X POST http://localhost:8082/api/v1/transaction \
    -H "Content-Type: application/json" \
    -d "{\"account_id\":\"ACC001\",\"amount\":\"1000\",\"type\":\"debit\"}"
done

# 4. Check pending transactions
curl http://localhost:8082/api/v1/pending/ACC001

# 5. Wait 5 seconds and check balance again
sleep 5
curl http://localhost:8082/api/v1/balance/ACC001
```

## Monitoring

### Redis Monitoring

```bash
# Check Redis keys
redis-cli keys "subbalance:*"

# Check pending counter
redis-cli get "subbalance:pending:ACC001"

# Monitor Redis operations
redis-cli monitor
```

### Database Monitoring

```sql
-- Check account balances
SELECT * FROM account_balances;

-- Check pending transactions
SELECT account_id, COUNT(*) as count, SUM(amount) as total 
FROM sub_balances 
WHERE status = 'PENDING' 
GROUP BY account_id;

-- Check settlement history
SELECT account_id, COUNT(*) as settled_count, SUM(amount) as total_settled
FROM sub_balances 
WHERE status = 'SETTLED' 
  AND updated_at >= NOW() - INTERVAL 1 HOUR
GROUP BY account_id;
```

## Performance Comparison

| Metric | Sistem Lama | Sistem Baru |
|--------|-------------|-------------|
| TPS | ~0.5 | ~10+ |
| Response Time | 2-5 detik | 0.1 detik |
| Lock Contention | High | None |
| Scalability | Limited | High |
| Consistency | Strong | Eventual |

## Troubleshooting

### Common Issues

1. **Redis Connection Failed**
   - Check Redis server status
   - Verify REDIS_URL environment variable

2. **Database Connection Failed**
   - Check PostgreSQL server status
   - Verify DATABASE_URL environment variable

3. **Settlement Not Working**
   - Check background worker logs
   - Verify Redis counter values

4. **High Memory Usage**
   - Check Redis memory usage
   - Monitor pending transactions count

### Logs

```bash
# Check application logs
tail -f logs/app.log

# Check Redis logs
tail -f /var/log/redis/redis-server.log

# Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql.log
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

MIT License
