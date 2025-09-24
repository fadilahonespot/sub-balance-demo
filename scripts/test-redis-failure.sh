#!/bin/bash

# Test script untuk Redis failure scenario

echo "🧪 Testing Redis Failure Scenario"
echo "================================="

BASE_URL="http://localhost:8080/api/v1"
ACCOUNT_ID="ACC001"

# Function untuk test API
test_api() {
    local endpoint=$1
    local method=$2
    local data=$3
    local description=$4
    
    echo "📋 $description"
    if [ "$method" = "POST" ]; then
        response=$(curl -s -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -X GET "$BASE_URL$endpoint")
    fi
    
    echo "Response: $response"
    echo ""
}

# Function untuk stop Redis
stop_redis() {
    echo "🛑 Stopping Redis..."
    docker-compose stop redis
    sleep 2
}

# Function untuk start Redis
start_redis() {
    echo "🔄 Starting Redis..."
    docker-compose start redis
    sleep 5
}

echo "1️⃣ Testing normal operation (Redis OK)"
echo "======================================"

# Test 1: Normal transaction
test_api "/transaction" "POST" '{
    "account_id": "'$ACCOUNT_ID'",
    "amount": 50000,
    "type": "DEBIT"
}' "Normal transaction with Redis"

# Check balance
test_api "/balance/$ACCOUNT_ID" "GET" "" "Check balance after transaction"

# Check pending
test_api "/pending/$ACCOUNT_ID" "GET" "" "Check pending transactions"

echo ""
echo "2️⃣ Testing Redis failure scenario"
echo "================================="

# Stop Redis
stop_redis

# Test 2: Transaction with Redis down
test_api "/transaction" "POST" '{
    "account_id": "'$ACCOUNT_ID'",
    "amount": 30000,
    "type": "DEBIT"
}' "Transaction with Redis down (should use database fallback)"

# Check balance
test_api "/balance/$ACCOUNT_ID" "GET" "" "Check balance after Redis failure transaction"

# Check pending
test_api "/pending/$ACCOUNT_ID" "GET" "" "Check pending transactions after Redis failure"

echo ""
echo "3️⃣ Testing Redis recovery"
echo "========================="

# Start Redis
start_redis

# Wait for settlement
echo "⏳ Waiting for settlement worker to run..."
sleep 6

# Check balance after settlement
test_api "/balance/$ACCOUNT_ID" "GET" "" "Check balance after settlement"

# Check pending after settlement
test_api "/pending/$ACCOUNT_ID" "GET" "" "Check pending transactions after settlement"

echo ""
echo "4️⃣ Testing data consistency"
echo "==========================="

# Test 3: Another transaction after Redis recovery
test_api "/transaction" "POST" '{
    "account_id": "'$ACCOUNT_ID'",
    "amount": 20000,
    "type": "DEBIT"
}' "Transaction after Redis recovery"

# Check balance
test_api "/balance/$ACCOUNT_ID" "GET" "" "Check final balance"

# Check pending
test_api "/pending/$ACCOUNT_ID" "GET" "" "Check final pending transactions"

echo ""
echo "✅ Redis failure scenario test completed!"
echo ""
echo "📊 Expected Results:"
echo "- Transaction 1: Success with Redis"
echo "- Transaction 2: Success with database fallback"
echo "- Settlement: Both transactions processed"
echo "- Transaction 3: Success with Redis recovery"
echo "- Data consistency: All balances correct"
