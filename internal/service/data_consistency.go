package service

import (
	"context"
	"fmt"
	"log"

	"sub-balance-demo/internal/repository"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

type DataConsistencyService struct {
	db             *gorm.DB
	redisCounter   RedisCounter
	accountRepo    repository.AccountBalanceRepository
	subBalanceRepo repository.SubBalanceRepository
}

func NewDataConsistencyService(
	db *gorm.DB,
	redisCounter RedisCounter,
	accountRepo repository.AccountBalanceRepository,
	subBalanceRepo repository.SubBalanceRepository,
) *DataConsistencyService {
	return &DataConsistencyService{
		db:             db,
		redisCounter:   redisCounter,
		accountRepo:    accountRepo,
		subBalanceRepo: subBalanceRepo,
	}
}

func (d *DataConsistencyService) ValidateAndRepair(ctx context.Context) error {
	log.Println("Starting data consistency validation...")

	// 1. Get all account balances
	var accounts []repository.AccountBalance
	err := d.db.Find(&accounts).Error
	if err != nil {
		return fmt.Errorf("failed to get accounts: %w", err)
	}

	repairCount := 0
	for _, account := range accounts {
		repaired, err := d.validateAccount(ctx, account)
		if err != nil {
			log.Printf("Failed to validate account %s: %v", account.ID, err)
			continue
		}
		if repaired {
			repairCount++
		}
	}

	log.Printf("Data consistency validation completed. Repaired %d accounts", repairCount)
	return nil
}

func (d *DataConsistencyService) validateAccount(ctx context.Context, account repository.AccountBalance) (bool, error) {
	// 1. Calculate pending from sub-balance table
	var pendingFromDB decimal.Decimal
	err := d.db.Model(&repository.SubBalance{}).
		Where("account_id = ? AND status = ?", account.ID, "PENDING").
		Select("COALESCE(SUM(amount), 0)").
		Scan(&pendingFromDB).Error
	if err != nil {
		return false, fmt.Errorf("failed to get pending from DB: %w", err)
	}

	// 2. Get pending from Redis (if available)
	pendingFromRedis, err := d.redisCounter.GetPending(ctx, account.ID)
	if err != nil {
		log.Printf("Redis unavailable for consistency check on account %s", account.ID)
		// Continue with DB-only validation
	}

	// 3. Calculate actual available balance
	actualAvailable := account.SettledBalance.Sub(pendingFromDB)

	// 4. Check Redis consistency (if available)
	redisInconsistent := false
	if err == nil && !pendingFromDB.Equal(pendingFromRedis) {
		log.Printf("Redis inconsistency detected for account %s: DB=%s, Redis=%s",
			account.ID, pendingFromDB.String(), pendingFromRedis.String())
		redisInconsistent = true
	}

	// 5. Check account balance calculation
	balanceInconsistent := !account.AvailableBalance.Equal(actualAvailable)
	if balanceInconsistent {
		log.Printf("Account balance inconsistency for %s: stored=%s, calculated=%s",
			account.ID, account.AvailableBalance.String(), actualAvailable.String())
	}

	// 6. Auto-repair if needed
	repaired := false
	if redisInconsistent || balanceInconsistent {
		err := d.repairAccount(ctx, account, pendingFromDB, actualAvailable)
		if err != nil {
			return false, fmt.Errorf("failed to repair account: %w", err)
		}
		repaired = true
	}

	return repaired, nil
}

func (d *DataConsistencyService) repairAccount(ctx context.Context, account repository.AccountBalance, pendingFromDB, actualAvailable decimal.Decimal) error {
	return d.db.Transaction(func(tx *gorm.DB) error {
		// 1. Update account balance
		account.AvailableBalance = actualAvailable
		err := tx.Save(&account).Error
		if err != nil {
			return fmt.Errorf("failed to update account balance: %w", err)
		}

		// 2. Update Redis counter (if available)
		err = d.redisCounter.ClearPending(ctx, account.ID)
		if err != nil {
			log.Printf("Failed to clear Redis counter for account %s: %v", account.ID, err)
		}

		if !pendingFromDB.IsZero() {
			// Re-add pending amount to Redis
			_, _, err = d.redisCounter.AddPending(ctx, account.ID, pendingFromDB, account.SettledBalance)
			if err != nil {
				log.Printf("Failed to update Redis counter for account %s: %v", account.ID, err)
			}
		}

		log.Printf("Repaired account %s: available=%s, pending=%s",
			account.ID, actualAvailable.String(), pendingFromDB.String())
		return nil
	})
}

func (d *DataConsistencyService) RecoverRedisFromDatabase(ctx context.Context) error {
	log.Println("Starting Redis recovery from database...")

	// 1. Get all pending transactions from database
	var pendingTransactions []repository.SubBalance
	err := d.db.Where("status = ?", "PENDING").Find(&pendingTransactions).Error
	if err != nil {
		return fmt.Errorf("failed to get pending transactions: %w", err)
	}

	// 2. Group by account and calculate total pending
	accountPending := make(map[string]decimal.Decimal)
	for _, tx := range pendingTransactions {
		accountPending[tx.AccountID] = accountPending[tx.AccountID].Add(tx.Amount)
	}

	// 3. Update Redis counter
	for accountID, totalPending := range accountPending {
		// Clear existing counter
		err := d.redisCounter.ClearPending(ctx, accountID)
		if err != nil {
			log.Printf("Failed to clear Redis counter for account %s: %v", accountID, err)
		}

		// Set new counter
		if !totalPending.IsZero() {
			// Get account balance for max balance validation
			account, err := d.accountRepo.GetByID(ctx, accountID)
			if err != nil {
				log.Printf("Failed to get account %s for Redis recovery: %v", accountID, err)
				continue
			}

			maxBalance := account.SettledBalance.Add(account.PendingCredit).Sub(account.PendingDebit)
			_, _, err = d.redisCounter.AddPending(ctx, accountID, totalPending, maxBalance)
			if err != nil {
				log.Printf("Failed to set Redis counter for account %s: %v", accountID, err)
			} else {
				log.Printf("Recovered Redis counter for account %s: %s", accountID, totalPending.String())
			}
		}
	}

	// 4. Clear Redis counter for accounts with no pending
	var allAccounts []string
	err = d.db.Model(&repository.AccountBalance{}).Pluck("id", &allAccounts).Error
	if err != nil {
		return fmt.Errorf("failed to get all accounts: %w", err)
	}

	for _, accountID := range allAccounts {
		if _, exists := accountPending[accountID]; !exists {
			err := d.redisCounter.ClearPending(ctx, accountID)
			if err != nil {
				log.Printf("Failed to clear Redis counter for account %s: %v", accountID, err)
			}
		}
	}

	log.Println("Redis recovery completed")
	return nil
}
