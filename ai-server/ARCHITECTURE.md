# AI Server Architecture

Self-contained Bun application for bridging AI CLI providers via HTTP.

## Design Principles

### 1. **Self-Contained**
- Own `package.json` with dependencies
- Own `node_modules/` (managed by Bun)
- Own `.gitignore`
- Can run standalone: `cd ai-server && bun run start`

### 2. **Bun Only - No Node.js**
- Bun provides all Node.js APIs we need
- Faster startup and runtime
- Native TypeScript support
- Smaller dependency footprint

### 3. **Working Directory Aware**
- Nix wrapper script handles `cd` to correct directory
- Bun runs from `ai-server/` base directory
- All imports relative to this base

### 4. **Nix Build Process**

```bash
# Source: ./ai-server only
# Build:
  1. Copy ai-server/ to /build
  2. Run: bun install --frozen-lockfile
  3. Copy everything to /nix/store/.../ai-server/
  4. Create wrapper: /nix/store/.../bin/ai-server

# Wrapper script:
  cd $out/ai-server
  exec bun run src/server.ts
```

## Directory Structure

```
ai-server/
├── package.json           # Independent package config
├── bun.lockb             # Bun lock file (gitignored)
├── .gitignore            # AI server specific ignores
├── README.md             # Usage documentation
├── ARCHITECTURE.md       # This file
├── src/
│   ├── server.ts         # Main HTTP server
│   └── load-credentials.ts  # Credential loading
├── scripts/
│   ├── bundle-credentials.sh  # Bundle for deployment
│   └── deploy-fly.sh          # Deploy to fly.io
└── node_modules/         # Dependencies (gitignored)
```

## Build Outputs

### Local Development
```
ai-server/
└── node_modules/  # Created by: bun install
```

### Nix Build
```
/nix/store/<hash>-ai-server/
├── bin/
│   └── ai-server       # Wrapper script
└── ai-server/
    ├── package.json
    ├── node_modules/   # All dependencies
    └── src/
        └── server.ts
```

### Docker Image
```
/app/
├── bin/
│   └── ai-server       # Wrapper script
└── ai-server/
    ├── package.json
    ├── node_modules/
    └── src/
```

## Deployment Workflow

### Local Development
```bash
cd ai-server
bun install          # Install dependencies
bun run dev          # Start with watch mode
```

### Nix Build
```bash
nix build .#ai-server     # Build package
./result/bin/ai-server    # Run built package
```

### Fly.io Deployment
```bash
./ai-server/scripts/bundle-credentials.sh
./ai-server/scripts/deploy-fly.sh
```

## Key Files

### `/ai-server/package.json`
- **Independent** from root package.json
- Contains only AI server dependencies
- Scripts: `start`, `dev`

### `/flake.nix`
- Defines `packages.ai-server`
- Source: `./ai-server` only
- Build with Bun, no Node.js needed

### `/Dockerfile.nix`
- Multi-stage build
- Stage 1: Nix build
- Stage 2: Minimal runtime (Debian + built package)

### `/ai-server/src/server.ts`
- Main entry point
- Imports from `./load-credentials`
- Runs from `ai-server/` as working directory

## Why This Structure?

### ✅ Benefits

1. **Clear Separation**: AI server is isolated from Elixir code
2. **Self-Contained**: Can `cd ai-server && bun run start` independently
3. **No Confusion**: Root `package.json` just delegates to ai-server
4. **Easy to Build**: Nix only needs `ai-server/` directory
5. **Portable**: Whole ai-server/ can be copied anywhere
6. **Simpler CI/CD**: Only build what changed

### ✅ Working Directory Management

The wrapper script handles directory management:

```bash
#!/usr/bin/env bash
cd $out/ai-server      # Change to base directory
exec bun run src/server.ts  # Bun runs from here
```

This means:
- Imports work: `import { x } from './load-credentials'`
- File paths work: `./scripts/bundle-credentials.sh`
- Everything relative to `ai-server/` base

### ✅ No Node.js Needed

Bun provides everything:
- ES modules
- TypeScript
- Node.js APIs
- Package management
- Faster than Node.js

## Environment Variables

Set in deployment, loaded by `load-credentials.ts`:

```bash
GOOGLE_APPLICATION_CREDENTIALS_JSON  # Base64 Gemini ADC
CLAUDE_ACCESS_TOKEN                  # Claude OAuth token
CURSOR_AUTH_JSON                     # Base64 Cursor OAuth
GH_TOKEN / GITHUB_TOKEN              # GitHub token
GEMINI_CODE_PROJECT                  # Gemini Code project
PORT                                 # Server port
```

## Integration Points

### From Elixir
```elixir
# config/runtime.exs
config :app, :ai_server_url,
  System.get_env("AI_SERVER_URL", "http://localhost:3000")

# Usage
HTTPoison.post("#{ai_server_url}/chat", ...)
```

### From Other Services
```bash
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{"provider": "gemini-code-cli", "messages": [...]}'
```

## Testing

### Unit Tests
```bash
cd ai-server
bun test
```

### Integration Tests
```bash
# Start server
bun run dev

# Test endpoints
curl http://localhost:3000/health
```

### Nix Build Test
```bash
nix build .#ai-server
./result/bin/ai-server
```

## See Also

- [README.md](README.md) - Usage guide
- [../FLY_DEPLOYMENT.md](../FLY_DEPLOYMENT.md) - Fly.io deployment
- [../flake.nix](../flake.nix) - Nix package definition
