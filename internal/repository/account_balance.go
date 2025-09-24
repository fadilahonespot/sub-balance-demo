package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type AccountBalanceRepository interface {
	GetByID(ctx context.Context, id string) (*AccountBalance, error)
	GetByIDForUpdate(ctx context.Context, id string) (*AccountBalance, error)
	Create(ctx context.Context, balance *AccountBalance) error
	Update(ctx context.Context, balance *AccountBalance) error
	UpdateBalance(ctx context.Context, balance *AccountBalance) error
}

type accountBalanceRepository struct {
	db *gorm.DB
}

func NewAccountBalanceRepository(db *gorm.DB) AccountBalanceRepository {
	return &accountBalanceRepository{db: db}
}

func (r *accountBalanceRepository) GetByID(ctx context.Context, id string) (*AccountBalance, error) {
	var balance AccountBalance
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&balance).Error
	if err != nil {
		return nil, err
	}
	return &balance, nil
}

func (r *accountBalanceRepository) GetByIDForUpdate(ctx context.Context, id string) (*AccountBalance, error) {
	var balance AccountBalance
	err := r.db.WithContext(ctx).Set("gorm:query_option", "FOR UPDATE").
		Where("id = ?", id).First(&balance).Error
	if err != nil {
		return nil, err
	}
	return &balance, nil
}

func (r *accountBalanceRepository) Create(ctx context.Context, balance *AccountBalance) error {
	balance.CreatedAt = time.Now()
	balance.UpdatedAt = time.Now()
	return r.db.WithContext(ctx).Create(balance).Error
}

func (r *accountBalanceRepository) Update(ctx context.Context, balance *AccountBalance) error {
	balance.UpdatedAt = time.Now()
	return r.db.WithContext(ctx).Save(balance).Error
}

func (r *accountBalanceRepository) UpdateBalance(ctx context.Context, balance *AccountBalance) error {
	balance.UpdatedAt = time.Now()
	balance.Version = balance.Version + 1

	// Update available balance
	balance.AvailableBalance = balance.SettledBalance.Add(balance.PendingCredit).Sub(balance.PendingDebit)

	return r.db.WithContext(ctx).Model(balance).
		Where("id = ? AND version = ?", balance.ID, balance.Version-1).
		Updates(map[string]interface{}{
			"settled_balance":    balance.SettledBalance,
			"pending_debit":      balance.PendingDebit,
			"pending_credit":     balance.PendingCredit,
			"available_balance":  balance.AvailableBalance,
			"version":            balance.Version,
			"last_settlement_at": balance.LastSettlementAt,
			"updated_at":         balance.UpdatedAt,
		}).Error
}
