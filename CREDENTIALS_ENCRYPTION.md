# Encrypted Credentials Workflow

Safe way to store and distribute AI provider credentials using encryption.

## Why Encrypt Credentials?

❌ **DON'T** commit raw credentials:
- `~/.claude/.credentials.json` ← Contains API tokens
- `~/.config/gcloud/application_default_credentials.json` ← Contains secrets
- `~/.config/cursor/auth.json` ← Contains OAuth tokens

✅ **DO** commit encrypted credentials:
- `.credentials.encrypted/*.age` ← Safe to commit
- Encrypted with `age` (modern, simple, secure)
- Decrypt at runtime using secret key

## Architecture

```
┌─────────────────────────────────────────────┐
│ Developer Machine                           │
│                                             │
│  1. Run: ./scripts/setup-encryption.sh     │
│     ↓                                       │
│  2. Generates .age-key.txt                 │
│     ↓                                       │
│  3. Stores in fly.io: AGE_SECRET_KEY       │
│     ↓                                       │
│  4. Shows key → Copy to GitHub Secrets     │
│                                             │
│  5. Run: ./scripts/encrypt-credentials.sh  │
│     ↓                                       │
│  6. Creates .credentials.encrypted/*.age   │
│     ↓                                       │
│  7. git add .credentials.encrypted/*.age   │
│  8. git commit -m "Add encrypted creds"    │
│  9. git push                                │
└─────────────────────────────────────────────┘
                    │
                    │ GitHub push
                    ↓
┌─────────────────────────────────────────────┐
│ GitHub Actions (CI/CD)                      │
│                                             │
│  - Builds with Nix                         │
│  - Deploys to fly.io                       │
│  - No credential handling needed           │
│  - Encrypted files go to fly.io            │
└─────────────────────────────────────────────┘
                    │
                    │ Deploy
                    ↓
┌─────────────────────────────────────────────┐
│ Fly.io Runtime                              │
│                                             │
│  1. Starts with AGE_SECRET_KEY in env      │
│  2. Wrapper script detects .age files      │
│  3. Runs: ./scripts/decrypt-credentials.sh │
│     ↓                                       │
│  4. Decrypts using AGE_SECRET_KEY          │
│     ↓                                       │
│  5. Writes to ~/.config/, ~/.claude/       │
│     ↓                                       │
│  6. Starts AI server with credentials      │
└─────────────────────────────────────────────┘
```

## Setup (One-Time)

### Step 1: Generate Key and Store in Fly.io

```bash
cd ai-server
./scripts/setup-encryption.sh oneshot
```

This will:
1. Generate `.age-key.txt`
2. Store it in fly.io as `AGE_SECRET_KEY`
3. Display the key for GitHub

### Step 2: Add Key to GitHub Secrets

```bash
# The setup script shows the key - copy it

# Then add to GitHub:
# 1. Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions
# 2. Click "New repository secret"
# 3. Name: AGE_SECRET_KEY
# 4. Value: <paste the key>
# 5. Click "Add secret"
```

### Step 3: Encrypt Credentials

```bash
# Still in ai-server/
./scripts/encrypt-credentials.sh
```

This creates:
```
.credentials.encrypted/
├── gcloud-adc.json.age          # ← Encrypted Gemini ADC
├── claude-credentials.json.age  # ← Encrypted Claude token
└── cursor-auth.json.age         # ← Encrypted Cursor OAuth
```

### Step 4: Commit Encrypted Files

```bash
# These are SAFE to commit
git add .credentials.encrypted/*.age
git commit -m "Add encrypted AI provider credentials"
git push
```

## Daily Workflow

### Adding New Credentials

```bash
# 1. Authenticate with provider (updates local JSON files)
claude setup-token              # Updates ~/.claude/.credentials.json
cursor-agent login              # Updates ~/.config/cursor/auth.json
gcloud auth application-default login  # Updates gcloud ADC

# 2. Re-encrypt
cd ai-server
./scripts/encrypt-credentials.sh

# 3. Commit updated encrypted files
git add .credentials.encrypted/*.age
git commit -m "Update encrypted credentials"
git push
```

### Rotating Keys

```bash
# Generate new key
cd ai-server
rm .age-key.txt
./scripts/setup-encryption.sh oneshot

# Update GitHub secret with new key
# (copy from setup script output)

# Re-encrypt all credentials with new key
./scripts/encrypt-credentials.sh

# Commit new encrypted files
git add .credentials.encrypted/*.age
git commit -m "Rotate encryption key"
git push
```

## How Decryption Works

### Automatic on Fly.io

The Nix wrapper script automatically decrypts:

```bash
# In /nix/store/.../bin/ai-server:

if [ -n "$AGE_SECRET_KEY" ] && [ -d ".credentials.encrypted" ]; then
    echo "🔓 Decrypting credentials..."
    ./scripts/decrypt-credentials.sh .credentials.encrypted
fi

exec bun run src/server.ts
```

### Manual Decryption (for testing)

```bash
# Set key in environment
export AGE_SECRET_KEY="$(cat .age-key.txt)"

# Decrypt
cd ai-server
./scripts/decrypt-credentials.sh

# Credentials are now in standard locations:
ls ~/.config/gcloud/application_default_credentials.json
ls ~/.claude/.credentials.json
ls ~/.config/cursor/auth.json
```

## Security Model

### What's Encrypted?
- ✓ OAuth tokens
- ✓ API keys
- ✓ Refresh tokens
- ✓ Account IDs

### What's NOT Encrypted?
- Code (public repo)
- Configuration (fly.toml, etc.)
- Encrypted .age files (safe to commit)

### Where's the Key?
1. **Local**: `.age-key.txt` (gitignored)
2. **Fly.io**: Secret `AGE_SECRET_KEY` (runtime decryption)
3. **GitHub**: Secret `AGE_SECRET_KEY` (CI/CD, if needed)

### Key Properties
- 🔐 Modern encryption (`age` by @FiloSottile)
- 🔑 Single key for all credentials
- 📦 Encrypted files safe in git
- 🚀 Auto-decrypt on deployment
- 🔄 Easy rotation

## Files Reference

### Encryption Scripts

| File | Purpose |
|------|---------|
| `scripts/setup-encryption.sh` | One-time: Generate key, store in fly.io + GitHub |
| `scripts/encrypt-credentials.sh` | Encrypt local credentials → .age files |
| `scripts/decrypt-credentials.sh` | Decrypt .age files → local credentials |

### Key Files

| File | Safe to Commit? | Purpose |
|------|----------------|---------|
| `.age-key.txt` | ❌ NO | Encryption key (gitignored) |
| `.credentials.encrypted/*.age` | ✅ YES | Encrypted credentials |
| Raw JSON files | ❌ NO | Unencrypted credentials (gitignored) |

### Secrets Storage

| Location | Secret Name | Purpose |
|----------|------------|---------|
| **Fly.io** | `AGE_SECRET_KEY` | Runtime decryption |
| **GitHub** | `AGE_SECRET_KEY` | CI/CD (if needed) |
| **Local** | `.age-key.txt` | Encryption |

## Troubleshooting

### "age command not found"

```bash
# macOS
brew install age

# Linux (Nix)
nix-env -iA nixpkgs.age

# Linux (apt)
apt install age
```

### Decryption Fails on Fly.io

```bash
# Check if secret is set
flyctl secrets list --app oneshot

# Should show: AGE_SECRET_KEY

# If missing, set it:
flyctl secrets set AGE_SECRET_KEY="$(cat .age-key.txt)" --app oneshot
```

### Lost .age-key.txt

If you lose the key but have it in fly.io:

```bash
# Get from fly.io (requires deploy to see it)
flyctl ssh console --app oneshot
echo $AGE_SECRET_KEY > /tmp/key.txt
age-keygen -y /tmp/key.txt  # Get public key

# Or from GitHub secrets UI
# Copy the value and save to .age-key.txt
```

### Wrong Credentials After Deploy

```bash
# Re-encrypt with current credentials
cd ai-server
./scripts/encrypt-credentials.sh

# Commit and redeploy
git add .credentials.encrypted/*.age
git commit -m "Update credentials"
git push  # Triggers auto-deploy
```

## Comparison with Alternatives

### vs Base64 in Secrets

| Approach | Encrypted Files | Base64 in Secrets |
|----------|----------------|-------------------|
| **Storage** | Git (version controlled) | fly.io only |
| **Rotation** | Git commit | flyctl secrets set |
| **Audit** | Git history | No history |
| **Portability** | Works anywhere | fly.io specific |
| **Security** | Encrypted | Encoded (not encrypted) |

### vs Vault/Secret Managers

| Feature | age Encryption | HashiCorp Vault |
|---------|---------------|-----------------|
| **Complexity** | Low | High |
| **Setup** | 1 command | Server + config |
| **Cost** | Free | Paid/hosted |
| **Dependencies** | Just `age` | Vault server |
| **Good for** | Small teams | Enterprise |

## See Also

- [age encryption tool](https://github.com/FiloSottile/age)
- [Fly.io Secrets](https://fly.io/docs/reference/secrets/)
- [GitHub Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
