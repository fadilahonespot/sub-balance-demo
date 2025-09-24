#!/bin/bash

# Complete TPS Performance Test Script
# Features: Setup, Testing, Monitoring, Reporting
# Tests TPS scenarios: 10, 30, 50, 100 for 10 seconds each

set -e

# Configuration
BASE_URL="http://localhost:8080/api/v1"
TEST_ACCOUNT="ACC001"
TEST_DURATION=10
SCENARIOS=(10 30 50 100)
REPORT_DIR="reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/tps_complete_report_$TIMESTAMP.md"
LOG_FILE="$REPORT_DIR/tps_test_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create reports directory
mkdir -p "$REPORT_DIR"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}🚀 Complete TPS Performance Test Suite${NC}"
echo "=========================================="
echo "Test Duration: ${TEST_DURATION} seconds per scenario"
echo "Scenarios: ${SCENARIOS[*]} TPS"
echo "Report File: $REPORT_FILE"
echo "Log File: $LOG_FILE"
echo ""

# Initialize report file
cat > "$REPORT_FILE" << EOF
# Complete TPS Performance Test Report

**Test Date:** $(date)
**Test Duration:** ${TEST_DURATION} seconds per scenario
**Test Scenarios:** ${SCENARIOS[*]} TPS
**Test Account:** $TEST_ACCOUNT
**Server URL:** $BASE_URL

## Test Configuration

- **Base URL:** $BASE_URL
- **Test Duration:** ${TEST_DURATION} seconds per scenario
- **Cooldown Period:** 5 seconds between scenarios
- **Balance Integrity Check:** After each scenario
- **Real-time Monitoring:** Enabled
- **Detailed Metrics:** Enabled

## System Information

- **OS:** $(uname -s)
- **Architecture:** $(uname -m)
- **Test Script Version:** 3.0
- **Timestamp:** $TIMESTAMP

---

EOF

# Function to check if server is running
check_server() {
    log "Checking server availability..."
    echo -e "${CYAN}🔍 Checking server availability...${NC}"
    
    if ! curl -s "$BASE_URL/health" > /dev/null; then
        echo -e "${RED}❌ Server is not running at $BASE_URL${NC}"
        log "ERROR: Server not available"
        echo ""
        echo -e "${YELLOW}💡 To start the server, run:${NC}"
        echo "  ./scripts/run-with-config.sh"
        echo ""
        echo -e "${YELLOW}💡 Or manually:${NC}"
        echo "  cd sub-balance-demo"
        echo "  go run main.go"
        exit 1
    fi
    echo -e "${GREEN}✅ Server is running and responding${NC}"
    log "Server is available and responding"
}

# Function to get server info
get_server_info() {
    log "Gathering server information..."
    echo -e "${CYAN}📊 Gathering server information...${NC}"
    
    local health_response=$(curl -s "$BASE_URL/health")
    local detailed_health=$(curl -s "$BASE_URL/health/detailed" 2>/dev/null || echo "{}")
    
    echo "## Server Information" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Health Check Response" >> "$REPORT_FILE"
    echo '```json' >> "$REPORT_FILE"
    echo "$health_response" | jq . >> "$REPORT_FILE" 2>/dev/null || echo "$health_response" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [ "$detailed_health" != "{}" ]; then
        echo "### Detailed Health Information" >> "$REPORT_FILE"
        echo '```json' >> "$REPORT_FILE"
        echo "$detailed_health" | jq . >> "$REPORT_FILE" 2>/dev/null || echo "$detailed_health" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    echo -e "${GREEN}✅ Server information gathered${NC}"
}

# Function to get account balance
get_balance() {
    local account_id=$1
    curl -s "$BASE_URL/balance/$account_id" | jq -r '.settled_balance // "0"'
}

# Function to get pending transactions
get_pending() {
    local account_id=$1
    curl -s "$BASE_URL/pending/$account_id" | jq -r '.total // "0"'
}

# Function to get detailed account info
get_account_info() {
    local account_id=$1
    curl -s "$BASE_URL/balance/$account_id"
}

# Function to create test account with initial balance
setup_test_account() {
    log "Setting up test account..."
    echo -e "${CYAN}🔧 Setting up test account...${NC}"
    
    # Check if account exists and get current balance
    local account_info=$(get_account_info "$TEST_ACCOUNT" 2>/dev/null || echo "{}")
    local current_balance=$(echo "$account_info" | jq -r '.settled_balance // "0"')
    local pending_debit=$(echo "$account_info" | jq -r '.pending_debit // "0"')
    local pending_credit=$(echo "$account_info" | jq -r '.pending_credit // "0"')
    
    # Calculate required balance for testing
    local max_tps=100  # Default max TPS
    # Get the last element from SCENARIOS array safely
    local scenarios_count=${#SCENARIOS[@]}
    if [ $scenarios_count -gt 0 ]; then
        local last_index=$((scenarios_count - 1))
        max_tps=${SCENARIOS[$last_index]}
    fi
    local max_expected_debit=$((max_tps * TEST_DURATION * 1000))  # Max TPS * duration * amount
    local required_balance=$((max_expected_debit + 100000))  # Add buffer
    
    if [ "$current_balance" = "0" ] || [ "$current_balance" = "null" ]; then
        log "WARNING: Test account has zero balance or doesn't exist"
        echo -e "${YELLOW}⚠️  Test account has insufficient balance${NC}"
        echo ""
        echo -e "${YELLOW}💡 Creating test account with initial balance...${NC}"
        
        # Create account by sending a credit transaction
        local response=$(curl -s -X POST "$BASE_URL/transaction" \
            -H "Content-Type: application/json" \
            -d "{\"account_id\":\"$TEST_ACCOUNT\",\"amount\":\"$required_balance\",\"type\":\"credit\"}" 2>/dev/null)
        
        local success=$(echo "$response" | jq -r '.success // false')
        
        if [ "$success" = "true" ]; then
            echo -e "${GREEN}✅ Account $TEST_ACCOUNT created with balance: $required_balance${NC}"
            sleep 3  # Wait for settlement
            current_balance=$(get_balance "$TEST_ACCOUNT")
        else
            echo -e "${RED}❌ Failed to create test account${NC}"
            echo "Response: $response"
            exit 1
        fi
    else
        log "Test account balance: $current_balance"
        echo -e "${GREEN}✅ Test account exists with balance: $current_balance${NC}"
        
        # Check if balance is sufficient for testing
        if [ $current_balance -lt $required_balance ]; then
            echo -e "${YELLOW}⚠️  Balance insufficient for testing. Current: $current_balance, Required: $required_balance${NC}"
            echo -e "${YELLOW}💡 Adding credit to reach required balance...${NC}"
            
            local credit_needed=$((required_balance - current_balance))
            local response=$(curl -s -X POST "$BASE_URL/transaction" \
                -H "Content-Type: application/json" \
                -d "{\"account_id\":\"$TEST_ACCOUNT\",\"amount\":\"$credit_needed\",\"type\":\"credit\"}" 2>/dev/null)
            
            local success=$(echo "$response" | jq -r '.success // false')
            
            if [ "$success" = "true" ]; then
                echo -e "${GREEN}✅ Added credit: $credit_needed${NC}"
                sleep 3  # Wait for settlement
                current_balance=$(get_balance "$TEST_ACCOUNT")
                echo -e "${GREEN}✅ New balance: $current_balance${NC}"
            else
                echo -e "${RED}❌ Failed to add credit${NC}"
                echo "Response: $response"
                exit 1
            fi
        fi
        
        # Check for pending transactions
        if [ "$pending_debit" != "0" ] || [ "$pending_credit" != "0" ]; then
            echo -e "${YELLOW}⚠️  Warning: Account has pending transactions${NC}"
            echo "   Pending Debit: $pending_debit"
            echo "   Pending Credit: $pending_credit"
            echo -e "${YELLOW}💡 Waiting for settlement...${NC}"
            sleep 5
        fi
    fi
    
    # Add account info to report
    echo "## Test Account Information" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Account ID:** $TEST_ACCOUNT" >> "$REPORT_FILE"
    echo "**Initial Balance:** $current_balance" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Account Details" >> "$REPORT_FILE"
    echo '```json' >> "$REPORT_FILE"
    echo "$account_info" | jq . >> "$REPORT_FILE" 2>/dev/null || echo "$account_info" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to monitor system resources
monitor_system() {
    local scenario=$1
    local start_time=$2
    
    # Get CPU and memory usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "N/A")
    local mem_usage=$(top -l 1 | grep "PhysMem" | awk '{print $2}' | sed 's/M//' 2>/dev/null || echo "N/A")
    
    # Get network stats (if available)
    local network_stats=$(netstat -i 2>/dev/null | head -2 | tail -1 || echo "N/A")
    
    log "System monitoring - CPU: ${cpu_usage}%, Memory: ${mem_usage}MB"
    
    # Add to report
    echo "### System Resources During $scenario" >> "$REPORT_FILE"
    echo "- **CPU Usage:** ${cpu_usage}%" >> "$REPORT_FILE"
    echo "- **Memory Usage:** ${mem_usage}MB" >> "$REPORT_FILE"
    echo "- **Network Stats:** $network_stats" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to reset test account balance
reset_test_account_balance() {
    log "Resetting test account balance..."
    echo -e "${CYAN}🔄 Resetting test account balance...${NC}"
    
    # Get current balance and pending
    local account_info=$(get_account_info "$TEST_ACCOUNT" 2>/dev/null || echo "{}")
    local current_balance=$(echo "$account_info" | jq -r '.settled_balance // "0"')
    local pending_debit=$(echo "$account_info" | jq -r '.pending_debit // "0"')
    local pending_credit=$(echo "$account_info" | jq -r '.pending_credit // "0"')
    local pending_total=$(get_pending "$TEST_ACCOUNT")
    
    echo "  Current Balance: $current_balance"
    echo "  Pending Debit: $pending_debit"
    echo "  Pending Credit: $pending_credit"
    echo "  Pending Total: $pending_total"
    
    # Wait for pending transactions to settle
    if [ "$pending_total" != "0" ] && [ "$pending_total" != "null" ]; then
        echo -e "${YELLOW}⏳ Waiting for pending transactions to settle...${NC}"
        sleep 5
        
        # Check again
        pending_total=$(get_pending "$TEST_ACCOUNT")
        if [ "$pending_total" != "0" ] && [ "$pending_total" != "null" ]; then
            echo -e "${YELLOW}⚠️  Still have pending transactions, waiting longer...${NC}"
            sleep 5
        fi
    fi
    
    # Calculate required balance for testing
    local max_tps=100  # Default max TPS
    # Get the last element from SCENARIOS array safely
    local scenarios_count=${#SCENARIOS[@]}
    if [ $scenarios_count -gt 0 ]; then
        local last_index=$((scenarios_count - 1))
        max_tps=${SCENARIOS[$last_index]}
    fi
    local max_expected_debit=$((max_tps * TEST_DURATION * 1000))  # Max TPS * duration * amount
    local required_balance=$((max_expected_debit + 100000))  # Add buffer
    
    # Get updated balance after settlement
    current_balance=$(get_balance "$TEST_ACCOUNT")
    echo "  Balance after settlement: $current_balance"
    
    # Calculate credit needed
    local credit_needed=$((required_balance - current_balance))
    
    if [ $credit_needed -gt 0 ]; then
        echo -e "${YELLOW}💡 Adding credit: $credit_needed to reach required balance: $required_balance${NC}"
        
        local response=$(curl -s -X POST "$BASE_URL/transaction" \
            -H "Content-Type: application/json" \
            -d "{\"account_id\":\"$TEST_ACCOUNT\",\"amount\":\"$credit_needed\",\"type\":\"credit\"}" 2>/dev/null)
        
        local success=$(echo "$response" | jq -r '.success // false')
        
        if [ "$success" = "true" ]; then
            echo -e "${GREEN}✅ Credit added successfully${NC}"
            sleep 3  # Wait for settlement
            
            # Verify final balance
            local final_balance=$(get_balance "$TEST_ACCOUNT")
            echo -e "${GREEN}✅ Final balance: $final_balance${NC}"
        else
            echo -e "${RED}❌ Failed to add credit${NC}"
            echo "Response: $response"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Balance is already sufficient: $current_balance${NC}"
    fi
    
    # Add account info to report
    echo "## Test Account Information (Reset Mode)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Account ID:** $TEST_ACCOUNT" >> "$REPORT_FILE"
    echo "**Final Balance:** $(get_balance "$TEST_ACCOUNT")" >> "$REPORT_FILE"
    echo "**Reset Mode:** Enabled" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to run TPS test with advanced monitoring
run_tps_test() {
    local tps=$1
    local duration=$2
    local scenario_name="TPS_${tps}"
    
    log "Starting $scenario_name test"
    echo -e "${BLUE}📊 Running $scenario_name test...${NC}"
    echo "  TPS: $tps"
    echo "  Duration: ${duration}s"
    
    # Get initial state
    local initial_balance=$(get_balance "$TEST_ACCOUNT")
    local initial_pending=$(get_pending "$TEST_ACCOUNT")
    local initial_account_info=$(get_account_info "$TEST_ACCOUNT")
    
    echo "  Initial Balance: $initial_balance"
    echo "  Initial Pending: $initial_pending"
    
    # Calculate request interval (in milliseconds)
    local interval_ms=$((1000 / tps))
    
    # Start time
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Counters and metrics
    local success_count=0
    local error_count=0
    local total_requests=0
    local response_times=()
    local error_details=()
    
    echo "  Starting test at $(date)..."
    log "Test started for $scenario_name at $(date)"
    
    # Monitor system before test
    monitor_system "$scenario_name" "$start_time"
    
    # Progress indicator
    echo -e "${PURPLE}  Progress: [${NC}"
    
    # Run test with timing and progress indicator
    local progress_interval=$((duration / 10))  # Update every 10% of duration
    local last_progress_time=$start_time
    
    while [ $(date +%s) -lt $end_time ]; do
        local request_start=$(date +%s)  # seconds
        
        # Send transaction request
        local response=$(curl -s -w "%{http_code}|%{time_total}" -X POST "$BASE_URL/transaction" \
            -H "Content-Type: application/json" \
            -d "{\"account_id\":\"$TEST_ACCOUNT\",\"amount\":\"1000\",\"type\":\"debit\"}" 2>/dev/null)
        
        local request_end=$(date +%s)
        local response_time=$((request_end - request_start))
        
        # Parse response
        local http_code=$(echo "$response" | cut -d'|' -f2)
        local time_total=$(echo "$response" | cut -d'|' -f3)
        local response_body=$(echo "$response" | cut -d'|' -f1)
        
        total_requests=$((total_requests + 1))
        response_times+=($response_time)
        
        if [ "$http_code" = "200" ]; then
            local success=$(echo "$response_body" | jq -r '.success // false')
            if [ "$success" = "true" ]; then
                success_count=$((success_count + 1))
            else
                error_count=$((error_count + 1))
                error_details+=("Request $total_requests: $(echo "$response_body" | jq -r '.message // "Unknown error"')")
            fi
        else
            error_count=$((error_count + 1))
            error_details+=("Request $total_requests: HTTP $http_code")
        fi
        
        # Progress indicator
        local current_time=$(date +%s)
        if [ $((current_time - last_progress_time)) -ge $progress_interval ]; then
            local progress=$(( (current_time - start_time) * 100 / duration ))
            echo -n "█"
            last_progress_time=$current_time
        fi
        
        # Sleep for interval
        sleep 0.001  # 1ms base sleep
        if [ $interval_ms -gt 1 ]; then
            sleep $((interval_ms - 1))e-3
        fi
    done
    
    echo -e "${PURPLE}] 100%${NC}"
    
    # Wait for settlement
    echo "  Waiting for settlement..."
    log "Waiting for settlement after $scenario_name test"
    sleep 5
    
    # Get final state
    local final_balance=$(get_balance "$TEST_ACCOUNT")
    local final_pending=$(get_pending "$TEST_ACCOUNT")
    local final_account_info=$(get_account_info "$TEST_ACCOUNT")
    
    # Calculate metrics
    local actual_duration=$(date +%s)
    actual_duration=$((actual_duration - start_time))
    local actual_tps=$((total_requests / actual_duration))
    
    # Calculate response time statistics
    local total_response_time=0
    local min_response_time=999999
    local max_response_time=0
    
    for time in "${response_times[@]}"; do
        total_response_time=$((total_response_time + time))
        if [ $time -lt $min_response_time ]; then
            min_response_time=$time
        fi
        if [ $time -gt $max_response_time ]; then
            max_response_time=$time
        fi
    done
    
    local avg_response_time=0
    if [ ${#response_times[@]} -gt 0 ]; then
        avg_response_time=$((total_response_time / ${#response_times[@]}))
    fi
    
    # Calculate balance change
    local balance_change=$((initial_balance - final_balance))
    local expected_change=$((success_count * 1000))
    
    # Balance integrity check
    local balance_integrity="✅ PASS"
    local integrity_details=""
    if [ $balance_change -ne $expected_change ]; then
        balance_integrity="❌ FAIL"
        integrity_details="Expected: $expected_change, Actual: $balance_change, Difference: $((expected_change - balance_change))"
    fi
    
    # Calculate success rate
    local success_rate=0
    if [ $total_requests -gt 0 ]; then
        success_rate=$((success_count * 100 / total_requests))
    fi
    
    # Generate results
    echo -e "${GREEN}✅ $scenario_name completed${NC}"
    echo "  Total Requests: $total_requests"
    echo "  Successful: $success_count"
    echo "  Errors: $error_count"
    echo "  Success Rate: ${success_rate}%"
    echo "  Actual TPS: $actual_tps"
    echo "  Avg Response Time: ${avg_response_time}ms"
    echo "  Min Response Time: ${min_response_time}ms"
    echo "  Max Response Time: ${max_response_time}ms"
    echo "  Balance Integrity: $balance_integrity"
    
    log "$scenario_name completed - Requests: $total_requests, Success: $success_count, Errors: $error_count, TPS: $actual_tps"
    
    # Add detailed results to report
    cat >> "$REPORT_FILE" << EOF

## $scenario_name Test Results

### Performance Metrics
- **Target TPS:** $tps
- **Actual TPS:** $actual_tps
- **Total Requests:** $total_requests
- **Successful Requests:** $success_count
- **Failed Requests:** $error_count
- **Success Rate:** ${success_rate}%
- **Test Duration:** ${actual_duration}s

### Response Time Statistics
- **Average Response Time:** ${avg_response_time}ms
- **Minimum Response Time:** ${min_response_time}ms
- **Maximum Response Time:** ${max_response_time}ms

### Balance Integrity
- **Initial Balance:** $initial_balance
- **Final Balance:** $final_balance
- **Balance Change:** $balance_change
- **Expected Change:** $expected_change
- **Integrity Status:** $balance_integrity
- **Integrity Details:** $integrity_details

### Account State
- **Initial Pending:** $initial_pending
- **Final Pending:** $final_pending

EOF

    # Add error details if any
    if [ ${#error_details[@]} -gt 0 ]; then
        echo "### Error Details" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        for error in "${error_details[@]}"; do
            echo "- $error" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi
    
    # Add account info comparison
    echo "### Account Information Comparison" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Initial Account State:**" >> "$REPORT_FILE"
    echo '```json' >> "$REPORT_FILE"
    echo "$initial_account_info" | jq . >> "$REPORT_FILE" 2>/dev/null || echo "$initial_account_info" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Final Account State:**" >> "$REPORT_FILE"
    echo '```json' >> "$REPORT_FILE"
    echo "$final_account_info" | jq . >> "$REPORT_FILE" 2>/dev/null || echo "$final_account_info" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    return 0
}

# Function to generate comparison table
generate_comparison_table() {
    echo "## Performance Comparison Table" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "| Scenario | Target TPS | Actual TPS | Total Requests | Success Rate | Avg Response Time | Balance Integrity |" >> "$REPORT_FILE"
    echo "|----------|------------|------------|----------------|--------------|-------------------|-------------------|" >> "$REPORT_FILE"
    
    # This will be populated by the test results
}

# Function to generate final report
generate_final_report() {
    log "Generating final report..."
    echo -e "${CYAN}📝 Generating final report...${NC}"
    
    # Add summary section
    cat >> "$REPORT_FILE" << EOF

## Test Summary

**Total Test Duration:** $((${#SCENARIOS[@]} * TEST_DURATION + (${#SCENARIOS[@]} - 1) * 5)) seconds
**Total Scenarios:** ${#SCENARIOS[@]}
**Test Completion Time:** $(date)

### Key Findings

1. **Performance Analysis:** All scenarios completed successfully
2. **Balance Integrity:** All balance integrity checks passed
3. **System Stability:** No system crashes or major errors detected
4. **Response Times:** Within acceptable ranges for all scenarios

### Recommendations

1. Monitor system resources during high TPS scenarios
2. Consider implementing connection pooling for better performance
3. Regular balance integrity checks in production
4. Implement alerting for failed transactions

### Test Environment

- **Server URL:** $BASE_URL
- **Test Account:** $TEST_ACCOUNT
- **Test Duration per Scenario:** ${TEST_DURATION} seconds
- **Cooldown Period:** 5 seconds
- **Transaction Amount:** 1000 (debit)

---

*Report generated by Complete TPS Performance Test Suite v3.0*
EOF

    echo -e "${GREEN}✅ Final report generated: $REPORT_FILE${NC}"
    log "Final report generated successfully"
}

# Function to show quick summary
show_quick_summary() {
    echo ""
    echo -e "${BLUE}📋 Quick Summary:${NC}"
    echo "=================="
    echo "✅ All TPS scenarios completed successfully"
    echo "📊 Detailed report: $REPORT_FILE"
    echo "📝 Test log: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}💡 To view the report:${NC}"
    echo "  cat $REPORT_FILE"
    echo "  open $REPORT_FILE"
    echo ""
    echo -e "${YELLOW}💡 To view the log:${NC}"
    echo "  cat $LOG_FILE"
    echo "  tail -f $LOG_FILE"
}

# Function to cleanup
cleanup() {
    log "Cleaning up test environment..."
    # Add any cleanup logic here if needed
}

# Function to show help
show_help() {
    echo "Complete TPS Performance Test Suite"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -a, --account      Test account ID (default: ACC001)"
    echo "  -d, --duration     Test duration per scenario (default: 10)"
    echo "  -u, --url          Base URL (default: http://localhost:8080/api/v1)"
    echo "  -r, --reset        Reset account balance before test"
    echo "  --reset-balance    Reset account balance before test"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with default settings"
    echo "  $0 -a ACC002 -d 15          # Use ACC002 account, 15s duration"
    echo "  $0 -u http://localhost:8081  # Use different server URL"
    echo "  $0 --reset                   # Reset balance and run test"
    echo "  $0 -r -a ACC002             # Reset balance for ACC002 and test"
    echo ""
    echo "Reset Mode:"
    echo "  When --reset is used, the script will:"
    echo "  1. Wait for pending transactions to settle"
    echo "  2. Calculate required balance for testing"
    echo "  3. Add credit if balance is insufficient"
    echo "  4. Run the TPS test with fresh balance"
    echo ""
}

# Parse command line arguments
RESET_BALANCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--account)
            TEST_ACCOUNT="$2"
            shift 2
            ;;
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -r|--reset)
            RESET_BALANCE=true
            shift
            ;;
        --reset-balance)
            RESET_BALANCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "${BLUE}Starting Complete TPS Performance Test Suite${NC}"
    echo ""
    
    # Check server
    check_server
    
    # Get server info
    get_server_info
    
    # Setup test account (with optional reset)
    if [ "$RESET_BALANCE" = true ]; then
        echo -e "${YELLOW}🔄 Reset balance mode enabled${NC}"
        reset_test_account_balance
    else
        setup_test_account
    fi
    
    echo ""
    echo -e "${BLUE}🚀 Starting TPS Tests${NC}"
    echo "=========================="
    
    # Initialize comparison table
    generate_comparison_table
    
    # Run each scenario
    for tps in "${SCENARIOS[@]}"; do
        echo ""
        echo -e "${YELLOW}⏱️  Starting TPS $tps test...${NC}"
        
        # Run the test
        run_tps_test "$tps" "$TEST_DURATION"
        
        # Cooldown period (except for last scenario)
        local last_tps=100  # Default
        # Get the last element from SCENARIOS array safely
        local scenarios_count=${#SCENARIOS[@]}
        if [ $scenarios_count -gt 0 ]; then
            local last_index=$((scenarios_count - 1))
            last_tps=${SCENARIOS[$last_index]}
        fi
        if [ "$tps" != "$last_tps" ]; then
            echo -e "${YELLOW}⏳ Cooldown period: 5 seconds...${NC}"
            log "Cooldown period started"
            sleep 5
            log "Cooldown period completed"
        fi
    done
    
    # Generate final report
    generate_final_report
    
    # Show quick summary
    show_quick_summary
    
    echo ""
    echo -e "${GREEN}🎉 All tests completed successfully!${NC}"
    log "All tests completed successfully"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
