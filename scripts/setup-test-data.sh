#!/bin/bash

# Setup Test Data Script
# Creates test accounts and initial balances for TPS testing

set -e

# Configuration
BASE_URL="http://localhost:8080/api/v1"
TEST_ACCOUNTS=("ACC001" "ACC002" "ACC003")
INITIAL_BALANCE="1000000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Test Data Setup Script${NC}"
echo "=========================="
echo "Base URL: $BASE_URL"
echo "Test Accounts: ${TEST_ACCOUNTS[*]}"
echo "Initial Balance: $INITIAL_BALANCE"
echo ""

# Function to check if server is running
check_server() {
    echo -e "${BLUE}🔍 Checking server availability...${NC}"
    
    if ! curl -s "$BASE_URL/health" > /dev/null; then
        echo -e "${RED}❌ Server is not running at $BASE_URL${NC}"
        echo ""
        echo -e "${YELLOW}💡 To start the server, run:${NC}"
        echo "  ./scripts/run-with-config.sh"
        exit 1
    fi
    echo -e "${GREEN}✅ Server is running and responding${NC}"
}

# Function to create test account with initial balance
create_test_account() {
    local account_id=$1
    local balance=$2
    
    echo -e "${YELLOW}📝 Creating test account: $account_id${NC}"
    
    # Check if account already exists
    local existing_balance=$(curl -s "$BASE_URL/balance/$account_id" | jq -r '.settled_balance // "0"' 2>/dev/null || echo "0")
    
    if [ "$existing_balance" != "0" ] && [ "$existing_balance" != "null" ]; then
        echo -e "${YELLOW}⚠️  Account $account_id already exists with balance: $existing_balance${NC}"
        
        # Ask if user wants to reset balance
        read -p "Do you want to reset the balance to $balance? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}ℹ️  Skipping account $account_id${NC}"
            return 0
        fi
    fi
    
    # Create account by sending a credit transaction
    echo "  Sending credit transaction..."
    local response=$(curl -s -X POST "$BASE_URL/transaction" \
        -H "Content-Type: application/json" \
        -d "{\"account_id\":\"$account_id\",\"amount\":\"$balance\",\"type\":\"credit\"}" 2>/dev/null)
    
    local success=$(echo "$response" | jq -r '.success // false')
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ Account $account_id created successfully${NC}"
        
        # Wait for settlement
        echo "  Waiting for settlement..."
        sleep 3
        
        # Verify balance
        local final_balance=$(curl -s "$BASE_URL/balance/$account_id" | jq -r '.settled_balance // "0"')
        echo "  Final balance: $final_balance"
    else
        echo -e "${RED}❌ Failed to create account $account_id${NC}"
        echo "  Response: $response"
        return 1
    fi
}

# Function to show account status
show_account_status() {
    local account_id=$1
    
    echo -e "${BLUE}📊 Account Status: $account_id${NC}"
    
    local account_info=$(curl -s "$BASE_URL/balance/$account_id" 2>/dev/null || echo "{}")
    
    if [ "$account_info" != "{}" ]; then
        echo "  Settled Balance: $(echo "$account_info" | jq -r '.settled_balance // "0"')"
        echo "  Pending Debit: $(echo "$account_info" | jq -r '.pending_debit // "0"')"
        echo "  Pending Credit: $(echo "$account_info" | jq -r '.pending_credit // "0"')"
        echo "  Available Balance: $(echo "$account_info" | jq -r '.available_balance // "0"')"
    else
        echo -e "${RED}  Account not found${NC}"
    fi
}

# Function to show all accounts status
show_all_accounts_status() {
    echo ""
    echo -e "${BLUE}📋 All Test Accounts Status${NC}"
    echo "============================="
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        show_account_status "$account"
        echo ""
    done
}

# Function to cleanup test data
cleanup_test_data() {
    echo -e "${YELLOW}🧹 Cleaning up test data...${NC}"
    
    for account in "${TEST_ACCOUNTS[@]}"; do
        echo "  Cleaning account: $account"
        # Note: In a real scenario, you might want to implement account deletion
        # For now, we'll just show a message
        echo "    (Account cleanup not implemented - accounts will remain)"
    done
    
    echo -e "${GREEN}✅ Test data cleanup completed${NC}"
}

# Function to show help
show_help() {
    echo "Test Data Setup Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  create     Create test accounts with initial balance"
    echo "  status     Show status of all test accounts"
    echo "  cleanup    Clean up test data (not implemented)"
    echo "  help       Show this help message"
    echo ""
    echo "Options:"
    echo "  -a, --account  Specific account ID to create/check"
    echo "  -b, --balance  Initial balance amount (default: 1000000)"
    echo "  -u, --url      Base URL (default: http://localhost:8080/api/v1)"
    echo ""
    echo "Examples:"
    echo "  $0 create                    # Create all test accounts"
    echo "  $0 create -a ACC001         # Create specific account"
    echo "  $0 status                   # Show all accounts status"
    echo "  $0 create -b 2000000        # Create with different balance"
    echo ""
}

# Parse command line arguments
COMMAND="create"
SPECIFIC_ACCOUNT=""
BALANCE="$INITIAL_BALANCE"

while [[ $# -gt 0 ]]; do
    case $1 in
        create|status|cleanup|help)
            COMMAND="$1"
            shift
            ;;
        -a|--account)
            SPECIFIC_ACCOUNT="$2"
            shift 2
            ;;
        -b|--balance)
            BALANCE="$2"
            shift 2
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
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
    case $COMMAND in
        create)
            check_server
            
            if [ -n "$SPECIFIC_ACCOUNT" ]; then
                echo -e "${BLUE}Creating specific account: $SPECIFIC_ACCOUNT${NC}"
                create_test_account "$SPECIFIC_ACCOUNT" "$BALANCE"
            else
                echo -e "${BLUE}Creating all test accounts...${NC}"
                for account in "${TEST_ACCOUNTS[@]}"; do
                    create_test_account "$account" "$BALANCE"
                    echo ""
                done
            fi
            
            echo ""
            show_all_accounts_status
            ;;
            
        status)
            check_server
            show_all_accounts_status
            ;;
            
        cleanup)
            cleanup_test_data
            ;;
            
        help)
            show_help
            ;;
            
        *)
            echo "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
