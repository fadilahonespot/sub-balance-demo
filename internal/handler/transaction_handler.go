package handler

import (
	"net/http"

	"sub-balance-demo/internal/config"
	"sub-balance-demo/internal/repository"
	"sub-balance-demo/internal/service"

	"github.com/go-playground/validator/v10"
	"github.com/labstack/echo/v4"
	"github.com/shopspring/decimal"
)

type TransactionHandler struct {
	transactionService service.TransactionService
	validator          *validator.Validate
	config             *config.Config
}

func NewTransactionHandler(transactionService service.TransactionService, config *config.Config) *TransactionHandler {
	return &TransactionHandler{
		transactionService: transactionService,
		validator:          validator.New(),
		config:             config,
	}
}

func (h *TransactionHandler) CreateAccount(c echo.Context) error {
	var req struct {
		AccountID string `json:"account_id" validate:"required"`
		Balance   string `json:"balance"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Validation failed",
		})
	}

	// Parse balance
	balance, err := decimal.NewFromString(req.Balance)
	if err != nil {
		balance = decimal.Zero
	}

	// Create account using service
	err = h.transactionService.CreateAccount(c.Request().Context(), req.AccountID, balance)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	response := map[string]interface{}{
		"success":    true,
		"message":    "Account created successfully",
		"account_id": req.AccountID,
		"balance":    balance.String(),
	}

	return c.JSON(http.StatusOK, response)
}

func (h *TransactionHandler) ProcessTransaction(c echo.Context) error {
	var req repository.TransactionRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request format",
		})
	}

	// Validate request
	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Validation failed: " + err.Error(),
		})
	}

	// Validate amount
	if req.Amount.LessThanOrEqual(decimal.Zero) {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Amount must be greater than zero",
		})
	}

	// Process transaction
	response, err := h.transactionService.ProcessTransaction(c.Request().Context(), &req)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Internal server error: " + err.Error(),
		})
	}

	// Return response
	statusCode := http.StatusOK
	if !response.Success {
		statusCode = http.StatusBadRequest
	}

	return c.JSON(statusCode, response)
}

func (h *TransactionHandler) GetBalance(c echo.Context) error {
	accountID := c.Param("account_id")
	if accountID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Account ID is required",
		})
	}

	balance, err := h.transactionService.GetBalance(c.Request().Context(), accountID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Account not found",
		})
	}

	return c.JSON(http.StatusOK, balance)
}

func (h *TransactionHandler) GetPendingTransactions(c echo.Context) error {
	accountID := c.Param("account_id")
	if accountID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Account ID is required",
		})
	}

	pending, err := h.transactionService.GetPendingTransactions(c.Request().Context(), accountID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get pending transactions",
		})
	}

	return c.JSON(http.StatusOK, pending)
}

func (h *TransactionHandler) HealthCheck(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"status":  "healthy",
		"service": h.config.AppName,
		"version": h.config.AppVersion,
	})
}
