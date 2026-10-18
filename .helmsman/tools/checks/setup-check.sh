#!/usr/bin/env bash
# Fail when the setup file is missing or an app has no watchable end-to-end command.
# The setup keys stay `E2E smoke` and `Watch`.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup-field.sh"

file="${1:-.helmsman/setup.md}"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [[ -f "$root/platform/Cargo.toml" || -f "$root/platform/package.json" ]]; then
  echo "helmsman: the shared kernel is packages/platform/rs, not a root platform/." >&2
  exit 1
fi

"$(cd "$(dirname "$0")" && pwd)/tool-home.sh"

if [[ ! -f "$file" ]]; then
  echo "helmsman: missing $file. Run helmsman-setup." >&2
  exit 1
fi

languages="$(field "languages" "$file")"
surfaces="$(field "surfaces" "$file")"
smoke="$(field "e2e smoke" "$file")"
watch="$(field "watch" "$file")"
issues="$(field "issues" "$file")"
ci="$(field "ci" "$file")"
file_issues="$(field "file issues" "$file")"
fix="$(field "fix" "$file")"

missing=()
[[ -n "$languages" ]] || missing+=("Languages")
[[ -n "$surfaces" ]] || missing+=("Surfaces")
[[ -n "$smoke" ]] || missing+=("E2E smoke")
[[ -n "$watch" ]] || missing+=("Watch")
[[ -n "$issues" ]] || missing+=("Issues")
[[ -n "$ci" ]] || missing+=("CI")
[[ -n "$file_issues" ]] || missing+=("File issues")
[[ -n "$fix" ]] || missing+=("Fix")

if ((${#missing[@]} > 0)); then
  echo "helmsman: $file is missing: ${missing[*]}" >&2
  exit 1
fi

if [[ "$(lower "$file_issues")" != "yes" && "$(lower "$file_issues")" != "no" ]]; then
  echo "helmsman: File issues must be yes or no." >&2
  exit 1
fi

if [[ "$(lower "$fix")" != "yes" && "$(lower "$fix")" != "no" ]]; then
  echo "helmsman: Fix must be yes or no." >&2
  exit 1
fi

ci_integration="$(field "ci integration" "$file")"
ci_smoke="$(field "ci e2e smoke" "$file")"
if [[ -n "$ci_integration" && "$(lower "$ci_integration")" != "yes" && "$(lower "$ci_integration")" != "no" ]]; then
  echo "helmsman: CI integration must be yes or no." >&2
  exit 1
fi
if [[ -n "$ci_smoke" && "$(lower "$ci_smoke")" != "yes" && "$(lower "$ci_smoke")" != "no" ]]; then
  echo "helmsman: CI e2e smoke must be yes or no." >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"
"$here/docs-commands.sh"
"$here/env-example.sh"
"$here/agents-words.sh"
"$here/../tsc/check.sh" --strict

if [[ "$(lower "$surfaces")" == "none" ]]; then
  if [[ "$(lower "$smoke")" != "none" || "$(lower "$watch")" != "none" ]]; then
    echo "helmsman: Surfaces is none, so E2E smoke and Watch must be none." >&2
    exit 1
  fi
  echo "helmsman: setup ok (no app surface)."
  exit 0
fi

if [[ "$(lower "$smoke")" == "none" || "$(lower "$watch")" == "none" ]]; then
  echo "helmsman: Surfaces is '$surfaces' but the end-to-end suite cannot be watched. Name the CI command and the watch command." >&2
  exit 1
fi

echo "helmsman: setup ok. End-to-end: $smoke"
