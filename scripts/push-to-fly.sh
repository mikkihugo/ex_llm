#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FLY_APP:-}" ]]; then
  echo "Usage: FLY_APP=seed-agent ./scripts/push-to-fly.sh <tag>" >&2
  exit 64
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: FLY_APP=seed-agent ./scripts/push-to-fly.sh <tag>" >&2
  exit 64
fi

TAG=$1
ROOT=$(git rev-parse --show-toplevel)
IMAGE="registry.fly.io/${FLY_APP}:${TAG}"

nix build "${ROOT}#seed-agent-oci"

podman load < "${ROOT}/result"
ID=$(podman images -q seed-agent:latest)
if [[ -z "${ID}" ]]; then
  echo "Failed to load image" >&2
  exit 1
fi

podman tag "${ID}" "${IMAGE}"
podman push "${IMAGE}"

echo "Image pushed: ${IMAGE}"
