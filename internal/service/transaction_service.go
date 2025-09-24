package service

import (
	"context"
	"fmt"
	"log"
	"time"

	"sub-balance-demo/internal/config"
	"sub-balance-demo/internal/repository"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

type TransactionService interface {
	ProcessTransaction(ctx context.Context, req *repository.TransactionRequest) (*repository.TransactionResponse, error)
	GetBalance(ctx context.Context, accountID string) (*repository.BalanceResponse, error)
	GetPendingTransactions(ctx context.Context, accountID string) (*repository.PendingTransactionsResponse, error)
	CreateAccount(ctx context.Context, accountID string, initialBalance decimal.Decimal) error
	StartSettlementWorker(ctx context.Context)
}

type transactionService struct {
	accountBalanceRepo repository.AccountBalanceRepository
	subBalanceRepo     repository.SubBalanceRepository
	redisCounter       RedisCounter
	config             *config.Config
	healthChecker      *RedisHealthChecker
	circuitBreaker     *CircuitBreaker
	consistencyService *DataConsistencyService
}

func NewTransactionService(
	accountBalanceRepo repository.AccountBalanceRepository,
	subBalanceRepo repository.SubBalanceRepository,
	redisCounter RedisCounter,
	config *config.Config,
	healthChecker *RedisHealthChecker,
	circuitBreaker *CircuitBreaker,
	consistencyService *DataConsistencyService,
) TransactionService {
	return &transactionService{
		accountBalanceRepo: accountBalanceRepo,
		subBalanceRepo:     subBalanceRepo,
		redisCounter:       redisCounter,
		config:             config,
		healthChecker:      healthChecker,
		circuitBreaker:     circuitBreaker,
		consistencyService: consistencyService,
	}
}

func (s *transactionService) ProcessTransaction(ctx context.Context, req *repository.TransactionRequest) (*repository.TransactionResponse, error) {
	// Strategy 1: Try Redis first (if healthy)
	if s.healthChecker.IsHealthy() {
		return s.processWithRedis(ctx, req)
	}

	// Strategy 2: Fallback to database lock
	return s.processWithDatabaseFallback(ctx, req)
}

func (s *transactionService) processWithRedis(ctx context.Context, req *repository.TransactionRequest) (*repository.TransactionResponse, error) {
	// 1. Quick validation (tanpa lock)
	err := s.quickValidateBalance(ctx, req.AccountID, req.Amount)
	if err != nil {
		return &repository.TransactionResponse{
			Success:   false,
			Message:   err.Error(),
			AccountID: req.AccountID,
			Amount:    req.Amount,
			Type:      req.Type,
			Status:    "REJECTED",
			Timestamp: time.Now(),
		}, nil
	}

	// 2. Baca balance untuk max balance
	balance, err := s.accountBalanceRepo.GetByID(ctx, req.AccountID)
	if err != nil {
		return nil, fmt.Errorf("failed to get account balance: %w", err)
	}

	maxBalance := balance.SettledBalance.Add(balance.PendingCredit).Sub(balance.PendingDebit)

	// 3. Atomic Redis counter update dengan validation (with circuit breaker)
	var success bool
	if s.config.EnableCircuitBreaker && s.circuitBreaker != nil {
		err = s.circuitBreaker.Call(func() error {
			var cbErr error
			success, _, cbErr = s.redisCounter.AddPending(ctx, req.AccountID, req.Amount, maxBalance)
			return cbErr
		})
	} else {
		// Direct call without circuit breaker
		var cbErr error
		success, _, cbErr = s.redisCounter.AddPending(ctx, req.AccountID, req.Amount, maxBalance)
		err = cbErr
	}

	if err != nil {
		// Redis failed, fallback to database (if enabled)
		if s.config.EnableRedisFallback {
			log.Printf("Redis failed, falling back to database: %v", err)
			return s.processWithDatabaseFallback(ctx, req)
		} else {
			return &repository.TransactionResponse{
				Success:   false,
				Message:   "Redis unavailable and fallback disabled",
				AccountID: req.AccountID,
				Amount:    req.Amount,
				Type:      req.Type,
			}, nil
		}
	}

	if !success {
		return &repository.TransactionResponse{
			Success:   false,
			Message:   "saldo tidak mencukupi (overspend protection)",
			AccountID: req.AccountID,
			Amount:    req.Amount,
			Type:      req.Type,
			Status:    "REJECTED",
			Timestamp: time.Now(),
		}, nil
	}

	// 4. Insert ke sub_balance
	subBalance := &repository.SubBalance{
		ID:        uuid.New().String(),
		AccountID: req.AccountID,
		Amount:    req.Amount,
		Type:      req.Type,
		Status:    "PENDING",
	}

	err = s.subBalanceRepo.Create(ctx, subBalance)
	if err != nil {
		// Rollback Redis counter
		s.redisCounter.RemovePending(ctx, req.AccountID, req.Amount)
		return nil, fmt.Errorf("failed to create sub balance: %w", err)
	}

	return &repository.TransactionResponse{
		Success:   true,
		Message:   "Transaksi berhasil diproses (Redis)",
		AccountID: req.AccountID,
		Amount:    req.Amount,
		Type:      req.Type,
		Status:    "PENDING",
		Timestamp: time.Now(),
	}, nil
}

func (s *transactionService) processWithDatabaseFallback(ctx context.Context, req *repository.TransactionRequest) (*repository.TransactionResponse, error) {
	// 1. Lock account balance
	balance, err := s.accountBalanceRepo.GetByIDForUpdate(ctx, req.AccountID)
	if err != nil {
		return nil, fmt.Errorf("failed to lock account balance: %w", err)
	}

	// 2. Calculate total pending from sub-balance table
	var totalPending decimal.Decimal
	err = s.subBalanceRepo.GetTotalPendingByAccountID(ctx, req.AccountID, &totalPending)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending amount: %w", err)
	}

	// 3. Calculate actual available balance
	actualAvailable := balance.SettledBalance.Sub(totalPending)

	if actualAvailable.LessThan(req.Amount) {
		return &repository.TransactionResponse{
			Success:   false,
			Message:   "saldo tidak mencukupi",
			AccountID: req.AccountID,
			Amount:    req.Amount,
			Type:      req.Type,
			Status:    "REJECTED",
			Timestamp: time.Now(),
		}, nil
	}

	// 4. Create sub-balance record
	subBalance := &repository.SubBalance{
		ID:        uuid.New().String(),
		AccountID: req.AccountID,
		Amount:    req.Amount,
		Type:      req.Type,
		Status:    "PENDING",
	}

	err = s.subBalanceRepo.Create(ctx, subBalance)
	if err != nil {
		return nil, fmt.Errorf("failed to create sub balance: %w", err)
	}

	// 5. Update account balance (temporary for consistency)
	balance.PendingDebit = balance.PendingDebit.Add(req.Amount)
	balance.AvailableBalance = balance.SettledBalance.Add(balance.PendingCredit).Sub(balance.PendingDebit)

	err = s.accountBalanceRepo.UpdateBalance(ctx, balance)
	if err != nil {
		return nil, fmt.Errorf("failed to update account balance: %w", err)
	}

	return &repository.TransactionResponse{
		Success:   true,
		Message:   "Transaksi berhasil diproses (Database Fallback)",
		AccountID: req.AccountID,
		Amount:    req.Amount,
		Type:      req.Type,
		Status:    "PENDING",
		Timestamp: time.Now(),
	}, nil
}

func (s *transactionService) quickValidateBalance(ctx context.Context, accountID string, amount decimal.Decimal) error {
	// Baca balance (tanpa lock)
	balance, err := s.accountBalanceRepo.GetByID(ctx, accountID)
	if err != nil {
		return fmt.Errorf("account not found")
	}

	// Hitung available balance
	availableBalance := balance.SettledBalance.Add(balance.PendingCredit).Sub(balance.PendingDebit)

	// Cek Redis counter untuk pending real-time
	pendingAmount, err := s.redisCounter.GetPending(ctx, accountID)
	if err != nil {
		return fmt.Errorf("failed to get pending amount")
	}

	// Hitung sisa saldo yang bisa digunakan
	remainingBalance := availableBalance.Sub(pendingAmount)

	// Validasi ketat: sisa saldo harus >= amount
	if remainingBalance.LessThan(amount) {
		return fmt.Errorf("saldo tidak mencukupi")
	}

	return nil
}

func (s *transactionService) GetBalance(ctx context.Context, accountID string) (*repository.BalanceResponse, error) {
	balance, err := s.accountBalanceRepo.GetByID(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("account not found")
	}

	return &repository.BalanceResponse{
		AccountID:        balance.ID,
		SettledBalance:   balance.SettledBalance,
		PendingDebit:     balance.PendingDebit,
		PendingCredit:    balance.PendingCredit,
		AvailableBalance: balance.AvailableBalance,
		LastUpdated:      balance.UpdatedAt,
	}, nil
}

func (s *transactionService) GetPendingTransactions(ctx context.Context, accountID string) (*repository.PendingTransactionsResponse, error) {
	items, err := s.subBalanceRepo.GetPendingByAccountID(ctx, accountID)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending transactions")
	}

	total := decimal.Zero
	for _, item := range items {
		total = total.Add(item.Amount)
	}

	return &repository.PendingTransactionsResponse{
		AccountID: accountID,
		Count:     len(items),
		Total:     total,
		Items:     items,
	}, nil
}

func (s *transactionService) StartSettlementWorker(ctx context.Context) {
	interval, err := time.ParseDuration(s.config.SettlementInterval)
	if err != nil {
		log.Printf("Invalid settlement interval, using default 5s: %v", err)
		interval = 5 * time.Second
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	log.Println("Settlement worker started")

	for {
		select {
		case <-ticker.C:
			s.processSettlement(ctx)
		case <-ctx.Done():
			log.Println("Settlement worker stopped")
			return
		}
	}
}

func (s *transactionService) processSettlement(ctx context.Context) error {
	// 1. Ambil semua pending transactions dengan batch size
	batchSize := s.config.SettlementBatchSize
	if batchSize <= 0 {
		batchSize = 100 // default batch size
	}

	pendingTransactions, err := s.subBalanceRepo.GetAllPending(ctx)
	if err != nil {
		log.Printf("Failed to get pending transactions: %v", err)
		return err
	}

	if len(pendingTransactions) == 0 {
		return nil // Tidak ada yang perlu disettlement
	}

	// 2. Process in batches
	for i := 0; i < len(pendingTransactions); i += batchSize {
		end := i + batchSize
		if end > len(pendingTransactions) {
			end = len(pendingTransactions)
		}

		batch := pendingTransactions[i:end]

		// Group by account for this batch
		accountGroups := make(map[string][]repository.SubBalance)
		for _, txn := range batch {
			accountGroups[txn.AccountID] = append(accountGroups[txn.AccountID], txn)
		}

		// Process per account in this batch
		for accountID, transactions := range accountGroups {
			err := s.settleAccount(ctx, accountID, transactions)
			if err != nil {
				log.Printf("Failed to settle account %s: %v", accountID, err)
				continue
			}
		}
	}

	// 4. Redis Recovery: Sync Redis dengan database (if enabled)
	if s.config.EnableAutoRecovery && s.healthChecker.IsHealthy() {
		err := s.consistencyService.RecoverRedisFromDatabase(ctx)
		if err != nil {
			log.Printf("Failed to recover Redis from database: %v", err)
		}
	}

	return nil
}

func (s *transactionService) settleAccount(ctx context.Context, accountID string, transactions []repository.SubBalance) error {
	// 1. Lock account balance
	balance, err := s.accountBalanceRepo.GetByIDForUpdate(ctx, accountID)
	if err != nil {
		return fmt.Errorf("failed to lock account balance: %w", err)
	}

	// 2. Hitung total delta berdasarkan type (debit mengurangi, credit menambah)
	totalDelta := decimal.Zero
	var transactionIDs []string
	for _, txn := range transactions {
		log.Printf("Processing transaction: id=%s, type=%s, amount=%s", txn.ID, txn.Type, txn.Amount.String())
		switch txn.Type {
		case "debit":
			totalDelta = totalDelta.Sub(txn.Amount) // Debit mengurangi balance
			log.Printf("Debit transaction: amount=%s, new_totalDelta=%s", txn.Amount.String(), totalDelta.String())
		case "credit":
			totalDelta = totalDelta.Add(txn.Amount) // Credit menambah balance
			log.Printf("Credit transaction: amount=%s, new_totalDelta=%s", txn.Amount.String(), totalDelta.String())
		}
		transactionIDs = append(transactionIDs, txn.ID)
	}

	// 3. Validasi ulang (double check) - untuk debit, pastikan balance tidak minus
	availableBalance := balance.SettledBalance.Add(balance.PendingCredit).Sub(balance.PendingDebit)
	newBalance := availableBalance.Add(totalDelta)
	if newBalance.LessThan(decimal.Zero) {
		// Jika akan minus, reject semua transaksi
		s.subBalanceRepo.UpdateStatusBatch(ctx, transactionIDs, "REJECTED")
		s.redisCounter.RemovePending(ctx, accountID, totalDelta.Abs())
		return fmt.Errorf("settlement akan menyebabkan saldo minus: current=%s, delta=%s, new=%s",
			availableBalance.String(), totalDelta.String(), newBalance.String())
	}

	// 4. Update balance utama
	oldBalance := balance.SettledBalance
	balance.SettledBalance = balance.SettledBalance.Add(totalDelta)
	balance.PendingDebit = decimal.Zero
	balance.PendingCredit = decimal.Zero
	now := time.Now()
	balance.LastSettlementAt = &now

	log.Printf("Settlement: account=%s, old_balance=%s, delta=%s, new_balance=%s, transactions=%d",
		accountID, oldBalance.String(), totalDelta.String(), balance.SettledBalance.String(), len(transactions))

	// 5. Update balance
	err = s.accountBalanceRepo.UpdateBalance(ctx, balance)
	if err != nil {
		return fmt.Errorf("failed to update balance: %w", err)
	}

	// 6. Update status sub_balance
	err = s.subBalanceRepo.UpdateStatusBatch(ctx, transactionIDs, "SETTLED")
	if err != nil {
		return fmt.Errorf("failed to update sub balance status: %w", err)
	}

	// 7. Clear Redis counter
	err = s.redisCounter.ClearPending(ctx, accountID)
	if err != nil {
		log.Printf("Failed to clear redis counter for account %s: %v", accountID, err)
	}

	log.Printf("Successfully settled %d transactions for account %s", len(transactions), accountID)
	return nil
}

func (s *transactionService) CreateAccount(ctx context.Context, accountID string, initialBalance decimal.Decimal) error {
	// Check if account already exists
	existingBalance, err := s.accountBalanceRepo.GetByID(ctx, accountID)
	if err == nil && existingBalance != nil {
		return fmt.Errorf("account already exists")
	}

	// Create new account balance
	accountBalance := &repository.AccountBalance{
		ID:               accountID,
		SettledBalance:   initialBalance,
		PendingDebit:     decimal.Zero,
		PendingCredit:    decimal.Zero,
		AvailableBalance: initialBalance,
		Version:          1,
	}

	err = s.accountBalanceRepo.Create(ctx, accountBalance)
	if err != nil {
		return fmt.Errorf("failed to create account: %w", err)
	}

	log.Printf("Successfully created account %s with initial balance %s", accountID, initialBalance.String())
	return nil
}
