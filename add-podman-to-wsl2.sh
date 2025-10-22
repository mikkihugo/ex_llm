#!/usr/bin/env bash
# Add Podman to existing WSL2 RTX 4080 setup
# Run this in your WSL2 Ubuntu 24.04 environment (recommended)

set -e

echo "🐳 Adding Podman to RTX 4080 WSL2 setup..."

# Install Podman in WSL2
echo "📦 Installing Podman..."
sudo apt-get update
sudo apt-get install -y podman

# Configure Podman for rootless
echo "⚙️  Configuring rootless Podman..."
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER

# Enable podman socket
systemctl --user enable podman.socket
systemctl --user start podman.socket

# Test Podman
echo "🧪 Testing Podman..."
podman --version
podman info

# Test GPU support (limited in WSL2)
echo "🎮 Testing GPU support..."
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA GPU detected"
    # Try GPU-enabled container (may not work in WSL2)
    podman run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi || echo "⚠️  GPU passthrough not available in WSL2"
else
    echo "⚠️  No NVIDIA GPU detected"
fi

# Create Singularity container
echo "🏗️  Building Singularity container..."
cd singularity-incubation

# Build Nix container image
nix build .#dockerImage

# Load into Podman
echo "📦 Loading container image..."
podman load < result

# Tag the image
podman tag singularity-prod:latest localhost/singularity:latest

echo ""
echo "✅ Podman setup complete!"
echo ""
echo "🚀 Usage:"
echo "# Run Singularity container"
echo "podman run -p 4000:4000 -p 3000:3000 localhost/singularity:latest"
echo ""
echo "# Development (use WSL2 directly)"
echo "nix develop .#prod"
echo ""
echo "# Build new images"
echo "nix build .#dockerImage && podman load < result"