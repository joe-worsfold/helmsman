# Readiness

**Score:** 4.5 / 5
**Level:** 4 of 5 — Feedback stays fast, and we have watched an agent work
**What the number is:** levels earned, plus the fraction of the next level, truncated to one decimal. Unknown is a fail on a scored row. Not applicable leaves that row out. Adapter is not the score. Example: levels 1–3 earned, and 3 of 5 checks on level 4, is 3.6.

**End to end:**
- Local: pass. `.helmsman/setup.md` has `Surfaces: none` and `Watch: none`. This repo has no app.
- Pre-merge smoke: pass. `E2E smoke` is `none`, so the emitter writes no smoke job. There is no app. This row gates level 1.
- Post-deploy / full: fail. No deploy workflow, no nightly exhaustive suite, and no application. Level 4. It does not replace the level 1 smoke.

Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly. There is no application here, so the smoke row passes without a journey.

**Integration:** n/a. No database, queue, or emulator boundary. `Integration: none` in `.helmsman/setup.md`, so the emitter writes no integration job.
**Safety floor:** held. Secret scan, `pnpm audit --audit-level=high` on the root lock and the two package locks, the diff guard, and the ESLint package test that rejects a `scripts/` import.
**Owners:** pass. `.github/CODEOWNERS` names an owner. Adapter: native.
**Branch protection:** unknown. Required reviewers and required status checks are not in this clone. This line does not change Owners.

`pnpm typecheck` fails the pull request when `eval/failure-text.mjs` or `eval/quarantine.mjs` does not typecheck. The `typecheck (tsc)` job runs that script after `pnpm install --frozen-lockfile`. Level 2 is 5 of 6, so that level still holds. Level 5 is 2 of 4: repeated trials and rules tested. The next gate is a sandbox that denies agent shell and network unless allowed.

| Level | Check | Capability | Adapter | Evidence |
| ----- | ----- | ---------- | ------- | -------- |
| 1 | End-to-end, local | pass | helmsman | `.helmsman/setup.md` Surfaces none. No app. |
| 1 | End-to-end, pre-merge smoke | pass | helmsman | `E2E smoke` is `none`. No smoke job. No app. Gates level 1. |
| 1 | Setup | pass | native | `README.md` names install-by-copy, `pnpm install --frozen-lockfile`, and `./eval/run.sh`. |
| 1 | Lint | pass | helmsman | `pnpm setup:check` runs `bash-n.sh` and `no-silences.sh` on the hook and in the setup job. |
| 1 | Types | pass | helmsman | `pnpm typecheck` runs `tsc --noEmit -p eval/tsconfig.json`. The `typecheck (tsc)` job installs dependencies, then runs that script. |
| 1 | Integration | n/a | helmsman | No database, queue, or emulator. `Integration: none`, so no integration job. |
| 1 | Pure unit | pass | helmsman | `test (harness)` runs `pnpm test` with `HELMSMAN_FILTER=harness`. In CI that is flake and three trials. It does not clear the rows above. |
| 1 | Lockfile | pass | helmsman | `pnpm install --frozen-lockfile` on the root lock in typecheck, test, and audit. `pnpm-lock.sh` runs in the setup job. The ESLint and Knip jobs use their own frozen install when they run. |
| 2 | One standard | pass | helmsman | `.cursor/rules/helmsman-standards.mdc` is the only always-on rule. |
| 2 | Pre-commit | pass | helmsman | `lefthook.yml` runs `pnpm setup:check`, `pnpm diff:guard`, and `pnpm plain:language` on every commit, and lint, format, typecheck, and test by language glob. |
| 2 | Pull-request template | pass | native | `.github/PULL_REQUEST_TEMPLATE.md` |
| 2 | Owners | pass | native | `.github/CODEOWNERS` names an owner. |
| 2 | Local setup | pass | native | `README.md` |
| 2 | Pinned toolchain | fail | absent | No environment image. `.nvmrc` pins the Node version. |
| 3 | Secrets and dependencies | pass | helmsman | The secret scan runs in `pnpm setup:check` and in `pnpm audit:all`. The audit job runs `pnpm audit --audit-level=high` on the root lock and on `.helmsman/tools/eslint` and `.helmsman/tools/knip`. gitleaks is not installed here; the built-in patterns still fail the commit. |
| 3 | Policy scan | n/a | absent | No application SAST target. Infrastructure is SST; there is no Terraform or Checkov adapter. |
| 3 | Boundaries | pass | helmsman | `.helmsman/tools/eslint/check.mjs` rejects `import "scripts/..."`. The `eslint-package` job runs that file when `.helmsman/tools/eslint` changes. |
| 3 | Suppression guard | pass | helmsman | `.helmsman/tools/checks/diff-guard.sh` in lefthook and the workflow. |
| 3 | Telemetry | n/a | absent | No running app. |
| 4 | Post-deploy / full end-to-end | fail | absent | No deploy workflow, no nightly exhaustive suite, and no application. |
| 4 | Fast CI | pass | helmsman | `ci-paths.sh` sets `eslint` and `knip`. The workflow skips those package jobs when the output is not `true`. An unknown range runs both. Push is `main` only. |
| 4 | Review classes | pass | helmsman | `.cursor/rules/helmsman-checklist.mdc` and `.cursor/skills/helmsman-review/SKILL.md` use Approve or Request changes, and the labels Blocker, Judo, High, Medium, Low, Fix forward, and Nit. |
| 4 | Flake control | pass | helmsman | `./eval/flake.sh` retries `./eval/run.sh` once and reports, including `GITHUB_STEP_SUMMARY` when set. `eval/quarantine.txt` accepts a scenario only with an issue URL. `pnpm test` in CI runs flake. No scenario is listed. |
| 4 | Task eval | pass | helmsman | Scenarios under `eval/scenarios/`. `./eval/run.sh` copies the fixture, keeps the diff, and grades it. The workflow runs that command through flake and trials. |
| 5 | Repeated trials | pass | helmsman | `test (harness)` runs `pnpm test`, which runs `./eval/trials.sh 3` when `GITHUB_ACTIONS` is set. The script prints `helmsman: eval trials <passed>/3` and fails unless all three pass. |
| 5 | Sandbox | fail | absent | No agent hook denies shell or network. |
| 5 | Outcome loop | unknown | absent | No written review in this tree that changed the harness because of change-failure data. |
| 5 | Rules are tested | pass | helmsman | `test (harness)` runs flake and trials on every pull request and on push to `main`. `ci-paths.sh` does not skip that job. |

### Next

1. Add an agent sandbox that denies shell and network unless the run allows them.
2. Record an outcome review that names a change-failure and the harness change that followed.
