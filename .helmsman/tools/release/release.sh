#!/usr/bin/env bash
# Publish a Helmsman release for HEAD when the commits since the last release need one.
#
#   .helmsman/tools/release/release.sh            tag HEAD and create the GitHub release
#   .helmsman/tools/release/release.sh --dry-run  print the next tag and the reason, publish nothing
#
# The version comes from commit subjects since the last helmsman-v* tag (squash merges put the
# pull request title first). A breaking change (`type!:` or `BREAKING CHANGE`) moves the major
# version from 1.0.0 on, and the minor version before it. `feat` moves the minor version. `fix`
# and `perf` move the patch version. Anything else publishes nothing. With no tag yet, the base is 0.0.0.
set -euo pipefail

dry=0
case "${1:-}" in
  "") ;;
  --dry-run) dry=1 ;;
  -h | --help)
    echo "helmsman: release.sh [--dry-run]"
    echo "  .helmsman/tools/release/release.sh --dry-run"
    exit 0
    ;;
  *)
    echo "helmsman: release.sh [--dry-run]" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel)"
cd "$root"

last="$(git describe --tags --abbrev=0 --match 'helmsman-v*' 2>/dev/null || true)"
if [[ -n "$last" ]]; then
  range="${last}..HEAD"
  version="${last#helmsman-v}"
else
  range="HEAD"
  version="0.0.0"
fi

log="$(git log --format='%s%n%b' "$range")"
level=""
if grep -Eq '^[a-z]+(\([^)]*\))?!:|^BREAKING[ -]CHANGE:' <<< "$log"; then
  level="breaking"
elif grep -Eq '^feat(\([^)]*\))?:' <<< "$log"; then
  level="minor"
elif grep -Eq '^(fix|perf)(\([^)]*\))?:' <<< "$log"; then
  level="patch"
fi

if [[ -z "$level" ]]; then
  echo "helmsman: no feat, fix, perf, or breaking commit since ${last:-the first commit}. Nothing to release."
  exit 0
fi

IFS=. read -r major minor patch <<< "$version"
case "$level" in
  breaking)
    if [[ "$major" -ge 1 ]]; then
      major=$((major + 1)); minor=0; patch=0
    else
      minor=$((minor + 1)); patch=0
    fi
    ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
tag="helmsman-v${major}.${minor}.${patch}"

if [[ "$dry" -eq 1 ]]; then
  echo "helmsman: would release ${tag} (${level}) at $(git rev-parse HEAD)."
  exit 0
fi

gh release create "$tag" --target "$(git rev-parse HEAD)" --title "Helmsman ${major}.${minor}.${patch}" --generate-notes
echo "helmsman: released ${tag}."
