# Secret Sync Guide

Sync secrets across your development environments using a **private GitHub Gist**.

## Quick Start

### On Your Primary Machine (First Time Setup)

```bash
# 1. Setup creates private gist and .envrc.local template
./scripts/sync-secrets.sh setup

# 2. Edit .envrc.local with your actual secrets
vim .envrc.local

# 3. Push secrets to private gist
./scripts/sync-secrets.sh push
```

### On Other Machines (Auto-Sync)

```bash
# Option 1: Automatic (just clone and enter directory)
git clone https://github.com/mikkihugo/singularity-incubation.git
cd singularity-incubation
direnv allow
# Secrets automatically downloaded from gist!

# Option 2: Manual
./scripts/sync-secrets.sh pull
direnv allow
```

## How It Works

1. **Private Gist**: Your secrets are stored in a private GitHub gist
   - URL: https://gist.github.com/mikkihugo/aefa228ec3a7337f887bc5fe6d3d5db3
   - Only you can access it (requires GitHub authentication)
   - Backed by Git (has commit history and hashes)

2. **Gist ID**: Stored in `.gist_id` (git-ignored, but shared across machines)
   - Contains: `aefa228ec3a7337f887bc5fe6d3d5db3`
   - Copy this file to new machines OR it's auto-fetched

3. **Local Secrets**: Stored in `.envrc.local` (git-ignored, auto-loaded by direnv)
   - Contains your actual secret values
   - Automatically loaded when you `cd` into the directory

4. **Auto-Sync with Hash Detection**: `.envrc` automatically pulls secrets
   - **New machine**: If `.gist_id` exists but `.envrc.local` doesn't → auto-pull
   - **Updated secrets**: Compares SHA256 hash of local vs remote → auto-pull if different
   - **Every `cd`**: Checks for updates when you enter the directory
   - Runs `./scripts/sync-secrets.sh pull` automatically when needed

## Commands

```bash
# Show current sync status
./scripts/sync-secrets.sh show

# Push local secrets to gist (after editing .envrc.local)
./scripts/sync-secrets.sh push

# Pull secrets from gist (on new machine or after changes)
./scripts/sync-secrets.sh pull

# Setup (only needed once, already done)
./scripts/sync-secrets.sh setup
```

## Adding a New Secret

### On Machine A (where you add the secret):

```bash
# 1. Edit .envrc.local
echo 'export MY_NEW_SECRET="value123"' >> .envrc.local

# 2. Push to gist
./scripts/sync-secrets.sh push

# 3. Reload direnv
direnv allow
```

### On Machine B (auto-syncs):

```bash
# Just pull the latest secrets
./scripts/sync-secrets.sh pull
direnv allow

# OR let it auto-sync next time you cd into the directory
```

## Secrets Synced

The following secrets are stored in `.envrc.local` and synced via gist:

- `SECRET_KEY_BASE` - Phoenix secret key (required)
- `CACHIX_AUTH_TOKEN` - Cachix binary cache token (optional)
- `CLAUDE_CODE_OAUTH_TOKEN` - Claude Code OAuth token (optional)
- `GOOGLE_APPLICATION_CREDENTIALS_JSON` - Google Cloud credentials (optional)
- `SLACK_TOKEN` - Slack bot token (optional)
- `GOOGLE_CHAT_WEBHOOK_URL` - Google Chat webhook (optional)

## Security

✅ **Private Gist**: Only you can access (requires GitHub auth)
✅ **Git-Ignored**: `.envrc.local` and `.gist_id` never committed
✅ **Encrypted in Transit**: HTTPS for all gist operations
✅ **GitHub Auth**: Uses your existing `gh` CLI authentication

⚠️ **Important**: Keep your GitHub token secure! Anyone with access to your GitHub account can read the gist.

## Troubleshooting

### "Gist not set up yet"

```bash
# Check if .gist_id exists
cat .gist_id
# Should contain: aefa228ec3a7337f887bc5fe6d3d5db3

# If missing, create it manually:
echo "aefa228ec3a7337f887bc5fe6d3d5db3" > .gist_id
./scripts/sync-secrets.sh pull
```

### "Not authenticated with GitHub CLI"

```bash
gh auth login
# Follow prompts to authenticate
```

### Secrets not loading in new shell

```bash
# Reload direnv
direnv allow
```

## GitHub Secrets (for CI/CD)

Separate from this gist sync system, GitHub repository secrets are used for CI/CD:

```bash
# List GitHub repository secrets
gh secret list

# Set a GitHub repository secret (for CI/CD only)
echo "value" | gh secret set SECRET_NAME
```

**Note**: GitHub repository secrets are **only** for GitHub Actions. They cannot be read locally. Use the gist sync system for local development.

## Files

- **`.envrc.local`** - Your actual secrets (git-ignored, synced via gist)
- **`.gist_id`** - Gist ID for syncing (git-ignored, but can be copied manually)
- **`scripts/sync-secrets.sh`** - Sync script
- **`.envrc`** - Loads `.envrc.local` automatically (has auto-pull logic)

## Workflow Example

```bash
# Machine 1: Set up and push secrets
cd ~/code/singularity-incubation
./scripts/sync-secrets.sh setup
vim .envrc.local  # Add your secrets
./scripts/sync-secrets.sh push

# Machine 2: Auto-pull secrets (first time)
cd ~/code/singularity-incubation
# 📥 Auto-syncing secrets from gist (new machine)...
# ✅ Secrets pulled from gist!
direnv allow

# Add new secret on Machine 2
echo 'export NEW_TOKEN="abc123"' >> .envrc.local
./scripts/sync-secrets.sh push

# Machine 1: Auto-detects update on next cd
cd ~/code/singularity-incubation
# 📥 Secrets updated in gist! Auto-syncing...
# ✅ Secrets pulled from gist!
direnv allow
```

## Visual Indicators

When you `cd` into the directory, you'll see:

- **New machine**: `📥 Auto-syncing secrets from gist (new machine)...`
- **Updated secrets**: `📥 Secrets updated in gist! Auto-syncing...`
- **No changes**: (silent, no output)
- **Success**: `✅ Secrets pulled from gist!`

## Best Practices

1. **Always push after adding secrets**: Don't forget to run `./scripts/sync-secrets.sh push`
2. **Pull before making changes**: Run `./scripts/sync-secrets.sh pull` to get latest
3. **Use descriptive comments**: Add comments in `.envrc.local` for clarity
4. **Backup your secrets**: The gist is your backup, but consider a password manager too
5. **Rotate secrets regularly**: Update secrets periodically for security

---

**Your Gist**: https://gist.github.com/mikkihugo/aefa228ec3a7337f887bc5fe6d3d5db3
