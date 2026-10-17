#!/usr/bin/env bash
# Turbo runs this inside one Rust package directory.
# lint is clippy, format is rustfmt, test is cargo test on the library and binaries.
set -euo pipefail

mode="${1:-}"
case "$mode" in
  lint | format | test) ;;
  *)
    echo "helmsman: cargo-package.sh lint|format|test" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
manifest="$PWD/Cargo.toml"
if [[ ! -f "$manifest" ]]; then
  echo "helmsman: cargo-package.sh needs a Cargo.toml in the working directory." >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "helmsman: cargo is not installed." >&2
  exit 1
fi

case "$mode" in
  test)
    # A tests/*_int.rs file needs the local stack, so it runs from pnpm test:integration.
    # Every other target, including the rest of tests/ and the doc tests, runs here.
    args=(--manifest-path "$manifest")
    lib=0
    if [[ -f src/lib.rs ]] || grep -q '^\[lib\]' Cargo.toml; then
      args+=(--lib)
      lib=1
    fi
    if [[ -f src/main.rs || -d src/bin ]] || grep -q '^\[\[bin\]\]' Cargo.toml; then
      args+=(--bins)
    fi
    shopt -s nullglob
    for file in tests/*.rs; do
      name="$(basename "$file" .rs)"
      [[ "$name" == *_int ]] || args+=(--test "$name")
    done
    shopt -u nullglob
    if [[ ${#args[@]} -eq 2 ]]; then
      echo "helmsman: no unit test target in $PWD. Unit tests skipped."
      exit 0
    fi
    cargo test "${args[@]}"
    if [[ "$lib" -eq 1 ]]; then
      cargo test --manifest-path "$manifest" --doc
    fi
    exit 0
    ;;
  format)
    if [[ -f "$root/rustfmt.toml" || -f "$root/.rustfmt.toml" || -f rustfmt.toml || -f .rustfmt.toml ]]; then
      cargo fmt --manifest-path "$manifest" -- --check
    elif [[ -f "$root/.helmsman/tools/rustfmt/rustfmt.toml" ]]; then
      cargo fmt --manifest-path "$manifest" -- --check --config-path "$root/.helmsman/tools/rustfmt"
    else
      echo "helmsman: rustfmt.toml is not installed. See .helmsman/tools/rustfmt." >&2
      exit 1
    fi
    exit 0
    ;;
esac

clippy_dir=""
if [[ -f "$root/clippy.toml" || -f "$root/.clippy.toml" ]]; then
  clippy_dir="$root"
elif [[ -f "$root/.helmsman/tools/clippy/clippy.toml" ]]; then
  clippy_dir="$root/.helmsman/tools/clippy"
else
  echo "helmsman: the Helmsman Clippy config is not installed. See .helmsman/tools/clippy." >&2
  exit 1
fi

has_lints=0
dir="$PWD"
while true; do
  if [[ -f "$dir/Cargo.toml" ]] && grep -Eq '^\[(workspace\.)?lints' "$dir/Cargo.toml"; then
    has_lints=1
    break
  fi
  if [[ "$dir" == "$root" ]]; then
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ "$has_lints" -eq 1 ]]; then
  CLIPPY_CONF_DIR="$clippy_dir" cargo clippy --manifest-path "$manifest" --all-targets
  exit 0
fi

attr_reason=allow_attributes_without_reason
CLIPPY_CONF_DIR="$clippy_dir" cargo clippy --manifest-path "$manifest" --all-targets -- \
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
