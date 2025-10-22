#!/usr/bin/env bash
# RTX 4080 Setup Script for Singularity
# Run this on your Windows machine with RTX 4080

set -e

echo "🚀 Setting up Singularity on RTX 4080..."

# Check if running in WSL2
if [[ ! -f /proc/version ]] || ! grep -q "Microsoft" /proc/version; then
    echo "❌ This script must be run in WSL2 on Windows"
    exit 1
fi

# Check GPU
echo "🔍 Checking GPU..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA drivers not found. Install NVIDIA drivers in Windows first."
    exit 1
fi

nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits
echo "✅ GPU detected!"

# Install Nix if not present
if ! command -v nix &> /dev/null; then
    echo "📦 Installing Nix..."
    curl -L https://nixos.org/nix/install | sh
    . ~/.nix-profile/etc/profile.d/nix.sh
fi

# Enable flakes
echo "⚙️  Configuring Nix..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
echo "extra-substituters = https://mikkihugo.cachix.org" >> ~/.config/nix/nix.conf
echo "extra-trusted-public-keys = mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po=" >> ~/.config/nix/nix.conf

# Clone repo if not present
if [[ ! -d "singularity-incubation" ]]; then
    echo "📥 Cloning Singularity..."
    git clone https://github.com/mikkihugo/singularity-incubation.git
fi

cd singularity-incubation

# Test the setup
echo "🧪 Testing RTX 4080 setup..."
nix develop .#prod --command bash -c '
    echo "🎮 RTX 4080 Environment loaded!"
    echo "CUDA Version: $(nvcc --version | grep "release" | sed -n -e "s/^.*release \([0-9]\+\.[0-9]\+\).*$/\1/p")"
    echo "GPU Memory: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits) MB"
    python3 -c "import torch; print(f\'PyTorch CUDA: {torch.cuda.is_available()}\')" 2>/dev/null || echo "PyTorch not available yet"
'

echo ""
echo "✅ RTX 4080 setup complete!"
echo ""
echo "🚀 Next steps:"
echo "1. Run: nix develop .#prod"
echo "2. Start services: just start-all"
echo "3. Access from macOS: http://[WSL2_IP]:4000"
echo ""
echo "🎯 Your RTX 4080 is now a production ML server!"