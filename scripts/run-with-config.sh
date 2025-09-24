#!/bin/bash

# Run application with full configuration
echo "🚀 Starting Sub-Balance System with Full Configuration"
echo "======================================================"

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating from environment.env..."
    if [ -f environment.env ]; then
        cp environment.env .env
        echo "✅ .env file created from environment.env"
    else
        echo "❌ environment.env not found. Please run ./scripts/setup-env.sh first"
        exit 1
    fi
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

echo "📋 Configuration Summary:"
echo "  - App Name: $APP_NAME"
echo "  - App Version: $APP_VERSION"
echo "  - App Environment: $APP_ENV"
echo "  - Server Port: $PORT"
echo "  - Database: $DATABASE_URL"
echo "  - Redis: $REDIS_URL"
echo "  - Debug Mode: $DEBUG_MODE"
echo "  - Test Mode: $ENABLE_TEST_MODE"
echo ""

echo "🔧 Feature Flags:"
echo "  - Redis Fallback: $ENABLE_REDIS_FALLBACK"
echo "  - Circuit Breaker: $ENABLE_CIRCUIT_BREAKER"
echo "  - Data Consistency: $ENABLE_DATA_CONSISTENCY_CHECK"
echo "  - Auto Recovery: $ENABLE_AUTO_RECOVERY"
echo "  - Graceful Shutdown: $ENABLE_GRACEFUL_SHUTDOWN"
echo "  - Rate Limiting: $ENABLE_RATE_LIMIT"
echo "  - Monitoring: $ENABLE_METRICS"
echo "  - CORS: $ENABLE_CORS"
echo ""

echo "⚡ Performance Settings:"
echo "  - Max Concurrent Requests: $MAX_CONCURRENT_REQUESTS"
echo "  - Rate Limit: $RATE_LIMIT_REQUESTS requests per $RATE_LIMIT_WINDOW"
echo "  - Settlement Interval: $SETTLEMENT_INTERVAL"
echo "  - Settlement Batch Size: $SETTLEMENT_BATCH_SIZE"
echo ""

echo "🏥 Health & Monitoring:"
echo "  - Health Check Interval: $HEALTH_CHECK_INTERVAL"
echo "  - Consistency Check Interval: $CONSISTENCY_CHECK_INTERVAL"
echo "  - Circuit Breaker Threshold: $CIRCUIT_BREAKER_FAILURE_THRESHOLD"
echo "  - Circuit Breaker Timeout: $CIRCUIT_BREAKER_TIMEOUT"
echo ""

# Check if Docker services are running
echo "🐳 Checking Docker services..."
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Docker services not running. Starting them..."
    docker-compose up -d postgres redis
    echo "⏳ Waiting for services to be ready..."
    sleep 10
fi

echo "✅ Starting application..."
echo ""

# Run the application
go run main.go
