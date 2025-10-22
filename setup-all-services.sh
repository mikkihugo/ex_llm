#!/bin/bash

# Setup All Singularity Services
# This script sets up PostgreSQL, NATS, and Rust services with proper scheduling

set -e

echo "🚀 Setting up All Singularity Services..."

# Check if we're in the right directory
if [ ! -f "rust/Cargo.toml" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# 1. Setup PostgreSQL Service
echo "🐘 Setting up PostgreSQL Service..."
cat > singularity-postgres.service << 'PG_EOF'
[Unit]
Description=Singularity PostgreSQL Database
After=network.target
Wants=network.target

[Service]
Type=notify
User=postgres
Group=postgres
WorkingDirectory=/var/lib/postgresql
Environment=PGDATA=/var/lib/postgresql/data
Environment=POSTGRES_DB=singularity
Environment=POSTGRES_USER=singularity
Environment=POSTGRES_PASSWORD=singularity
ExecStart=/usr/bin/postgres -D /var/lib/postgresql/data
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
PG_EOF

# 2. Setup NATS Service
echo "📡 Setting up NATS Service..."
cat > singularity-nats.service << 'NATS_EOF'
[Unit]
Description=Singularity NATS Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=mhugo
Group=mhugo
WorkingDirectory=/home/mhugo/code/singularity
Environment=NATS_URL=nats://127.0.0.1:4222
ExecStart=/usr/bin/nats-server -js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
NATS_EOF

# 3. Setup Rust Service (already created)
echo "🦀 Setting up Rust Service..."
# Copy the existing service file
cp singularity-rust.service singularity-rust.service.bak

# 4. Create service orchestration script
echo "📝 Creating service orchestration script..."
cat > manage-singularity-services.sh << 'MANAGE_EOF'
#!/bin/bash

# Manage All Singularity Services
# This script provides easy management of all services

case "$1" in
    start)
        echo "🚀 Starting all Singularity services..."
        sudo systemctl start singularity-postgres.service
        sleep 2
        sudo systemctl start singularity-nats.service
        sleep 2
        sudo systemctl start singularity-rust.service
        echo "✅ All services started!"
        ;;
    stop)
        echo "🛑 Stopping all Singularity services..."
        sudo systemctl stop singularity-rust.service
        sudo systemctl stop singularity-nats.service
        sudo systemctl stop singularity-postgres.service
        echo "✅ All services stopped!"
        ;;
    restart)
        echo "🔄 Restarting all Singularity services..."
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo "📊 Singularity Services Status:"
        echo ""
        echo "PostgreSQL:"
        sudo systemctl status singularity-postgres.service --no-pager
        echo ""
        echo "NATS:"
        sudo systemctl status singularity-nats.service --no-pager
        echo ""
        echo "Rust:"
        sudo systemctl status singularity-rust.service --no-pager
        ;;
    logs)
        echo "📝 Recent logs from all services:"
        echo ""
        echo "=== PostgreSQL ==="
        journalctl -u singularity-postgres.service --since "5 minutes ago" --no-pager
        echo ""
        echo "=== NATS ==="
        journalctl -u singularity-nats.service --since "5 minutes ago" --no-pager
        echo ""
        echo "=== Rust ==="
        journalctl -u singularity-rust.service --since "5 minutes ago" --no-pager
        ;;
    enable)
        echo "🔧 Enabling all services to start on boot..."
        sudo systemctl enable singularity-postgres.service
        sudo systemctl enable singularity-nats.service
        sudo systemctl enable singularity-rust.service
        echo "✅ All services enabled for boot startup!"
        ;;
    disable)
        echo "🔧 Disabling all services from starting on boot..."
        sudo systemctl disable singularity-postgres.service
        sudo systemctl disable singularity-nats.service
        sudo systemctl disable singularity-rust.service
        echo "✅ All services disabled from boot startup!"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  status   - Show status of all services"
        echo "  logs     - Show recent logs from all services"
        echo "  enable   - Enable services to start on boot"
        echo "  disable  - Disable services from starting on boot"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x manage-singularity-services.sh

# 5. Create database setup script
echo "📝 Creating database setup script..."
cat > setup-database.sh << 'DB_EOF'
#!/bin/bash

# Setup Singularity Database
# This script sets up the PostgreSQL database for Singularity

set -e

echo "🐘 Setting up Singularity Database..."

# Check if PostgreSQL is running
if ! systemctl is-active --quiet singularity-postgres.service; then
    echo "❌ PostgreSQL service is not running. Please start it first:"
    echo "   ./manage-singularity-services.sh start"
    exit 1
fi

# Create database and user
echo "📦 Creating database and user..."
sudo -u postgres psql << 'SQL'
CREATE DATABASE singularity;
CREATE USER singularity WITH PASSWORD 'singularity';
GRANT ALL PRIVILEGES ON DATABASE singularity TO singularity;
\q
SQL

# Run migrations
echo "🔄 Running database migrations..."
cd singularity
mix ecto.migrate
cd ..

echo "✅ Database setup complete!"
echo ""
echo "📊 Database info:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: singularity"
echo "  User: singularity"
echo "  Password: singularity"
DB_EOF

chmod +x setup-database.sh

# 6. Install all services
echo "📦 Installing all services..."
sudo cp singularity-postgres.service /etc/systemd/system/
sudo cp singularity-nats.service /etc/systemd/system/
sudo cp singularity-rust.service /etc/systemd/system/
sudo systemctl daemon-reload

# 7. Enable services
echo "🔧 Enabling services to start on boot..."
sudo systemctl enable singularity-postgres.service
sudo systemctl enable singularity-nats.service
sudo systemctl enable singularity-rust.service

# 8. Create log directory
echo "📁 Creating log directory..."
mkdir -p logs

echo ""
echo "🎉 All services setup complete!"
echo ""
echo "📋 Available commands:"
echo "  ./manage-singularity-services.sh start    - Start all services"
echo "  ./manage-singularity-services.sh stop     - Stop all services"
echo "  ./manage-singularity-services.sh restart  - Restart all services"
echo "  ./manage-singularity-services.sh status   - Check status"
echo "  ./manage-singularity-services.sh logs     - View logs"
echo "  ./setup-database.sh                      - Setup database"
echo ""
echo "🔧 Individual service management:"
echo "  sudo systemctl start singularity-postgres.service"
echo "  sudo systemctl start singularity-nats.service"
echo "  sudo systemctl start singularity-rust.service"
echo ""
echo "📝 Logs:"
echo "  journalctl -u singularity-postgres.service -f"
echo "  journalctl -u singularity-nats.service -f"
echo "  journalctl -u singularity-rust.service -f"
