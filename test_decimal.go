package main

import (
	"fmt"

	"github.com/shopspring/decimal"
)

func main() {
	// Test decimal arithmetic for debit transaction
	totalDelta := decimal.Zero
	amount := decimal.NewFromInt(1000)

	fmt.Printf("Initial totalDelta: %s\n", totalDelta.String())
	fmt.Printf("Amount: %s\n", amount.String())

	// For debit transaction, we subtract the amount
	totalDelta = totalDelta.Sub(amount)
	fmt.Printf("After subtracting amount (debit): %s\n", totalDelta.String())

	// Test balance update
	balance := decimal.NewFromInt(1000000)
	fmt.Printf("Initial balance: %s\n", balance.String())

	newBalance := balance.Add(totalDelta)
	fmt.Printf("New balance after adding totalDelta: %s\n", newBalance.String())

	// Expected: 1000000 + (-1000) = 999000
	fmt.Printf("Expected: 999000\n")
}
