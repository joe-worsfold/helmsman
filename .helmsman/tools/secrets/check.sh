#!/usr/bin/env bash
# Secret scan. A built-in pattern runs every time.
# gitleaks runs when it is installed. A gitleaks config with no binary fails.
# secretlint runs when a secretlint config is present. A missing binary then fails.
# Recorded eval patches live under eval/scenarios and are not a leak in this repo.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "helmsman: secret scan needs a git checkout." >&2
  exit 1
fi

begin="$(printf '%s' '-----BEGIN ')"
end="$(printf '%s' '-----')"
pem="${begin}[A-Z ]*PRIVATE KEY${end}"
aws='AKIA[0-9A-Z]{16}'
github='ghp_[A-Za-z0-9]{20,}'
pat='github_pat_[A-Za-z0-9_]{20,}'
stripe='sk_live_[0-9A-Za-z]{10,}'
slack='xox[baprs]-[0-9A-Za-z-]{10,}'

fail=0
while IFS= read -r -d '' file; do
  case "$file" in
    eval/scenarios/*|.helmsman/tools/secrets/check.sh|.helmsman/tools/checks/gates.test.sh)
      continue
      ;;
  esac
  # A tracked symlink is a path. Its target is scanned under its own name.
  if [[ -L "$file" ]]; then
    continue
  fi
  hits="$(grep -nIE -- "$aws|$pem|$github|$pat|$stripe|$slack" "$file" || true)"
  if [[ -n "$hits" ]]; then
    echo "helmsman: secret pattern in $file" >&2
    printf '%s\n' "$hits" >&2
    fail=1
  fi
done < <(git ls-files -z)

if command -v gitleaks >/dev/null 2>&1; then
  echo "helmsman: gitleaks"
  gitleaks detect --no-banner --no-git --redact --source "$root"
elif [[ -f .gitleaks.toml || -f .gitleaks.yml ]]; then
  echo "helmsman: gitleaks config is present but gitleaks is not installed." >&2
  exit 1
else
  echo "helmsman: gitleaks is not installed. Built-in patterns ran."
fi

secretlint_config=""
for candidate in .secretlintrc .secretlintrc.json .secretlintrc.js .secretlintrc.yml .secretlintrc.yaml; do
  if [[ -f "$candidate" ]]; then
    secretlint_config="$candidate"
    break
  fi
done

if [[ -n "$secretlint_config" ]]; then
  if command -v secretlint >/dev/null 2>&1; then
    echo "helmsman: secretlint $secretlint_config"
    secretlint --secretlintrc "$secretlint_config" "**/*"
  elif command -v npx >/dev/null 2>&1 && npx --no-install secretlint --version >/dev/null 2>&1; then
    echo "helmsman: secretlint $secretlint_config"
    npx --no-install secretlint --secretlintrc "$secretlint_config" "**/*"
  else
    echo "helmsman: $secretlint_config is present but secretlint is not installed." >&2
    exit 1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: secrets ok."
