#!/usr/bin/env bash
# Optional Expo doctor. Not on the default language gate.
# Set HELMSMAN_EXPO_DOCTOR=1 to run it. Maestro stays on the setup file's e2e smoke line.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if [[ "${HELMSMAN_EXPO_DOCTOR:-}" != "1" ]]; then
  echo "helmsman: Expo doctor is opt-in. Set HELMSMAN_EXPO_DOCTOR=1 to run it. mobile:e2e is the e2e smoke, not this script."
  exit 0
fi

if [[ -f package.json ]] && command -v python3 >/dev/null 2>&1; then
  script="$(python3 - << 'PY'
import json
from pathlib import Path
manifest = json.loads(Path("package.json").read_text())
scripts = manifest.get("scripts") or {}
for name in ("mobile:doctor", "expo:doctor"):
    if name in scripts:
        print(name)
        break
PY
)"
  if [[ -n "$script" ]]; then
    if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
      pnpm run "$script"
      exit 0
    fi
    if command -v npm >/dev/null 2>&1; then
      npm run "$script"
      exit 0
    fi
  fi
fi

if command -v npx >/dev/null 2>&1; then
  npx --no-install expo-doctor
  exit 0
fi

echo "helmsman: HELMSMAN_EXPO_DOCTOR=1 but expo-doctor is not installed." >&2
exit 1
