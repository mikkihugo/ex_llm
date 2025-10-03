#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

: "${FLY_APP_NAME:=}"
APP_ARG=${FLY_APP_NAME:+--app "$FLY_APP_NAME"}

require_var() {
  local name=$1
  if [[ -z "${!name:-}" ]]; then
    echo "Missing environment variable: $name" >&2
    exit 1
  fi
}

require_var CLAUDE_CODE_OAUTH_TOKEN
require_var GITHUB_TOKEN

echo "➡️  Syncing secrets to Fly"
set -x
flyctl secrets set CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" GITHUB_TOKEN="$GITHUB_TOKEN" HTTP_SERVER_ENABLED="true" ${APP_ARG:-}
set +x

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  set -x
  flyctl secrets set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" ${APP_ARG:-}
  set +x
fi

echo "➡️  Syncing secrets to GitHub"
if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required to sync repo secrets" >&2
  exit 1
fi

repo="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
set -x
gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "$CLAUDE_CODE_OAUTH_TOKEN" --repo "$repo"
gh secret set GITHUB_TOKEN --body "$GITHUB_TOKEN" --repo "$repo"
set +x

echo "✅ Secrets updated for Fly${FLY_APP_NAME:+ ($FLY_APP_NAME)} and GitHub ($repo)"
