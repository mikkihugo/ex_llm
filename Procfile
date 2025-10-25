# Procfile for local development with Overmind
# Usage: nix develop && overmind start
#
# Orchestrates all services for Singularity development environment:
# - NATS message broker (for distributed service communication)
# - PostgreSQL database (shared by all 4 Elixir applications)
# - 3 pure OTP backend services (Singularity, Genesis, CentralCloud)
# - 1 Phoenix web frontend (Nexus) with LiveView dashboard
#
# Startup order (Overmind handles dependencies):
# 1. nats - Message broker for all inter-service communication
# 2. singularity - Core AI analysis and execution engine (pure OTP)
# 3. genesis - Experimentation and sandboxing engine (pure OTP)
# 4. centralcloud - Cross-instance learning and aggregation (pure OTP)
# 5. nexus - Unified web control panel (Phoenix + LiveView)

# NATS JetStream Message Broker (localhost:4222)
# Required for all inter-service communication
nats: nats-server -js

# Singularity: Core AI agents & code analysis
# Pure OTP application - no Phoenix web server
# Listens on NATS for requests from other services
singularity: cd singularity && iex -S mix

# Genesis: Experimentation & sandboxing engine
# Pure OTP application - no Phoenix web server
# Listens on NATS for experiment requests
genesis: cd genesis && iex -S mix phx.server

# CentralCloud: Cross-instance learning & aggregation
# Pure OTP application - no Phoenix web server
# Listens on NATS for learning aggregation requests
centralcloud: cd centralcloud && iex -S mix

# Nexus: Unified web control panel
# Phoenix + LiveView frontend for dashboard
# Communicates with all 3 backends via NATS
# HTTP: http://localhost:4000
nexus: cd nexus && iex -S mix phx.server
