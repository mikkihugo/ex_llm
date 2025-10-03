# Quick Start Guide

Get the AI Providers Server deployed to fly.io in 5 minutes.

## Prerequisites

```bash
# Install Nix with flakes
sh <(curl -L https://nixos.org/nix/install) --daemon
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Install fly.io CLI
curl -L https://fly.io/install.sh | sh
flyctl auth login

# Install age for encryption
nix-env -iA nixpkgs.age
# or: brew install age
```

## One-Time Setup (5 minutes)

### 1. Authenticate with AI Providers

```bash
# Gemini (both providers)
gcloud auth application-default login

# Claude
claude setup-token

# Cursor
cursor-agent login

# GitHub Copilot
gh auth login
```

### 2. Encrypt and Store Credentials

```bash
cd ai-server

# Generate key and store in fly.io
./scripts/setup-encryption.sh oneshot

# Encrypt credentials
./scripts/encrypt-credentials.sh

# The script shows a key - copy it
# Add to GitHub Secrets:
#   Name: AGE_SECRET_KEY
#   Value: <paste the key>
```

### 3. Commit Encrypted Credentials

```bash
# These are SAFE to commit (encrypted with age)
git add .credentials.encrypted/*.age
git commit -m "Add encrypted AI provider credentials"
git push
```

### 4. Deploy to Fly.io

```bash
cd ..  # Back to project root

# Build with Nix
nix build .#oneshot-integrated

# Deploy
flyctl deploy --app oneshot --config fly-integrated.toml --nixpacks
```

## That's It!

Your server is now running with:
- ✅ Elixir app on port 8080
- ✅ AI Server on port 3000 (internal)
- ✅ All credentials decrypted automatically
- ✅ Encrypted credentials safe in git

## Test It

```bash
# Check status
flyctl status --app oneshot

# View logs
flyctl logs --app oneshot

# Test from Elixir app (internally accessible)
# The AI server is at http://localhost:3000
```

## Daily Use

### Update Credentials

```bash
# Re-authenticate with a provider
claude setup-token  # Updates ~/.claude/.credentials.json

# Re-encrypt
cd ai-server
./scripts/encrypt-credentials.sh

# Commit and push
git add .credentials.encrypted/*.age
git commit -m "Update Claude credentials"
git push  # Auto-deploys via GitHub Actions
```

### Local Development

```bash
# Terminal 1: Elixir
mix phx.server

# Terminal 2: AI Server
cd ai-server
bun run dev

# Or run both with Nix
nix build .#oneshot-integrated
./result/bin/start-oneshot
```

## What Just Happened?

```
Local Machine:
  1. ./scripts/setup-encryption.sh
     ↓
  2. Generates .age-key.txt
     ↓
  3. Stores AGE_SECRET_KEY in fly.io secrets
     ↓
  4. ./scripts/encrypt-credentials.sh
     ↓
  5. Creates .credentials.encrypted/*.age (SAFE to commit)
     ↓
  6. git push

GitHub:
  7. Actions builds with Nix
     ↓
  8. Deploys to fly.io

Fly.io:
  9. Reads AGE_SECRET_KEY from secrets
     ↓
  10. Auto-decrypts .age files at startup
     ↓
  11. Runs both Elixir + AI Server
```

## Key Files

| File | Safe to Commit? | Purpose |
|------|----------------|---------|
| `.age-key.txt` | ❌ NO | Encryption key |
| `.credentials.encrypted/*.age` | ✅ YES | Encrypted credentials |
| `fly-integrated.toml` | ✅ YES | Deployment config |
| `flake.nix` | ✅ YES | Nix package definition |

## Secrets Storage

| Location | Name | Purpose |
|----------|------|---------|
| **Fly.io** | `AGE_SECRET_KEY` | Decrypt at runtime |
| **GitHub** | `AGE_SECRET_KEY` | For CI/CD |
| **Local** | `.age-key.txt` | Encrypt credentials |

## Common Commands

```bash
# Deploy
flyctl deploy --app oneshot --config fly-integrated.toml --nixpacks

# View logs
flyctl logs --app oneshot

# SSH into instance
flyctl ssh console --app oneshot

# Update secrets
flyctl secrets set AGE_SECRET_KEY="$(cat .age-key.txt)" --app oneshot

# Scale
flyctl scale count 2 --app oneshot

# Check secrets
flyctl secrets list --app oneshot
```

## Troubleshooting

### Deployment fails

```bash
# Check build locally
nix build .#oneshot-integrated --show-trace

# Check fly.io logs
flyctl logs --app oneshot
```

### Credentials not working

```bash
# Re-encrypt
cd ai-server
./scripts/encrypt-credentials.sh

# Verify AGE_SECRET_KEY is set
flyctl secrets list --app oneshot

# Redeploy
flyctl deploy --app oneshot --config fly-integrated.toml --nixpacks
```

### Need to rotate key

```bash
cd ai-server

# Remove old key
rm .age-key.txt

# Generate new key
./scripts/setup-encryption.sh oneshot

# Update GitHub secret with new key

# Re-encrypt all credentials
./scripts/encrypt-credentials.sh

# Commit and deploy
git add .credentials.encrypted/*.age
git commit -m "Rotate encryption key"
git push
```

## Next Steps

- Read [CREDENTIALS_ENCRYPTION.md](CREDENTIALS_ENCRYPTION.md) for details
- Read [NIX_DEPLOYMENT.md](NIX_DEPLOYMENT.md) for Nix specifics
- Read [DEPLOYMENT_OPTIONS.md](DEPLOYMENT_OPTIONS.md) for alternatives
- Read [ai-server/README.md](ai-server/README.md) for API docs

## Support

Issues? Check:
1. [Troubleshooting](#troubleshooting) above
2. `flyctl logs --app oneshot`
3. [Full docs](CREDENTIALS_ENCRYPTION.md)
