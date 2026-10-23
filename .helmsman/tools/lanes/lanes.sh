#!/usr/bin/env bash
# Lanes: how many worktrees this machine's disk can hold, and a Claude Code and
# Cursor hook that refuses a new worktree once they are all in use.
#
#   lanes.sh                       print the budget, the lane size, the lane count, and the active lanes
#   lanes.sh budget <GB> [root...] set the disk budget for lanes, then measure
#   lanes.sh measure               measure the lane size from the active lanes and rewrite the count
#   lanes.sh hook                  pre-tool hook: deny a new worktree when every lane is in use
#
# Claude Code: Bash running git worktree add, an Agent with worktree isolation, and
# EnterWorktree without a path. Cursor: Shell running git worktree add. Cursor's own
# agent worktrees are created without a tool call, so they count as lanes but no hook
# can refuse them.
#
# budget and measure take --dry-run: print the file they would write, and write nothing.
#
# The budget belongs to the machine, not the repo, so it lives in
# ~/.config/helmsman/lanes (HELMSMAN_LANES_FILE overrides it). With no file there is
# no cap, and the hook allows everything.
#
# A lane is a linked worktree that is not on main or master, in any repo directly
# under a root. The lane size is the largest active lane that has installed or
# built anything (node_modules/ or target/). Lanes = budget / lane size.
set -euo pipefail

file="${HELMSMAN_LANES_FILE:-$HOME/.config/helmsman/lanes}"
default_size_gb=10
dry_run=0

usage() {
  echo "helmsman: lanes.sh [budget <GB> [root...] | measure | hook] [--dry-run]"
  echo "  bash .helmsman/tools/lanes/lanes.sh budget 150   give lanes 150 GB of this machine's disk"
}

field() {
  if [[ -f "$file" ]]; then
    sed -n "s/^$1: *//p" "$file" | head -1
  fi
}

# One line per lane: "<path> [<branch>]".
active_lanes() {
  local root repo
  for root in ${ROOTS:-$(field Roots)}; do
    for repo in "$root"/*/.git "$root"/*.git; do
      [[ -d "$repo" ]] || continue
      git --git-dir="$repo" worktree list --porcelain 2>/dev/null | awk '
        function emit() {
          if (!skip && branch != "main" && branch != "master" && path != "") print path " [" branch "]"
          path = ""
        }
        /^worktree / { path = substr($0, 10); branch = ""; skip = (++n == 1) }
        /^bare$/ || /^prunable/ { skip = 1 }
        /^branch / { branch = substr($0, 8); sub("refs/heads/", "", branch) }
        /^$/ { emit() }
        END { emit() }
      '
    done
  done
}

write_file() {
  local budget="$1" roots="$2" size="$3" lanes="$4" text
  text="# Helmsman lanes for this machine. Set Disk budget and Roots; lanes.sh measure writes the rest.
Disk budget: ${budget}G
Roots: ${roots}
Lane size: ${size}G
Lanes: ${lanes}
Measured: $(date '+%Y-%m-%d %H:%M')"
  if (( dry_run )); then
    printf 'helmsman: would write %s:\n%s\n' "$file" "$text"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$text" > "$file"
}

# Takes the budget and roots from the file, or from budget() before it writes them.
measure() {
  local budget="${1:-}" roots="${2:-}" size_kb=0 kb line path size lanes
  budget="${budget:-$(field 'Disk budget' | tr -dc '0-9')}"
  roots="${roots:-$(field Roots)}"
  if [[ -z "$budget" || -z "$roots" ]]; then
    echo "helmsman: no disk budget. Run lanes.sh budget <GB>." >&2
    exit 1
  fi
  while IFS= read -r line; do
    path="${line% \[*}"
    [[ -d "$path/node_modules" || -d "$path/target" ]] || continue
    kb="$(du -sk "$path" 2> /dev/null | cut -f1)"
    if (( kb > size_kb )); then size_kb=$kb; fi
  done < <(ROOTS="$roots" active_lanes)
  if (( size_kb > 0 )); then
    size=$(( (size_kb + 1048575) / 1048576 ))
  else
    size="$(field 'Lane size' | tr -dc '0-9')"
    size="${size:-$default_size_gb}"
  fi
  lanes=$(( budget / size ))
  if (( lanes < 1 )); then lanes=1; fi
  write_file "$budget" "$roots" "$size" "$lanes"
  echo "helmsman: ${budget}G budget / ${size}G per lane = ${lanes} lanes."
}

# The directory that holds this repo, so its sibling repos are counted too.
default_root() {
  local common
  common="$(cd "$(git rev-parse --git-common-dir 2> /dev/null)" 2> /dev/null && pwd)" || return 1
  if [[ "$(basename "$common")" == ".git" ]]; then
    dirname "$(dirname "$common")"
  else
    dirname "$common"
  fi
}

budget() {
  local gb="${1:-}" roots
  gb="$(printf '%s' "$gb" | tr -dc '0-9')"
  if [[ -z "$gb" ]]; then
    usage >&2
    exit 2
  fi
  shift
  if (( $# > 0 )); then
    roots="$*"
  else
    roots="$(default_root)" || {
      echo "helmsman: not in a git repo. Name the folder that holds your repos: lanes.sh budget $gb <root>." >&2
      exit 2
    }
  fi
  measure "$gb" "$roots"
}

status() {
  local count
  if [[ ! -f "$file" ]]; then
    echo "helmsman: no lane budget on this machine, so there is no cap. Set one with lanes.sh budget <GB>."
    return 0
  fi
  count="$(active_lanes | grep -c . || true)"
  echo "Disk budget: $(field 'Disk budget')"
  echo "Lane size:   $(field 'Lane size') (measured $(field Measured))"
  echo "Lanes:       ${count} of $(field Lanes) in use"
  active_lanes | sed 's/^/  /'
}

hook() {
  local input lanes wants lines count
  input="$(cat)"
  # Most tool calls never mention a worktree. Leave before starting Python.
  [[ "$input" == *orktree* ]] || exit 0
  lanes="$(field Lanes)"
  [[ -n "$lanes" ]] || exit 0
  # Prints "cursor" or "claude" when the call would create a worktree, nothing otherwise.
  wants="$(python3 -c '
import json, re, sys
d = json.load(sys.stdin)
tool, args = d.get("tool_name"), d.get("tool_input") or {}
client = "cursor" if "cursor_version" in d else "claude"
# Git where it starts a command (after a separator, a quote, or env assignments), with any
# global options, so text that only mentions the words is not a worktree.
git_add = re.compile(
    r"(^|[;&|(\n\"\x27`]|\$\()\s*(\w+=\S*\s+)*git(\s+-[Cc]\s+\S+|\s+--[\w-]+(=\S+)?)*\s+worktree\s+add\b"
)
if tool in ("Bash", "Shell"):
    creates = bool(git_add.search(args.get("command", "")))
elif tool == "Agent":
    creates = args.get("isolation") == "worktree"
elif tool == "EnterWorktree":
    # With a path it enters a worktree that already exists, which must stay allowed.
    creates = not args.get("path")
else:
    creates = False
print(client if creates else "")
' <<< "$input")"
  [[ -n "$wants" ]] || exit 0
  lines="$(active_lanes)"
  count="$(printf '%s' "$lines" | grep -c . || true)"
  (( count < lanes )) && exit 0
  CLIENT="$wants" LINES_TEXT="$lines" COUNT="$count" LANES="$lanes" BUDGET="$(field 'Disk budget')" SIZE="$(field 'Lane size')" python3 -c '
import json, os
e = os.environ
lanes = "\n".join("  " + l for l in e["LINES_TEXT"].splitlines())
reason = (
    "Every lane is in use: {} worktrees, and this machine has {} lanes ({} disk budget / {} per lane). "
    "Do not create another worktree or work around this. "
    "Finish a lane first: once its pull request is merged, run `git worktree remove <path>`. "
    "If no lane can be freed, stop and tell the user the lanes are full.\nActive lanes:\n"
).format(e["COUNT"], e["LANES"], e["BUDGET"], e["SIZE"]) + lanes
if e["CLIENT"] == "cursor":
    print(json.dumps({"permission": "deny", "user_message": reason, "agent_message": reason}))
else:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}))
'
}

args=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then dry_run=1; else args+=("$arg"); fi
done
set -- ${args[@]+"${args[@]}"}

case "${1:-}" in
  "") status ;;
  budget) shift; budget "$@" ;;
  measure) measure ;;
  hook) hook ;;
  -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
