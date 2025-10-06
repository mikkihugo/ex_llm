#!/usr/bin/env bash
# Shell guard to ensure scripts run inside a Nix dev shell unless explicitly allowed.
# Usage:
#   source "$(dirname "$0")/lib/nix_guard.sh"  # from scripts/
#   require_nix_shell                            # hard fail outside nix
#   or: NIX_GUARD_MODE=warn require_nix_shell    # soft warn outside nix

set -euo pipefail

require_nix_shell() {
  local mode="${NIX_GUARD_MODE:-fail}"  # fail|warn|off
  if [[ "${mode}" == "off" ]]; then
    return 0
  fi

  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    local msg="[nix-guard] This script is intended to run inside 'nix develop'."
    if [[ "${mode}" == "warn" ]]; then
      echo "${msg} Proceeding because NIX_GUARD_MODE=warn." >&2
      return 0
    fi
    echo "${msg} Export NIX_GUARD_MODE=warn to bypass, or run 'nix develop'." >&2
    exit 1
  fi
}

