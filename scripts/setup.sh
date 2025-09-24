#!/bin/bash

# Setup script for sub-balance demo

echo "🚀 Setting up Sub-Balance Demo System"
echo "======================================"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21+ first."
    exit 1
fi

echo "✅ Go version: $(go version)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

echo "✅ Docker version: $(docker --version)"

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker Compose version: $(docker-compose --version)"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from config.env..."
    cp config.env .env
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# Install dependencies
echo "📦 Installing Go dependencies..."
go mod tidy
echo "✅ Dependencies installed"

# Start services with Docker Compose
echo "🐳 Starting services with Docker Compose..."
docker-compose up -d postgres redis
echo "✅ Services started"

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if PostgreSQL is ready
echo "🔍 Checking PostgreSQL connection..."
until docker-compose exec postgres pg_isready -U ahmadfadilah -d subbalance; do
    echo "⏳ Waiting for PostgreSQL..."
    sleep 2
done
echo "✅ PostgreSQL is ready"

# Check if Redis is ready
echo "🔍 Checking Redis connection..."
until docker-compose exec redis redis-cli ping; do
    echo "⏳ Waiting for Redis..."
    sleep 2
done
echo "✅ Redis is ready"

# Initialize database
echo "🗄️ Initializing database..."
docker-compose exec postgres psql -U ahmadfadilah -d subbalance -f /docker-entrypoint-initdb.d/init-db.sql 2>/dev/null || echo "Database already initialized"
echo "✅ Database initialized"

# Build and start the application
echo "🔨 Building application..."
go build -o bin/sub-balance-demo main.go
echo "✅ Application built"

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Start the application:"
echo "   ./bin/sub-balance-demo"
echo ""
echo "2. Or run with Docker Compose:"
echo "   docker-compose up"
echo ""
echo "3. Test the API:"
echo "   ./scripts/test-load.sh"
echo ""
echo "4. Check health:"
echo "   curl http://localhost:${PORT:-8082}/api/v1/health"
echo ""
echo "📊 API Endpoints:"
echo "   POST /api/v1/transaction - Process transaction"
echo "   GET  /api/v1/balance/:account_id - Get balance"
echo "   GET  /api/v1/pending/:account_id - Get pending transactions"
echo "   GET  /api/v1/health - Health check"
echo ""
echo "🔧 Configuration:"
echo "   Edit .env file to change settings"
echo "   Default accounts: ACC001, ACC002, ACC003"
echo ""
