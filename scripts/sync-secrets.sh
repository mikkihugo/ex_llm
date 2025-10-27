#!/usr/bin/env bash
# Sync secrets between environments using a private GitHub Gist
# Usage:
#   ./scripts/sync-secrets.sh setup   # Initial setup (create gist)
#   ./scripts/sync-secrets.sh push    # Push .envrc.local → private gist
#   ./scripts/sync-secrets.sh pull    # Pull private gist → .envrc.local
#   ./scripts/sync-secrets.sh show    # Show current gist URL

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVRC_LOCAL="${REPO_ROOT}/.envrc.local"
GIST_ID_FILE="${REPO_ROOT}/.gist_id"

usage() {
  cat <<EOF
🔐 Secret Sync - Sync secrets across environments using private GitHub Gist

Usage: $0 {setup|push|pull|show}

Commands:
  setup   Create a new private gist for secrets (one-time)
  push    Upload .envrc.local to private gist
  pull    Download private gist to .envrc.local
  show    Display gist URL and sync status

How it works:
  1. Run 'setup' once to create a private gist
  2. Use 'push' to upload your local secrets
  3. Use 'pull' on other machines to sync secrets
  4. Gist ID is stored in .gist_id (git-ignored)

Security:
  ✅ Gist is PRIVATE (only you can access)
  ✅ .envrc.local is git-ignored
  ✅ .gist_id is git-ignored
  ⚠️  Keep your GitHub token secure!

Requirements:
  - gh CLI (GitHub CLI)
  - Authenticated: gh auth login
EOF
  exit 1
}

check_gh_auth() {
  if ! gh auth status &>/dev/null; then
    echo "❌ Error: Not authenticated with GitHub CLI"
    echo ""
    echo "Run: gh auth login"
    exit 1
  fi
}

setup_gist() {
  check_gh_auth

  echo "🔧 Setting up private gist for secrets..."

  if [ -f "$GIST_ID_FILE" ]; then
    GIST_ID=$(cat "$GIST_ID_FILE")
    echo "⚠️  Gist already exists: https://gist.github.com/$GIST_ID"
    read -p "Create a new gist? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      exit 0
    fi
  fi

  if [ ! -f "$ENVRC_LOCAL" ]; then
    echo "📝 Creating .envrc.local template..."
    cat > "$ENVRC_LOCAL" <<'EOF'
# .envrc.local - Local secrets (git-ignored)
# Synced via private GitHub Gist
# DO NOT COMMIT THIS FILE

# Phoenix
export SECRET_KEY_BASE="BNgh9981"

# Cachix (optional - for pushing to binary cache)
# export CACHIX_AUTH_TOKEN="your_token_here"

# Claude Code (optional)
# export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-xxxxx"

# Google Cloud (optional)
# export GOOGLE_APPLICATION_CREDENTIALS_JSON="base64_encoded_json"

# Chat integrations (optional)
# export SLACK_TOKEN="xoxe-xoxp-xxxxx"
# export GOOGLE_CHAT_WEBHOOK_URL="https://chat.googleapis.com/..."
EOF
    echo "  ✅ Created .envrc.local template"
    echo ""
    echo "📝 Please edit .envrc.local with your actual secrets, then run:"
    echo "   ./scripts/sync-secrets.sh push"
    exit 0
  fi

  # Create private gist (default is secret/private, no flag needed)
  echo "📤 Creating private gist..."
  GIST_URL=$(gh gist create "$ENVRC_LOCAL" \
    --filename "envrc.local" \
    --desc "Singularity secrets (PRIVATE - synced across environments)")

  # Extract gist ID from URL
  GIST_ID=$(basename "$GIST_URL")
  echo "$GIST_ID" > "$GIST_ID_FILE"

  echo ""
  echo "✅ Private gist created!"
  echo "   URL: $GIST_URL"
  echo "   ID:  $GIST_ID"
  echo ""
  echo "📋 Gist ID saved to .gist_id (git-ignored)"
  echo ""
  echo "Next steps:"
  echo "  1. On this machine: Edit .envrc.local with your secrets"
  echo "  2. Push secrets: ./scripts/sync-secrets.sh push"
  echo "  3. On other machines: ./scripts/sync-secrets.sh pull"
}

push_secrets() {
  check_gh_auth

  if [ ! -f "$GIST_ID_FILE" ]; then
    echo "❌ Error: Gist not set up yet"
    echo "Run: ./scripts/sync-secrets.sh setup"
    exit 1
  fi

  if [ ! -f "$ENVRC_LOCAL" ]; then
    echo "❌ Error: .envrc.local not found"
    exit 1
  fi

  GIST_ID=$(cat "$GIST_ID_FILE")

  echo "📤 Pushing secrets..."
  echo ""

  # 1. Push to gist (for local sync across machines)
  echo "1️⃣  Updating gist $GIST_ID..."
  gh gist edit "$GIST_ID" "$ENVRC_LOCAL"
  echo "   ✅ Gist updated: https://gist.github.com/$GIST_ID"
  echo ""

  # 2. Push to GitHub repository secrets (for CI/CD)
  echo "2️⃣  Updating GitHub repository secrets (for CI/CD)..."

  # Source .envrc.local to get values
  set +u  # Allow unset variables
  source "$ENVRC_LOCAL"
  set -u

  # List of secrets to sync to GitHub
  # Note: GITHUB_TOKEN is excluded - GitHub Actions provides it automatically
  # Note: Google auth uses @google/gemini-cli OAuth (no ADC needed)
  GITHUB_SECRETS=(
    "CACHIX_AUTH_TOKEN"
    "CLAUDE_CODE_OAUTH_TOKEN"
    "GOOGLE_JULES_API_KEY"
    "OPENROUTER_API_KEY"
    "XAI_API_KEY"
    "ANTHROPIC_API_KEY"
    "GEMINI_AI_STUDIO_API_KEY"
    "GOOGLE_CLIENT_ID"
    "GOOGLE_CLIENT_SECRET"
  )

  for secret in "${GITHUB_SECRETS[@]}"; do
    # Get value from environment (set by sourcing .envrc.local)
    value="${!secret:-}"

    if [ -n "$value" ]; then
      echo "   Setting $secret..."
      echo "$value" | gh secret set "$secret"
      echo "   ✅ $secret synced to GitHub"
    else
      echo "   ⏭️  $secret not set, skipping"
    fi
  done

  echo ""
  echo "✅ All secrets pushed!"
  echo ""
  echo "📋 Summary:"
  echo "   • Gist (local sync):  https://gist.github.com/$GIST_ID"
  echo "   • GitHub secrets:     Available in GitHub Actions"
  echo ""
  echo "💡 On other machines: Secrets auto-sync on next 'cd'"
}

pull_secrets() {
  check_gh_auth

  if [ ! -f "$GIST_ID_FILE" ]; then
    echo "❌ Error: Gist not set up yet"
    echo ""
    echo "If this is a new machine:"
    echo "  1. Get the gist ID from another machine (.gist_id file)"
    echo "  2. Create .gist_id here: echo 'YOUR_GIST_ID' > .gist_id"
    echo "  3. Run this command again"
    echo ""
    echo "Or run 'setup' to create a new gist"
    exit 1
  fi

  GIST_ID=$(cat "$GIST_ID_FILE")

  echo "📥 Pulling secrets from gist $GIST_ID..."

  # Backup existing .envrc.local
  if [ -f "$ENVRC_LOCAL" ]; then
    BACKUP="${ENVRC_LOCAL}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENVRC_LOCAL" "$BACKUP"
    echo "📋 Backed up existing .envrc.local to: $BACKUP"
  fi

  # Download gist
  gh gist view "$GIST_ID" --raw --filename "envrc.local" > "$ENVRC_LOCAL"

  echo "✅ Secrets pulled from gist!"
  echo "   Saved to: $ENVRC_LOCAL"
  echo ""
  echo "💡 Reload direnv: direnv allow"
}

show_status() {
  if [ ! -f "$GIST_ID_FILE" ]; then
    echo "❌ Gist not set up yet"
    echo ""
    echo "Run: ./scripts/sync-secrets.sh setup"
    exit 1
  fi

  GIST_ID=$(cat "$GIST_ID_FILE")
  GIST_URL="https://gist.github.com/$GIST_ID"

  echo "🔐 Secret Sync Status"
  echo ""
  echo "Gist URL:    $GIST_URL"
  echo "Gist ID:     $GIST_ID"
  echo "Local file:  $ENVRC_LOCAL"
  echo ""

  if [ -f "$ENVRC_LOCAL" ]; then
    echo "✅ Local .envrc.local exists"
    echo "   Last modified: $(stat -f %Sm -t '%Y-%m-%d %H:%M:%S' "$ENVRC_LOCAL" 2>/dev/null || stat -c %y "$ENVRC_LOCAL" 2>/dev/null)"
  else
    echo "❌ Local .envrc.local not found"
  fi

  echo ""
  echo "Commands:"
  echo "  Push: ./scripts/sync-secrets.sh push"
  echo "  Pull: ./scripts/sync-secrets.sh pull"
}

# Main
case "${1:-}" in
  setup)
    setup_gist
    ;;
  push)
    push_secrets
    ;;
  pull)
    pull_secrets
    ;;
  show)
    show_status
    ;;
  *)
    usage
    ;;
esac
