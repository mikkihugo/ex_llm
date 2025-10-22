#!/usr/bin/env bash
# Wrapper around `nix develop` for the Singularity dev shells.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SHELL="${DEV_SHELL:-dev}"
APP_DIR="${SCRIPT_DIR}/singularity"

usage() {
  cat <<'EOF'
Usage: ./dev.sh [options] [command...]

Options:
  -s, --shell <name>   Use the specified dev shell (default: dev)
  -h, --help           Show this help message

Examples:
  ./dev.sh                     # Open interactive shell
  ./dev.sh mix test            # Run command inside dev shell
  ./dev.sh --shell test bash   # Use alternate shell profile
EOF
}

ensure_nix_available() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  local possible_profiles=(
    "$HOME/.nix-profile/etc/profile.d/nix.sh"
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  )

  for profile in "${possible_profiles[@]}"; do
    if [[ -f "$profile" ]]; then
      # shellcheck source=/dev/null
      source "$profile"
    fi
  done

  if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Nix is required but was not found in PATH." >&2
    exit 1
  fi
}

chosen_shell="$DEFAULT_SHELL"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--shell)
      if [[ $# -lt 2 ]]; then
        echo "Error: missing shell name for $1" >&2
        exit 1
      fi
      chosen_shell="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      break
    ;;
  esac
done

ensure_nix_available

join_args() {
  local result="" arg
  for arg in "$@"; do
    result+=" $(printf '%q' "$arg")"
  done
  printf '%s' "${result# }"
}

resolve_run_dir() {
  local first_arg="${1:-}"
  if [[ -n "${DEV_SH_CWD:-}" ]]; then
    if [[ "${DEV_SH_CWD}" = /* ]]; then
      printf '%s' "$DEV_SH_CWD"
    else
      printf '%s' "${SCRIPT_DIR}/${DEV_SH_CWD}"
    fi
  elif [[ "$first_arg" == "mix" ]]; then
    printf '%s' "$APP_DIR"
  else
    printf '%s' "$SCRIPT_DIR"
  fi
}

cmd=("$@")
nix_args=(develop "${SCRIPT_DIR}#${chosen_shell}")

if [[ ${#cmd[@]} -gt 0 ]]; then
  run_dir=$(resolve_run_dir "${cmd[0]}")
  shell_cmd=$(join_args "${cmd[@]}")
  exec nix "${nix_args[@]}" --command bash -lc "cd \"${run_dir}\" && ${shell_cmd}"
else
  exec nix "${nix_args[@]}"
fi
