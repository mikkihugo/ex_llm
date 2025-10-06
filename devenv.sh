#!/usr/bin/env bash
set -euo pipefail

# Quick developer bootstrap for Nix + Cachix + dev shell

CACHE_NAME="mikkihugo"
PUBLIC_KEY="mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="

echo "👉 Binary cache: flake provides nixConfig (pulls)"
if command -v cachix >/dev/null 2>&1; then
  # Optional: set cache globally for non-flake commands too
  cachix use "$CACHE_NAME" || true
else
  echo "ℹ️  'cachix' not found; flake-local cache config will still be used."
  echo "    Optional global setup: nix profile install nixpkgs#cachix && cachix use $CACHE_NAME"
fi

echo "🚀 Entering Nix dev shell (OTP 28, Elixir stable, Gleam)"
exec nix develop
