#!/usr/bin/env bash
# Move this repo to one Helmsman release: copy that release's files, then move every pin to its commit.
#
#   .helmsman/tools/update.sh                        the latest helmsman-v* release
#   .helmsman/tools/update.sh helmsman-v0.2.0        that release
#   .helmsman/tools/update.sh --from ../helmsman     a local Helmsman checkout; the pin is its HEAD
#   .helmsman/tools/update.sh --dry-run [...]        print what would change, write nothing
#
# Copies the setup Copy list: the helmsman-* rules, skills, and automations under .cursor/,
# .helmsman/tools/ (without node_modules/ and upstream/), lefthook.yml, and the PR template.
# A rule, skill, or automation without the helmsman- prefix is the repo's own and is left alone.
# A Helmsman file the repo changed on purpose goes on a `Local forks:` setup line (comma-separated
# paths). Each is three-way merged: the repo's copy, the release named on the `Helmsman:` line, and
# the new release. Any conflict stops the update before a file is written, and names the file.
# Then it writes the commit to the `Helmsman:` setup line, re-pins the plugin when this repo
# enabled it, and re-runs the workflow, Claude, and watermark emitters from the new copy.
main() {
  set -euo pipefail
  local repo="joe-worsfold/helmsman" ref="" from="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        echo "helmsman: update.sh [--dry-run] [<helmsman-vX.Y.Z> | --from <dir>]"
        echo "  .helmsman/tools/update.sh helmsman-v0.2.0"
        return 0
        ;;
      --dry-run) dry=1 ;;
      --from)
        from="${2:?--from needs a directory}"
        shift
        ;;
      -*)
        echo "helmsman: unknown option $1" >&2
        return 2
        ;;
      *) ref="$1" ;;
    esac
    shift
  done

  local root
  root="$(git rev-parse --show-toplevel)"
  cd "$root"

  local work src sha
  work="$(mktemp -d)"
  trap "rm -rf '$work'" EXIT
  if [[ -n "$from" ]]; then
    src="$(cd "$from" && pwd)"
    sha="$(git -C "$src" rev-parse HEAD)"
  else
    if [[ -z "$ref" ]]; then
      ref="$(git ls-remote --tags --refs "https://github.com/${repo}" 'helmsman-v*' |
        sed 's#.*refs/tags/##' | sort -V | tail -n 1)"
      [[ -n "$ref" ]] || { echo "helmsman: no helmsman-v* release found." >&2; return 1; }
    fi
    sha="$(git ls-remote "https://github.com/${repo}" "refs/tags/${ref}^{}" "refs/tags/${ref}" |
      sort -k2 -r | head -n 1 | cut -f1)"
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "helmsman: ${ref} is not a tag in ${repo}." >&2; return 1; }
    curl -fsSL "https://codeload.github.com/${repo}/tar.gz/${sha}" | tar -xz -C "$work"
    src="$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  fi
  echo "helmsman: updating to ${ref:-$from} (${sha})."

  local forks=() fork merged="$work/merged" old="$work/old" conflicts=()
  if [[ -f .helmsman/setup.md ]]; then
    IFS=',' read -r -a forks <<< "$(sed -n 's/^Local forks: *//p' .helmsman/setup.md | head -n 1)"
  fi
  if [[ ${#forks[@]} -gt 0 && "${forks[0]// /}" != "none" ]]; then
    local old_sha
    old_sha="$(sed -n 's/^Helmsman: *//p' .helmsman/setup.md | head -n 1)"
    if [[ ! "$old_sha" =~ ^[0-9a-f]{40}$ ]]; then
      echo "helmsman: Local forks need the Helmsman: line of the release this repo is on now, to merge from." >&2
      return 1
    fi
    mkdir -p "$old" "$merged"
    if [[ -n "$from" ]]; then
      git -C "$src" archive "$old_sha" | tar -x -C "$old"
    else
      curl -fsSL "https://codeload.github.com/${repo}/tar.gz/${old_sha}" | tar -xz --strip-components=1 -C "$old"
    fi
    for fork in "${forks[@]}"; do
      fork="$(printf '%s' "$fork" | xargs)"
      [[ -f "$fork" ]] || { echo "helmsman: Local forks names ${fork}, which is not in this repo." >&2; return 1; }
      mkdir -p "$merged/$(dirname "$fork")"
      if [[ ! -f "$src/$fork" ]]; then
        echo "helmsman: ${fork} is gone from this release. The repo's copy stays."
        cp "$fork" "$merged/$fork"
        continue
      fi
      [[ -f "$old/$fork" ]] || : > "$old/$fork"
      if git merge-file -p "$fork" "$old/$fork" "$src/$fork" > "$merged/$fork"; then
        echo "  fork: ${fork} merges cleanly."
      else
        conflicts+=("$fork")
      fi
    done
    if [[ ${#conflicts[@]} -gt 0 ]]; then
      printf 'helmsman: this release conflicts with the local fork %s.\n' "${conflicts[@]}" >&2
      echo "helmsman: nothing was changed. Merge those by hand, or take them off the Local forks line." >&2
      return 1
    fi
  else
    forks=()
  fi

  if [[ "$dry" -eq 1 ]]; then
    rsync -ain --delete --exclude node_modules --exclude upstream "$src/.helmsman/tools/" .helmsman/tools/ | sed 's/^/  tools: /'
    local kind
    for kind in rules skills automations; do
      rsync -ain --delete --include 'helmsman-*' --include 'helmsman-*/**' --exclude '*' \
        "$src/.cursor/${kind}/" ".cursor/${kind}/" 2>/dev/null | sed "s#^#  .cursor/${kind}: #"
    done
    cmp -s "$src/lefthook.yml" lefthook.yml || echo "  replace: lefthook.yml"
    cmp -s "$src/.github/PULL_REQUEST_TEMPLATE.md" .github/PULL_REQUEST_TEMPLATE.md || echo "  replace: .github/PULL_REQUEST_TEMPLATE.md"
    echo "  pin: Helmsman: ${sha}"
    return 0
  fi

  rsync -a --delete --exclude node_modules --exclude upstream "$src/.helmsman/tools/" .helmsman/tools/
  local kind dir name
  for kind in rules skills automations; do
    mkdir -p ".cursor/${kind}"
    for dir in ".cursor/${kind}"/helmsman-*; do
      [[ -e "$dir" ]] || continue
      name="$(basename "$dir")"
      [[ -e "$src/.cursor/${kind}/${name}" ]] || rm -rf "$dir"
    done
    for dir in "$src/.cursor/${kind}"/helmsman-*; do
      [[ -e "$dir" ]] || continue
      rm -rf ".cursor/${kind}/$(basename "$dir")"
      cp -R "$dir" ".cursor/${kind}/"
    done
  done
  cp "$src/lefthook.yml" lefthook.yml
  mkdir -p .github
  cp "$src/.github/PULL_REQUEST_TEMPLATE.md" .github/PULL_REQUEST_TEMPLATE.md
  for fork in ${forks[@]+"${forks[@]}"}; do
    cp "$merged/$(printf '%s' "$fork" | xargs)" "$(printf '%s' "$fork" | xargs)"
  done

  if [[ -f .helmsman/setup.md ]] && grep -q '^Helmsman:' .helmsman/setup.md; then
    sed -i.bak "s/^Helmsman:.*/Helmsman: ${sha}/" .helmsman/setup.md && rm -f .helmsman/setup.md.bak
  else
    echo "helmsman: .helmsman/setup.md has no Helmsman: line. Add \`Helmsman: ${sha}\`." >&2
  fi
  if .helmsman/tools/plugin/enable.sh --check >/dev/null 2>&1; then
    .helmsman/tools/plugin/enable.sh "$sha"
  fi
  .helmsman/tools/ci/emit.sh
  .helmsman/tools/claude/emit.sh
  bash .helmsman/tools/watermark/hooks-install.sh
  echo "helmsman: updated to ${sha}. Review the diff, then run pnpm check."
}
main "$@"; exit
