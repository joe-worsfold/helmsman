# Read `Key: value` lines from a Helmsman setup file. Sourced by the scripts that need it, not run.
#
#   field <key> [file]   the value on the first line whose key matches, ignoring case.
#                        The file defaults to .helmsman/setup.md. A missing file prints nothing.
#   lower <text>         the text in lower case

field() {
  local file="${2:-.helmsman/setup.md}"
  [[ -f "$file" ]] || return 0
  awk -F': ' -v key="$(lower "$1")" 'tolower($1) == key { sub(/^[^:]*: /, ""); print; exit }' "$file"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
