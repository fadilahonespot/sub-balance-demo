#!/bin/bash

# =====================================================
# Multi-Account Setup Script
# =====================================================
# This script sets up 5 test accounts with sufficient balance
# for multi-account TPS testing
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
TEST_ACCOUNTS=("ACC001" "ACC002" "ACC003" "ACC004" "ACC005")
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

# Function to create or update account
setup_account() {
    local account_id="$1"
    local target_balance="$2"
    
    echo -e "${CYAN}📝 Setting up account: $account_id${NC}"
    
    # Check if account exists
    local current_balance=$(get_balance "$account_id")
    
    # Check if account exists by trying to get balance
    local balance_response=$(curl -s "$BASE_URL/api/v1/balance/$account_id" 2>/dev/null || echo "{}")
    local account_exists=$(echo "$balance_response" | jq -r '.account_id // empty')
    
    if [ -z "$account_exists" ]; then
        echo -e "${YELLOW}⚠️  Account $account_id doesn't exist, creating...${NC}"
        
        # Create account
        local create_response=$(curl -s -X POST "$BASE_URL/test/accounts" \
            -H "Content-Type: application/json" \
            -d "{\"account_id\":\"$account_id\",\"balance\":\"$target_balance\"}" 2>/dev/null)
        
        local success=$(echo "$create_response" | jq -r '.success // false')
        
        if [ "$success" = "true" ]; then
            echo -e "${GREEN}✅ Account $account_id created with balance: $target_balance${NC}"
        else
            echo -e "${RED}❌ Failed to create account $account_id${NC}"
            echo "Response: $create_response"
            return 1
        fi
    else
        echo -e "${GREEN}✅ Account $account_id exists with balance: $current_balance${NC}"
        
        # Check if balance is sufficient
        if [ "$current_balance" -lt "$target_balance" ]; then
            echo -e "${YELLOW}⚠️  Balance insufficient. Current: $current_balance, Required: $target_balance${NC}"
            echo -e "${YELLOW}💡 Adding credit to reach required balance...${NC}"
            
            local credit_needed=$((target_balance - current_balance))
            local credit_response=$(curl -s -X POST "$BASE_URL/api/v1/transaction" \
                -H "Content-Type: application/json" \
                -d "{\"account_id\":\"$account_id\",\"amount\":\"$credit_needed\",\"type\":\"credit\"}" 2>/dev/null)
            
            local credit_success=$(echo "$credit_response" | jq -r '.success // false')
            
            if [ "$credit_success" = "true" ]; then
                echo -e "${GREEN}✅ Added credit: $credit_needed${NC}"
                sleep 2  # Wait for settlement
                local new_balance=$(get_balance "$account_id")
                echo -e "${GREEN}✅ New balance: $new_balance${NC}"
            else
                echo -e "${RED}❌ Failed to add credit${NC}"
                echo "Response: $credit_response"
                return 1
            fi
        else
            echo -e "${GREEN}✅ Balance is already sufficient: $current_balance${NC}"
        fi
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

# Function to reset all accounts
reset_accounts() {
    log "🔄 Resetting all accounts..."
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        echo -e "${YELLOW}🔄 Resetting account: $account${NC}"
        
        # Get current balance
        local current_balance=$(get_balance "$account")
        
        if [ "$current_balance" != "0" ] && [ "$current_balance" != "null" ]; then
            # Reset to target balance by adding credit if needed
            if [ "$current_balance" -lt "$INITIAL_BALANCE" ]; then
                local credit_needed=$((INITIAL_BALANCE - current_balance))
                echo -e "${YELLOW}💡 Adding credit: $credit_needed${NC}"
                
                local credit_response=$(curl -s -X POST "$BASE_URL/api/v1/transaction" \
                    -H "Content-Type: application/json" \
                    -d "{\"account_id\":\"$account\",\"amount\":\"$credit_needed\",\"type\":\"credit\"}" 2>/dev/null)
                
                local credit_success=$(echo "$credit_response" | jq -r '.success // false')
                
                if [ "$credit_success" = "true" ]; then
                    echo -e "${GREEN}✅ Credit added successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to add credit${NC}"
                fi
            else
                echo -e "${GREEN}✅ Balance is already sufficient${NC}"
            fi
        else
            # Create account if it doesn't exist
            setup_account "$account" "$INITIAL_BALANCE"
        fi
        
        sleep 1  # Small delay between accounts
    done
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Multi-Account Setup Script${NC}"
    echo "=================================="
    echo -e "${BLUE}👥 Setting up ${#TEST_ACCOUNTS[@]} test accounts${NC}"
    echo -e "${BLUE}💰 Initial balance per account: $INITIAL_BALANCE${NC}"
    echo -e "${BLUE}📊 Total balance: $((INITIAL_BALANCE * ${#TEST_ACCOUNTS[@]}))${NC}"
    echo ""
    
    # Check prerequisites
    check_server_health
    
    # Parse command line arguments
    case "${1:-setup}" in
        "setup")
            log "🔧 Setting up all accounts..."
            for account in "${TEST_ACCOUNTS[@]}"; do
                setup_account "$account" "$INITIAL_BALANCE"
                echo ""
            done
            ;;
        "reset")
            log "🔄 Resetting all accounts..."
            reset_accounts
            ;;
        "verify")
            log "🔍 Verifying all accounts..."
            verify_accounts
            exit $?
            ;;
        "status")
            log "📊 Checking account status..."
            verify_accounts
            exit $?
            ;;
        *)
            echo "Usage: $0 {setup|reset|verify|status}"
            echo ""
            echo "Commands:"
            echo "  setup  - Create and setup all accounts (default)"
            echo "  reset  - Reset all accounts to initial balance"
            echo "  verify - Verify all accounts are ready"
            echo "  status - Show current status of all accounts"
            exit 1
            ;;
    esac
    
    # Verify setup
    echo ""
    verify_accounts
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 Multi-account setup completed successfully!${NC}"
        echo -e "${GREEN}✅ Ready for multi-account TPS testing${NC}"
        echo ""
        echo -e "${BLUE}💡 Next steps:${NC}"
        echo "1. Run multi-account TPS test: make test-multi"
        echo "2. Monitor individual account performance"
        echo "3. Check balance integrity across all accounts"
    else
        echo ""
        echo -e "${RED}❌ Multi-account setup completed with issues${NC}"
        echo -e "${YELLOW}💡 Please check the accounts and try again${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
