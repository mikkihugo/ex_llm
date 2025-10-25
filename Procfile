# Procfile for local development with Overmind
# Usage: nix develop && overmind start
#
# Orchestrates all services for Singularity development environment:
# - PostgreSQL database (shared by all Elixir applications)
# - Pure OTP backend services (Singularity, Genesis, CentralCloud)
#
# Startup order (Overmind handles dependencies):
# 1. singularity - Core AI analysis and execution engine (pure OTP)
# 2. genesis - Experimentation and sandboxing engine (pure OTP)
# 3. centralcloud - Cross-instance learning and aggregation (pure OTP)

# Singularity: Core AI agents & code analysis
# Pure OTP application - no Phoenix web server
singularity: cd singularity && iex -S mix

# Genesis: Experimentation & sandboxing engine
# Pure OTP application - no Phoenix web server
genesis: cd genesis && iex -S mix phx.server

# CentralCloud: Cross-instance learning & aggregation
# Pure OTP application - no Phoenix web server
centralcloud: cd centralcloud && iex -S mix
