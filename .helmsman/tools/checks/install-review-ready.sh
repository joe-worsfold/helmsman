#!/usr/bin/env bash
# Append the review-before-ready section to AGENTS.md when the heading is absent.
# When the heading is already there, append the draft sentence if it is missing.
# A second run changes nothing. It does not replace the rest of the file.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

file="AGENTS.md"
review='Every agent PR finishes in order: (1) run helmsman-review on the full diff against base, (2) fix every Blocker, unjustified Judo, High, and Medium finding, (3) prove it locally with the pre-commit hook and `pnpm check`, (4) post the review as a pull request comment saying what was fixed and what remains Fix forward or Nit and why, (5) mark ready only after that comment. Marking ready is when CI runs. Do not merge until that run is green. The review catches what the standards missed, including when the change was written to them.'
draft='Agents work in draft. Prove the change locally with `pnpm check` and the pre-commit hook before pushing. CI runs when the pull request is marked ready, and on push to main. A draft pull request does not run CI.'

if [[ -f "$file" ]] && grep -q 'fix every block and revise finding' "$file"; then
  python3 - "$file" << 'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "fix every block and revise finding",
    "fix every Blocker, unjustified Judo, High, and Medium finding",
    1,
)
text = text.replace(
    "what remains minor or deferred and why",
    "what remains Fix forward or Nit and why",
    1,
)
text = text.replace(
    "post the review as a PR comment",
    "post the review as a pull request comment",
    1,
)
path.write_text(text)
print("helmsman: updated review before ready vocabulary.")
PY
fi

if [[ -f "$file" ]] && grep -q '(3) pre-commit and CI green' "$file"; then
  python3 - "$file" << 'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace(
    "(3) pre-commit and CI green",
    "(3) prove it locally with the pre-commit hook and `pnpm check`",
    1,
)
old_tail = "(5) mark ready only after that comment. The review catches"
new_tail = "(5) mark ready only after that comment. Marking ready is when CI runs. Do not merge until that run is green. The review catches"
if old_tail in text and "Marking ready is when CI runs." not in text:
    text = text.replace(old_tail, new_tail, 1)
path.write_text(text)
print("helmsman: updated review before ready for draft CI.")
PY
fi

has_heading=0
has_draft=0
if [[ -f "$file" ]] && grep -q '^## Review before ready$' "$file"; then
  has_heading=1
fi
if [[ -f "$file" ]] && grep -q 'Agents work in draft\.' "$file"; then
  has_draft=1
fi

if [[ "$has_heading" -eq 1 && "$has_draft" -eq 1 ]]; then
  echo "helmsman: review before ready already in AGENTS.md."
else
install_review=1
fi

if [[ "${install_review:-}" == "1" && ! -f "$file" ]]; then
  printf '%s\n' "# Agents" "" "## Review before ready" "" "$review" "" "$draft" "" > "$file"
  echo "helmsman: wrote AGENTS.md."
  has_heading=1
  has_draft=1
fi

if [[ "${install_review:-}" == "1" && -f "$file" ]]; then
  if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
    printf '\n' >> "$file"
  fi
  if [[ "$has_heading" -eq 0 ]]; then
    printf '\n%s\n\n%s\n\n%s\n' "## Review before ready" "$review" "$draft" >> "$file"
    echo "helmsman: appended review before ready to AGENTS.md."
  elif [[ "$has_draft" -eq 0 ]]; then
    printf '\n%s\n' "$draft" >> "$file"
    echo "helmsman: appended draft CI rule to AGENTS.md."
  fi
fi

if [[ -f "$file" ]] && grep -q '^## Rules and what enforces them$' "$file"; then
  echo "helmsman: rule table already in AGENTS.md."
  exit 0
fi

if [[ ! -f "$file" ]]; then
  printf '%s\n' "# Agents" "" > "$file"
fi
if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
  printf '\n' >> "$file"
fi
cat >> "$file" << 'EOF'

## Rules and what enforces them

| Rule | What enforces it |
| --- | --- |
| Added lines do not skip a test or suppress a linter | `pnpm diff:guard` |
| Added lines do not bring nautical terms back | `pnpm plain:language` |
| The review comment still matches the pull request patch | `pnpm review:current` |
| The upstream snapshot matches the pin | `pnpm setup:check` |
| The workflow file matches the emitter | `pnpm setup:check` |
| Lint, format, types, unused code, and tests | `pnpm check` |

`helmsman-correct` keeps this table current. A rule with nothing in the second column is not enforced.
EOF
echo "helmsman: appended rule table to AGENTS.md."
