package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"sub-balance-demo/internal/config"
	"sub-balance-demo/internal/handler"
	"sub-balance-demo/internal/repository"
	"sub-balance-demo/internal/service"

	"github.com/go-redis/redis/v8"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize database
	db, err := initDatabase(cfg)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Initialize Redis
	rdb := initRedis(cfg)

	// Initialize repositories
	accountBalanceRepo := repository.NewAccountBalanceRepository(db)
	subBalanceRepo := repository.NewSubBalanceRepository(db)

	// Initialize services
	redisCounter := service.NewRedisCounter(rdb, cfg)

	// Parse health check interval
	healthCheckInterval, err := time.ParseDuration(cfg.HealthCheckInterval)
	if err != nil {
		log.Printf("Invalid health check interval, using default 5s: %v", err)
		healthCheckInterval = 5 * time.Second
	}
	healthChecker := service.NewRedisHealthChecker(rdb, healthCheckInterval)

	// Parse circuit breaker timeout
	circuitBreakerTimeout, err := time.ParseDuration(cfg.CircuitBreakerTimeout)
	if err != nil {
		log.Printf("Invalid circuit breaker timeout, using default 30s: %v", err)
		circuitBreakerTimeout = 30 * time.Second
	}
	circuitBreaker := service.NewCircuitBreaker(cfg.CircuitBreakerFailureThreshold, circuitBreakerTimeout)

	consistencyService := service.NewDataConsistencyService(db, redisCounter, accountBalanceRepo, subBalanceRepo)
	transactionService := service.NewTransactionService(accountBalanceRepo, subBalanceRepo, redisCounter, cfg, healthChecker, circuitBreaker, consistencyService)

	// Initialize handlers
	transactionHandler := handler.NewTransactionHandler(transactionService, cfg)

	// Initialize Echo
	e := echo.New()

	// Configure logging based on debug mode
	if cfg.DebugMode {
		e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
			Format: "time=${time_rfc3339} method=${method} uri=${uri} status=${status} latency=${latency_human}\n",
		}))
	} else {
		e.Use(middleware.Logger())
	}
	e.Use(middleware.Recover())

	// Configure concurrent request limiting (using custom middleware)
	if cfg.MaxConcurrentReqs > 0 {
		e.Use(concurrentRequestLimiter(cfg.MaxConcurrentReqs))
	}

	// Configure rate limiting (if enabled)
	if cfg.EnableRateLimit && cfg.RateLimitRequests > 0 {
		// Parse rate limit window
		rateLimitWindow, err := time.ParseDuration(cfg.RateLimitWindow)
		if err != nil {
			log.Printf("Invalid rate limit window, using default 1m: %v", err)
			rateLimitWindow = 1 * time.Minute
		}

		e.Use(rateLimiter(cfg.RateLimitRequests, rateLimitWindow))
	}

	// Configure CORS if enabled
	if cfg.EnableCORS {
		e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
			AllowOrigins: []string{cfg.CORSOrigins},
			AllowMethods: []string{cfg.CORSMethods},
			AllowHeaders: []string{cfg.CORSHeaders},
		}))
	}

	// Setup routes
	setupRoutes(e, transactionHandler)

	// Setup monitoring (if enabled)
	if cfg.EnableMetrics {
		setupMonitoring(e, cfg)
	}

	// Setup test mode routes (if enabled)
	if cfg.EnableTestMode {
		setupTestRoutes(e, cfg, transactionHandler)
	}

	// Start background workers
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start Redis health checker (if enabled)
	if cfg.EnableCircuitBreaker {
		go healthChecker.StartHealthCheck(ctx)
	}

	// Start settlement worker
	go transactionService.StartSettlementWorker(ctx)

	// Start data consistency checker (if enabled)
	if cfg.EnableDataConsistencyCheck {
		go func() {
			consistencyInterval, err := time.ParseDuration(cfg.ConsistencyCheckInterval)
			if err != nil {
				log.Printf("Invalid consistency check interval, using default 30s: %v", err)
				consistencyInterval = 30 * time.Second
			}

			ticker := time.NewTicker(consistencyInterval)
			defer ticker.Stop()

			for {
				select {
				case <-ticker.C:
					err := consistencyService.ValidateAndRepair(ctx)
					if err != nil {
						log.Printf("Data consistency check failed: %v", err)
					}
				case <-ctx.Done():
					return
				}
			}
		}()
	}

	// Start server with timeouts
	go func() {
		// Parse server timeouts
		readTimeout, err := time.ParseDuration(cfg.ReadTimeout)
		if err != nil {
			log.Printf("Invalid read timeout, using default 10s: %v", err)
			readTimeout = 10 * time.Second
		}

		writeTimeout, err := time.ParseDuration(cfg.WriteTimeout)
		if err != nil {
			log.Printf("Invalid write timeout, using default 10s: %v", err)
			writeTimeout = 10 * time.Second
		}

		// Configure server with timeouts
		s := &http.Server{
			Addr:         ":" + cfg.Port,
			Handler:      e,
			ReadTimeout:  readTimeout,
			WriteTimeout: writeTimeout,
		}

		if err := s.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	cancel()

	// Graceful shutdown (if enabled)
	if cfg.EnableGracefulShutdown {
		shutdownTimeout, err := time.ParseDuration(cfg.RequestTimeout)
		if err != nil {
			log.Printf("Invalid request timeout, using default 10s: %v", err)
			shutdownTimeout = 10 * time.Second
		}
		ctx, cancel = context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()

		if err := e.Shutdown(ctx); err != nil {
			log.Fatal("Server forced to shutdown:", err)
		}
	}

	log.Println("Server exited")
}

func initDatabase(cfg *config.Config) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Configure connection pool
	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	// Parse connection max lifetime
	connMaxLifetime, err := time.ParseDuration(cfg.DBConnMaxLifetime)
	if err != nil {
		log.Printf("Invalid DB connection max lifetime, using default 5m: %v", err)
		connMaxLifetime = 5 * time.Minute
	}

	sqlDB.SetMaxOpenConns(cfg.DBMaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.DBMaxIdleConns)
	sqlDB.SetConnMaxLifetime(connMaxLifetime)

	// Auto migrate
	err = db.AutoMigrate(
		&repository.AccountBalance{},
		&repository.SubBalance{},
	)
	if err != nil {
		return nil, err
	}

	return db, nil
}

func initRedis(cfg *config.Config) *redis.Client {
	// Parse Redis timeouts
	dialTimeout, err := time.ParseDuration(cfg.RedisDialTimeout)
	if err != nil {
		log.Printf("Invalid Redis dial timeout, using default 5s: %v", err)
		dialTimeout = 5 * time.Second
	}

	readTimeout, err := time.ParseDuration(cfg.RedisReadTimeout)
	if err != nil {
		log.Printf("Invalid Redis read timeout, using default 3s: %v", err)
		readTimeout = 3 * time.Second
	}

	writeTimeout, err := time.ParseDuration(cfg.RedisWriteTimeout)
	if err != nil {
		log.Printf("Invalid Redis write timeout, using default 3s: %v", err)
		writeTimeout = 3 * time.Second
	}

	rdb := redis.NewClient(&redis.Options{
		Addr:         cfg.RedisURL,
		PoolSize:     cfg.RedisPoolSize,
		MinIdleConns: cfg.RedisMinIdleConns,
		MaxRetries:   cfg.RedisMaxRetries,
		DialTimeout:  dialTimeout,
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
	})

	// Test connection
	ctx := context.Background()
	_, err = rdb.Ping(ctx).Result()
	if err != nil {
		log.Fatal("Failed to connect to Redis:", err)
	}

	return rdb
}

func setupRoutes(e *echo.Echo, h *handler.TransactionHandler) {
	api := e.Group("/api/v1")
	api.POST("/transaction", h.ProcessTransaction)
	api.GET("/balance/:account_id", h.GetBalance)
	api.GET("/pending/:account_id", h.GetPendingTransactions)
	api.GET("/health", h.HealthCheck)
}

func setupMonitoring(e *echo.Echo, cfg *config.Config) {
	// Basic metrics endpoint
	e.GET("/metrics", func(c echo.Context) error {
		// Simple metrics response
		metrics := map[string]interface{}{
			"app_name":    cfg.AppName,
			"app_version": cfg.AppVersion,
			"app_env":     cfg.AppEnv,
			"timestamp":   time.Now().Unix(),
			"uptime":      time.Since(time.Now()).String(), // This would be better with actual uptime tracking
		}
		return c.JSON(http.StatusOK, metrics)
	})

	// Health check with more details
	e.GET("/health/detailed", func(c echo.Context) error {
		health := map[string]interface{}{
			"status":    "healthy",
			"timestamp": time.Now().Unix(),
			"version":   cfg.AppVersion,
			"features": map[string]bool{
				"redis_fallback":    cfg.EnableRedisFallback,
				"circuit_breaker":   cfg.EnableCircuitBreaker,
				"data_consistency":  cfg.EnableDataConsistencyCheck,
				"auto_recovery":     cfg.EnableAutoRecovery,
				"graceful_shutdown": cfg.EnableGracefulShutdown,
				"rate_limiting":     cfg.EnableRateLimit,
				"monitoring":        cfg.EnableMetrics,
			},
		}
		return c.JSON(http.StatusOK, health)
	})
}

func setupTestRoutes(e *echo.Echo, cfg *config.Config, transactionHandler *handler.TransactionHandler) {
	// Test routes for development/testing
	test := e.Group("/test")

	// Test account creation
	test.POST("/accounts", transactionHandler.CreateAccount)

	// Test data cleanup
	test.DELETE("/cleanup", func(c echo.Context) error {
		if cfg.TestDataCleanup {
			// This would clean up test data
			response := map[string]interface{}{
				"message": "Test data cleanup enabled",
				"prefix":  cfg.TestAccountPrefix,
			}
			return c.JSON(http.StatusOK, response)
		}
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Test data cleanup is disabled",
		})
	})
}

// Custom middleware for concurrent request limiting
func concurrentRequestLimiter(maxConcurrent int) echo.MiddlewareFunc {
	semaphore := make(chan struct{}, maxConcurrent)

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			select {
			case semaphore <- struct{}{}:
				defer func() { <-semaphore }()
				return next(c)
			default:
				return c.JSON(http.StatusTooManyRequests, map[string]string{
					"error": "Too many concurrent requests",
				})
			}
		}
	}
}

// Custom middleware for rate limiting
func rateLimiter(requests int, window time.Duration) echo.MiddlewareFunc {
	// Simple in-memory rate limiter (in production, use Redis)
	requestsPerWindow := make(map[string][]time.Time)

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			clientIP := c.RealIP()
			now := time.Now()

			// Clean old requests
			if timestamps, exists := requestsPerWindow[clientIP]; exists {
				var validTimestamps []time.Time
				for _, ts := range timestamps {
					if now.Sub(ts) < window {
						validTimestamps = append(validTimestamps, ts)
					}
				}
				requestsPerWindow[clientIP] = validTimestamps
			}

			// Check if limit exceeded
			if len(requestsPerWindow[clientIP]) >= requests {
				return c.JSON(http.StatusTooManyRequests, map[string]string{
					"error": "Rate limit exceeded",
				})
			}

			// Add current request
			requestsPerWindow[clientIP] = append(requestsPerWindow[clientIP], now)

			return next(c)
		}
	}
}
