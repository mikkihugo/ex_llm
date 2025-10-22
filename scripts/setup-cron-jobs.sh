#!/bin/bash

# Setup Cron Jobs for Singularity Services
# This script sets up automated scheduling

set -e

echo "⏰ Setting up Cron Jobs for Singularity Services..."

# Create cron job file
echo "📝 Creating cron job file..."
cat > singularity-cron << 'CRON_EOF'
# Singularity Rust Service Management
# Run every 5 minutes to ensure service is running
*/5 * * * * /home/mhugo/code/singularity/check-singularity-service.sh

# Restart service daily at 3 AM (maintenance window)
0 3 * * * /home/mhugo/code/singularity/restart-singularity-service.sh

# Clean up old logs weekly
0 2 * * 0 /home/mhugo/code/singularity/cleanup-singularity-logs.sh
CRON_EOF

# Create service check script
echo "📝 Creating service check script..."
cat > check-singularity-service.sh << 'CHECK_EOF'
#!/bin/bash

# Check if Singularity Rust Service is running
# If not, restart it

SERVICE_NAME="singularity-rust.service"
LOG_FILE="/home/mhugo/code/singularity/logs/service-check.log"

# Check if service is running
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "$(date): Service $SERVICE_NAME is not running. Restarting..." >> $LOG_FILE
    systemctl start $SERVICE_NAME
    echo "$(date): Service $SERVICE_NAME restarted." >> $LOG_FILE
else
    echo "$(date): Service $SERVICE_NAME is running." >> $LOG_FILE
fi
CHECK_EOF

chmod +x check-singularity-service.sh

# Create restart script
echo "📝 Creating restart script..."
cat > restart-singularity-service.sh << 'RESTART_EOF'
#!/bin/bash

# Restart Singularity Rust Service (daily maintenance)
SERVICE_NAME="singularity-rust.service"
LOG_FILE="/home/mhugo/code/singularity/logs/service-restart.log"

echo "$(date): Restarting $SERVICE_NAME for daily maintenance..." >> $LOG_FILE
systemctl restart $SERVICE_NAME
echo "$(date): $SERVICE_NAME restarted successfully." >> $LOG_FILE
RESTART_EOF

chmod +x restart-singularity-service.sh

# Create log cleanup script
echo "📝 Creating log cleanup script..."
cat > cleanup-singularity-logs.sh << 'CLEANUP_EOF'
#!/bin/bash

# Clean up old logs (keep last 7 days)
LOG_DIR="/home/mhugo/code/singularity/logs"
LOG_FILE="/home/mhugo/code/singularity/logs/cleanup.log"

echo "$(date): Cleaning up old logs..." >> $LOG_FILE
find $LOG_DIR -name "*.log" -mtime +7 -delete
echo "$(date): Log cleanup completed." >> $LOG_FILE
CLEANUP_EOF

chmod +x cleanup-singularity-logs.sh

# Install cron jobs
echo "📦 Installing cron jobs..."
crontab singularity-cron

echo "✅ Cron jobs installed!"
echo ""
echo "📋 Installed cron jobs:"
echo "  - Service check every 5 minutes"
echo "  - Daily restart at 3 AM"
echo "  - Weekly log cleanup on Sunday at 2 AM"
echo ""
echo "🔧 To manage cron jobs:"
echo "  crontab -l                    # List current jobs"
echo "  crontab -e                    # Edit jobs"
echo "  crontab -r                    # Remove all jobs"
echo ""
echo "📝 Log files:"
echo "  logs/service-check.log        # Service check logs"
echo "  logs/service-restart.log      # Restart logs"
echo "  logs/cleanup.log              # Cleanup logs"
