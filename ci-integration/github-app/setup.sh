#!/bin/bash
# Singularity GitHub App Setup Script

set -e

echo "🚀 Setting up Singularity GitHub App..."

# Check if required tools are installed
command -v mix >/dev/null 2>&1 || { echo "❌ Elixir/mix is required but not installed. Aborting."; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ Node.js/npm is required but not installed. Aborting."; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "❌ PostgreSQL client is required but not installed. Aborting."; exit 1; }

# Install Elixir dependencies
echo "📦 Installing Elixir dependencies..."
mix deps.get

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm --prefix assets ci

# Setup database
echo "🗄️ Setting up database..."
if [ -z "$DATABASE_URL" ]; then
    echo "⚠️  DATABASE_URL not set, using default PostgreSQL connection"
    mix ecto.create
    mix ecto.migrate
else
    echo "✅ Using DATABASE_URL from environment"
    mix ecto.create
    mix ecto.migrate
fi

# Create uploads directory
echo "📁 Creating uploads directory..."
mkdir -p priv/static/uploads

# Generate secret key base if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    echo "🔑 Generating SECRET_KEY_BASE..."
    SECRET_KEY_BASE=$(mix phx.gen.secret)
    echo "⚠️  Add this to your environment variables:"
    echo "export SECRET_KEY_BASE=$SECRET_KEY_BASE"
fi

# Setup GitHub App (if credentials provided)
if [ -n "$GITHUB_APP_ID" ] && [ -n "$GITHUB_PRIVATE_KEY" ]; then
    echo "🔐 Setting up GitHub App integration..."
    # Validate private key format
    if echo "$GITHUB_PRIVATE_KEY" | grep -q "BEGIN RSA PRIVATE KEY"; then
        echo "✅ GitHub private key format looks correct"
    else
        echo "⚠️  GitHub private key format may be incorrect"
    fi
else
    echo "⚠️  GitHub App credentials not provided"
    echo "   Set GITHUB_APP_ID and GITHUB_PRIVATE_KEY environment variables"
fi

# Build assets
echo "🏗️ Building assets..."
npm run --prefix assets deploy
mix phx.digest

echo ""
echo "✅ Setup complete!"
echo ""
echo "🚀 To start the development server:"
echo "   mix phx.server"
echo ""
echo "🌐 The app will be available at http://localhost:4000"
echo ""
echo "📚 For production deployment:"
echo "   MIX_ENV=prod mix release"
echo ""
echo "🔧 Environment variables needed:"
echo "   - DATABASE_URL (PostgreSQL connection string)"
echo "   - SECRET_KEY_BASE (Phoenix secret key)"
echo "   - GITHUB_APP_ID (GitHub App ID)"
echo "   - GITHUB_PRIVATE_KEY (GitHub App private key)"
echo "   - GITHUB_WEBHOOK_SECRET (GitHub webhook secret)"
echo ""
echo "📖 See README.md for detailed setup instructions"