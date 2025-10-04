#!/usr/bin/env bash
# Install Claude CLI to special recovery location for emergency fallback usage
# Installed as "claude-recovery" to avoid collision with system/NPM Claude
# This is used by Workbench.Integration.Claude as an emergency fallback
set -euo pipefail

CHANNEL=${1:-stable}
EMERGENCY_DIR="${SINGULARITY_EMERGENCY_BIN:-$HOME/.singularity/emergency/bin}"
EMERGENCY_CLAUDE="${EMERGENCY_DIR}/claude-recovery"

echo "🔧 Installing Claude CLI to recovery location: $EMERGENCY_CLAUDE"

# Create emergency bin directory
mkdir -p "$EMERGENCY_DIR"

# Install to standard location first
case "$CHANNEL" in
  stable) ARG="" ;;
  latest) ARG="latest" ;;
  *) ARG="$CHANNEL" ;;
esac

temp_install=$(mktemp -d)
trap 'rm -rf "$temp_install"' EXIT

echo "📥 Downloading Claude CLI ($CHANNEL)..."
if [[ -z "$ARG" ]]; then
  curl -fsSL https://claude.ai/install.sh | HOME="$temp_install" bash
else
  curl -fsSL https://claude.ai/install.sh | HOME="$temp_install" bash -s "$ARG"
fi

# Find the installed binary (installer puts it in ~/.local/bin/claude)
# Try multiple locations where the installer might place it
claude_bin=""
for candidate in \
  "$temp_install/.local/bin/claude" \
  "$temp_install/bin/claude" \
  "$HOME/.local/bin/claude" \
  "$(which claude 2>/dev/null)"; do
  if [[ -f "$candidate" && -x "$candidate" ]]; then
    claude_bin="$candidate"
    echo "📍 Found Claude binary: $claude_bin"
    break
  fi
done

if [[ -z "$claude_bin" ]] || [[ ! -f "$claude_bin" ]]; then
  # Try find as last resort
  claude_bin=$(find "$temp_install" "$HOME/.local" -name "claude" -type f -executable 2>/dev/null | head -1)
fi

if [[ -z "$claude_bin" ]] || [[ ! -f "$claude_bin" ]]; then
  echo "❌ Failed to locate Claude binary after install" >&2
  exit 1
fi

# Copy to emergency location
cp "$claude_bin" "$EMERGENCY_CLAUDE"
chmod +x "$EMERGENCY_CLAUDE"

# Verify it works
if ! "$EMERGENCY_CLAUDE" --version >/dev/null 2>&1; then
  echo "❌ Emergency Claude binary is not functional" >&2
  exit 1
fi

version=$("$EMERGENCY_CLAUDE" --version)
echo "✅ Claude Recovery CLI installed: $version"
echo "📍 Location: $EMERGENCY_CLAUDE"
echo ""
echo "🔍 Available flags:"
"$EMERGENCY_CLAUDE" --help | head -30
echo ""
echo "💡 Configure Elixir to use this:"
echo "   config :singularity, :claude,"
echo "     cli_path: \"$EMERGENCY_CLAUDE\""
echo ""
echo "   Or set environment variable:"
echo "   export CLAUDE_CLI_PATH=\"$EMERGENCY_CLAUDE\""
echo ""
echo "⚡ Recovery binary allows all flags including dangerous ones for emergency use"
