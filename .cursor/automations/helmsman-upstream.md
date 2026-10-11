# Helmsman upstream watch

Weekly, on the Helmsman repository only. Diff each pinned upstream against its newest ref and draft changes in Helmsman's words. The eval must pass before a draft can land. Opening a pull request is off unless `.helmsman/setup.md` says `Upstream PR: yes`. The default is `no`.

This does not run in a consumer repo. If `.helmsman/tools/upstream/upstream.json` is missing, stop. Say the pin is not in this tree.

## Read

- `.helmsman/tools/upstream/upstream.json` — the pin: repo, ref, commit, date, files, and where each was adopted.
- `.helmsman/setup.md` — `Upstream PR`. Missing or anything other than `yes` means do not open a pull request.
- The adopted Helmsman files named in the lock. Do not load the snapshot as a rule. It is reference material.

## Horizon

For each entry:

1. Resolve the newest ref. Ponytail: the newest release tag. `cursor/plugins`: the newest commit on the default branch that touches any listed path. That commit is the candidate pin, and every listed file is taken at that commit.
2. If the commit matches the pin, say the horizon is clear for that name.
3. If it differs, download the listed files at the new commit and diff them against the pin. Do not run `sync.sh` yet. That script rewrites the working tree.

Classify every upstream hunk:

- **ADOPT** — which Helmsman file and line, in Helmsman's words. Approve and Request changes stay the verdict. Blocker, Judo, High, Medium, Low, Fix forward, and Nit stay the finding labels. Tests stays the test bar. A second always-on standard is not adopted.
- **IGNORE** — why this hunk does not belong (levels, hooks, a marketing card, a test rule that fights the unit test). Model slugs and reasoning levels are never adopted.
- **CONFLICT** — which Helmsman rule wins, and why.

## Draft

Write the adopted edits in Helmsman's voice. Do not paste upstream sentences into a rule or a skill.

Then run `./eval/run.sh` and `./eval/trials.sh`. A draft that fails the suite does not land. Say which grader failed.

When `Upstream PR` is not `yes`, the report is the deliverable. Do not push and do not open a pull request. Do not leave the adopted edits committed.

When `Upstream PR` is `yes`, branch `agent/helmsman/upstream watch-<name>-<ref>` first, using the tag or a short sha so the branch has no slash. Then run `.helmsman/tools/upstream/sync.sh <name> <ref>`, draft the wording, and run the suite. Commit the pin and the voiced edits, and open one pull request, only if the suite passed. The pin update and the wording land together. A pin bump with no wording change still needs the suite. If the suite fails, do not open the pull request. Say which command failed.

## Report

```text
Upstream watch: <date>
Pin: <name> <old sha> -> <new sha> | clear
ADOPT: <file> — <one line>
IGNORE: <hunk> — <why>
CONFLICT: <hunk> — <Helmsman rule that wins>
Eval: passed | failed <command>
Pull request: not opened (Upstream PR: no) | <url>
```

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`). cursor/plugins@`11713c683fe4add4fd403ea880580abbc9e0875f`. MIT. The snapshot is `.helmsman/tools/upstream/`.
