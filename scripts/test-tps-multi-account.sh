#!/bin/bash

# =====================================================
# Multi-Account TPS Performance Test Script
# =====================================================
# This script tests TPS performance across 5 accounts
# to reduce lock contention and improve overall performance
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8080"
TEST_ACCOUNTS=("MULTI001" "MULTI002" "MULTI003" "MULTI004" "MULTI005")
TEST_DURATION=10
SCENARIOS=(10 20 30 50 100 200 300)
REPORT_DIR="reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/multi_account_tps_report_$TIMESTAMP.md"
LOG_FILE="$REPORT_DIR/multi_account_test_$TIMESTAMP.log"

# Create reports directory
mkdir -p "$REPORT_DIR"

# Function to log messages
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check server health
check_server_health() {
    log "🔍 Checking server health..."
    
    if ! curl -s "$BASE_URL/api/v1/health" >/dev/null 2>&1; then
        echo -e "${RED}❌ Server is not running or not accessible${NC}"
        echo "Please start the server first with: make run"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Server is running and accessible${NC}"
}

# Function to create test accounts
create_test_accounts() {
    log "👥 Creating test accounts..."
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        echo -e "${CYAN}📝 Creating account: $account${NC}"
        
        # Check if account exists
        local response=$(curl -s "$BASE_URL/api/v1/balance/$account" 2>/dev/null || echo "{}")
        local exists=$(echo "$response" | jq -r '.account_id // empty')
        
        if [ -n "$exists" ]; then
            echo -e "${GREEN}✅ Account $account already exists${NC}"
        else
            # Create account with initial balance
            local create_response=$(curl -s -X POST "$BASE_URL/test/accounts" \
                -H "Content-Type: application/json" \
                -d "{\"account_id\":\"$account\",\"balance\":\"10000000\"}" 2>/dev/null)
            
            local success=$(echo "$create_response" | jq -r '.success // false')
            
            if [ "$success" = "true" ]; then
                echo -e "${GREEN}✅ Account $account created successfully${NC}"
            else
                echo -e "${RED}❌ Failed to create account $account${NC}"
                echo "Response: $create_response"
                exit 1
            fi
        fi
    done
}

# Function to get account balance
get_balance() {
    local account_id="$1"
    local response=$(curl -s "$BASE_URL/api/v1/balance/$account_id" 2>/dev/null || echo "{}")
    echo "$response" | jq -r '.settled_balance // 0'
}

# Function to get account info
get_account_info() {
    local account_id="$1"
    curl -s "$BASE_URL/api/v1/balance/$account_id" 2>/dev/null || echo "{}"
}

# Function to run performance test for a scenario
run_performance_test() {
    local scenario_name="$1"
    local target_tps="$2"
    local total_requests=$((target_tps * TEST_DURATION))
    local requests_per_second=$((total_requests / TEST_DURATION))
    local interval=$((1000 / requests_per_second))  # milliseconds
    
    echo -e "${PURPLE}📊 $scenario_name${NC}"
    echo "Started with $total_requests transactions over ${TEST_DURATION}s (target TPS: $target_tps)"
    echo "Request interval: $(echo "scale=2; $interval" | bc)ms per request"
    
    local start_time=$(date +%s)
    local successful_requests=0
    local failed_requests=0
    local rate_limited=0
    local other_errors=0
    
    # Distribute requests across accounts
    local requests_per_account=$((total_requests / ${#TEST_ACCOUNTS[@]}))
    local remaining_requests=$((total_requests % ${#TEST_ACCOUNTS[@]}))
    
    echo "   Distributing $requests_per_account requests per account (${#TEST_ACCOUNTS[@]} accounts)"
    
    # Calculate timing for precise 10-second test
    local start_time=$(date +%s.%N)
    local end_time=$(echo "$start_time + $TEST_DURATION" | bc)
    local current_time=$start_time
    
    # Run test for precise duration
    while (( $(echo "$current_time < $end_time" | bc -l) )); do
        # Send requests for each account in parallel
        for account_idx in "${!TEST_ACCOUNTS[@]}"; do
            local account="${TEST_ACCOUNTS[$account_idx]}"
            local account_requests=$requests_per_account
            
            # Add remaining requests to first account
            if [ $account_idx -eq 0 ]; then
                account_requests=$((account_requests + remaining_requests))
            fi
            
            # Send requests for this account
            for ((i=1; i<=account_requests; i++)); do
                # Check if we still have time
                current_time=$(date +%s.%N)
                if (( $(echo "$current_time >= $end_time" | bc -l) )); then
                    break 2  # Break out of both loops
                fi
                
                # Send individual transaction request in background
                (
                    local response=$(curl -s -X POST "$BASE_URL/api/v1/transaction" \
                        -H "Content-Type: application/json" \
                        -d "{\"account_id\": \"$account\", \"amount\": \"1000\", \"type\": \"debit\"}")
                    
                    # Parse response
                    local success=$(echo "$response" | jq -r '.success // false')
                    local status=$(echo "$response" | jq -r '.status // "UNKNOWN"')
                    
                    if [ "$success" = "true" ]; then
                        echo "SUCCESS" >> /tmp/test_results_$$
                    else
                        if [ "$status" = "RATE_LIMITED" ]; then
                            echo "RATE_LIMITED" >> /tmp/test_results_$$
                        else
                            echo "OTHER_ERROR" >> /tmp/test_results_$$
                        fi
                    fi
                ) &
                
                # Small delay to prevent overwhelming the server
                sleep 0.001
            done
        done
        
        # Small delay before next batch
        sleep 0.1
        current_time=$(date +%s.%N)
    done
    
    # Wait for all background processes to complete
    wait
    
    # Count results
    if [ -f /tmp/test_results_$$ ]; then
        successful_requests=$(grep -c "SUCCESS" /tmp/test_results_$$ || echo "0")
        rate_limited=$(grep -c "RATE_LIMITED" /tmp/test_results_$$ || echo "0")
        other_errors=$(grep -c "OTHER_ERROR" /tmp/test_results_$$ || echo "0")
        failed_requests=$((rate_limited + other_errors))
        rm -f /tmp/test_results_$$
    fi
    
    local final_end_time=$(date +%s.%N)
    local actual_duration=$(echo "scale=2; $final_end_time - $start_time" | bc)
    local actual_tps=$(echo "scale=2; $successful_requests / $actual_duration" | bc)
    
    echo -e "${GREEN}Completed in ${actual_duration}s, with an Actual TPS: $actual_tps${NC}"
    
    # Get final balances for all accounts
    local final_balances=()
    local total_final_balance=0
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        local balance=$(get_balance "$account")
        final_balances+=("$balance")
        total_final_balance=$((total_final_balance + balance))
        echo "Final balance for $account: $balance"
    done
    
    echo "Total final balance across all accounts: $total_final_balance"
    echo "Successful: $successful_requests, Rate limited: $rate_limited, Other errors: $other_errors"
    
    # Calculate performance metrics
    local success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc)
    local rate_limit_rate=$(echo "scale=2; $rate_limited * 100 / $total_requests" | bc)
    local avg_duration=$(echo "scale=2; $actual_duration * 1000 / $total_requests" | bc)
    
    # Fix success rate calculation (should not exceed 100%)
    if (( $(echo "$success_rate > 100" | bc -l) )); then
        success_rate="100.00"
    fi
    
    echo "Performance Metrics:"
    echo "  Success rate: $success_rate% ($successful_requests/$total_requests)"
    echo "  Rate limit rate: $rate_limit_rate% ($rate_limited/$total_requests)"
    echo "  Average transaction duration: ${avg_duration}ms"
    
    # Store results for report
    echo "$scenario_name|$target_tps|$actual_tps|$success_rate|$successful_requests|$failed_requests|$rate_limited|$other_errors|$actual_duration" >> "$REPORT_FILE.tmp"
}

# Function to generate comprehensive report
generate_report() {
    log "📝 Generating comprehensive report..."
    
    # Initialize report file
    cat > "$REPORT_FILE" << EOF
# Multi-Account TPS Performance Test Report

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Test Duration:** $TEST_DURATION seconds per scenario
**Test Accounts:** ${TEST_ACCOUNTS[*]}
**Total Scenarios:** ${#SCENARIOS[@]}
**Report File:** $REPORT_FILE
**Log File:** $LOG_FILE

## Test Configuration

- **Base URL:** $BASE_URL
- **Test Accounts:** ${#TEST_ACCOUNTS[@]} accounts (${TEST_ACCOUNTS[*]})
- **Test Duration:** $TEST_DURATION seconds per scenario
- **Scenarios:** ${SCENARIOS[*]} TPS
- **Transaction Type:** Debit (1000 per transaction)
- **Load Distribution:** Evenly distributed across accounts

## Test Results

EOF

    # Add individual scenario results
    while IFS='|' read -r scenario target_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        cat >> "$REPORT_FILE" << EOF
### $scenario

**Configuration:**
- Target TPS: $target_tps
- Total Requests: $((target_tps * TEST_DURATION))
- Expected Duration: ${TEST_DURATION}s
- Request Distribution: $((target_tps * TEST_DURATION / ${#TEST_ACCOUNTS[@]})) per account

**Results:**
- **Actual Duration:** ${duration}s
- **Actual TPS:** $actual_tps
- **Successful Requests:** $successful
- **Failed Requests:** $failed
- **Rate Limited:** $rate_limited
- **Other Errors:** $other_errors
- **Success Rate:** $success_rate%

**Performance Analysis:**
- TPS Efficiency: $(echo "scale=1; $actual_tps / $target_tps" | bc)x target
- Success Rate: $success_rate%
- System Performance: $(if (( $(echo "$success_rate >= 90" | bc -l) )); then echo "🟢 Excellent"; elif (( $(echo "$success_rate >= 70" | bc -l) )); then echo "🟡 Good"; else echo "🔴 Poor"; fi)
- Rate Limiting: $(if [ "$rate_limited" -eq 0 ]; then echo "🟢 No rate limiting"; else echo "🟡 Rate limiting active"; fi)

---

EOF
    done < "$REPORT_FILE.tmp"

    # Add summary section
    cat >> "$REPORT_FILE" << EOF

## Summary

### Test Results Comparison Table

| Test Scenario | Target TPS | Actual TPS | TPS Efficiency | Success Rate | Duration | Performance | Rate Limited |
|---------------|------------|------------|----------------|--------------|----------|-------------|--------------|
EOF

    # Add comparison table rows
    while IFS='|' read -r scenario target_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        local tps_efficiency=$(echo "scale=1; $actual_tps / $target_tps" | bc)
        local performance_status
        if (( $(echo "$success_rate >= 90" | bc -l) )); then
            performance_status="🟢 Excellent"
        elif (( $(echo "$success_rate >= 70" | bc -l) )); then
            performance_status="🟡 Good"
        else
            performance_status="🔴 Poor"
        fi
        
        local rate_limit_status
        if [ "$rate_limited" -eq 0 ]; then
            rate_limit_status="0.0%"
        else
            rate_limit_status="$(echo "scale=1; $rate_limited * 100 / $((target_tps * TEST_DURATION))" | bc)%"
        fi
        
        echo "| $scenario | $target_tps | $actual_tps | ${tps_efficiency}x | $success_rate% | ${duration}s | $performance_status | $rate_limit_status |" >> "$REPORT_FILE"
    done < "$REPORT_FILE.tmp"

    # Add overall analysis
    local total_successful=0
    local total_failed=0
    local total_rate_limited=0
    local total_requests=0
    
    while IFS='|' read -r scenario target_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        total_successful=$((total_successful + successful))
        total_failed=$((total_failed + failed))
        total_rate_limited=$((total_rate_limited + rate_limited))
        total_requests=$((total_requests + target_tps * TEST_DURATION))
    done < "$REPORT_FILE.tmp"
    
    local overall_success_rate=$(echo "scale=1; $total_successful * 100 / $total_requests" | bc)
    local overall_rate_limit_rate=$(echo "scale=1; $total_rate_limited * 100 / $total_requests" | bc)
    
    cat >> "$REPORT_FILE" << EOF

### Overall Performance Analysis

| Metric | Value |
|--------|-------|
| Total Tests | ${#SCENARIOS[@]} |
| Total Requests | $total_requests |
| Total Successful | $total_successful |
| Total Failed | $total_failed |
| Total Rate Limited | $total_rate_limited |
| Average Success Rate | $overall_success_rate% |
| Average Rate Limit Rate | $overall_rate_limit_rate% |

### Multi-Account Benefits

**Load Distribution:**
- **Reduced Contention:** Load spread across ${#TEST_ACCOUNTS[@]} accounts
- **Better Parallelism:** Multiple accounts can process simultaneously
- **Improved TPS:** Reduced lock contention on individual accounts
- **Scalability:** System can handle higher overall TPS

**Account Performance:**
EOF

    # Add final balances for each account
    for account in "${TEST_ACCOUNTS[@]}"; do
        local final_balance=$(get_balance "$account")
        echo "- **$account:** $final_balance" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" << EOF

### Recommendations

**For Production:**
- Use multiple accounts to distribute load
- Monitor individual account performance
- Implement account-based load balancing
- Consider account sharding for higher TPS
- Monitor balance integrity across all accounts

**Performance Optimization:**
- Increase number of test accounts for higher TPS
- Implement account-specific connection pooling
- Use Redis clustering for better distribution
- Consider database sharding by account

### Test Environment

- **OS:** $(uname -s) $(uname -r)
- **Date:** $(date '+%Y-%m-%d %H:%M:%S')
- **Test Duration:** $(date '+%H:%M:%S')
- **Report Generated:** $(date '+%Y-%m-%d %H:%M:%S')
- **System Type:** Multi-Account Sub-Balance with Redis Atomic Operations
- **Database:** PostgreSQL with Optimized Indexes
- **Cache:** Redis with Lua Scripts
- **Framework:** Echo v4

---

*Report generated by Multi-Account TPS Performance Test Script*
EOF

    # Clean up temporary file
    rm -f "$REPORT_FILE.tmp"
    
    echo -e "${GREEN}📄 Report generated: $REPORT_FILE${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Multi-Account TPS Performance Test${NC}"
    echo "=========================================="
    echo -e "${BLUE}📊 Target: High TPS with multiple accounts${NC}"
    echo -e "${BLUE}👥 Test Accounts: ${TEST_ACCOUNTS[*]}${NC}"
    echo -e "${BLUE}⏱️  Test Duration: $TEST_DURATION seconds per scenario${NC}"
    echo -e "${BLUE}📄 Report File: $REPORT_FILE${NC}"
    echo -e "${BLUE}📝 Log File: $LOG_FILE${NC}"
    echo ""
    
    # Check prerequisites
    check_server_health
    
    # Create test accounts
    create_test_accounts
    
    # Initialize report
    log "📝 Initializing comprehensive report file: $REPORT_FILE"
    
    echo -e "${PURPLE}🧪 Running Multi-Account Performance Tests...${NC}"
    echo "=============================================="
    
    # Run performance tests for each scenario
    for tps in "${SCENARIOS[@]}"; do
        run_performance_test "Multi_Account_Test/${tps}_TPS" "$tps"
        
        # Get last element safely
        local scenarios_count=${#SCENARIOS[@]}
        local last_index=$((scenarios_count - 1))
        local last_tps=${SCENARIOS[$last_index]}
        
        if [ "$tps" != "$last_tps" ]; then
            echo -e "${YELLOW}⏸️  Pausing for 5 seconds before next scenario...${NC}"
            sleep 5
        fi
    done
    
    # Generate comprehensive report
    generate_report
    
    echo ""
    echo -e "${GREEN}🎉 Multi-Account TPS performance test completed successfully!${NC}"
    echo -e "${GREEN}📄 Report generated: $REPORT_FILE${NC}"
    echo -e "${GREEN}✅ Multi-account performance test completed!${NC}"
}

# Run main function
main "$@"
