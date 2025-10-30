# Singularity Code Quality Service
# Docker container for CI/CD integration

FROM rust:1.75-slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace configuration
COPY Cargo.toml Cargo.lock ./
COPY packages/code_quality_engine/Cargo.toml packages/code_quality_engine/
COPY packages/code_quality_engine/src packages/code_quality_engine/src/

# Build the scanner binary
RUN cargo build --release --bin singularity-scanner

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    git \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/singularity-scanner /usr/local/bin/

# Create non-root user
RUN useradd --create-home --shell /bin/bash singularity
USER singularity

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["singularity-scanner", "serve"]