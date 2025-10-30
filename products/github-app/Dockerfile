# Singularity GitHub App - Docker Configuration

# Build stage
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    npm \
    rust \
    cargo

# Set working directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod

# Copy application code
COPY lib lib
COPY priv priv
COPY assets assets

# Build assets
RUN npm --prefix assets ci --progress=false --no-audit --loglevel=error
RUN npm run --prefix assets deploy
RUN mix phx.digest

# Build release
RUN MIX_ENV=prod mix release

# Runtime stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    ncurses-libs \
    openssl \
    postgresql-client \
    curl

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/singularity ./

# Create directories for runtime data
RUN mkdir -p /app/data && \
    chown -R appuser:appuser /app

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/api/health || exit 1

# Expose port
EXPOSE 4000

# Start application
CMD ["bin/singularity", "start"]