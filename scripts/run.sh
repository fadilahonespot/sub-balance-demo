#!/bin/bash

# Run script for sub-balance demo

echo "🚀 Starting Sub-Balance Demo System"
echo "==================================="

# Load environment variables
if [ -f .env ]; then
    echo "📝 Loading environment variables from .env..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  .env file not found, using default values..."
fi

# Check if services are running
echo "🔍 Checking services..."

# Check PostgreSQL
if ! docker-compose ps postgres | grep -q "Up"; then
    echo "🐳 Starting PostgreSQL..."
    docker-compose up -d postgres
    sleep 5
fi

# Check Redis
if ! docker-compose ps redis | grep -q "Up"; then
    echo "🐳 Starting Redis..."
    docker-compose up -d redis
    sleep 5
fi

echo "✅ Services are running"

# Build application
echo "🔨 Building application..."
go build -o bin/sub-balance-demo main.go

# Start application
echo "🚀 Starting application..."
echo "Server will be available at: http://localhost:${PORT:-8080}"
echo "Press Ctrl+C to stop"
echo ""

./bin/sub-balance-demo
