#!/bin/bash

# Reset database script for sub-balance demo

echo "🔄 Resetting Database for Sub-Balance Demo"
echo "=========================================="

# Stop services
echo "🛑 Stopping services..."
docker-compose down

# Remove volumes to start fresh
echo "🗑️ Removing database volumes..."
docker volume rm sub-balance-demo_postgres_data 2>/dev/null || echo "Volume not found"
docker volume rm sub-balance-demo_redis_data 2>/dev/null || echo "Volume not found"

# Start services
echo "🐳 Starting services..."
docker-compose up -d postgres redis

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 15

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
docker-compose exec postgres psql -U ahmadfadilah -d subbalance -f /docker-entrypoint-initdb.d/init-db.sql
echo "✅ Database initialized"

echo ""
echo "🎉 Database reset completed!"
echo ""
echo "📋 Next steps:"
echo "1. Start the application:"
echo "   ./scripts/run.sh"
echo ""
echo "2. Or run with Docker Compose:"
echo "   docker-compose up"
echo ""


