#!/bin/bash

# Stop script for sub-balance demo

echo "🛑 Stopping Sub-Balance Demo System"
echo "==================================="

# Stop application if running
echo "🔄 Stopping application..."
pkill -f "sub-balance-demo" 2>/dev/null || echo "Application not running"

# Stop Docker services
echo "🐳 Stopping Docker services..."
docker-compose down

echo "✅ All services stopped"
echo ""
echo "💡 To start again, run:"
echo "   ./scripts/setup.sh"
echo "   ./scripts/run.sh"
