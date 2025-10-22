# GitHub Actions Secrets Setup Guide

## Required Secrets

This document lists all secrets needed for GitHub Actions workflows to function properly.

### 1. FLY_API_TOKEN (Required)
**Purpose:** Deploy to Fly.io  
**Used In:**
- `.github/workflows/deploy.yml`
- `.github/workflows/fly-oci-deploy.yml`

**How to Set:**
```bash
# 1. Login to Fly.io
fly auth login

# 2. Get your API token
fly auth token

# 3. Add to GitHub secrets
gh secret set FLY_API_TOKEN --body "YOUR_TOKEN_HERE"

# Or via GitHub UI:
# Go to: Settings → Secrets and variables → Actions → New repository secret
# Name: FLY_API_TOKEN
# Value: <paste token>
```

### 2. CLAUDE_CODE_OAUTH_TOKEN (Required for Claude features)
**Purpose:** Auto-review and auto-fix PRs using Claude Code  
**Used In:**
- `.github/workflows/claude-pr-fix.yml`
- `.github/workflows/claude-pr-review.yml`

**How to Set:**
```bash
# 1. Install Claude Code CLI (if not already installed)
# See: singularity_app/scripts/install_claude_native.sh

# 2. Run setup to get OAuth token
claude setup-token

# 3. Copy the CLAUDE_CODE_OAUTH_TOKEN from output

# 4. Add to GitHub secrets
gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "YOUR_TOKEN_HERE"

# Or via GitHub UI:
# Go to: Settings → Secrets and variables → Actions → New repository secret
# Name: CLAUDE_CODE_OAUTH_TOKEN
# Value: <paste token>
```

**Note:** This is the same token used in the `scripts/sync_secrets.sh` script.

### 3. CACHIX_AUTH_TOKEN (Optional but Recommended)
**Purpose:** Push Nix builds to Cachix cache for faster CI/CD  
**Used In:**
- `.github/workflows/nix-setup.yml`
- `.github/workflows/fly-oci-deploy.yml`
- All workflows that call `nix-setup.yml`

**How to Set:**
```bash
# 1. Create account at https://app.cachix.org

# 2. Create or use existing cache named "mikkihugo"

# 3. Generate auth token from Cachix dashboard

# 4. Add to GitHub secrets
gh secret set CACHIX_AUTH_TOKEN --body "YOUR_TOKEN_HERE"

# Or via GitHub UI:
# Go to: Settings → Secrets and variables → Actions → New repository secret
# Name: CACHIX_AUTH_TOKEN
# Value: <paste token>
```

**Benefits:**
- Speeds up CI/CD by caching Nix builds
- Reduces build times from ~20min to ~5min
- Shared cache across all workflows and contributors

**Without this secret:**
- Workflows will still work
- Builds will be slower (no cache reuse)
- Line in nix-setup.yml handles this gracefully

## Secrets NOT Needed in GitHub Actions

### AGE_SECRET_KEY
**Purpose:** Decrypt credentials at runtime on Fly.io  
**Where it's stored:** Fly.io secrets only  
**Why not in GitHub:** Used for runtime decryption, not build-time

**How to set in Fly.io:**
```bash
# From llm-server directory
cd llm-server

# Setup encryption (generates .age-key.txt)
./scripts/setup-encryption.sh singularity

# This automatically sets the secret in Fly.io
# Verify:
flyctl secrets list --app singularity
```

**See also:** `docs/setup/CREDENTIALS_ENCRYPTION.md`

### GITHUB_TOKEN
**Purpose:** Interact with GitHub API (comment on PRs, merge, etc.)  
**Where it comes from:** Automatically provided by GitHub Actions  
**Why not needed:** Built-in to all workflows

**Note:** In some workflows, this is passed as `${{ secrets.GITHUB_TOKEN }}` but no manual setup is required.

## Verification

### Check which secrets are currently set:
```bash
# List all secrets (values are hidden)
gh secret list

# Expected output:
# CACHIX_AUTH_TOKEN        Updated 2024-XX-XX
# CLAUDE_CODE_OAUTH_TOKEN  Updated 2024-XX-XX
# FLY_API_TOKEN            Updated 2024-XX-XX
```

### Test secrets in workflows:

1. **Test FLY_API_TOKEN:**
   ```bash
   # Trigger deploy workflow
   gh workflow run deploy.yml
   
   # Check logs
   gh run list --workflow=deploy.yml
   ```

2. **Test CLAUDE_CODE_OAUTH_TOKEN:**
   ```bash
   # Comment on a PR with:
   @claude Review this PR
   
   # Or:
   @claude-fix Fix the linting errors
   ```

3. **Test CACHIX_AUTH_TOKEN:**
   ```bash
   # Push to main/master (triggers ci-elixir.yml with cachix_push=true)
   git push origin main
   
   # Check workflow logs for "cachix push" step
   gh run list --workflow=ci-elixir.yml
   ```

## Security Best Practices

### Do:
- ✅ Rotate tokens regularly (every 90 days recommended)
- ✅ Use minimal permissions for tokens
- ✅ Store secrets only in GitHub Secrets (encrypted)
- ✅ Review secret access logs periodically
- ✅ Remove unused secrets

### Don't:
- ❌ Commit secrets to git
- ❌ Share secrets in Slack/Discord
- ❌ Use personal tokens for org workflows
- ❌ Hardcode secrets in workflow files
- ❌ Log secret values in workflow output

## Troubleshooting

### Secret not working in workflow

1. **Verify secret is set:**
   ```bash
   gh secret list
   ```

2. **Check secret name matches exactly:**
   - Names are case-sensitive
   - No spaces or special characters

3. **Check workflow has permission:**
   - Repository secrets are available to all workflows
   - Organization secrets may have restrictions

4. **Re-set the secret:**
   ```bash
   gh secret set SECRET_NAME --body "NEW_VALUE"
   ```

### Token expired

**FLY_API_TOKEN:**
```bash
fly auth login
fly auth token
gh secret set FLY_API_TOKEN --body "NEW_TOKEN"
```

**CLAUDE_CODE_OAUTH_TOKEN:**
```bash
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "NEW_TOKEN"
```

**CACHIX_AUTH_TOKEN:**
- Login to https://app.cachix.org
- Revoke old token
- Generate new token
- Update secret

## Syncing Secrets

The `scripts/sync_secrets.sh` script can sync some secrets to both Fly.io and GitHub:

```bash
# Set environment variables
export CLAUDE_CODE_OAUTH_TOKEN="your_token"
export GITHUB_TOKEN="your_github_pat"

# Run sync script
./scripts/sync_secrets.sh

# This sets:
# - Fly.io: CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN, HTTP_SERVER_ENABLED
# - GitHub: CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN
```

**Note:** This script does NOT sync FLY_API_TOKEN or CACHIX_AUTH_TOKEN.

## Related Documentation

- [GITHUB_ACTIONS_AUDIT.md](./GITHUB_ACTIONS_AUDIT.md) - Complete workflow audit
- [CREDENTIALS_ENCRYPTION.md](./setup/CREDENTIALS_ENCRYPTION.md) - AGE encryption setup
- [QUICKSTART.md](./setup/QUICKSTART.md) - General setup guide
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

## Quick Reference

| Secret | Required? | Where Used | How to Get |
|--------|-----------|------------|------------|
| FLY_API_TOKEN | Yes | Deployments | `fly auth token` |
| CLAUDE_CODE_OAUTH_TOKEN | Yes* | Claude PR features | `claude setup-token` |
| CACHIX_AUTH_TOKEN | No | Nix caching | https://app.cachix.org |
| AGE_SECRET_KEY | No** | N/A | In Fly.io only |
| GITHUB_TOKEN | No*** | PR automation | Auto-provided |

\* Required only if using Claude PR review/fix features  
\** Not used in GitHub Actions, only in Fly.io  
\*** Automatically provided by GitHub Actions
