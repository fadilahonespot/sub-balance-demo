#!/bin/bash

# =====================================================
# Simple Multi-Account Setup Script
# =====================================================
# This script sets up 5 test accounts by creating new ones
# with different names to avoid conflicts
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8080"
TEST_ACCOUNTS=("MULTI001" "MULTI002" "MULTI003" "MULTI004" "MULTI005")
INITIAL_BALANCE="10000000"  # 10 million per account

# Function to log messages
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# Function to create account
create_account() {
    local account_id="$1"
    local target_balance="$2"
    
    echo -e "${CYAN}📝 Creating account: $account_id${NC}"
    
    # Create account
    local create_response=$(curl -s -X POST "$BASE_URL/test/accounts" \
        -H "Content-Type: application/json" \
        -d "{\"account_id\":\"$account_id\",\"balance\":\"$target_balance\"}" 2>/dev/null)
    
    local success=$(echo "$create_response" | jq -r '.success // false')
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ Account $account_id created with balance: $target_balance${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to create account $account_id${NC}"
        echo "Response: $create_response"
        return 1
    fi
}

# Function to verify all accounts
verify_accounts() {
    log "🔍 Verifying all accounts..."
    
    local total_balance=0
    local all_good=true
    
    echo -e "${CYAN}📊 Account Summary:${NC}"
    echo "=================="
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        local balance=$(get_balance "$account")
        total_balance=$((total_balance + balance))
        
        if [ "$balance" -ge "$INITIAL_BALANCE" ]; then
            echo -e "${GREEN}✅ $account: $balance${NC}"
        else
            echo -e "${RED}❌ $account: $balance (insufficient)${NC}"
            all_good=false
        fi
    done
    
    echo "=================="
    echo -e "${CYAN}Total Balance: $total_balance${NC}"
    
    if [ "$all_good" = true ]; then
        echo -e "${GREEN}🎉 All accounts are ready for testing!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some accounts need attention${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Simple Multi-Account Setup Script${NC}"
    echo "======================================"
    echo -e "${BLUE}👥 Creating ${#TEST_ACCOUNTS[@]} new test accounts${NC}"
    echo -e "${BLUE}💰 Initial balance per account: $INITIAL_BALANCE${NC}"
    echo -e "${BLUE}📊 Total balance: $((INITIAL_BALANCE * ${#TEST_ACCOUNTS[@]}))${NC}"
    echo ""
    
    # Check prerequisites
    check_server_health
    
    # Create all accounts
    log "🔧 Creating all accounts..."
    for account in "${TEST_ACCOUNTS[@]}"; do
        create_account "$account" "$INITIAL_BALANCE"
        echo ""
    done
    
    # Verify setup
    echo ""
    verify_accounts
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 Multi-account setup completed successfully!${NC}"
        echo -e "${GREEN}✅ Ready for multi-account TPS testing${NC}"
        echo ""
        echo -e "${BLUE}💡 Next steps:${NC}"
        echo "1. Update test script to use these accounts: ${TEST_ACCOUNTS[*]}"
        echo "2. Run multi-account TPS test"
        echo "3. Monitor individual account performance"
        echo "4. Check balance integrity across all accounts"
        echo ""
        echo -e "${YELLOW}📝 Account List:${NC}"
        for account in "${TEST_ACCOUNTS[@]}"; do
            echo "   - $account"
        done
    else
        echo ""
        echo -e "${RED}❌ Multi-account setup completed with issues${NC}"
        echo -e "${YELLOW}💡 Please check the accounts and try again${NC}"
        exit 1
    fi
}

# Run main function
main "$@"

