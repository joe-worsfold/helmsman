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
