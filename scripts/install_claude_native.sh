#!/usr/bin/env bash
set -euo pipefail

CHANNEL=${1:-stable}
case "$CHANNEL" in
  stable) ARG="" ;;
  latest) ARG="latest" ;;
  *) ARG="$CHANNEL" ;;
esac

existing=$(command -v claude || true)
backup=""
if [[ -n "$existing" && -f "$existing" && -w $(dirname "$existing") ]]; then
  timestamp=$(date +%s)
  backup="${existing}.backup-${timestamp}"
  cp "$existing" "$backup"
  echo "📦 Backed up existing claude binary to $backup"
fi

restore() {
  if [[ -n "$backup" && -f "$backup" && -n "$existing" ]]; then
    echo "↩️  Restoring previous claude binary from $backup"
    cp "$backup" "$existing"
  fi
}

cleanup() {
  if [[ -n "$backup" && -f "$backup" ]]; then
    rm -f "$backup"
  fi
}

trap 'restore' ERR

if [[ -z "$ARG" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
else
  curl -fsSL https://claude.ai/install.sh | bash -s "$ARG"
fi

if ! command -v claude >/dev/null 2>&1 || ! claude --version >/dev/null 2>&1; then
  echo "❌ Claude CLI install failed; restoring backup" >&2
  restore
  exit 1
fi

echo "✅ Claude CLI installed: $(claude --version)"
cleanup
