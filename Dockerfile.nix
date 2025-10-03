# Nix-based Dockerfile for fly.io deployment
# Uses Bun runtime (no Node.js needed)

FROM nixos/nix:latest AS builder

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Copy source (only ai-server and flake)
WORKDIR /build
COPY flake.nix flake.lock ./
COPY ai-server ./ai-server/

# Build with Nix (includes Bun and all dependencies)
RUN nix build .#ai-server

# Create runtime image
FROM debian:bookworm-slim

# Install minimal runtime dependencies (curl for health checks)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy built package from Nix (self-contained with Bun)
COPY --from=builder /build/result /app

# Create directories for credentials
RUN mkdir -p /root/.config/gcloud \
             /root/.config/cursor \
             /root/.claude

# Set environment
ENV PATH="/app/bin:${PATH}"
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the server (wrapper script handles cd to working dir)
CMD ["/app/bin/ai-server"]
