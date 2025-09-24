package repository

import (
	"time"

	"github.com/shopspring/decimal"
)

// AccountBalance represents the main account balance table
type AccountBalance struct {
	ID               string          `json:"id" gorm:"primaryKey;column:id"`
	CreatedAt        time.Time       `json:"created_at" gorm:"column:created_at"`
	UpdatedAt        time.Time       `json:"updated_at" gorm:"column:updated_at"`
	SettledBalance   decimal.Decimal `json:"settled_balance" gorm:"column:settled_balance;type:decimal(20,2)"`
	PendingDebit     decimal.Decimal `json:"pending_debit" gorm:"column:pending_debit;type:decimal(20,2)"`
	PendingCredit    decimal.Decimal `json:"pending_credit" gorm:"column:pending_credit;type:decimal(20,2)"`
	AvailableBalance decimal.Decimal `json:"available_balance" gorm:"column:available_balance;type:decimal(20,2)"`
	Version          int64           `json:"version" gorm:"column:version"`
	LastSettlementAt *time.Time      `json:"last_settlement_at" gorm:"column:last_settlement_at"`
}

func (AccountBalance) TableName() string {
	return "account_balances"
}

// SubBalance represents the sub-balance (pending transactions) table
type SubBalance struct {
	ID        string          `json:"id" gorm:"primaryKey;column:id"`
	AccountID string          `json:"account_id" gorm:"column:account_id;index"`
	Amount    decimal.Decimal `json:"amount" gorm:"column:amount;type:decimal(20,2)"`
	Type      string          `json:"type" gorm:"column:type;index"`     // debit or credit
	Status    string          `json:"status" gorm:"column:status;index"` // PENDING, SETTLED, REJECTED
	CreatedAt time.Time       `json:"created_at" gorm:"column:created_at;index"`
	UpdatedAt time.Time       `json:"updated_at" gorm:"column:updated_at"`
}

func (SubBalance) TableName() string {
	return "sub_balances"
}

// TransactionRequest represents the request payload
type TransactionRequest struct {
	AccountID string          `json:"account_id" validate:"required"`
	Amount    decimal.Decimal `json:"amount" validate:"required"`
	Type      string          `json:"type" validate:"required,oneof=debit credit"` // debit or credit
}

// TransactionResponse represents the response payload
type TransactionResponse struct {
	Success   bool            `json:"success"`
	Message   string          `json:"message"`
	AccountID string          `json:"account_id"`
	Amount    decimal.Decimal `json:"amount"`
	Type      string          `json:"type"`
	Status    string          `json:"status"`
	Timestamp time.Time       `json:"timestamp"`
}

// BalanceResponse represents the balance response
type BalanceResponse struct {
	AccountID        string          `json:"account_id"`
	SettledBalance   decimal.Decimal `json:"settled_balance"`
	PendingDebit     decimal.Decimal `json:"pending_debit"`
	PendingCredit    decimal.Decimal `json:"pending_credit"`
	AvailableBalance decimal.Decimal `json:"available_balance"`
	LastUpdated      time.Time       `json:"last_updated"`
}

// PendingTransactionsResponse represents pending transactions response
type PendingTransactionsResponse struct {
	AccountID string          `json:"account_id"`
	Count     int             `json:"count"`
	Total     decimal.Decimal `json:"total"`
	Items     []SubBalance    `json:"items"`
}
