# Morning report

Read this first. Then [coverage.md](coverage.md) and [readiness.md](readiness.md).

## What shipped

Helmsman checks the stacks this repository uses. It does not score people.

- `.helmsman/tools/checks/delegate-gate.sh` runs `make check` when that target exists, otherwise the root `package.json` `check` script (`pnpm check` when the repo uses pnpm; `npm run check` only when there is no pnpm lock or field and no yarn lock; `yarn run check` is a legacy fallback). Exit 11 means the script passed. ESLint, Knip, and the tsc adapter do not run after that. rust-workspace still runs when the script omits `cargo fmt` and clippy.
- New bash gates for STAR: Python (`uv`, `ruff`, `ty`, `pytest`), Surreal, Postgres, DynamoDB, OpenSearch, secrets (gitleaks if installed, secretlint if configured, built-in patterns always), silence scan, `bash -n`. Rust file length is 500 on every tracked `.rs` file.
- Expo: Maestro `mobile:e2e` is recognized as an e2e smoke runner. Doctor is opt-in. It is not inside `check`.
- `.helmsman/tools/make/helmsman.mk` defines a `helmsman` target and does not define `check`.
- `docs/coverage.md` is the map of what fails the commit and what the consumer command owns.
- `./eval/run.sh` grades the scenarios under `eval/scenarios/`, including gate bypass, a missing end-to-end command, the protected-test rule, a mocked integration, a secret in source, a rule that drops a gate, the ABTest-shaped lane, claim, skip, overwrite, and generated-file cases, and the review bar for an ad-hoc branch, a refactor that moves a formula, a renamed env var or port, and a feature-gate leak. No model call.
- Toolchain versions are the publisher's latest stable, resolved in the session that bumps them. `.helmsman/tools/checks/toolchain-latest.sh` fails the commit when a Helmsman-owned Node, TypeScript, `@types/node`, or pnpm 12 pin is behind that. Node's pin is `.nvmrc`. Do not invent a version from memory.
- This repo's own lefthook hook and workflow run the language gate, the secret scan, the upstream pin, the setup check, and the eval. The root `package.json` typechecks the eval helpers with `tsc`. It has no `check` script, so the tsc adapter runs. `File issues: yes`. `Fix: no`. `Upstream PR: no`.
- Readiness and slop score an adopting repo that copied only those skills. Capability is the score. Adapter is `helmsman`, `native`, or `absent`, and a missing adapter does not fail a row. End-to-end is three facts: local, pre-merge smoke, and post-deploy / full. Only the critical-path smoke gates level 1. A path filter or a `run-e2e` label counts when that smoke can fail the pull request. The exhaustive suite is deferred and does not replace the smoke. Slop baselines the tree on a first measure and uses a branch delta only after a `slop.md` exists. Detail: [standalone-skills.md](standalone-skills.md).
- Overnight reports are ticket-ready when you later turn filing on. The shape is [issue-body.md](issue-body.md). The nightly still writes reports first and does not file unless the setup says yes. Reports stay gitignored so a finding is not committed. A local run prints the report and does not write a file unless `HELMSMAN_WRITE_REPORTS=1`. A Cursor cloud agent (`CURSOR_AGENT=1`) or CI (`GITHUB_ACTIONS=true` or `CI=true`) may write when the path is gitignored. Detail: [agent-access.md](agent-access.md).

## Readiness on this repo

**4.5 / 5. Level 4.** Detail and every row: [readiness.md](readiness.md). Previous score on this tree was 3.4, level 3.

Held: shell syntax, silence tokens, secrets, dependency audit, the diff guard, the task eval, review classes, a real `tsc` on the eval helpers, path-filtered ESLint and Knip package jobs, flake retry plus quarantine, and three eval trials in CI. There is no app, so local and the pre-merge smoke pass. The workflow runs `e2e-smoke.sh`, which finds no command. Integration does not apply. Post-deploy / full stays a separate fail.

Owners passes because `.github/CODEOWNERS` names an owner. Branch protection is a separate unknown: required reviewers and required status checks are not in the clone, and that unknown does not change Owners.

Still open on level 5: no sandbox, and no written outcome loop. Post-deploy / full stays a fail because this repo does not deploy an application and has no nightly exhaustive suite. It does not replace the level 1 smoke.

## How to run the eval

From the repository root, after `pnpm install --frozen-lockfile`:

```bash
./eval/run.sh
./eval/flake.sh
./eval/trials.sh
```

The workflow step Rules conformance is `./eval/flake.sh`. Repeated trials is `./eval/trials.sh 3`.

## Product loop

1. Each pull request: `.cursor/automations/helmsman-review.md` plus the checklist. Advisory.
2. Overnight: readiness, then slop (`.helmsman/reports/<UTC>/slop.md`, including the score trend), then security (`security.md` in that directory). Reports first. The chat reply is always the report. The fixer stays off until `Nightly fix: yes`.
3. Issues only when `File issues: yes`. Body: [issue-body.md](issue-body.md).
4. Fix forward is one finding. `Fix: yes` allows one in-place edit. `Nightly fix: yes` opens draft pull requests, capped by `Nightly max PRs`, `Nightly max tokens`, and `Nightly max minutes`. The default for both switches is no.

## Remaining gaps

- gitleaks is preferred and is not installed in this checkout. The built-in scan still fails a commit.
- Postgres migrate status and Surreal apply stay on the Integration line. The commit hook does not start a database.
- There is no post-deploy or nightly exhaustive suite, and no application to deploy.
- PHP, Ruby, and .NET were left alone.
- No agent sandbox, and no outcome-loop review.
