#!/usr/bin/env bash
# Deploy to fly.io using pure Nix (no Docker)
set -e

APP_NAME="${1:-oneshot}"
DEPLOYMENT_TYPE="${2:-integrated}"  # integrated or ai-server-only

echo "🚀 Deploying to fly.io with Nix..."
echo "App: $APP_NAME"
echo "Type: $DEPLOYMENT_TYPE"
echo ""

# Check if nix is available
if ! command -v nix &> /dev/null; then
    echo "❌ Nix not found. Install from: https://nixos.org/download.html"
    exit 1
fi

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
if [ "$DEPLOYMENT_TYPE" = "integrated" ]; then
    if [ -f "./ai-server/scripts/bundle-credentials.sh" ]; then
        cd ai-server
        ./scripts/bundle-credentials.sh ../.env.fly
        cd ..
    fi
else
    if [ -f "./ai-server/scripts/bundle-credentials.sh" ]; then
        ./ai-server/scripts/bundle-credentials.sh
    fi
fi

# Build with Nix
echo "🔨 Building with Nix..."
if [ "$DEPLOYMENT_TYPE" = "integrated" ]; then
    nix build .#oneshot-integrated --show-trace
    PACKAGE="oneshot-integrated"
else
    nix build .#ai-server --show-trace
    PACKAGE="ai-server"
fi

# Create Nix closure for fly.io
echo "📦 Creating deployment closure..."
CLOSURE_PATH=$(mktemp -d)
nix-store --export $(nix-store -qR result) > "$CLOSURE_PATH/closure.nar"

# Create fly.io launcher script
cat > "$CLOSURE_PATH/launcher.sh" << 'EOF'
#!/usr/bin/env bash
# Import Nix closure and run the app
nix-store --import < /closure.nar
if [ "$PROCESS_NAME" = "web" ]; then
    exec /result/bin/web
elif [ "$PROCESS_NAME" = "ai-server" ]; then
    exec /result/bin/ai-server
else
    exec /result/bin/start-oneshot
fi
EOF
chmod +x "$CLOSURE_PATH/launcher.sh"

echo ""
echo "✅ Nix build complete: ./result"
echo ""
echo "⚠️  Note: fly.io doesn't natively support Nix closures yet."
echo "   Using nixpacks builder instead..."
echo ""

# Use nixpacks for fly.io deployment
if [ "$DEPLOYMENT_TYPE" = "integrated" ]; then
    CONFIG="fly-integrated.toml"
else
    CONFIG="fly.toml"
fi

# Check if app exists
if flyctl apps list | grep -q "$APP_NAME"; then
    echo "✓ App $APP_NAME exists"
else
    echo "📝 Creating app $APP_NAME..."
    flyctl apps create "$APP_NAME" --org personal
fi

# Create volume if needed
if [ "$DEPLOYMENT_TYPE" = "integrated" ]; then
    VOL_NAME="oneshot_data"
else
    VOL_NAME="ai_providers_data"
fi

if ! flyctl volumes list -a "$APP_NAME" | grep -q "$VOL_NAME"; then
    echo "💾 Creating persistent volume..."
    flyctl volumes create "$VOL_NAME" --size 1 --region iad -a "$APP_NAME"
fi

# Set secrets if .env.fly exists
if [ -f ".env.fly" ]; then
    echo "🔐 Setting secrets..."
    flyctl secrets set --app "$APP_NAME" \
      GOOGLE_APPLICATION_CREDENTIALS_JSON="$(grep GOOGLE .env.fly | cut -d= -f2)" \
      CLAUDE_ACCESS_TOKEN="$(grep CLAUDE .env.fly | cut -d= -f2)" \
      CURSOR_AUTH_JSON="$(grep CURSOR .env.fly | cut -d= -f2)" \
      GH_TOKEN="$(grep GH_TOKEN .env.fly | cut -d= -f2)" \
      --stage

    flyctl secrets deploy -a "$APP_NAME"
fi

# Deploy using nixpacks
echo "🚢 Deploying with nixpacks..."
flyctl deploy \
  --app "$APP_NAME" \
  --config "$CONFIG" \
  --nixpacks

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔗 App URL: https://$APP_NAME.fly.dev"
echo "📊 Status: flyctl status -a $APP_NAME"
echo "📝 Logs: flyctl logs -a $APP_NAME"
echo ""
echo "Test the deployment:"
if [ "$DEPLOYMENT_TYPE" = "integrated" ]; then
    echo "  Web: curl https://$APP_NAME.fly.dev/"
    echo "  AI: curl https://$APP_NAME.fly.dev:3000/health (internal only)"
else
    echo "  curl https://$APP_NAME.fly.dev/health"
fi
echo ""

# Cleanup
rm -rf "$CLOSURE_PATH"
