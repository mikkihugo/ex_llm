#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

if ! command -v just >/dev/null 2>&1; then
  echo "just is required; run inside the nix shell or install just" >&2
  exit 1
fi

type=${1:-micro}
case "$type" in
  micro)
    bump_arg="micro"
    preflight=("just" "verify")
    tag_prefix="v"
    ;;
  baseline)
    bump_arg="baseline"
    preflight=("just" "verify")
    baseline_checks=("just" "coverage")
    tag_prefix="baseline-v"
    ;;
  *)
    echo "Usage: scripts/release.sh [micro|baseline]" >&2
    exit 1
    ;;
esac

echo "=> Ensuring clean worktree"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Uncommitted changes present. Please commit or stash before releasing." >&2
  exit 1
fi

if [[ ${preflight-} ]]; then
  echo "=> Running verification: ${preflight[*]}"
  "${preflight[@]}"
fi

if [[ ${baseline_checks-} ]]; then
  echo "=> Running extended checks: ${baseline_checks[*]}"
  "${baseline_checks[@]}"
fi

echo "=> Bumping version ($bump_arg)"
./scripts/bump_version.sh "$bump_arg"
new_version=$(<VERSION)

cat <<SUMMARY > RELEASE_SUMMARY.md
# Release $new_version

- Type: $type
- Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Verification: ${preflight[*]}
$(if [[ ${baseline_checks-} ]]; then printf "- Extended: %s" "${baseline_checks[*]}"; fi)
SUMMARY

if git status --short | grep -q .; then
  git add VERSION RELEASE_SUMMARY.md
  git commit -m "chore(release): $new_version"
fi

tag_name="${tag_prefix}${new_version}"
if git tag | grep -q "^${tag_name}$"; then
  echo "Tag ${tag_name} already exists; skipping tagging" >&2
else
  git tag -a "$tag_name" -m "Release $new_version"
fi

echo "Release ready: version $new_version (tag: $tag_name)"
echo "Push with: git push origin HEAD --tags"
