#!/bin/bash
# Singularity GitHub App - Production Deployment Script

set -e

echo "🚀 Deploying Singularity GitHub App to production..."

# Check if required environment variables are set
required_vars=("DATABASE_URL" "SECRET_KEY_BASE" "GITHUB_APP_ID" "GITHUB_PRIVATE_KEY" "GITHUB_WEBHOOK_SECRET")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set"
        exit 1
    fi
done

# Optional variables with defaults
DB_PASSWORD=${DB_PASSWORD:-"singularity"}
REDIS_URL=${REDIS_URL:-"redis://redis:6379"}

echo "✅ Environment variables validated"

# Build and start services
echo "🏗️ Building and starting services..."
docker-compose -f docker-compose.prod.yml down || true
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

echo "⏳ Waiting for services to be healthy..."
sleep 30

# Run database migrations
echo "🗄️ Running database migrations..."
docker-compose -f docker-compose.prod.yml exec -T app bin/singularity_github_app eval "Singularity.Release.migrate()"

# Verify deployment
echo "🔍 Verifying deployment..."
health_check=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")
if [ "$health_check" = "200" ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Application is running at:"
    echo "   - Health Check: http://localhost/health"
    echo "   - API: http://localhost/api"
    echo ""
    echo "📊 Monitoring:"
    echo "   - Logs: docker-compose -f docker-compose.prod.yml logs -f app"
    echo "   - Database: docker-compose -f docker-compose.prod.yml exec db psql -U singularity -d singularity_github_app"
    echo ""
    echo "🔧 Management:"
    echo "   - Restart: docker-compose -f docker-compose.prod.yml restart app"
    echo "   - Stop: docker-compose -f docker-compose.prod.yml down"
    echo "   - Update: docker-compose -f docker-compose.prod.yml pull && docker-compose -f docker-compose.prod.yml up -d"
else
    echo "❌ Health check failed (HTTP $health_check)"
    echo "📋 Checking logs..."
    docker-compose -f docker-compose.prod.yml logs app
    exit 1
fi

echo ""
echo "🎉 Singularity GitHub App is now live!"
echo "   Don't forget to configure your GitHub App webhook URL to point to this server."