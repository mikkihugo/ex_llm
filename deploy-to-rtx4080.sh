#!/usr/bin/env bash
# Mac to RTX 4080 Deployment Script
# Run this on your Mac to deploy changes to RTX 4080

set -e

RTX4080_HOST="${RTX4080_HOST:-rtx4080.local}"  # Set your RTX 4080 IP/hostname
RTX4080_USER="${RTX4080_USER:-user}"          # Set your username on RTX 4080

echo "🚀 Deploying to RTX 4080 ($RTX4080_HOST)..."

# Check if we have uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  You have uncommitted changes. Commit them first:"
    echo "   git add . && git commit -m 'deployment'"
    exit 1
fi

# Push changes to git
echo "📤 Pushing changes to git..."
git push origin main

# Deploy to RTX 4080
echo "🔄 Updating RTX 4080..."
ssh "$RTX4080_USER@$RTX4080_HOST" << 'EOF'
    cd singularity-incubation || exit 1

    echo "📥 Pulling latest changes..."
    git pull origin main

    echo "🔧 Updating dependencies..."
    nix develop .#prod --command mix deps.get || true
    nix develop .#prod --command mix compile || true

    echo "🛑 Stopping existing services..."
    pkill -f "singularity" || true
    pkill -f "phoenix" || true
    pkill -f "ai-server" || true

    echo "🚀 Starting services with GPU..."
    nohup nix develop .#prod --command just start-all > singularity.log 2>&1 &

    echo "⏳ Waiting for services to start..."
    sleep 10

    echo "✅ Checking service status..."
    curl -s http://localhost:4000/health && echo " Phoenix: OK" || echo " Phoenix: FAILED"
    curl -s http://localhost:3000/health && echo " AI Server: OK" || echo " AI Server: FAILED"

    echo "🎮 GPU Status:"
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits || echo "GPU not available"
EOF

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Access your application:"
echo "   Phoenix:  http://$RTX4080_HOST:4000"
echo "   AI Server: http://$RTX4080_HOST:3000"
echo ""
echo "📊 Monitor logs:"
echo "   ssh $RTX4080_USER@$RTX4080_HOST 'tail -f singularity-incubation/singularity.log'"