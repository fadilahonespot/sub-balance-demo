#!/bin/bash

# Setup environment file script

echo "🔧 Setting up environment configuration"
echo "======================================"

# Check if .env already exists
if [ -f .env ]; then
    echo "⚠️  .env file already exists"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Setup cancelled"
        exit 1
    fi
fi

# Copy from environment.env
if [ -f environment.env ]; then
    echo "📝 Copying environment.env to .env..."
    cp environment.env .env
    echo "✅ .env file created successfully"
else
    echo "❌ environment.env file not found"
    exit 1
fi

# Check if config.env exists as fallback
if [ -f config.env ]; then
    echo "📝 config.env found as fallback"
    echo "💡 You can also use: cp config.env .env"
fi

echo ""
echo "🎉 Environment setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Review and customize .env file if needed"
echo "2. Start the application:"
echo "   ./scripts/run.sh"
echo ""
echo "🔧 Configuration files available:"
echo "   - .env (active configuration)"
echo "   - environment.env (full configuration template)"
echo "   - config.env (basic configuration template)"

