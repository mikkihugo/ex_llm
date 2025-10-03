# Pure Nix Deployment (No Docker)

Deploy to fly.io using pure Nix - no Docker or Podman required.

## Why Nix Instead of Docker?

✅ **Reproducible** - Exact same build every time
✅ **Cacheable** - Nix store enables efficient caching
✅ **Declarative** - Everything in `flake.nix`
✅ **Smaller** - No Docker layers overhead
✅ **Faster** - Binary cache hits
✅ **No Docker daemon** - Works without Docker/Podman

## How It Works

```
Local Machine                    Fly.io
─────────────                    ──────

1. nix build .#oneshot-integrated
   ↓
2. Creates /nix/store closure
   ↓
3. nixpacks detects flake.nix
   ↓
4. fly.io builds with Nix  ───────→  Nix environment
   ↓                                  ↓
5. Runs /app/bin/start-oneshot   ←── Executes binaries
```

## Prerequisites

### 1. Nix with Flakes

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 2. Fly.io CLI

```bash
curl -L https://fly.io/install.sh | sh
flyctl auth login
```

## Deployment Steps

### Option 1: Automated Script (Recommended)

```bash
# Integrated deployment (Elixir + AI Server)
./scripts/deploy-fly-nix.sh oneshot integrated

# Or AI Server only
./scripts/deploy-fly-nix.sh oneshot-ai-providers ai-server-only
```

### Option 2: Manual Deployment

```bash
# 1. Build locally with Nix
nix build .#oneshot-integrated

# 2. Verify build
./result/bin/web          # Test Elixir
./result/bin/ai-server    # Test AI Server
./result/bin/start-oneshot # Test both

# 3. Bundle credentials
cd ai-server
./scripts/bundle-credentials.sh ../.env.fly
cd ..

# 4. Create app (first time only)
flyctl apps create oneshot

# 5. Create volume (first time only)
flyctl volumes create oneshot_data --size 1 --region iad --app oneshot

# 6. Set secrets
flyctl secrets set --app oneshot \
  GOOGLE_APPLICATION_CREDENTIALS_JSON="$(grep GOOGLE .env.fly | cut -d= -f2)" \
  CLAUDE_ACCESS_TOKEN="$(grep CLAUDE .env.fly | cut -d= -f2)" \
  CURSOR_AUTH_JSON="$(grep CURSOR .env.fly | cut -d= -f2)" \
  GH_TOKEN="$(grep GH_TOKEN .env.fly | cut -d= -f2)"

# 7. Deploy with nixpacks
flyctl deploy --app oneshot --config fly-integrated.toml --nixpacks
```

## Files Involved

### `flake.nix`
Defines Nix packages:
- `ai-server` - Standalone AI server
- `oneshot-integrated` - Both Elixir + AI server

### `nixpacks.toml`
Configuration for fly.io's nixpacks builder:
- Tells fly.io to use Nix
- Specifies build commands
- Defines start command

### `fly-integrated.toml`
Fly.io configuration:
- Multi-process setup
- Environment variables
- Health checks

## Build Process

### Local Build

```bash
# Build integrated package
nix build .#oneshot-integrated

# Result structure:
./result/
├── bin/
│   ├── start-oneshot   # Runs both processes
│   ├── web             # Elixir only
│   └── ai-server       # Bun only
├── elixir/             # Elixir app files
└── ai-server/          # AI server files
```

### Fly.io Build

When you run `flyctl deploy --nixpacks`:

1. Fly.io detects `flake.nix` and `nixpacks.toml`
2. Installs Nix in build environment
3. Runs `nix build .#oneshot-integrated`
4. Copies result to `/app/`
5. Sets up processes from `fly-integrated.toml`

## Process Management

### Integrated Deployment

Fly.io runs two processes:

```toml
[processes]
  web = "./result/bin/web"
  ai-server = "./result/bin/ai-server"
```

Each process gets its own VM, but they share:
- Internal network (localhost)
- Secrets
- Volumes

### Communication

```elixir
# From Elixir app:
HTTPoison.post("http://localhost:3000/chat", ...)
# ↑ ai-server is on localhost:3000 internally
```

## Advantages Over Docker

| Feature | Docker | Pure Nix |
|---------|--------|----------|
| **Build tool** | Docker daemon | Nix (no daemon) |
| **Layers** | Many layers | Nix store paths |
| **Caching** | Layer cache | Binary cache |
| **Reproducibility** | Approximate | Exact |
| **Size** | Larger (base image) | Smaller (only deps) |
| **Dependencies** | In Dockerfile | In flake.nix |
| **Local testing** | docker run | nix build && ./result/bin/... |

## Troubleshooting

### Build Fails

```bash
# Clean and rebuild
nix flake update
nix build .#oneshot-integrated --rebuild --show-trace

# Check build logs
flyctl logs --app oneshot
```

### Missing Dependencies

```bash
# Add to flake.nix buildInputs:
buildInputs = [
  pkgs.yourPackage
];

# Then rebuild
nix build .#oneshot-integrated
```

### Bun Install Issues

Dependencies auto-install during build:

```nix
buildPhase = ''
  cd ai-server
  if [ -f bun.lockb ]; then
    ${pkgs.bun}/bin/bun install --frozen-lockfile
  else
    ${pkgs.bun}/bin/bun install  # Auto-generates lockfile
  fi
'';
```

## Development Workflow

```bash
# 1. Make changes to code

# 2. Test locally with Nix
nix build .#oneshot-integrated
./result/bin/start-oneshot

# 3. Test locally with dev mode
mix phx.server                    # Terminal 1
cd ai-server && bun run dev       # Terminal 2

# 4. Deploy to fly.io
./scripts/deploy-fly-nix.sh oneshot integrated
```

## Binary Cache

Speed up builds with Nix binary cache:

```bash
# Add cachix for faster builds (optional)
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use nix-community

# Or set up your own cache
# See: https://docs.cachix.org/
```

## CI/CD with Pure Nix

### GitHub Actions

```yaml
name: Deploy to Fly.io

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v22
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes

      - uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Build with Nix
        run: nix build .#oneshot-integrated

      - name: Deploy to Fly.io
        run: flyctl deploy --app oneshot --config fly-integrated.toml --nixpacks
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

## Comparison: Deployment Methods

| Method | Build Tool | Deploy Tool | Pros | Cons |
|--------|-----------|-------------|------|------|
| **Pure Nix** | Nix | Nixpacks | Reproducible, fast cache | Requires Nix knowledge |
| **Docker** | Docker | Dockerfile | Familiar, portable | Larger, slower |
| **Podman** | Podman | Dockerfile | Daemonless | Still container-based |

## Why We Chose Pure Nix

1. **Already using Nix** - Project uses flake.nix for dev environment
2. **No extra tools** - Don't need Docker/Podman
3. **Faster builds** - Binary cache hits
4. **Exact reproducibility** - Same hash = same build
5. **Simpler CI** - Just `nix build`

## See Also

- [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) - Deployment strategies
- [flake.nix](flake.nix) - Nix package definitions
- [nixpacks.toml](nixpacks.toml) - Fly.io Nix configuration
- [Nixpacks Documentation](https://nixpacks.com/)
