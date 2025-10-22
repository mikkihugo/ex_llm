#!/bin/bash

# Setup Singularity Rust Service with Scheduling
# This script sets up the service to run automatically

set -e

echo "🚀 Setting up Singularity Rust Service with Scheduling..."

# Check if we're in the right directory
if [ ! -f "rust/Cargo.toml" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# Build the service
echo "🔨 Building singularity-rust-service..."
cd rust
cargo build --release --bin singularity-rust-service
cd ..

# Install systemd service
echo "📦 Installing systemd service..."
sudo cp singularity-rust.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable service to start on boot
echo "🔧 Enabling service to start on boot..."
sudo systemctl enable singularity-rust.service

# Create log directory
echo "📁 Creating log directory..."
mkdir -p logs

# Create startup script
echo "📝 Creating startup script..."
cat > start-singularity-service.sh << 'SERVICE_EOF'
#!/bin/bash

# Start Singularity Rust Service
echo "🚀 Starting Singularity Rust Service..."

# Check if NATS is running
if ! nc -z localhost 4222 2>/dev/null; then
    echo "❌ NATS server is not running. Please start NATS first:"
    echo "   nats-server -js"
    exit 1
fi

# Start the service
sudo systemctl start singularity-rust.service

echo "✅ Singularity Rust Service started!"
echo "📊 Status: sudo systemctl status singularity-rust.service"
echo "📝 Logs: journalctl -u singularity-rust.service -f"
echo "🛑 Stop: sudo systemctl stop singularity-rust.service"
SERVICE_EOF

chmod +x start-singularity-service.sh

# Create stop script
echo "📝 Creating stop script..."
cat > stop-singularity-service.sh << 'STOP_EOF'
#!/bin/bash

# Stop Singularity Rust Service
echo "🛑 Stopping Singularity Rust Service..."

sudo systemctl stop singularity-rust.service

echo "✅ Singularity Rust Service stopped!"
STOP_EOF

chmod +x stop-singularity-service.sh

# Create status script
echo "📝 Creating status script..."
cat > status-singularity-service.sh << 'STATUS_EOF'
#!/bin/bash

# Check Singularity Rust Service Status
echo "📊 Singularity Rust Service Status:"
echo ""

sudo systemctl status singularity-rust.service

echo ""
echo "📝 Recent logs:"
journalctl -u singularity-rust.service --since "5 minutes ago" --no-pager
STATUS_EOF

chmod +x status-singularity-service.sh

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Available commands:"
echo "  ./start-singularity-service.sh   - Start the service"
echo "  ./stop-singularity-service.sh    - Stop the service"
echo "  ./status-singularity-service.sh  - Check status"
echo ""
echo "🔧 Service management:"
echo "  sudo systemctl start singularity-rust.service"
echo "  sudo systemctl stop singularity-rust.service"
echo "  sudo systemctl status singularity-rust.service"
echo "  sudo systemctl enable singularity-rust.service  # Start on boot"
echo "  sudo systemctl disable singularity-rust.service # Don't start on boot"
echo ""
echo "📝 Logs:"
echo "  journalctl -u singularity-rust.service -f"
