#!/bin/bash

# Load testing script for sub-balance system

BASE_URL="http://localhost:${PORT:-8082}"
ACCOUNT_ID="ACC001"

echo "🚀 Starting load test for sub-balance system"
echo "Base URL: $BASE_URL"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Function to make a transaction
make_transaction() {
    local amount=$1
    local type=$2
    
    curl -s -X POST "$BASE_URL/api/v1/transaction" \
        -H "Content-Type: application/json" \
        -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"$amount\",\"type\":\"$type\"}" \
        | jq -r '.message // .error'
}

# Function to get balance
get_balance() {
    curl -s "$BASE_URL/api/v1/balance/$ACCOUNT_ID" | jq -r '.available_balance'
}

# Function to get pending transactions
get_pending() {
    curl -s "$BASE_URL/api/v1/pending/$ACCOUNT_ID" | jq -r '.count'
}

echo "📊 Initial Balance: $(get_balance)"
echo ""

# Test 1: Single transaction
echo "🧪 Test 1: Single transaction"
result=$(make_transaction "10000" "debit")
echo "Result: $result"
echo "Balance after: $(get_balance)"
echo "Pending: $(get_pending)"
echo ""

# Test 2: Multiple transactions
echo "🧪 Test 2: Multiple transactions (10 concurrent)"
for i in {1..10}; do
    make_transaction "5000" "debit" &
done
wait

echo "Balance after 10 transactions: $(get_balance)"
echo "Pending transactions: $(get_pending)"
echo ""

# Test 3: High volume test
echo "🧪 Test 3: High volume test (50 transactions)"
start_time=$(date +%s)

for i in {1..50}; do
    make_transaction "1000" "debit" &
done
wait

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Balance after 50 transactions: $(get_balance)"
echo "Pending transactions: $(get_pending)"
echo "Duration: ${duration}s"
echo "TPS: $((50 / duration))"
echo ""

# Test 4: Overspend test
echo "🧪 Test 4: Overspend test"
result=$(make_transaction "999999999" "debit")
echo "Result: $result"
echo "Balance: $(get_balance)"
echo "Pending: $(get_pending)"
echo ""

# Test 5: Wait for settlement
echo "🧪 Test 5: Waiting for settlement (10 seconds)"
sleep 10
echo "Balance after settlement: $(get_balance)"
echo "Pending transactions: $(get_pending)"
echo ""

# Test 6: Credit transactions
echo "🧪 Test 6: Credit transactions"
for i in {1..5}; do
    make_transaction "20000" "credit" &
done
wait

echo "Balance after credits: $(get_balance)"
echo "Pending: $(get_pending)"
echo ""

# Final settlement wait
echo "⏳ Final settlement wait (5 seconds)"
sleep 5
echo "Final balance: $(get_balance)"
echo "Final pending: $(get_pending)"
echo ""

echo "✅ Load test completed!"
