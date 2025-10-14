#!/usr/bin/env bash
# Stop PostgreSQL server
set -euo pipefail

DEV_PGROOT="${PWD}/.dev-db"
PGDATA="${DEV_PGROOT}/pg"
PG_PID_FILE="${DEV_PGROOT}/postgres.pid"

if [ -f "$PG_PID_FILE" ]; then
    PG_PID=$(cat "$PG_PID_FILE")
    if kill -0 "$PG_PID" 2>/dev/null; then
        echo "🛑 Stopping PostgreSQL (PID: $PG_PID)..."
        pg_ctl -D "$PGDATA" -m fast stop >/dev/null 2>&1 || true
        echo "   ✅ PostgreSQL stopped"
    else
        echo "   PostgreSQL not running (stale PID file)"
    fi
    rm -f "$PG_PID_FILE"
else
    echo "🗄️  PostgreSQL not running (no PID file)"
fi