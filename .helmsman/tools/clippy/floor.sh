#!/usr/bin/env bash
# Floor: complexity 15, lines 50, arguments 6, type complexity 250.
# A lower number in the repo file is stronger and stays.
# No arguments: check only. languages.sh uses that, and it does not write.
# A destination copies a missing clippy.toml and appends a missing lint table.
# An existing clippy.toml or [workspace.lints] / [lints] table is not replaced.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
package="$here/clippy.toml"
lints="$here/workspace-lints.toml"

if [[ ! -f "$package" || ! -f "$lints" ]]; then
  echo "helmsman: missing the Clippy floor files in $here" >&2
  exit 1
fi

dest=""
if [[ -n "${1:-}" ]]; then
  if [[ ! -d "$1" ]]; then
    echo "helmsman: $1 is not a directory." >&2
    exit 1
  fi
  dest="$(cd "$1" && pwd)"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  cd "$root"
fi

read_key() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      v = $2
      sub(/[[:space:]]*#.*/, "", v)
      gsub(/[[:space:]]/, "", v)
      print v
      exit
    }
  ' "$file"
}

# The package file is the floor. A higher number is a weaker gate.
hold_package() {
  local key="$1"
  local ceiling="$2"
  local value
  value="$(read_key "$package" "$key")"
  if [[ -z "$value" || ! "$value" =~ ^[0-9]+$ || "$value" -gt "$ceiling" ]]; then
    echo "helmsman: package $key is ${value:-missing}. Floor is $ceiling. Refusing a weaker gate." >&2
    exit 1
  fi
}

hold_package cognitive-complexity-threshold 15
hold_package too-many-lines-threshold 50
hold_package too-many-arguments-threshold 6
hold_package type-complexity-threshold 250

# name, ceiling, required (1 = missing fails). A lower number stays. This does not write the file.
check_key() {
  local file="$1"
  local key="$2"
  local ceiling="$3"
  local required="$4"
  local value
  value="$(read_key "$file" "$key")"
  if [[ -z "$value" ]]; then
    if [[ "$required" -eq 1 ]]; then
      echo "helmsman: $file does not set $key. The floor is $ceiling. Helmsman does not write this file." >&2
      exit 1
    fi
    return 0
  fi
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "helmsman: $key in $file is not an integer." >&2
    exit 1
  fi
  if [[ "$value" -gt "$ceiling" ]]; then
    echo "helmsman: $key $value is above the floor of $ceiling. Helmsman does not rewrite $file." >&2
    exit 1
  fi
}

has_lints() {
  local cargo="$1"
  [[ -f "$cargo" ]] && grep -Eq '^\[(workspace\.)?lints' "$cargo"
}

audit_clippy() {
  local file="$1"
  check_key "$file" cognitive-complexity-threshold 15 1
  check_key "$file" too-many-lines-threshold 50 0
  check_key "$file" too-many-arguments-threshold 6 0
  check_key "$file" type-complexity-threshold 250 0
}

clippy_file() {
  local dir="$1"
  if [[ -f "$dir/clippy.toml" ]]; then
    printf '%s\n' "$dir/clippy.toml"
  elif [[ -f "$dir/.clippy.toml" ]]; then
    printf '%s\n' "$dir/.clippy.toml"
  fi
}

if [[ -z "$dest" ]]; then
  if [[ -f Cargo.toml ]] && has_lints Cargo.toml; then
    echo "helmsman: lint table already present. Skip copy."
  fi
  file="$(clippy_file "$PWD")"
  if [[ -z "$file" ]]; then
    echo "helmsman: no repo clippy.toml. Floor file stays in .helmsman/tools/clippy."
    exit 0
  fi
  audit_clippy "$file"
  echo "helmsman: clippy floor held. Left $file in place."
  exit 0
fi

file="$(clippy_file "$dest")"
if [[ -n "$file" ]]; then
  audit_clippy "$file"
  echo "helmsman: clippy.toml already present. Skip copy."
else
  cp "$package" "$dest/clippy.toml"
  echo "helmsman: copied clippy.toml floor to $dest/clippy.toml."
fi

if [[ ! -f "$dest/Cargo.toml" ]]; then
  echo "helmsman: no Cargo.toml. Workspace lints not copied."
  exit 0
fi

if has_lints "$dest/Cargo.toml"; then
  echo "helmsman: lint table already present. Skip copy."
  exit 0
fi

{
  printf '\n'
  awk '
    /^\[/ { keep = 1 }
    keep { print }
  ' "$lints"
} >> "$dest/Cargo.toml"
echo "helmsman: appended workspace lint floor to $dest/Cargo.toml."
