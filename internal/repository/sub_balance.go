package repository

import (
	"context"
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

type SubBalanceRepository interface {
	Create(ctx context.Context, subBalance *SubBalance) error
	GetPendingByAccountID(ctx context.Context, accountID string) ([]SubBalance, error)
	GetAllPending(ctx context.Context) ([]SubBalance, error)
	UpdateStatus(ctx context.Context, id string, status string) error
	UpdateStatusBatch(ctx context.Context, ids []string, status string) error
	GetPendingCountByAccountID(ctx context.Context, accountID string) (int64, error)
	GetPendingTotalByAccountID(ctx context.Context, accountID string) (decimal.Decimal, error)
	GetTotalPendingByAccountID(ctx context.Context, accountID string, total *decimal.Decimal) error
}

type subBalanceRepository struct {
	db *gorm.DB
}

func NewSubBalanceRepository(db *gorm.DB) SubBalanceRepository {
	return &subBalanceRepository{db: db}
}

func (r *subBalanceRepository) Create(ctx context.Context, subBalance *SubBalance) error {
	subBalance.CreatedAt = time.Now()
	subBalance.UpdatedAt = time.Now()
	subBalance.Status = "PENDING"
	return r.db.WithContext(ctx).Create(subBalance).Error
}

func (r *subBalanceRepository) GetPendingByAccountID(ctx context.Context, accountID string) ([]SubBalance, error) {
	var subBalances []SubBalance
	err := r.db.WithContext(ctx).
		Where("account_id = ? AND status = ?", accountID, "PENDING").
		Order("created_at ASC").
		Find(&subBalances).Error
	return subBalances, err
}

func (r *subBalanceRepository) GetAllPending(ctx context.Context) ([]SubBalance, error) {
	var subBalances []SubBalance
	err := r.db.WithContext(ctx).
		Where("status = ?", "PENDING").
		Order("account_id, created_at ASC").
		Find(&subBalances).Error
	return subBalances, err
}

func (r *subBalanceRepository) UpdateStatus(ctx context.Context, id string, status string) error {
	return r.db.WithContext(ctx).Model(&SubBalance{}).
		Where("id = ?", id).
		Update("status", status).Error
}

func (r *subBalanceRepository) UpdateStatusBatch(ctx context.Context, ids []string, status string) error {
	return r.db.WithContext(ctx).Model(&SubBalance{}).
		Where("id IN ?", ids).
		Updates(map[string]interface{}{
			"status":     status,
			"updated_at": time.Now(),
		}).Error
}

func (r *subBalanceRepository) GetPendingCountByAccountID(ctx context.Context, accountID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&SubBalance{}).
		Where("account_id = ? AND status = ?", accountID, "PENDING").
		Count(&count).Error
	return count, err
}

func (r *subBalanceRepository) GetPendingTotalByAccountID(ctx context.Context, accountID string) (decimal.Decimal, error) {
	var result struct {
		Total decimal.Decimal `gorm:"column:total"`
	}

	err := r.db.WithContext(ctx).Model(&SubBalance{}).
		Select("COALESCE(SUM(amount), 0) as total").
		Where("account_id = ? AND status = ?", accountID, "PENDING").
		Scan(&result).Error

	if err != nil {
		return decimal.Zero, err
	}

	return result.Total, nil
}

func (r *subBalanceRepository) GetTotalPendingByAccountID(ctx context.Context, accountID string, total *decimal.Decimal) error {
	err := r.db.WithContext(ctx).
		Model(&SubBalance{}).
		Where("account_id = ? AND status = ?", accountID, "PENDING").
		Select("COALESCE(SUM(amount), 0)").
		Scan(total).Error
	return err
}
