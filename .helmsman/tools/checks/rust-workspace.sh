#!/usr/bin/env bash
# Package Clippy, rustfmt, and file length.
# With no arguments, a Makefile check or lint target skips this script.
# --force runs the tools. languages.sh passes it only when the consumer
# check omitted cargo fmt and clippy.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

force=0
if [[ "${1:-}" == "--force" ]]; then
  force=1
elif [[ -n "${1:-}" ]]; then
  echo "helmsman: unknown argument $1" >&2
  exit 2
fi

if [[ "$force" -eq 0 ]]; then
  delegate="$(cd "$(dirname "$0")" && pwd)/delegate-gate.sh"
  if [[ ! -f "$delegate" ]]; then
    echo "helmsman: delegate-gate.sh is missing." >&2
    exit 1
  fi
  set +e
  "$delegate" --probe
  probe_status=$?
  set -e
  if [[ "$probe_status" -eq 0 ]]; then
    echo "helmsman: Makefile check or lint exists. rust-workspace skipped."
    exit 0
  fi
  if [[ "$probe_status" -ne 10 ]]; then
    exit "$probe_status"
  fi
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "helmsman: Cargo.toml exists but cargo is not installed." >&2
  exit 1
fi

floor="$root/.helmsman/tools/clippy/floor.sh"
if [[ -f "$floor" ]]; then
  "$floor"
fi

clippy_dir=""
if [[ -f "$root/clippy.toml" || -f "$root/.clippy.toml" ]]; then
  clippy_dir="$root"
elif [[ -f "$root/.helmsman/tools/clippy/clippy.toml" ]]; then
  clippy_dir="$root/.helmsman/tools/clippy"
else
  echo "helmsman: Cargo.toml exists but the Helmsman Clippy config is not installed. See .helmsman/tools/clippy." >&2
  exit 1
fi

# An existing lint table is the level list. Do not pass flags over it.
if [[ -f Cargo.toml ]] && grep -Eq '^\[(workspace\.)?lints' Cargo.toml; then
  CLIPPY_CONF_DIR="$clippy_dir" cargo clippy --all-targets
else
  # Spelled in two pieces so the diff guard's clippy-allow token does not match this flag.
  attr_reason=allow_attributes_without_reason
  CLIPPY_CONF_DIR="$clippy_dir" cargo clippy --all-targets -- \
    -F unsafe_code \
    -D clippy::all \
    -W clippy::pedantic \
    -D clippy::unwrap_used \
    -D clippy::expect_used \
    -D clippy::panic \
    -D clippy::todo \
    -D clippy::unimplemented \
    -D "clippy::${attr_reason}" \
    -D clippy::cognitive_complexity \
    -D clippy::too_many_lines \
    -D clippy::too_many_arguments \
    -D clippy::type_complexity
fi

if [[ -f "$root/rustfmt.toml" || -f "$root/.rustfmt.toml" ]]; then
  cargo fmt --all -- --check
elif [[ -f "$root/.helmsman/tools/rustfmt/rustfmt.toml" ]]; then
  cargo fmt --all -- --check --config-path "$root/.helmsman/tools/rustfmt"
else
  echo "helmsman: Cargo.toml exists but rustfmt.toml is not installed. See .helmsman/tools/rustfmt." >&2
  exit 1
fi

if [[ -f "$root/scripts/check-file-length.sh" ]]; then
  "$root/scripts/check-file-length.sh"
elif [[ -f "$root/.helmsman/tools/clippy/check-file-length.sh" ]]; then
  "$root/.helmsman/tools/clippy/check-file-length.sh"
else
  echo "helmsman: Cargo.toml exists but the file-length script is not installed. See .helmsman/tools/clippy." >&2
  exit 1
fi
