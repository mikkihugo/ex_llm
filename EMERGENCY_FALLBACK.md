# Claude Recovery: Emergency Fallback CLI

## Overview

Singularity maintains **two separate Claude installations** for redundancy with zero collision:

1. **NPM Package** - `ai-sdk-provider-claude-code` (TypeScript ai-server)
2. **Recovery Binary** - `claude-recovery` native CLI for emergency Elixir fallback

Named `claude-recovery` instead of `claude` to avoid conflicts with NPM SDK and allow dangerous flags for recovery scenarios.

## Architecture

```
┌─────────────────────────────────────────────┐
│ Primary Path (HTTP)                         │
│ Elixir → HTTP → ai-server → NPM Claude SDK  │
└─────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ Recovery Fallback (Direct CLI)                   │
│ Elixir → ~/.singularity/emergency/bin/claude-recovery │
└──────────────────────────────────────────────────┘
```

## Installation Paths

| Type | Binary Name | Location | Purpose | Installed By |
|------|-------------|----------|---------|--------------|
| NPM SDK | (internal) | `node_modules/ai-sdk-provider-claude-code` | ai-server primary | `bun install` |
| Recovery CLI | `claude-recovery` | `~/.singularity/emergency/bin/` | Elixir emergency fallback | `./scripts/install_claude_native.sh` |

## Installation

Install the emergency Claude CLI binary:

```bash
./scripts/install_claude_native.sh
```

This installs to `~/.singularity/emergency/bin/claude-recovery` (isolated from the system or NPM Claude binary).

### Custom Location

Set a custom emergency bin directory:

```bash
export SINGULARITY_EMERGENCY_BIN=/opt/singularity/emergency/bin
./scripts/install_claude_native.sh
```

## Configuration

The emergency CLI is automatically configured in `seed_agent/config/config.exs`:

```elixir
config :seed_agent, :claude,
  cli_path: System.get_env("CLAUDE_CLI_PATH") || "~/.singularity/emergency/bin/claude-recovery"
```

Priority order:
1. `CLAUDE_CLI_PATH` env var (manual override)
2. `~/.singularity/emergency/bin/claude` (emergency fallback)
3. `claude-recovery` (system PATH) then `claude`

## Usage

### Primary (HTTP Server)

```elixir
# Use the HTTP ai-server (primary path)
{:ok, response} = Singularity.AIProvider.chat("claude-code-cli", [
  %{role: "user", content: "Hello"}
])
```

### Emergency Fallback (Direct CLI)

```elixir
# Use direct CLI when HTTP server is down
{:ok, response} = SeedAgent.Integration.Claude.chat("Hello")

# Or with messages
{:ok, response} = SeedAgent.Integration.Claude.chat([
  %{role: "user", content: "Hello"}
], model: "sonnet")
```

## Authentication

The emergency CLI uses the same auth as regular Claude CLI:

1. **OAuth Token** (preferred):
   ```bash
   export CLAUDE_CODE_OAUTH_TOKEN="your-token"
   ```

2. **Credentials File**:
   ```bash
   # Automatically reads from ~/.claude/.credentials.json
   # Or set custom location:
   export CLAUDE_HOME=/path/to/claude/config
   ```

3. **Encrypted Credentials** (for deployment):
   ```bash
   # Decrypt credentials at runtime
   ./ai-server/scripts/decrypt-credentials.sh
   ```

## Deployment (Fly.io)

The emergency CLI is included in the Nix environment and available in production:

1. **Encrypted credentials** are decrypted at startup
2. **Emergency binary** is available at `~/.singularity/emergency/bin/claude`
3. **Fallback logic** can detect HTTP server failures and use direct CLI

### Secrets Required

```bash
flyctl secrets set AGE_SECRET_KEY=<your-age-key> --app singularity
```

## Monitoring

To test the fallback:

```elixir
# Check if emergency CLI is available
case System.find_executable("~/.singularity/emergency/bin/claude") do
  nil -> Logger.warning("Emergency Claude CLI not installed")
  path -> Logger.info("Emergency CLI ready: #{path}")
end

# Test emergency integration
case SeedAgent.Integration.Claude.chat("ping") do
  {:ok, _} -> Logger.info("Emergency fallback working")
  {:error, reason} -> Logger.error("Emergency fallback failed: #{inspect(reason)}")
end
```

## Version Management

Update the emergency CLI:

```bash
# Install stable (default)
./scripts/install_claude_native.sh

# Install latest
./scripts/install_claude_native.sh latest

# Install specific version
./scripts/install_claude_native.sh v0.13.0
```

## Benefits

1. **Isolation**: Emergency binary won't conflict with user's Claude installation
2. **Reliability**: Always available even if HTTP server crashes
3. **Security**: Dedicated credentials location separate from user data
4. **Portability**: Can be bundled in Docker/Nix without affecting host system

## Verification

```bash
# Verify installation
~/.singularity/emergency/bin/claude-recovery --version

# Check available flags (including dangerous ones)
~/.singularity/emergency/bin/claude-recovery --help

# Test with credentials
~/.singularity/emergency/bin/claude-recovery chat --print "ping"
```

## Git Ignore

The `.singularity/` directory (containing recovery binaries) is gitignored and should **never** be committed:

```gitignore
# Local tooling & build outputs
.singularity/
```

Each environment installs its own recovery CLI locally.
