# Local Development Setup

This guide covers running all services locally for development with Overmind.

## Quick Start

```bash
# 1. Enter Nix development shell (one-time per session)
nix develop
# Or with direnv (recommended for auto-entry):
direnv allow

# 2. Start all services with Overmind
overmind start
```

That's it! Overmind will:
- ✅ Start NATS message broker (localhost:4222)
- ✅ Start 3 pure OTP backend services (Singularity, Genesis, CentralCloud)
- ✅ Start Nexus Phoenix web dashboard (http://localhost:4000)
- ✅ Display logs from all services in color-coded format

## Architecture

### Service Topology

```
┌─────────────────────────────────────────────────────────┐
│                    Nexus Web Dashboard                  │
│              (Phoenix + LiveView on port 4000)          │
└──────────────────────────┬──────────────────────────────┘
                           │
                    NATS (localhost:4222)
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   Singularity         Genesis            CentralCloud
   (Pure OTP)          (Pure OTP)          (Pure OTP)
   Code Analysis       Experiments        Learning Agg.
```

### Service Details

| Service | Type | Database | Purpose |
|---------|------|----------|---------|
| **NATS** | Message Broker | None | Inter-service communication |
| **Singularity** | Pure OTP | `singularity` | Core AI analysis & code generation |
| **Genesis** | Pure OTP | `genesis` | Experimentation & sandboxing |
| **CentralCloud** | Pure OTP | `centralcloud` | Cross-instance learning aggregation |
| **Nexus** | Phoenix Web | None | Web control panel + LiveView dashboard |

## Managing Services

### View Logs

While Overmind is running, you can:

```bash
# Within Overmind:
c              # Show process list and their status
n              # Navigate between processes
0-4            # Jump to specific process (0=NATS, 1=Singularity, etc.)
C-c (in focus) # Stop specific process
C-c globally   # Stop all services
```

### Stop All Services

```bash
# Ctrl+C in the Overmind window, or:
pkill -f overmind
```

### Restart Individual Service (Advanced)

If you need to restart just one service:

```bash
# In another terminal:
overmind restart singularity  # or genesis, centralcloud, nexus
```

## Database Migrations

Migrations run automatically on first startup. If you need to re-run them:

```bash
# From project root (while services are running):
cd singularity && mix ecto.migrate
cd ../genesis && mix ecto.migrate
cd ../centralcloud && mix ecto.migrate
```

## Accessing Services

### Web Dashboard
- **URL**: http://localhost:4000
- **Purpose**: Real-time status of all three backend systems
- **Tech**: Phoenix LiveView with NATS integration

### NATS Admin (Optional)
- **URL**: http://localhost:8222 (if NATS enabled HTTP monitoring)
- **Purpose**: Debug NATS topics and subscribers

### Elixir REPL (In Service Containers)

Each service runs `iex -S mix`, so you can interact with them:

```bash
# In another terminal, attach to a service:
overmind exec singularity   # Interactive shell for Singularity
```

## Development Workflow

### Making Changes

1. **Elixir Code Changes**
   - Edit `.ex` files in any service directory
   - Changes automatically recompile (hot reload)
   - No restart needed for non-compiled assets

2. **Database Changes**
   - Create migration: `cd singularity && mix ecto.gen.migration my_change`
   - Run migration: `mix ecto.migrate`
   - Restart service if needed

3. **Phoenix/LiveView Changes** (Nexus only)
   - Edit `.ex` or `.heex` files
   - Browser auto-refreshes on changes

### Debugging

**Print Logs from Specific Service:**
```bash
# While Overmind running, press: 0 (for NATS), 1 (for Singularity), etc.
# Or in another terminal:
overmind logs singularity | tail -100
```

**Check NATS Status:**
```bash
# In another terminal:
nats server info
```

**Connect to NATS Interactively:**
```bash
nats
# Then: server info, pub/sub tests, etc.
```

## Troubleshooting

### Services won't start

```bash
# Kill any zombie processes
pkill -f "mix phx.server"
pkill -f "mix"
pkill -f nats-server
pkill -f overmind

# Try again
overmind start
```

### NATS Connection Errors

```bash
# Check if NATS is actually running
ps aux | grep nats-server

# Test NATS connection
nats server info
```

### Database Already in Use

```bash
# Kill Postgres connections
psql
# Then: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'singularity';
```

### Flake Lock Issues

```bash
nix flake update
direnv reload
overmind start
```

## Environment Variables

All required env vars are automatically configured by `nix develop`. To override:

```bash
# Example: Change NATS port
export NATS_PORT=5000
overmind start
```

### Available Env Vars

- `NATS_HOST` - NATS server host (default: 127.0.0.1)
- `NATS_PORT` - NATS server port (default: 4222)
- `MIX_ENV` - Elixir environment (default: dev)
- `ELIXIR_ERL_OPTIONS` - Erlang VM options (pre-configured for development)

## Performance Tips

### Reduce Logging Verbosity

Edit `config/dev.exs` in each service:
```elixir
config :logger, level: :info  # Instead of :debug
```

### Parallel Compilation

Overmind starts services in order (NATS first, then others in parallel). For faster startup:
- Pre-compile with `mix compile` before starting
- This prevents recompilation during service startup

### Monitor System Resources

```bash
# In another terminal:
watch -n 1 'ps aux | grep beam'
```

## References

- **Procfile**: `./Procfile` - Service definitions
- **Nix Configuration**: `./flake.nix` - Development environment
- **NATS Subjects**: `./nexus/NATS_SUBJECTS.md` - Message bus interface
- **Service Architecture**: `./CLAUDE.md` - Complete system overview
