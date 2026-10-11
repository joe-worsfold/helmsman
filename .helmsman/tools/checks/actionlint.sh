#!/usr/bin/env bash
# Lint GitHub Actions workflows with rhysd/actionlint.
# The installer script is the official one, pinned to the v1.7.12 commit.
# The first run downloads the binary into the user cache. Later runs reuse it.
set -euo pipefail

sha="${ACTIONLINT_SHA:-914e7df21a07ef503a81201c76d2b11c789d3fca}"
version="${ACTIONLINT_VERSION:-1.7.12}"

if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "helmsman: actionlint pin is not a 40-character commit sha." >&2
  exit 1
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "helmsman: actionlint version is not major.minor.patch." >&2
  exit 1
fi

cache="${XDG_CACHE_HOME:-$HOME/.cache}/helmsman/actionlint/${version}"
bin="${cache}/actionlint"

if [[ ! -x "$bin" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "helmsman: curl is required to install actionlint ${version}." >&2
    exit 1
  fi
  mkdir -p "$cache"
  installer="$(mktemp)"
  curl -sSfL "https://raw.githubusercontent.com/rhysd/actionlint/${sha}/scripts/download-actionlint.bash" -o "$installer"
  bash "$installer" "$version" "$cache"
  rm -f "$installer"
fi

if [[ ! -d .github/workflows && ! -d .github/actions ]]; then
  echo "helmsman: no GitHub Actions files to lint."
  exit 0
fi

"$bin"
