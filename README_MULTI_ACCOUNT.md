# Multi-Account TPS Testing

## Overview

Script testing multi-account dirancang untuk menguji performa TPS dengan mendistribusikan load ke 5 account berbeda. Ini membantu mengurangi contention pada single account dan meningkatkan overall TPS.

## Benefits

### 🚀 **Performance Improvements**
- **Reduced Lock Contention**: Load didistribusikan ke 5 account
- **Better Parallelism**: Multiple account dapat diproses bersamaan
- **Higher Overall TPS**: Mengurangi bottleneck pada single account
- **Improved Scalability**: Sistem dapat handle TPS yang lebih tinggi

### 📊 **Load Distribution**
- **Even Distribution**: Load dibagi rata ke semua account
- **Account Isolation**: Setiap account memiliki balance terpisah
- **Independent Processing**: Transaksi dapat diproses secara paralel
- **Better Resource Utilization**: Mengoptimalkan penggunaan database dan Redis

## Scripts Available

### 1. **Setup Multi-Account** (`setup-multi-accounts.sh`)

**Purpose**: Setup 5 test account dengan balance yang cukup

**Commands**:
```bash
# Setup semua account (default)
make setup-multi

# Reset semua account ke balance awal
make reset-multi

# Cek status semua account
make status-multi
```

**Features**:
- ✅ Create 5 accounts (ACC001-ACC005)
- ✅ Set initial balance 10,000,000 per account
- ✅ Auto top-up jika balance kurang
- ✅ Verify semua account ready
- ✅ Status checking dan reporting

### 2. **Multi-Account TPS Test** (`test-tps-multi-account.sh`)

**Purpose**: Test TPS performance dengan 5 account

**Command**:
```bash
make test-multi
```

**Features**:
- ✅ Test scenarios: 10, 20, 30, 50, 100, 200, 300 TPS
- ✅ Load distribution ke 5 account
- ✅ Comprehensive reporting
- ✅ Balance integrity checking
- ✅ Performance metrics per scenario

## Test Configuration

### 📋 **Test Accounts**
- **ACC001**: Account 1
- **ACC002**: Account 2  
- **ACC003**: Account 3
- **ACC004**: Account 4
- **ACC005**: Account 5

### 💰 **Balance Configuration**
- **Initial Balance**: 10,000,000 per account
- **Total Balance**: 50,000,000 across all accounts
- **Transaction Amount**: 1,000 per debit transaction
- **Max Transactions**: 50,000 per account (before balance runs out)

### ⏱️ **Test Scenarios**
| Scenario | Target TPS | Total Requests | Per Account | Duration |
|----------|------------|----------------|-------------|----------|
| Low TPS | 10 | 100 | 20 | 10s |
| Low TPS | 20 | 200 | 40 | 10s |
| Medium TPS | 30 | 300 | 60 | 10s |
| Medium TPS | 50 | 500 | 100 | 10s |
| High TPS | 100 | 1,000 | 200 | 10s |
| High TPS | 200 | 2,000 | 400 | 10s |
| High TPS | 300 | 3,000 | 600 | 10s |

## Usage Examples

### 🚀 **Quick Start**

```bash
# 1. Setup 5 test accounts
make setup-multi

# 2. Run multi-account TPS test
make test-multi

# 3. Check results in reports/
```

### 🔄 **Reset and Retest**

```bash
# Reset all accounts to initial balance
make reset-multi

# Run test again
make test-multi
```

### 📊 **Check Account Status**

```bash
# Check current status of all accounts
make status-multi
```

## Expected Results

### 🎯 **Performance Targets**

| TPS Scenario | Expected Success Rate | Expected TPS Efficiency |
|--------------|----------------------|------------------------|
| 10 TPS | 100% | 0.9x+ |
| 20 TPS | 100% | 0.9x+ |
| 30 TPS | 100% | 0.9x+ |
| 50 TPS | 90%+ | 0.8x+ |
| 100 TPS | 70%+ | 0.6x+ |
| 200 TPS | 50%+ | 0.4x+ |
| 300 TPS | 40%+ | 0.3x+ |

### 📈 **Benefits vs Single Account**

| Metric | Single Account | Multi-Account | Improvement |
|--------|----------------|---------------|-------------|
| 50 TPS Success Rate | 87% | 95%+ | +8% |
| 100 TPS Success Rate | 61% | 80%+ | +19% |
| 200 TPS Success Rate | 39% | 60%+ | +21% |
| Overall TPS | Limited by contention | Higher throughput | 2-3x |

## Report Analysis

### 📄 **Report Location**
- **Report File**: `reports/multi_account_tps_report_YYYYMMDD_HHMMSS.md`
- **Log File**: `reports/multi_account_test_YYYYMMDD_HHMMSS.log`

### 📊 **Key Metrics**
- **Per-Account Performance**: Individual account success rates
- **Load Distribution**: How well load is distributed
- **Overall TPS**: Total system throughput
- **Balance Integrity**: Account balance consistency
- **Rate Limiting**: System rate limiting behavior

### 🔍 **Analysis Points**
1. **Account Performance**: Compare individual account success rates
2. **Load Distribution**: Verify even distribution across accounts
3. **Contention Reduction**: Measure improvement over single account
4. **Scalability**: How well system scales with multiple accounts
5. **Balance Integrity**: Ensure no balance corruption

## Troubleshooting

### ❌ **Common Issues**

**1. Account Creation Failed**
```bash
# Check server is running
curl http://localhost:8080/api/v1/health

# Restart server if needed
make run
```

**2. Insufficient Balance**
```bash
# Reset all accounts
make reset-multi

# Or manually add credit
curl -X POST http://localhost:8080/api/v1/transaction \
  -H "Content-Type: application/json" \
  -d '{"account_id":"ACC001","amount":"1000000","type":"credit"}'
```

**3. High Failure Rate**
- Check database connection
- Verify Redis is running
- Check system resources (CPU, Memory)
- Review database indexes

### 🔧 **Debug Commands**

```bash
# Check account status
make status-multi

# Check server health
curl http://localhost:8080/api/v1/health

# Check database indexes
make monitor-db

# View recent logs
tail -f logs/app.log
```

## Best Practices

### 🎯 **For Production**

1. **Account Sharding**: Use multiple accounts to distribute load
2. **Load Balancing**: Implement account-based load balancing
3. **Monitoring**: Monitor individual account performance
4. **Scaling**: Add more accounts as TPS requirements grow
5. **Balance Management**: Implement automatic balance top-up

### 📊 **Performance Optimization**

1. **Account Distribution**: Distribute load evenly across accounts
2. **Connection Pooling**: Use account-specific connection pools
3. **Redis Clustering**: Implement Redis clustering for better distribution
4. **Database Sharding**: Consider database sharding by account
5. **Monitoring**: Implement real-time performance monitoring

## Conclusion

Multi-account testing memberikan insight yang lebih baik tentang:
- **System Scalability**: Bagaimana sistem menangani multiple account
- **Load Distribution**: Efektivitas distribusi load
- **Contention Reduction**: Pengurangan bottleneck pada single account
- **Overall Performance**: Total throughput sistem

**Expected Improvement**: 2-3x better TPS performance compared to single account testing.

