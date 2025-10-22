# Auto-Start Guide - Singularity Development Environment

## What Auto-Starts

When you enter the Nix development shell (`nix develop` or `direnv allow`), **two services automatically start in the background**:

### 1. NATS Server with JetStream
- **Port:** 4222
- **URL:** `nats://localhost:4222`
- **Logs:** `.nats/nats-server.log`
- **Data:** `.nats/` directory
- **Check if running:** `pgrep -x "nats-server"`

### 2. Singularity Phoenix Server
- **Port:** 4000
- **URL:** `http://localhost:4000`
- **Logs:** `.singularity-server.log`
- **PID file:** `.singularity-server.pid`
- **Check if running:** `cat .singularity-server.pid && kill -0 $(cat .singularity-server.pid)`

## Usage

### Enter Dev Shell (Auto-Start)

```bash
# Option 1: Using Nix directly
nix develop

# Option 2: Using direnv (recommended)
direnv allow

# You'll see output like:
# 📡 Starting NATS with JetStream...
#    NATS running on nats://localhost:4222 (logs: .nats/nats-server.log)
# 🚀 Starting Singularity Phoenix server...
#    Phoenix server starting on http://localhost:4000 (logs: .singularity-server.log)
#    PID: 12345 (stop with: kill $(cat .singularity-server.pid))
```

### Verify Services Are Running

```bash
# Check NATS
pgrep -x "nats-server"  # Should show PID

# Check Phoenix server
cat .singularity-server.pid  # Should show PID
curl http://localhost:4000/health  # Should return JSON health status

# Check both via HTTP endpoints
curl http://localhost:4000/health
curl http://localhost:4000/metrics
```

### View Logs

```bash
# NATS logs
tail -f .nats/nats-server.log

# Phoenix server logs
tail -f .singularity-server.log
```

### Stop Services

```bash
# Stop Phoenix server
kill $(cat .singularity-server.pid)
rm .singularity-server.pid

# Stop NATS
pkill nats-server

# OR exit the Nix shell (services continue in background)
exit

# To fully clean up, stop manually before exiting shell
```

## Available Endpoints (Auto-Started)

Once auto-start completes, you can immediately access:

### Health Check
```bash
curl http://localhost:4000/health
```

**Response:**
```json
{
  "status": "ok",
  "services": {
    "database": "ok",
    "nats": "ok",
    "rust_nifs": "ok"
  },
  "timestamp": "2025-10-13T22:37:00Z"
}
```

### Metrics
```bash
curl http://localhost:4000/metrics
```

**Response:**
```json
{
  "vm": {
    "memory_total_mb": 512,
    "process_count": 1234,
    "scheduler_count": 8,
    "uptime_seconds": 3600
  },
  "agents": {
    "active_count": 3,
    "total_spawned": 10
  },
  "llm": {
    "total_requests": 42,
    "cache_hit_rate": 0.75,
    "total_cost_usd": 1.23
  },
  "nats": {
    "messages_sent": 1000,
    "messages_received": 1000
  },
  "timestamp": "2025-10-13T22:37:00Z"
}
```

## Troubleshooting

### NATS Already Running
If NATS was already running before entering the shell:
```
📡 NATS already running on nats://localhost:4222
```
✅ This is fine! The shell detected the existing process and skipped startup.

### Phoenix Server Already Running
If Phoenix server PID file exists:
```
🚀 Singularity Phoenix server already running (PID: 12345)
```
✅ This is fine! The shell detected the existing process and skipped startup.

### Previous Server Died
If the PID file exists but process is dead:
```
Previous server process died, restart shell to launch again
```
❌ Exit and re-enter the shell:
```bash
exit
nix develop  # or direnv allow
```

### Dependencies Not Installed
On first run, you may see:
```
Installing dependencies...
```
⏳ This is normal! The shell automatically runs `mix deps.get` before starting the server.

### Port Already in Use
If port 4000 is already in use by another process:
```bash
# Find what's using port 4000
lsof -i :4000

# Kill the process
kill -9 <PID>

# Restart shell
exit
nix develop
```

### Can't Connect to Database
If health check shows database error:
```bash
# Setup database (first time only)
./scripts/setup-database.sh

# Or manually:
cd singularity
mix ecto.create
mix ecto.migrate
```

## Running Tests

With auto-start enabled, tests can run immediately:

```bash
cd singularity

# All tests
mix test

# Only integration tests (require NATS)
mix test --only integration

# Specific test file
mix test test/singularity/nats_integration_test.exs

# With coverage
mix test.ci --only integration
```

## Manual Control (Override Auto-Start)

If you want to start services manually instead:

### Disable Auto-Start Temporarily
```bash
# Start NATS manually BEFORE entering shell
nats-server -js -p 4222 &

# Then enter shell (will detect existing process)
nix develop
```

### Start Phoenix Server Manually
```bash
# If you removed .singularity-server.pid
cd singularity
mix phx.server
# Server runs in foreground with live output
```

## What Happens on Shell Exit

When you exit the Nix shell (`exit` or Ctrl-D):

- **NATS server:** Continues running in background ✅
- **Phoenix server:** Continues running in background ✅
- **PID file:** Remains, used to detect existing process next time

**To fully stop everything:**
```bash
# Before exiting shell
kill $(cat .singularity-server.pid)
pkill nats-server

# Then exit
exit
```

## Next Steps

With auto-start enabled, you can immediately:

1. **Run integration tests:**
   ```bash
   cd singularity
   mix test --only integration
   ```

2. **View metrics:**
   ```bash
   curl http://localhost:4000/metrics | jq
   ```

3. **Check health:**
   ```bash
   curl http://localhost:4000/health | jq
   ```

4. **Start coding:**
   - All services ready
   - No manual startup required
   - Focus on development!

---

**Implementation Date:** 2025-10-13
**Status:** ✅ Auto-start fully implemented in `flake.nix`
