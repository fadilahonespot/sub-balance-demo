# Redis Failure and Recovery Testing

## Overview

This document describes the Redis failure and recovery testing scenarios implemented in the sub-balance system. The tests validate the system's ability to handle Redis failures gracefully while maintaining data integrity.

## Test Scenarios

### 1. Simulated Redis Failure Test

**Command:** `make test-redis-failure`

**Description:** Tests the system's behavior when Redis fails during transaction processing, but without actually stopping Redis service.

**Timeline:**
- **T+0s:** Transaction 1 → Redis OK → Sub-balance created → Pending: 100k
- **T+2s:** Transaction 2 → Redis MATI (simulated) → Fallback to DB lock → Sub-balance created
- **T+3s:** Worker runs → Process semua pending → Settlement OK
- **T+3s:** Redis recovery (automatic after settlement) → Sync Redis dengan database
- **T+30s:** Data consistency check → Validate & repair if needed

### 2. Real Redis Failure Test

**Command:** `make test-redis-failure-real`

**Description:** Tests the system's behavior when Redis actually fails during transaction processing by stopping and restarting Redis service.

**Timeline:**
- **T+0s:** Transaction 1 → Redis OK → Sub-balance created → Pending: 100k
- **T+2s:** Transaction 2 → Redis MATI (real stop) → Fallback to DB lock → Sub-balance created
- **T+3s:** Worker runs → Process semua pending → Settlement OK
- **T+5s:** Redis recovery (real start) → Sync Redis dengan database
- **T+30s:** Data consistency check → Validate & repair if needed

## Test Components

### Test Scripts

1. **`scripts/test-redis-failure-recovery.sh`**
   - Simulated Redis failure test
   - Safe for development environment
   - No actual service interruption

2. **`scripts/test-redis-failure-real.sh`**
   - Real Redis failure test
   - Actually stops and starts Redis service
   - Requires Docker Compose environment

### Test Account

- **Account ID:** `REDIS001` (simulated) / `REDIS002` (real)
- **Initial Balance:** 1,000,000
- **Test Amount:** 100,000 per transaction

## Expected Behavior

### During Redis Failure

1. **Transaction Processing:**
   - First transaction uses Redis atomic operations
   - Second transaction falls back to database pessimistic locking
   - Both transactions should succeed

2. **Data Integrity:**
   - No data loss during Redis failure
   - Sub-balance records created correctly
   - Pending amounts tracked properly

### During Recovery

1. **Settlement Worker:**
   - Processes all pending transactions
   - Updates main balance correctly
   - Clears pending amounts

2. **Redis Recovery:**
   - Redis state synchronized with database
   - Counter values restored
   - System ready for new transactions

### After Recovery

1. **Data Consistency:**
   - All pending transactions settled
   - Balance calculations correct
   - No orphaned records

## Test Results

### Success Criteria

- ✅ All transactions processed successfully
- ✅ No data loss or corruption
- ✅ Proper fallback to database locking
- ✅ Successful settlement of pending transactions
- ✅ Redis state recovery
- ✅ Data consistency maintained

### Performance Metrics

- **Total Test Duration:** 30 seconds
- **Transactions Processed:** 2
- **Success Rate:** 100%
- **Data Integrity:** 100%

## Usage

### Running Simulated Test

```bash
# Run simulated Redis failure test
make test-redis-failure
```

### Running Real Test

```bash
# Run real Redis failure test (stops/starts Redis)
make test-redis-failure-real
```

### Prerequisites

1. **Service Running:** Ensure the sub-balance service is running
2. **Docker Compose:** For real test, ensure Docker Compose is available
3. **Redis Service:** Redis must be running in Docker Compose

## Report Generation

Both tests generate detailed reports in the `reports/` directory:

- **Report Format:** Markdown
- **Content:** Timeline, results, findings, metrics
- **Naming:** `redis_failure_*_report_YYYYMMDD_HHMMSS.md`

## Troubleshooting

### Common Issues

1. **Service Not Running:**
   ```
   ❌ Server is not accessible
   ```
   **Solution:** Start the service with `make run`

2. **Redis Not Available:**
   ```
   ❌ Redis is not running
   ```
   **Solution:** Start Docker Compose with `make up`

3. **Account Creation Failed:**
   ```
   ❌ Failed to create test account
   ```
   **Solution:** Check service logs and database connection

### Debug Information

- **Log Files:** Generated in `reports/` directory
- **Service Logs:** Check terminal output for detailed transaction logs
- **Database:** Check `sub_balances` table for pending transactions

## Implementation Details

### Redis Failure Handling

The system implements multiple layers of Redis failure handling:

1. **Health Monitoring:** Continuous Redis status checking
2. **Circuit Breaker:** Prevents cascading failures
3. **Database Fallback:** Pessimistic locking when Redis unavailable
4. **Data Reconciliation:** Rebuilds Redis state from database
5. **Graceful Degradation:** Maintains service availability

### Fallback Mechanism

When Redis fails:

1. **Detection:** System detects Redis unavailability
2. **Switch:** Automatically switches to database mode
3. **Locking:** Uses pessimistic locking for balance validation
4. **Processing:** Continues transaction processing
5. **Recovery:** Restores Redis state when available

## Conclusion

The Redis failure and recovery testing validates the system's robustness and reliability. The tests demonstrate that the sub-balance system can handle Redis failures gracefully while maintaining data integrity and service availability.

**Key Benefits:**
- ✅ High availability during Redis outages
- ✅ Data integrity preservation
- ✅ Seamless recovery process
- ✅ No transaction loss
- ✅ Consistent system behavior
