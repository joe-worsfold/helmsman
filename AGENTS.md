# Agents

This repository is the Helmsman harness. It is not a STAR product and it has no domain lane. A change here is a whole-repo change.

## Review before ready

Every agent PR finishes in order: (1) run helmsman-review on the full diff against base, (2) fix every Blocker, unjustified Judo, High, and Medium finding, (3) prove it locally with the pre-commit hook and `pnpm check`, (4) post the review as a pull request comment saying what was fixed and what remains Fix forward or Nit and why, (5) mark ready only after that comment. Marking ready is when CI runs. Do not merge until that run is green. The review catches what the standards missed, including when the change was written to them.

Agents work in draft. Prove the change locally with `pnpm check` and the pre-commit hook before pushing. CI runs when the pull request is marked ready, and on push to main. A draft pull request does not run CI.

## Rules and what enforces them

| Rule | What enforces it |
| --- | --- |
| Added lines do not skip a test or suppress a linter | `pnpm diff:guard` |
| Added lines do not bring nautical terms back | `pnpm plain:language` |
| The review comment still matches the pull request patch | `pnpm review:current` |
| The upstream snapshot matches the pin | `pnpm setup:check` |
| The workflow file matches the emitter | `pnpm setup:check` |
| `.claude/` and `CLAUDE.md` match `.cursor/` | `pnpm setup:check` |
| Lint, format, types, unused code, and tests | `pnpm check` |

`helmsman-correct` keeps this table current. A rule with nothing in the second column is not enforced.

## Getting CI green

Use `gh pr checks` to see the failing job. Do not start from `gh run list`. Fix one failure, then look again. Retry a flake once and report that retry. When the failure is already fixed on the default branch and this change did not cause it, merge that branch in. A draft does not run CI, so the draft loop is `pnpm check` and the pre-commit hook.
