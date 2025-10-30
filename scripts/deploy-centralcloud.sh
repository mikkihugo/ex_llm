#!/usr/bin/env bash
set -euo pipefail

# TODO(minimal): Implement deployment to target environment/cluster
# Expects: VERSION tag (e.g., centralcloud-v0.1.0)

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-tag>" >&2
  exit 1
fi

echo "[CentralCloud] Deploying version $VERSION"
# Example (k8s):
# kubectl set image deployment/centralcloud centralcloud=ghcr.io/ORG/centralcloud:"$VERSION"
# kubectl rollout status deployment/centralcloud

echo "[CentralCloud] Deploy complete (stub)"
