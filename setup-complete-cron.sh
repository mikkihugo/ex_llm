#!/bin/bash

# Setup Complete Cron Jobs for All Singularity Services
# This script sets up automated scheduling for PostgreSQL, NATS, and Rust services

set -e

echo "⏰ Setting up Complete Cron Jobs for All Singularity Services..."

# Create comprehensive cron job file
echo "📝 Creating comprehensive cron job file..."
cat > singularity-complete-cron << 'CRON_EOF'
# Singularity Complete Service Management
# Run every 5 minutes to ensure all services are running
*/5 * * * * /home/mhugo/code/singularity/check-all-services.sh

# Restart all services daily at 3 AM (maintenance window)
0 3 * * * /home/mhugo/code/singularity/restart-all-services.sh

# Clean up old logs weekly
0 2 * * 0 /home/mhugo/code/singularity/cleanup-all-logs.sh

# Database backup daily at 2 AM
0 2 * * * /home/mhugo/code/singularity/backup-database.sh

# Health check every hour
0 * * * * /home/mhugo/code/singularity/health-check.sh
CRON_EOF

# Create comprehensive service check script
echo "📝 Creating comprehensive service check script..."
cat > check-all-services.sh << 'CHECK_EOF'
#!/bin/bash

# Check if all Singularity services are running
# If not, restart them

SERVICES=("singularity-postgres.service" "singularity-nats.service" "singularity-rust.service")
LOG_FILE="/home/mhugo/code/singularity/logs/service-check.log"

for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet $service; then
        echo "$(date): Service $service is not running. Restarting..." >> $LOG_FILE
        systemctl start $service
        echo "$(date): Service $service restarted." >> $LOG_FILE
    else
        echo "$(date): Service $service is running." >> $LOG_FILE
    fi
done
CHECK_EOF

chmod +x check-all-services.sh

# Create restart all services script
echo "📝 Creating restart all services script..."
cat > restart-all-services.sh << 'RESTART_EOF'
#!/bin/bash

# Restart all Singularity services (daily maintenance)
SERVICES=("singularity-rust.service" "singularity-nats.service" "singularity-postgres.service")
LOG_FILE="/home/mhugo/code/singularity/logs/service-restart.log"

echo "$(date): Restarting all services for daily maintenance..." >> $LOG_FILE

for service in "${SERVICES[@]}"; do
    echo "$(date): Restarting $service..." >> $LOG_FILE
    systemctl restart $service
    echo "$(date): $service restarted successfully." >> $LOG_FILE
    sleep 2
done

echo "$(date): All services restarted successfully." >> $LOG_FILE
RESTART_EOF

chmod +x restart-all-services.sh

# Create log cleanup script
echo "📝 Creating log cleanup script..."
cat > cleanup-all-logs.sh << 'CLEANUP_EOF'
#!/bin/bash

# Clean up old logs (keep last 7 days)
LOG_DIR="/home/mhugo/code/singularity/logs"
LOG_FILE="/home/mhugo/code/singularity/logs/cleanup.log"

echo "$(date): Cleaning up old logs..." >> $LOG_FILE
find $LOG_DIR -name "*.log" -mtime +7 -delete
echo "$(date): Log cleanup completed." >> $LOG_FILE
CLEANUP_EOF

chmod +x cleanup-all-logs.sh

# Create database backup script
echo "📝 Creating database backup script..."
cat > backup-database.sh << 'BACKUP_EOF'
#!/bin/bash

# Backup Singularity database
BACKUP_DIR="/home/mhugo/code/singularity/backups"
LOG_FILE="/home/mhugo/code/singularity/logs/backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/singularity_backup_$DATE.sql"

# Create backup directory
mkdir -p $BACKUP_DIR

echo "$(date): Starting database backup..." >> $LOG_FILE

# Check if PostgreSQL is running
if ! systemctl is-active --quiet singularity-postgres.service; then
    echo "$(date): PostgreSQL service is not running. Skipping backup." >> $LOG_FILE
    exit 1
fi

# Create backup
pg_dump -h localhost -U singularity -d singularity > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "$(date): Database backup completed: $BACKUP_FILE" >> $LOG_FILE
    # Compress backup
    gzip $BACKUP_FILE
    echo "$(date): Backup compressed: $BACKUP_FILE.gz" >> $LOG_FILE
else
    echo "$(date): Database backup failed!" >> $LOG_FILE
    exit 1
fi

# Clean up old backups (keep last 7 days)
find $BACKUP_DIR -name "singularity_backup_*.sql.gz" -mtime +7 -delete
echo "$(date): Old backups cleaned up." >> $LOG_FILE
BACKUP_EOF

chmod +x backup-database.sh

# Create health check script
echo "📝 Creating health check script..."
cat > health-check.sh << 'HEALTH_EOF'
#!/bin/bash

# Health check for all Singularity services
LOG_FILE="/home/mhugo/code/singularity/logs/health-check.log"

echo "$(date): Starting health check..." >> $LOG_FILE

# Check PostgreSQL
if systemctl is-active --quiet singularity-postgres.service; then
    if pg_isready -h localhost -p 5432 -U singularity; then
        echo "$(date): PostgreSQL is healthy" >> $LOG_FILE
    else
        echo "$(date): PostgreSQL is not responding" >> $LOG_FILE
    fi
else
    echo "$(date): PostgreSQL service is not running" >> $LOG_FILE
fi

# Check NATS
if systemctl is-active --quiet singularity-nats.service; then
    if nc -z localhost 4222; then
        echo "$(date): NATS is healthy" >> $LOG_FILE
    else
        echo "$(date): NATS is not responding" >> $LOG_FILE
    fi
else
    echo "$(date): NATS service is not running" >> $LOG_FILE
fi

# Check Rust service
if systemctl is-active --quiet singularity-rust.service; then
    echo "$(date): Rust service is running" >> $LOG_FILE
else
    echo "$(date): Rust service is not running" >> $LOG_FILE
fi

echo "$(date): Health check completed" >> $LOG_FILE
HEALTH_EOF

chmod +x health-check.sh

# Install cron jobs
echo "📦 Installing cron jobs..."
crontab singularity-complete-cron

echo "✅ Complete cron jobs installed!"
echo ""
echo "📋 Installed cron jobs:"
echo "  - Service check every 5 minutes"
echo "  - Daily restart at 3 AM"
echo "  - Weekly log cleanup on Sunday at 2 AM"
echo "  - Daily database backup at 2 AM"
echo "  - Health check every hour"
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
echo "  logs/backup.log               # Backup logs"
echo "  logs/health-check.log         # Health check logs"
echo ""
echo "💾 Backup directory:"
echo "  backups/                      # Database backups"
