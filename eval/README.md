# Eval

This suite checks that Helmsman's written bar can fail a change. It does not make the fixture production-ready, and it does not replace the e2e smoke or the unit test in a repo you are building.

A scenario is a short task, the kind an agent is asked to do. A recorded patch stands in for the diff that agent would write. Graders then run. A golden patch must pass. A fail patch must trip the checks named in the scenario. CI does not call a model. Reading the prompt beside the diff is a second opinion, and it does not gate.

The harness does not load Cursor rules or skills into a model. `.helmsman/tools/checks/gates.test.sh` runs the bash gates in temp repositories. `.helmsman/tools/checks/migrate-layout.bats` covers the layout move, and `.helmsman/tools/checks/migrate-names.bats` covers the name migration. `review-current.bats`, `fix-forward.bats`, `decision-log.bats`, and `nightly-plan.bats` cover the review sha, the fix-forward issues, the decision log, and the nightly fixer switch. They need `bats`. `eval/graders/grade.mjs` encodes the same bar the rules name: thin handlers, the protected-test rule, an unmocked integration test, an end-to-end test on a UI change, no ESLint installed over `make check`, no secret in an added line, and no rule edit that drops a gate. A change to a rule file is kept only when the suite still passes. CI runs `./eval/flake.sh` and then `./eval/trials.sh`.

## Run

From the repository root, with Node 26.11.1:

```bash
./eval/run.sh
./eval/flake.sh
./eval/trials.sh
```

`./eval/run.sh` is one graded pass. It also runs `eval/readiness.test.mjs`, which pins readiness and slop arithmetic: native pull-request jobs, CODEOWNERS with unknown branch protection, local plus post-deploy without a pull-request smoke, a smoke that can earn level 1 while the full suite stays post-deploy, a path filter or `run-e2e` label as that smoke, and slop baseline versus an empty delta. `./eval/flake.sh` runs the graded pass and, on failure, retries once and reports the result, including to `GITHUB_STEP_SUMMARY` when that file is set. `./eval/trials.sh` runs it three times by default and prints `helmsman: eval trials <passed>/<n>`. A failed trial fails the script. Trials do not retry.

`eval/quarantine.txt` lists scenarios to skip. Each line is a scenario id and an `http` or `https` issue URL. A line without that URL fails the run. The file in this repo has no skips.

`pnpm test` with `HELMSMAN_FILTER=harness` runs flake and then trials when `GITHUB_ACTIONS` is set, and `eval/run.sh` once locally. `pnpm typecheck` runs `tsc --noEmit -p eval/tsconfig.json`. A consumer workflow is emitted by `.helmsman/tools/ci/emit.sh` and does not run this suite.

## What a run does

1. Check the fixture setup file. `Surfaces: web`, so an e2e smoke command is required.
2. Run the fixture's own tests.
3. For each scenario, copy the fixture, apply the patch, grade it, and run the fixture tests on a golden patch.

## How to add a scenario

1. Add `eval/scenarios/<id>/scenario.md` with front matter: `id`, `title`, `checks`, `allowed`, `pass`, `fail`, and `catch-<fail file>` listing the checks that fail patch must trip.
2. Add `pass.diff` and at least one fail diff, generated against `eval/fixture` (`git diff` from a copy of the fixture).
3. Keep the fail diff's bad tokens under `eval/scenarios/`. `.helmsman/tools/checks/diff-guard.sh` ignores that directory because the fail patches contain them on purpose.
4. Run `./eval/run.sh`. A golden that fails, or a fail patch that comes out clean, fails the command.

## Graders

| Check | What fails |
| --- | --- |
| `diff_guard` | `.helmsman/tools/checks/diff-guard.sh` on the patch. Suppressions and skipped or focused tests. |
| `schema_parse` | A handler change that does not call `parseQuery`. |
| `thin_handler` | SQL or `.query(` in `src/server.js` or `src/routes/`. |
| `layer_leak` | SQL or `.query(` in a handler, `src/pages/`, or `web/`. A `src/domain/` import whose path includes `server`, `pages`, or `scripts`. |
| `worker_ack` | Added worker lines that neither call `consume(` nor both ack and check an idempotency key (`.has(` or `idempoten`). |
| `no_eval` | Added `eval(` or `new Function(`. |
| `integration_unmocked` | No `*.int.test.*` integration, or that integration uses `mock.method`, `jest.mock`, `sinon`, or `__mocks__`. The fixture queue is the `seen` set and the sink. |
| `ui_e2e` | A UI change that does not touch `e2e/`, `cypress/`, `playwright`, or `maestro`. |
| `ui_selector` | Added lines with no `data-testid` or `getByRole`, or a hashed `css-` / `sc-` class. |
| `ui_no_sleep` | `waitForTimeout`, `cy.wait(<number>)`, `setTimeout`, or a Maestro `sleep:` used as the wait. |
| `unit_test` | `src/domain/` changed and no test file changed. |
| `protected_test` | A removed `assert.` or `expect(` in a test file, unless the diff says `old assertion is now false`. |
| `gate_bypass` | An ESLint config added while the fixture Makefile has a `check` target. |
| `missing_e2e` | The fixture records a Helmsman adapter. `Surfaces` is not `none`, and E2E smoke or Watch is `none`. A native journey with no setup file is not this case. |
| `secret_in_source` | An added line matches a cloud key, a private-key block, or a live token prefix. |
| `rules_drop_gate` | An added line says not to run the secret scan, the diff guard, the e2e smoke, integration, or the silence scan. |
| `lane_bound` | The scenario sets `lane:` and the patch touches another `packages/<domain>/`. |
| `claim_evidence` | `REPORT.md` claims a pass without naming a command that ran or changing a test. |
| `silent_skip` | A domain or package source change claims done, complete, or finished with no test. |
| `overwrite_kept` | The scenario sets `keep:` and the patch deletes or rewrites that file. |
| `generated_hand_edit` | The patch hand-edits `generated/`, `pnpm-lock.yaml`, `Cargo.lock`, or another lockfile. |
| `spaghetti_growth` | An added `if` in a handler that is not a new route (`path ===` or `method ===`). |
| `concept_move` | A new function plus a `return` that only calls it, and the diff deletes no branch. The concept count did not drop. |
| `devex_break` | An environment name or a `.listen(port)` number was removed, and no added migration note names it. Keeping the old name as a fallback is not this. |
| `feature_leak` | A `FEATURE_`… gate was removed from a file and not put back. |
| `hollow_test` | An added test line stubs the subject, or asserts `toBeDefined`, `toBeTruthy`, `toHaveBeenCalled`, an empty list, or `toBeGreaterThan(0)`. The test would still pass if every import returned nothing. |
| `docs_drift` | `.helmsman/tools/checks/docs-commands.sh` on the work tree. A fenced command is missing, or a stated Node version disagrees with the pin. |
| `env_missing` | `.helmsman/tools/checks/env-example.sh` on the work tree. A product env read has no `.env.example` line, or a value looks like a secret. |
| `allowed_files` | The patch touches a file the scenario did not allow. Always on. |

## Later

`spaghetti_growth`, `concept_move`, `devex_break`, and `feature_leak` are the measurement of the review and structure bar: an ad-hoc branch, a refactor that moves a formula, a renamed env var or port, and a feature-gate leak. The suite encodes that bar. It does not call a model. A later pass can add an infrastructure change that bypasses SST, an auth route whose check lives only in the page, and a migration that renames a stored field in place. Scenarios under `eval/scenarios/` are gated in CI. Repeated trials are `./eval/trials.sh`, three by default, on the same workflow.
