#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
VERSION_FILE="$REPO_ROOT/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi

release_type=${1:-patch}
version=$(<"$VERSION_FILE")
IFS='.' read -r major minor patch <<<"$version"

case "$release_type" in
  patch|micro)
    patch=$((patch + 1))
    ;;
  minor|baseline)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  *)
    echo "Unknown release type: $release_type" >&2
    exit 1
    ;;
esac

new_version="$major.$minor.$patch"
echo "$new_version" > "$VERSION_FILE"

printf '\nBumped version: %s -> %s\n' "$version" "$new_version"
