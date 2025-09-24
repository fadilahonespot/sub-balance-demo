# Makefile for Sub-Balance Demo Project
# Provides easy commands for development, testing, and deployment

.PHONY: help build run test clean setup install deps docker-up docker-down logs

# Default target
.DEFAULT_GOAL := help

# Configuration
APP_NAME := sub-balance-demo
DOCKER_COMPOSE := docker-compose
GO := go
PORT := 8080
TEST_ACCOUNT := ACC001

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Sub-Balance Demo Project$(NC)"
	@echo "=========================="
	@echo ""
	@echo "$(YELLOW)🚀 Main Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /setup|build|run|test|clean/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)🧪 Testing Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /test-|setup-|reset-|status-/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)🔧 Utility Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && !/setup|build|run|test|clean|test-|setup-|reset-|status-/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make setup    # Setup environment and dependencies"
	@echo "  make run      # Start the application"
	@echo "  make test     # Run TPS performance tests"
	@echo ""

setup: ## Setup environment and dependencies
	@echo "$(BLUE)🔧 Setting up environment...$(NC)"
	@./scripts/setup-env.sh
	@echo "$(GREEN)✅ Environment setup completed$(NC)"

install: ## Install Go dependencies
	@echo "$(BLUE)📦 Installing dependencies...$(NC)"
	@$(GO) mod download
	@$(GO) mod tidy
	@echo "$(GREEN)✅ Dependencies installed$(NC)"

deps: install ## Alias for install

build: ## Build the application
	@echo "$(BLUE)🔨 Building application...$(NC)"
	@$(GO) build -o bin/$(APP_NAME) .
	@echo "$(GREEN)✅ Application built: bin/$(APP_NAME)$(NC)"

run: ## Run the application
	@echo "$(BLUE)🚀 Starting application...$(NC)"
	@./scripts/run-with-config.sh

dev: ## Run in development mode with auto-reload
	@echo "$(BLUE)🔄 Starting development server...$(NC)"
	@$(GO) run main.go

start: run ## Alias for run

stop: ## Stop the application
	@echo "$(BLUE)⏹️  Stopping application...$(NC)"
	@pkill -f "go run main.go" || true
	@pkill -f "$(APP_NAME)" || true
	@echo "$(GREEN)✅ Application stopped$(NC)"

docker-up: ## Start Docker services (PostgreSQL, Redis)
	@echo "$(BLUE)🐳 Starting Docker services...$(NC)"
	@$(DOCKER_COMPOSE) up -d postgres redis
	@echo "$(GREEN)✅ Docker services started$(NC)"
	@echo "$(YELLOW)💡 Wait a few seconds for services to be ready$(NC)"

docker-down: ## Stop Docker services
	@echo "$(BLUE)🐳 Stopping Docker services...$(NC)"
	@$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✅ Docker services stopped$(NC)"

docker-restart: docker-down docker-up ## Restart Docker services

logs: ## Show application logs
	@echo "$(BLUE)📝 Showing application logs...$(NC)"
	@$(DOCKER_COMPOSE) logs -f app

logs-db: ## Show database logs
	@echo "$(BLUE)📝 Showing database logs...$(NC)"
	@$(DOCKER_COMPOSE) logs -f postgres

logs-redis: ## Show Redis logs
	@echo "$(BLUE)📝 Showing Redis logs...$(NC)"
	@$(DOCKER_COMPOSE) logs -f redis

# Test commands
test: ## Run comprehensive TPS performance tests with detailed report
	@echo "$(BLUE)🧪 Running comprehensive TPS performance tests...$(NC)"
	@./scripts/test-tps-comprehensive.sh

test-simple: ## Run simple TPS performance tests (auto reset balance)
	@echo "$(BLUE)🧪 Running simple TPS performance tests with auto balance reset...$(NC)"
	@./scripts/test-tps-complete.sh --reset

test-multi: ## Run multi-account TPS performance tests (5 accounts)
	@echo "$(BLUE)🧪 Running multi-account TPS performance tests...$(NC)"
	@./scripts/test-tps-multi-account.sh

test-multi-simple: ## Run simple multi-account TPS performance tests (5 accounts, precise timing)
	@echo "$(BLUE)🧪 Running simple multi-account TPS performance tests...$(NC)"
	@./scripts/test-tps-multi-account-simple.sh

test-redis-failure: ## Run Redis failure and recovery test (simulated)
	@echo "$(BLUE)🧪 Running Redis failure and recovery test (simulated)...$(NC)"
	@./scripts/test-redis-failure-recovery.sh

test-redis-failure-real: ## Run Redis failure and recovery test (real Redis stop/start)
	@echo "$(BLUE)🧪 Running Redis failure and recovery test (real)...$(NC)"
	@./scripts/test-redis-failure-real.sh

setup-multi: ## Setup 5 test accounts for multi-account testing
	@echo "$(BLUE)👥 Setting up 5 test accounts...$(NC)"
	@./scripts/setup-multi-accounts.sh setup

reset-multi: ## Reset all 5 test accounts to initial balance
	@echo "$(BLUE)🔄 Resetting all test accounts...$(NC)"
	@./scripts/setup-multi-accounts.sh reset

status-multi: ## Check status of all 5 test accounts
	@echo "$(BLUE)📊 Checking account status...$(NC)"
	@./scripts/setup-multi-accounts.sh status

optimize-db: ## Optimize database with advanced indexing for high TPS performance
	@echo "$(BLUE)🚀 Optimizing database for high TPS performance...$(NC)"
	@./scripts/optimize_database.sh

monitor-db: ## Monitor database index performance and usage
	@echo "$(BLUE)📊 Monitoring database performance...$(NC)"
	@psql -h localhost -U ahmadfadilah -d subbalance -f scripts/monitor_index_performance.sql

test-setup: ## Setup test data
	@echo "$(BLUE)🔧 Setting up test data...$(NC)"
	@./scripts/setup-test-data.sh create
	@echo "$(GREEN)✅ Test data setup completed$(NC)"

test-status: ## Check test account status
	@echo "$(BLUE)📊 Checking test account status...$(NC)"
	@./scripts/setup-test-data.sh status

test-clean: ## Clean test data
	@echo "$(BLUE)🧹 Cleaning test data...$(NC)"
	@./scripts/setup-test-data.sh cleanup

test-reset: ## Reset test account balance
	@echo "$(BLUE)🔄 Resetting test account balance...$(NC)"
	@./scripts/setup-test-data.sh create -a $(TEST_ACCOUNT) -b 1000000
	@echo "$(GREEN)✅ Test account balance reset$(NC)"

# Development commands
dev-setup: docker-up setup ## Complete development setup
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo "$(YELLOW)💡 Run 'make run' to start the application$(NC)"
	@echo "$(YELLOW)💡 Run 'make test' to run TPS tests$(NC)"

dev-full: dev-setup run ## Complete development setup and run

# Health check commands
health: ## Check application health
	@echo "$(BLUE)🏥 Checking application health...$(NC)"
	@curl -s http://localhost:$(PORT)/api/v1/health | jq . || echo "$(RED)❌ Application not responding$(NC)"

health-detailed: ## Check detailed application health
	@echo "$(BLUE)🏥 Checking detailed application health...$(NC)"
	@curl -s http://localhost:$(PORT)/health/detailed | jq . || echo "$(RED)❌ Application not responding$(NC)"

balance: ## Check test account balance
	@echo "$(BLUE)💰 Checking test account balance...$(NC)"
	@curl -s http://localhost:$(PORT)/api/v1/balance/$(TEST_ACCOUNT) | jq . || echo "$(RED)❌ Cannot get balance$(NC)"

pending: ## Check pending transactions
	@echo "$(BLUE)⏳ Checking pending transactions...$(NC)"
	@curl -s http://localhost:$(PORT)/api/v1/pending/$(TEST_ACCOUNT) | jq . || echo "$(RED)❌ Cannot get pending transactions$(NC)"

# Cleanup commands
clean: ## Clean build artifacts
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(NC)"
	@rm -rf bin/
	@rm -rf reports/
	@$(GO) clean
	@echo "$(GREEN)✅ Build artifacts cleaned$(NC)"

clean-reports: ## Clean test reports
	@echo "$(BLUE)🧹 Cleaning test reports...$(NC)"
	@rm -rf reports/
	@echo "$(GREEN)✅ Test reports cleaned$(NC)"

clean-all: clean docker-down ## Clean everything including Docker
	@echo "$(GREEN)✅ Everything cleaned$(NC)"

# Database commands
db-reset: ## Reset database
	@echo "$(BLUE)🗄️  Resetting database...$(NC)"
	@$(DOCKER_COMPOSE) down -v
	@$(DOCKER_COMPOSE) up -d postgres redis
	@echo "$(GREEN)✅ Database reset completed$(NC)"

db-migrate: ## Run database migrations
	@echo "$(BLUE)🗄️  Running database migrations...$(NC)"
	@$(GO) run main.go --migrate-only || echo "$(YELLOW)⚠️  Migration not implemented$(NC)"

# Monitoring commands
monitor: ## Monitor application metrics
	@echo "$(BLUE)📊 Monitoring application metrics...$(NC)"
	@curl -s http://localhost:$(PORT)/metrics | jq . || echo "$(RED)❌ Metrics not available$(NC)"

# Configuration commands
config: ## Show current configuration
	@echo "$(BLUE)⚙️  Current configuration:$(NC)"
	@echo "  App Name: $(APP_NAME)"
	@echo "  Port: $(PORT)"
	@echo "  Test Account: $(TEST_ACCOUNT)"
	@echo "  Docker Compose: $(DOCKER_COMPOSE)"
	@echo "  Go Version: $$($(GO) version | cut -d' ' -f3)"

env: ## Show environment variables
	@echo "$(BLUE)🌍 Environment variables:$(NC)"
	@env | grep -E "(DATABASE_URL|REDIS_URL|PORT|APP_)" | sort

# Quick commands
quick-test: test ## Quick test (alias for test)
	@echo "$(GREEN)✅ Quick test completed$(NC)"


quick-start: docker-up run ## Quick start with Docker and run

# Development workflow
dev-workflow: ## Complete development workflow
	@echo "$(BLUE)🔄 Starting development workflow...$(NC)"
	@make docker-up
	@sleep 5
	@make setup
	@make test-setup
	@make run

# Production commands
prod-build: ## Build for production
	@echo "$(BLUE)🏭 Building for production...$(NC)"
	@CGO_ENABLED=0 GOOS=linux $(GO) build -a -installsuffix cgo -o bin/$(APP_NAME) .
	@echo "$(GREEN)✅ Production build completed$(NC)"

prod-run: prod-build ## Build and run for production
	@echo "$(BLUE)🏭 Running production build...$(NC)"
	@./bin/$(APP_NAME)

# Utility commands
check: ## Check if all dependencies are available
	@echo "$(BLUE)🔍 Checking dependencies...$(NC)"
	@command -v $(GO) >/dev/null 2>&1 || { echo "$(RED)❌ Go is not installed$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ Docker is not installed$(NC)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)❌ Docker Compose is not installed$(NC)"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "$(RED)❌ jq is not installed$(NC)"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "$(RED)❌ curl is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✅ All dependencies are available$(NC)"

version: ## Show version information
	@echo "$(BLUE)📋 Version Information:$(NC)"
	@echo "  Go Version: $$($(GO) version | cut -d' ' -f3)"
	@echo "  Docker Version: $$(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
	@echo "  Docker Compose Version: $$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
	@echo "  jq Version: $$(jq --version)"
	@echo "  curl Version: $$(curl --version | head -1 | cut -d' ' -f2)"

# Documentation commands
docs: ## Generate documentation
	@echo "$(BLUE)📚 Generating documentation...$(NC)"
	@echo "$(YELLOW)⚠️  Documentation generation not implemented$(NC)"

# Security commands
security: ## Run security checks
	@echo "$(BLUE)🔒 Running security checks...$(NC)"
	@$(GO) list -json -deps ./... | nancy sleuth || echo "$(YELLOW)⚠️  Nancy not installed$(NC)"

# Performance commands
benchmark: ## Run benchmarks
	@echo "$(BLUE)⚡ Running benchmarks...$(NC)"
	@$(GO) test -bench=. ./... || echo "$(YELLOW)⚠️  No benchmarks found$(NC)"

# Linting commands
lint: ## Run linter
	@echo "$(BLUE)🔍 Running linter...$(NC)"
	@$(GO) vet ./... || echo "$(YELLOW)⚠️  Go vet found issues$(NC)"

fmt: ## Format code
	@echo "$(BLUE)🎨 Formatting code...$(NC)"
	@$(GO) fmt ./...
	@echo "$(GREEN)✅ Code formatted$(NC)"

# Test coverage
coverage: ## Run tests with coverage
	@echo "$(BLUE)📊 Running tests with coverage...$(NC)"
	@$(GO) test -coverprofile=coverage.out ./...
	@$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✅ Coverage report generated: coverage.html$(NC)"

# All-in-one commands
all: check install build test ## Run all checks, build, and test
	@echo "$(GREEN)✅ All tasks completed successfully$(NC)"

fresh: clean-all dev-setup ## Fresh start - clean everything and setup
	@echo "$(GREEN)✅ Fresh environment ready$(NC)"

# Show available targets
targets: ## Show all available targets
	@echo "$(BLUE)📋 Available targets:$(NC)"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | uniq
