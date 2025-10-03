#!/usr/bin/env bash
# Deploy AI Server to fly.io with Nix
set -e

APP_NAME="${1:-singularity-ai-providers}"

echo "🚀 Deploying AI Server to fly.io..."
echo "App: $APP_NAME"
echo ""

# Check if flyctl is installed
if ! command -v flyctl &> /dev/null; then
    echo "❌ flyctl not found. Install with: curl -L https://fly.io/install.sh | sh"
    exit 1
fi

# Check if logged in
if ! flyctl auth whoami &> /dev/null; then
    echo "🔐 Please login to fly.io first:"
    flyctl auth login
fi

# Bundle credentials
echo "📦 Bundling credentials..."
if [ -f "./scripts/bundle-credentials.sh" ]; then
    ./scripts/bundle-credentials.sh .env.fly
else
    echo "⚠️  Warning: bundle-credentials.sh not found, skipping..."
fi

# Check if app exists
if flyctl apps list | grep -q "$APP_NAME"; then
    echo "✓ App $APP_NAME exists"
else
    echo "📝 Creating app $APP_NAME..."
    flyctl apps create "$APP_NAME" --org personal
fi

# Create volume for persistent data if it doesn't exist
if ! flyctl volumes list -a "$APP_NAME" | grep -q "ai_providers_data"; then
    echo "💾 Creating persistent volume..."
    flyctl volumes create ai_providers_data --size 1 --region iad -a "$APP_NAME"
fi

# Set secrets from bundled credentials
if [ -f ".env.fly" ]; then
    echo "🔐 Setting secrets..."

    # Read each line from .env.fly and set as secret
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        echo "  Setting secret: $key"
        flyctl secrets set "$key=$value" -a "$APP_NAME" --stage
    done < .env.fly

    # Deploy secrets
    flyctl secrets deploy -a "$APP_NAME"
else
    echo "⚠️  No .env.fly file found. Set secrets manually with:"
    echo "    flyctl secrets set GOOGLE_APPLICATION_CREDENTIALS_JSON=<base64> -a $APP_NAME"
    echo "    flyctl secrets set CLAUDE_ACCESS_TOKEN=<token> -a $APP_NAME"
    echo "    flyctl secrets set CURSOR_AUTH_JSON=<base64> -a $APP_NAME"
    echo "    flyctl secrets set GH_TOKEN=<token> -a $APP_NAME"
fi

# Deploy the application
echo "🚢 Deploying application..."
flyctl deploy \
  --app "$APP_NAME" \
  --dockerfile Dockerfile.nix \
  --ha=false

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔗 App URL: https://$APP_NAME.fly.dev"
echo "📊 Status: flyctl status -a $APP_NAME"
echo "📝 Logs: flyctl logs -a $APP_NAME"
echo "🔍 SSH: flyctl ssh console -a $APP_NAME"
echo ""
echo "Test the deployment:"
echo "  curl https://$APP_NAME.fly.dev/health"
echo ""
