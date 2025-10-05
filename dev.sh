#!/usr/bin/env bash
# Quick development environment loader
# Usage: ./dev.sh <command>

# Load Nix environment
if [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
  source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Load direnv
eval "$(direnv export bash 2>/dev/null)"

# Set unfree for CUDA
export NIXPKGS_ALLOW_UNFREE=1

# If no args, start interactive shell
if [ $# -eq 0 ]; then
  nix develop --impure
else
  # Run command in dev environment
  nix develop --impure -c "$@"
fi
