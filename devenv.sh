#!/usr/bin/env bash
set -euo pipefail

# Quick developer bootstrap for Nix + Cachix + dev shell

CACHE_NAME="mikkihugo"
PUBLIC_KEY="mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="

echo "👉 Ensuring Cachix binary cache is configured (pulls only)"
if command -v cachix >/dev/null 2>&1; then
  cachix use "$CACHE_NAME" || true
else
  echo "ℹ️  'cachix' not found; using NIX_CONFIG fallback inside dev shell."
  echo "    To install permanently: nix profile install nixpkgs#cachix && cachix use $CACHE_NAME"
fi

echo "🚀 Entering Nix dev shell (OTP 28, Elixir stable, Gleam)"
exec nix develop

