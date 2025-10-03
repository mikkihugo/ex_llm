#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

OUTPUT=${1:-bundles/cli-state.tar.gz}
shift || true >/dev/null 2>&1

CLAUDE_HOME=${CLAUDE_HOME:-"$HOME/.claude"}
CODEX_HOME=${CODEX_HOME:-"$HOME/.codex"}

INCLUDE=()
if [[ -d "$CLAUDE_HOME" ]]; then
  INCLUDE+=("$CLAUDE_HOME")
else
  echo "⚠️  Claude directory not found at $CLAUDE_HOME; skipping" >&2
fi

if [[ -d "$CODEX_HOME" ]]; then
  INCLUDE+=("$CODEX_HOME")
else
  echo "⚠️  Codex directory not found at $CODEX_HOME; skipping" >&2
fi

if [[ ${#INCLUDE[@]} -eq 0 ]]; then
  echo "❌ Nothing to bundle (no CLI state found)." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
tar czf "$OUTPUT" "${INCLUDE[@]}"

cat <<MSG
✅ Bundled CLI state to $OUTPUT
   Included:
$(printf '   - %s\n' "${INCLUDE[@]}")

Restoration example:
  tar xzf $OUTPUT -C / --strip-components=1
  # or mount the directories on Fly and set CLAUDE_HOME / CODEX_HOME
MSG
