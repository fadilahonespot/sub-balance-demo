package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	// Database Configuration
	DatabaseURL       string
	DBMaxOpenConns    int
	DBMaxIdleConns    int
	DBConnMaxLifetime string

	// Redis Configuration
	RedisURL          string
	RedisKeyPrefix    string
	RedisKeyExpiry    int
	RedisPoolSize     int
	RedisMinIdleConns int
	RedisMaxRetries   int
	RedisDialTimeout  string
	RedisReadTimeout  string
	RedisWriteTimeout string

	// Server Configuration
	Port              string
	RequestTimeout    string
	ReadTimeout       string
	WriteTimeout      string
	MaxConcurrentReqs int

	// Application Configuration
	AppName    string
	AppVersion string
	AppEnv     string
	LogLevel   string
	LogFormat  string

	// Settlement Configuration
	SettlementInterval  string
	SettlementBatchSize int

	// Circuit Breaker Configuration
	CircuitBreakerFailureThreshold int
	CircuitBreakerTimeout          string

	// Health Check Configuration
	HealthCheckInterval string
	HealthCheckTimeout  string

	// Data Consistency Configuration
	ConsistencyCheckInterval string
	ConsistencyCheckTimeout  string

	// Monitoring Configuration
	EnableMetrics   bool
	MetricsPort     string
	EnableTracing   bool
	TracingEndpoint string

	// Security Configuration
	EnableCORS  bool
	CORSOrigins string
	CORSMethods string
	CORSHeaders string

	// Rate Limiting Configuration
	EnableRateLimit   bool
	RateLimitRequests int
	RateLimitWindow   string

	// Development Configuration
	DebugMode   bool
	EnablePprof bool
	PprofPort   string

	// Testing Configuration
	EnableTestMode    bool
	TestAccountPrefix string
	TestDataCleanup   bool

	// Feature Flags
	EnableRedisFallback        bool
	EnableCircuitBreaker       bool
	EnableDataConsistencyCheck bool
	EnableAutoRecovery         bool
	EnableGracefulShutdown     bool
}

func Load() *Config {
	// Load .env file
	err := godotenv.Load()
	if err != nil {
		log.Println("Warning: .env file not found, using system environment variables")
	}

	return &Config{
		// Database Configuration
		DatabaseURL:       getEnv("DATABASE_URL", "postgres://ahmadfadilah:postgres@localhost:5432/subbalance?sslmode=disable"),
		DBMaxOpenConns:    getEnvInt("DB_MAX_OPEN_CONNS", 25),
		DBMaxIdleConns:    getEnvInt("DB_MAX_IDLE_CONNS", 25),
		DBConnMaxLifetime: getEnv("DB_CONN_MAX_LIFETIME", "5m"),

		// Redis Configuration
		RedisURL:          getEnv("REDIS_URL", "localhost:6379"),
		RedisKeyPrefix:    getEnv("REDIS_KEY_PREFIX", "subbalance"),
		RedisKeyExpiry:    getEnvInt("REDIS_KEY_EXPIRY", 30),
		RedisPoolSize:     getEnvInt("REDIS_POOL_SIZE", 10),
		RedisMinIdleConns: getEnvInt("REDIS_MIN_IDLE_CONNS", 5),
		RedisMaxRetries:   getEnvInt("REDIS_MAX_RETRIES", 3),
		RedisDialTimeout:  getEnv("REDIS_DIAL_TIMEOUT", "5s"),
		RedisReadTimeout:  getEnv("REDIS_READ_TIMEOUT", "3s"),
		RedisWriteTimeout: getEnv("REDIS_WRITE_TIMEOUT", "3s"),

		// Server Configuration
		Port:              getEnv("PORT", "8080"),
		RequestTimeout:    getEnv("REQUEST_TIMEOUT", "30s"),
		ReadTimeout:       getEnv("READ_TIMEOUT", "10s"),
		WriteTimeout:      getEnv("WRITE_TIMEOUT", "10s"),
		MaxConcurrentReqs: getEnvInt("MAX_CONCURRENT_REQUESTS", 1000),

		// Application Configuration
		AppName:    getEnv("APP_NAME", "sub-balance-system"),
		AppVersion: getEnv("APP_VERSION", "1.0.0"),
		AppEnv:     getEnv("APP_ENV", "development"),
		LogLevel:   getEnv("LOG_LEVEL", "info"),
		LogFormat:  getEnv("LOG_FORMAT", "json"),

		// Settlement Configuration
		SettlementInterval:  getEnv("SETTLEMENT_INTERVAL", "5s"),
		SettlementBatchSize: getEnvInt("SETTLEMENT_BATCH_SIZE", 100),

		// Circuit Breaker Configuration
		CircuitBreakerFailureThreshold: getEnvInt("CIRCUIT_BREAKER_FAILURE_THRESHOLD", 3),
		CircuitBreakerTimeout:          getEnv("CIRCUIT_BREAKER_TIMEOUT", "30s"),

		// Health Check Configuration
		HealthCheckInterval: getEnv("HEALTH_CHECK_INTERVAL", "5s"),
		HealthCheckTimeout:  getEnv("HEALTH_CHECK_TIMEOUT", "2s"),

		// Data Consistency Configuration
		ConsistencyCheckInterval: getEnv("CONSISTENCY_CHECK_INTERVAL", "30s"),
		ConsistencyCheckTimeout:  getEnv("CONSISTENCY_CHECK_TIMEOUT", "10s"),

		// Monitoring Configuration
		EnableMetrics:   getEnvBool("ENABLE_METRICS", true),
		MetricsPort:     getEnv("METRICS_PORT", "9090"),
		EnableTracing:   getEnvBool("ENABLE_TRACING", true),
		TracingEndpoint: getEnv("TRACING_ENDPOINT", "http://localhost:14268/api/traces"),

		// Security Configuration
		EnableCORS:  getEnvBool("ENABLE_CORS", true),
		CORSOrigins: getEnv("CORS_ORIGINS", "*"),
		CORSMethods: getEnv("CORS_METHODS", "GET,POST,PUT,DELETE,OPTIONS"),
		CORSHeaders: getEnv("CORS_HEADERS", "Content-Type,Authorization"),

		// Rate Limiting Configuration
		EnableRateLimit:   getEnvBool("ENABLE_RATE_LIMIT", true),
		RateLimitRequests: getEnvInt("RATE_LIMIT_REQUESTS", 100),
		RateLimitWindow:   getEnv("RATE_LIMIT_WINDOW", "1m"),

		// Development Configuration
		DebugMode:   getEnvBool("DEBUG_MODE", true),
		EnablePprof: getEnvBool("ENABLE_PPROF", false),
		PprofPort:   getEnv("PPROF_PORT", "6060"),

		// Testing Configuration
		EnableTestMode:    getEnvBool("ENABLE_TEST_MODE", false),
		TestAccountPrefix: getEnv("TEST_ACCOUNT_PREFIX", "TEST_"),
		TestDataCleanup:   getEnvBool("TEST_DATA_CLEANUP", true),

		// Feature Flags
		EnableRedisFallback:        getEnvBool("ENABLE_REDIS_FALLBACK", true),
		EnableCircuitBreaker:       getEnvBool("ENABLE_CIRCUIT_BREAKER", true),
		EnableDataConsistencyCheck: getEnvBool("ENABLE_DATA_CONSISTENCY_CHECK", true),
		EnableAutoRecovery:         getEnvBool("ENABLE_AUTO_RECOVERY", true),
		EnableGracefulShutdown:     getEnvBool("ENABLE_GRACEFUL_SHUTDOWN", true),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}
