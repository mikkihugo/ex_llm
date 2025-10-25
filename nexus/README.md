# Nexus - Unified Control Panel

Nexus is a Phoenix web application that provides a unified control panel for three autonomous backend systems:

- **🧠 Singularity** - Core AI agents & code analysis (pure OTP)
- **🧪 Genesis** - Experimentation & sandboxing engine (pure OTP)
- **☁️ CentralCloud** - Cross-instance learning & aggregation (pure OTP)

All backend systems are pure Elixir OTP applications that communicate only via NATS messaging.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Nexus (Phoenix)                          │
│              (Web Dashboard on port 4000)                    │
└──────────────┬──────────────────────────────────────────────┘
               │
         NATS (4222)
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌─────────────┐
│Singul  │ │Genesis │ │CentralCloud │
│arity   │ │        │ │             │
└────────┘ └────────┘ └─────────────┘
  (OTP)     (OTP)        (OTP)
```

## Running Nexus

### Prerequisites

- Elixir 1.18+
- NATS server running on localhost:4222

### Setup

```bash
cd nexus

# Install dependencies
mix setup

# Generate SECRET_KEY_BASE if needed
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Start the server
mix phx.server
```

The web server will be available at http://localhost:4000

### Environment Variables

- `NATS_HOST` - NATS server hostname (default: 127.0.0.1)
- `NATS_PORT` - NATS server port (default: 4222)
- `SECRET_KEY_BASE` - Phoenix secret key for session signing

## Features

### Dashboard

The main dashboard displays:
- Status of all three backend systems
- Agent count in Singularity
- Experiment count in Genesis
- Insight count in CentralCloud

Real-time updates via Phoenix LiveView and NATS subscriptions.

### API Endpoints

#### Singularity
- `GET /api/singularity/status` - Get system status
- `POST /api/singularity/analyze` - Request code analysis

#### Genesis
- `GET /api/genesis/status` - Get system status
- `POST /api/genesis/experiment` - Create new experiment

#### CentralCloud
- `GET /api/centralcloud/status` - Get system status
- `GET /api/centralcloud/insights` - Get aggregated insights

## NATS Communication

See [NATS_SUBJECTS.md](NATS_SUBJECTS.md) for complete NATS subject map.

### Example: Request-Response

```elixir
# From Nexus controller
response = Nexus.NatsClient.request("singularity.analyze.code",
  %{code: "def hello, do: :world", language: "elixir"},
  timeout: 5000)
```

### Example: Publish-Subscribe

```elixir
# Subscribe to status updates
Nexus.NatsClient.subscribe_to_status()

# Backend system publishes
:gnat.pub(conn, "singularity.status.update",
  Jason.encode!(%{status: "online", agents: 6}))
```

## Testing

```bash
# Run tests
mix test

# Run with coverage
mix test.ci
```

## Code Quality

```bash
# Format code
mix format

# Run linter
mix credo --strict

# Type checking
mix dialyzer

# Security analysis
mix sobelow --exit-on-warning
```

## Files & Structure

```
nexus/
├── lib/
│   ├── nexus/                          # Core OTP application
│   │   ├── application.ex              # Supervisor & startup
│   │   ├── nats_client.ex              # NATS GenServer
│   │   └── telemetry.ex                # Metrics
│   ├── nexus_web/                      # Phoenix web layer
│   │   ├── endpoint.ex                 # HTTP endpoint
│   │   ├── router.ex                   # Routes
│   │   ├── controllers/                # API controllers
│   │   ├── live/                       # LiveView modules
│   │   └── components/
│   │       └── layouts/                # HTML templates
│   └── nexus_web.ex                    # Web module helpers
├── priv/
│   ├── repo/migrations/                # Database migrations (none yet)
│   └── static/                         # Static assets
├── config/
│   ├── config.exs                      # Main config
│   ├── dev.exs                         # Development
│   ├── test.exs                        # Testing
│   └── runtime.exs                     # Runtime (env vars)
├── test/                               # Tests
├── mix.exs                             # Project definition
└── NATS_SUBJECTS.md                    # NATS message map
```

## Implementation Status

✅ Project structure created
✅ Config files
✅ Phoenix endpoint
✅ Router with API routes
✅ Dashboard LiveView
✅ NATS client (scaffolding)
✅ Controllers (scaffolding)

⏳ Full NATS integration (with gnat library)
⏳ LiveView status subscriptions
⏳ Backend system integration (requires backend changes)

## Troubleshooting

### NATS Connection Failed

```
⚠️  Failed to connect to NATS: :econnrefused
Retrying in 5 seconds...
```

**Solution:** Start NATS server in another terminal:
```bash
nats-server -js
```

### Port 4000 Already In Use

```
error: :eaddrinuse
```

**Solution:** Change port in `config/dev.exs`:
```elixir
config :nexus, NexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],  # Changed from 4000
```

### Missing SECRET_KEY_BASE

```
environment variable SECRET_KEY_BASE is missing.
```

**Solution:** Generate and set it:
```bash
export SECRET_KEY_BASE=$(mix phx.gen.secret)
mix phx.server
```

## Related Systems

- **Singularity** - Main OTP application with AI agents
- **Genesis** - Experimentation engine
- **CentralCloud** - Multi-instance learning aggregation
- **NATS** - Message bus for all inter-system communication

## See Also

- [NATS Subjects Map](NATS_SUBJECTS.md)
- [Phoenix Documentation](https://hexdocs.pm/phoenix)
- [LiveView Documentation](https://hexdocs.pm/phoenix_live_view)
- [Gnat NATS Client](https://hexdocs.pm/gnat)
