#!/usr/bin/env bash
# Start PostgreSQL server
set -euo pipefail

DEV_PGROOT="${DEV_PGROOT:-${PWD}/.dev-db}"
PGDATA="${PGDATA:-${DEV_PGROOT}/pg}"
PG_PID_FILE="${DEV_PGROOT}/postgres.pid"
PGHOST="localhost"

# Find available port starting from 5432
find_available_port() {
    local port=5432
    while [ $port -le 65535 ]; do
        if ! lsof -i :$port >/dev/null 2>&1; then
            echo $port
            return
        fi
        port=$((port + 1))
    done
    echo "5432"  # fallback
}

PGPORT="${PGPORT:-$(find_available_port)}"

if [ -f "$PG_PID_FILE" ] && kill -0 "$(cat "$PG_PID_FILE")" 2>/dev/null; then
    echo "🗄️  PostgreSQL already running on port $PGPORT (PID: $(cat "$PG_PID_FILE"))"
    exit 0
fi

if [ ! -d "$PGDATA" ]; then
    echo "🗄️  Initializing PostgreSQL database on port $PGPORT..."
    mkdir -p "$DEV_PGROOT"
    initdb --no-locale --encoding=UTF8 -D "$PGDATA" >/dev/null
    
    cat > "$PGDATA/pg_hba.conf" <<'EOF'
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
EOF
    
    cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = 'localhost'
port = $PGPORT
unix_socket_directories = '$PGDATA'
log_destination = 'stderr'
logging_collector = off
shared_preload_libraries = 'timescaledb,pg_cron,pgsodium'
cron.database_name = 'singularity'
EOF
    
    echo "   ✅ PostgreSQL initialized on port $PGPORT"
fi

echo "🚀 Starting PostgreSQL on port $PGPORT..."
pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" -o "-p $PGPORT" start >/dev/null
PG_START_RESULT=$?

if [ $PG_START_RESULT -eq 0 ]; then
    # Get the actual PID from the postmaster.pid file
    if [ -f "$PGDATA/postmaster.pid" ]; then
        PG_PID=$(head -n 1 "$PGDATA/postmaster.pid")
        echo $PG_PID > "$PG_PID_FILE" 2>/dev/null || true
    fi
    echo "   ✅ PostgreSQL started on port $PGPORT"
    echo "   📝 Data: $PGDATA"
    echo "   📝 Logs: $PGDATA/postgres.log"
    echo "   🔗 Connection: postgres://localhost:$PGPORT/postgres"
else
    echo "   ❌ Failed to start PostgreSQL"
    echo "   📝 Check logs: $PGDATA/postgres.log"
    exit 1
fi
