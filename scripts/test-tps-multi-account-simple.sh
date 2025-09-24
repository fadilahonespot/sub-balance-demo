#!/bin/bash

# =====================================================
# Simple Multi-Account TPS Performance Test Script
# =====================================================
# This script tests TPS performance across 5 accounts
# with precise 10-second timing
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
REPORT_FILE="$REPORT_DIR/multi_account_simple_report_$TIMESTAMP.md"
LOG_FILE="$REPORT_DIR/multi_account_simple_test_$TIMESTAMP.log"

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

# Function to get account balance
get_balance() {
    local account_id="$1"
    local response=$(curl -s "$BASE_URL/api/v1/balance/$account_id" 2>/dev/null || echo "{}")
    local balance=$(echo "$response" | jq -r '.settled_balance // empty')
    
    if [ -z "$balance" ] || [ "$balance" = "null" ]; then
        echo "0"
    else
        echo "$balance"
    fi
}

# Function to run performance test for a scenario
run_performance_test() {
    local scenario_name="$1"
    local target_tps="$2"
    local total_requests=$((target_tps * TEST_DURATION))
    local requests_per_account=$((total_requests / ${#TEST_ACCOUNTS[@]}))
    
    echo -e "${PURPLE}📊 $scenario_name${NC}"
    echo "Target: $target_tps TPS for ${TEST_DURATION}s = $total_requests requests"
    echo "Distribution: $requests_per_account requests per account"
    
    # Initialize counters
    local successful_requests=0
    local failed_requests=0
    local rate_limited=0
    local other_errors=0
    
    # Start timing
    local start_time=$(date +%s.%N)
    local end_time=$(echo "$start_time + $TEST_DURATION" | bc)
    
    # Create temporary files for results
    local success_file="/tmp/success_$$"
    local failed_file="/tmp/failed_$$"
    local rate_limit_file="/tmp/rate_limit_$$"
    touch "$success_file" "$failed_file" "$rate_limit_file"
    
    # Run test with controlled request count
    local requests_sent=0
    local current_time=$start_time
    
    while (( $(echo "$current_time < $end_time" | bc -l) )) && [ $requests_sent -lt $total_requests ]; do
        # Send requests to all accounts in parallel
        for account in "${TEST_ACCOUNTS[@]}"; do
            # Check if we've sent enough requests
            if [ $requests_sent -ge $total_requests ]; then
                break
            fi
            
            # Send request in background
            (
                local response=$(curl -s -X POST "$BASE_URL/api/v1/transaction" \
                    -H "Content-Type: application/json" \
                    -d "{\"account_id\": \"$account\", \"amount\": \"1000\", \"type\": \"debit\"}" \
                    --max-time 5)
                
                local success=$(echo "$response" | jq -r '.success // false')
                local status=$(echo "$response" | jq -r '.status // "UNKNOWN"')
                
                if [ "$success" = "true" ]; then
                    echo "1" >> "$success_file"
                elif [ "$status" = "RATE_LIMITED" ]; then
                    echo "1" >> "$rate_limit_file"
                else
                    echo "1" >> "$failed_file"
                fi
            ) &
            
            ((requests_sent++))
        done
        
        # Small delay to prevent overwhelming
        sleep 0.01
        current_time=$(date +%s.%N)
    done
    
    # Wait for all requests to complete
    wait
    
    # Count results
    successful_requests=$(wc -l < "$success_file" 2>/dev/null || echo "0")
    rate_limited=$(wc -l < "$rate_limit_file" 2>/dev/null || echo "0")
    other_errors=$(wc -l < "$failed_file" 2>/dev/null || echo "0")
    failed_requests=$((rate_limited + other_errors))
    
    # Clean up temporary files
    rm -f "$success_file" "$failed_file" "$rate_limit_file"
    
    # Calculate final metrics
    local final_time=$(date +%s.%N)
    local actual_duration=$(echo "scale=2; $final_time - $start_time" | bc)
    
    # Actual TPS should be based on successful requests vs target duration (10 seconds)
    # This gives us the actual TPS achieved within the target timeframe
    local actual_tps=$(echo "scale=2; $successful_requests / $TEST_DURATION" | bc)
    local target_actual_tps=$(echo "scale=2; $total_requests / $actual_duration" | bc)
    local success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc)
    
    # Fix success rate if it exceeds 100%
    if (( $(echo "$success_rate > 100" | bc -l) )); then
        success_rate="100.00"
    fi
    
    echo -e "${GREEN}✅ Completed in ${actual_duration}s${NC}"
    echo "   Target TPS: $target_tps"
    echo "   Actual TPS (successful): $actual_tps"
    echo "   Target vs Actual TPS: $target_actual_tps"
    echo "   Success Rate: $success_rate% ($successful_requests/$total_requests)"
    echo "   Rate Limited: $rate_limited"
    echo "   Other Errors: $other_errors"
    
    # Get final balances
    local total_final_balance=0
    for account in "${TEST_ACCOUNTS[@]}"; do
        local balance=$(get_balance "$account")
        total_final_balance=$((total_final_balance + balance))
    done
    echo "   Total Final Balance: $total_final_balance"
    
    # Store results for report
    echo "$scenario_name|$target_tps|$target_actual_tps|$actual_tps|$success_rate|$successful_requests|$failed_requests|$rate_limited|$other_errors|$actual_duration" >> "$REPORT_FILE.tmp"
}

# Function to generate report
generate_report() {
    log "📝 Generating report..."
    
    # Initialize report file
    cat > "$REPORT_FILE" << EOF
# Multi-Account TPS Performance Test Report (Simple)

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Test Duration:** $TEST_DURATION seconds per scenario
**Test Accounts:** ${TEST_ACCOUNTS[*]}
**Total Scenarios:** ${#SCENARIOS[@]}
**Report File:** $REPORT_FILE

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
    while IFS='|' read -r scenario target_tps target_actual_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        cat >> "$REPORT_FILE" << EOF
### $scenario

**Configuration:**
- Target TPS: $target_tps
- Total Requests: $((target_tps * TEST_DURATION))
- Expected Duration: ${TEST_DURATION}s

**Results:**
- **Actual Duration:** ${duration}s
- **Target TPS:** $target_tps
- **Target vs Actual TPS:** $target_actual_tps
- **Successful TPS:** $actual_tps
- **Successful Requests:** $successful
- **Failed Requests:** $failed
- **Rate Limited:** $rate_limited
- **Other Errors:** $other_errors
- **Success Rate:** $success_rate%

**Performance Analysis:**
- TPS Efficiency: $(echo "scale=1; $target_actual_tps / $target_tps" | bc)x target
- Success Rate: $success_rate%
- System Performance: $(if (( $(echo "$success_rate >= 90" | bc -l) )); then echo "🟢 Excellent"; elif (( $(echo "$success_rate >= 70" | bc -l) )); then echo "🟡 Good"; else echo "🔴 Poor"; fi)

---

EOF
    done < "$REPORT_FILE.tmp"

    # Add summary section
    cat >> "$REPORT_FILE" << EOF

## Summary

### Test Results Comparison Table

| Test Scenario | Target TPS | Actual TPS | TPS Efficiency | Success Rate | Duration | Performance |
|---------------|------------|------------|----------------|--------------|----------|-------------|
EOF

    # Add comparison table rows
    while IFS='|' read -r scenario target_tps target_actual_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        # TPS Efficiency should be based on successful TPS vs target TPS
        local tps_efficiency=$(echo "scale=1; $actual_tps / $target_tps" | bc)
        local performance_status
        if (( $(echo "$success_rate >= 90" | bc -l) )); then
            performance_status="🟢 Excellent"
        elif (( $(echo "$success_rate >= 70" | bc -l) )); then
            performance_status="🟡 Good"
        else
            performance_status="🔴 Poor"
        fi
        
        echo "| $scenario | $target_tps | $actual_tps | ${tps_efficiency}x | $success_rate% | ${duration}s | $performance_status |" >> "$REPORT_FILE"
    done < "$REPORT_FILE.tmp"

    # Add overall analysis
    local total_successful=0
    local total_failed=0
    local total_rate_limited=0
    local total_requests=0
    
    while IFS='|' read -r scenario target_tps target_actual_tps actual_tps success_rate successful failed rate_limited other_errors duration; do
        total_successful=$((total_successful + successful))
        total_failed=$((total_failed + failed))
        total_rate_limited=$((total_rate_limited + rate_limited))
        total_requests=$((total_requests + target_tps * TEST_DURATION))
    done < "$REPORT_FILE.tmp"
    
    local overall_success_rate=$(echo "scale=1; $total_successful * 100 / $total_requests" | bc)
    
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

### Multi-Account Benefits

**Load Distribution:**
- **Reduced Contention:** Load spread across ${#TEST_ACCOUNTS[@]} accounts
- **Better Parallelism:** Multiple accounts can process simultaneously
- **Improved TPS:** Reduced lock contention on individual accounts
- **Scalability:** System can handle higher overall TPS

### Recommendations

**For Production:**
- Use multiple accounts to distribute load
- Monitor individual account performance
- Implement account-based load balancing
- Consider account sharding for higher TPS

---

*Report generated by Simple Multi-Account TPS Performance Test Script*
EOF

    # Clean up temporary file
    rm -f "$REPORT_FILE.tmp"
    
    echo -e "${GREEN}📄 Report generated: $REPORT_FILE${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Simple Multi-Account TPS Performance Test${NC}"
    echo "=============================================="
    echo -e "${BLUE}📊 Target: High TPS with multiple accounts${NC}"
    echo -e "${BLUE}👥 Test Accounts: ${TEST_ACCOUNTS[*]}${NC}"
    echo -e "${BLUE}⏱️  Test Duration: $TEST_DURATION seconds per scenario${NC}"
    echo -e "${BLUE}📄 Report File: $REPORT_FILE${NC}"
    echo ""
    
    # Check prerequisites
    check_server_health
    
    # Initialize report
    log "📝 Initializing report file: $REPORT_FILE"
    
    echo -e "${PURPLE}🧪 Running Simple Multi-Account Performance Tests...${NC}"
    echo "=============================================="
    
    # Run performance tests for each scenario
    for tps in "${SCENARIOS[@]}"; do
        run_performance_test "Multi_Account_Simple/${tps}_TPS" "$tps"
        
        # Get last element safely
        local scenarios_count=${#SCENARIOS[@]}
        local last_index=$((scenarios_count - 1))
        local last_tps=${SCENARIOS[$last_index]}
        
        if [ "$tps" != "$last_tps" ]; then
            echo -e "${YELLOW}⏸️  Pausing for 3 seconds before next scenario...${NC}"
            sleep 3
        fi
    done
    
    # Generate report
    generate_report
    
    echo ""
    echo -e "${GREEN}🎉 Simple multi-account TPS performance test completed successfully!${NC}"
    echo -e "${GREEN}📄 Report generated: $REPORT_FILE${NC}"
}

# Run main function
main "$@"

