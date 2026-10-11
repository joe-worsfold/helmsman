---
name: helmsman-readiness
description: >-
  Scores how ready a repo is for agentic coding: whether its checks can
  actually fail a commit or a pull request. Record capability, adapter,
  and evidence. Works standalone, with no setup file, and with a full
  Helmsman setup.
user-invocable: true
---

# helmsman-readiness

[Helmsman](../../../README.md) is a set of rules and checks for agent-written code. This skill asks what stops a bad change. [helmsman-slop](../helmsman-slop/SKILL.md) measures unnecessary code. [helmsman-security](../helmsman-security/SKILL.md) records each security finding and how to fix it. [helmsman-delivery](../helmsman-delivery/SKILL.md) measures recent delivery cost.

This score is how ready a repo is for agentic coding: whether its checks can actually fail a commit or a pull request.

Answer one question: if an agent edits this repo, what actually stops a bad change, and what still depends on the agent behaving?

Do not implement fixes unless asked. Do not award a check because a rule says "run the tests". Award it when a command or CI job fails the commit or the pull request, and name that file or job. A green pure-unit suite does not award end-to-end or integration. Trust the watchable journey, then integration, ahead of unit tests.

The skill works when it is the only Helmsman file in the repo. No `.helmsman/setup.md`, no `.helmsman/tools/checks/`, and no Helmsman init are required to score. Adopting repos keep their own standards and rules. Do not copy Helmsman rules in order to award a row. Full Helmsman setup is optional and uses the same capability rules.

This is not an Anthropic, Google, OpenAI, or Cursor product score. Nobody publishes one. The five levels are the useful part of [Factory's Agent Readiness](https://docs.factory.ai/agent-readiness/overview). The top two levels add what Anthropic, OpenAI, and Cursor say to measure next: run the agent on real tasks, more than once, inside a sandbox.

## How a row is scored

Every scored row has three columns. Only capability enters the level.

| Column | Meaning |
| --- | --- |
| Capability | `pass`, `fail`, `unknown`, or `n/a`. This is the score. |
| Adapter | `helmsman`, `native`, or `absent`. This is not the score. A missing adapter does not lower the level and does not flip capability to fail. |
| Evidence | The file or job that fails the commit or the pull request. A README sentence with no command does not count. |

Setup, Local setup, and Pure unit may add an Observed value: `ran: pass`, `ran: fail`, or `ran: env-blocked`. The level still uses capability. `env-blocked` means the tool environment could not run the command. It is not a repository defect. When you score this repository, run the documented install and `pnpm check`. Stop at 10 minutes and record `env-blocked` if the environment cannot finish.

`helmsman` means a Helmsman script is what fails the commit or the pull request. `e2e-smoke.sh`, `integration.sh`, `languages.sh`, and `setup.md` are that adapter when a hook or CI runs them. `native` means the repo's own command or job does, and Helmsman is not installed or is not the thing that runs. `absent` means nothing runs. A copied Helmsman package that nothing runs is `absent` and the capability fails. An equivalent command that does run is `native` and the capability passes.

Unknown counts as a fail on a scored row. Say what you could not see. `n/a` leaves the count. It is not a pass and not a fail.

## How the score works

There are five levels. A level is a group of checks. You earn it when at least 80% of its checks pass (`ceil(0.8 × count)`) and every level below it also passes. The pre-merge smoke is outside that 80% count and is required on its own for level 1.

The score out of 5 is the levels earned, plus the fraction of the next level. All of levels 1–3, and 3 of 5 checks on level 4, is `3 + 0.6 = 3.6`.

The fraction is passes divided by checks that still count on the first level not earned, truncated to one decimal. Not applicable leaves both the 80% count and the fraction.

On level 1 the fraction includes the pre-merge smoke and the other level 1 rows. The smoke stays outside the 80% count: if it fails, level 1 is not earned. Local end-to-end is inside the 80% count. It does not withhold level 1 on its own. Post-deploy / full is a level 4 row. It is not part of the level 1 fraction. A pass there does not earn level 1. A fail there does not erase level 1 or the other passes. The exhaustive suite does not stand in for the smoke.

Example: local passes, the pre-merge smoke fails, post-deploy / full passes, and lockfile fails. Setup, lint, types, integration, and pure unit pass. Integration applies, so eight level 1 rows count. Six pass. `6/8` truncates to `0.7`. The 80% group is 6 of 7, which would be enough, and the smoke still fails, so level 1 is not earned. Score `0.7`. Level 0. Post-deploy / full stays a level 4 pass in the table.

Example: local passes, the pre-merge smoke passes, the exhaustive suite runs only after deploy, and the other level 1 rows pass. The 80% group passes and the smoke passes, so level 1 is earned. Post-deploy / full is a level 4 pass. It is not what earned level 1.

Four checks are a safety floor. If any fail, the level cannot go above 2, even if later checks pass. Native jobs count.

- Secret scanning fails the pull request.
- Dependency audit fails the pull request on a high production advisory.
- A new lint suppression, type suppression, or skipped test fails the pull request.
- Application and library source cannot import repo-root scripts or other agent-only tooling.

## End to end is three facts

Print all three. Do not collapse them into "Missing end-to-end that can run locally and in CI." That sentence is false when a local command or a post-deploy job exists. It is also the wrong summary when all three fail: name each fact.

| Fact | Capability passes when | Gates level 1 |
| --- | --- | --- |
| Local | A person can run a journey and watch it. Cypress, Playwright, Maestro, `pnpm test:e2e`, an open runner, or the Helmsman `Watch` command. The runner config is in the tree. | No. It is a normal level 1 check. |
| Pre-merge smoke | A critical-path smoke fails the pull request when it runs. Core journeys only, such as login and the main workflow. Target under about 5 minutes. Parallel Playwright or Cypress is preferred. A path filter on the frontend or API, or a label or comment such as `run-e2e`, passes when that smoke can still fail the pull request when it runs. If you cannot see that the filtered job fails the pull request, the row is unknown. An exhaustive suite on the pull request does not pass this row. | Yes, when the repo has an app. This is the level 1 gate. |
| Post-deploy / full | The exhaustive suite runs after a non-production deploy, on main, or nightly. | No. This is the level 4 row. Credit it there. It does not replace the smoke. |

Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly.

A path filter on the smoke is evidence for the pre-merge row. It does not, by itself, pass Fast CI.

No application: local and the pre-merge smoke pass. Say there is no app. A setup file with `Surfaces: none` is the Helmsman adapter for that pass, not a requirement. Post-deploy / full still fails when nothing deploys an app and no nightly exhaustive suite runs.

A pure-unit suite does not pass any of the three. An integration suite does not pass them either. A unit job named as the end-to-end job fails the row it claims.

### One journey

A sole Cypress, Playwright, or Maestro setup is the journey. Record adapter `native` and the workflow or script.

Fail the duplicate-runner rule only when a Helmsman journey command already runs and the repo added a second Cypress, Playwright, or Maestro journey beside it. That fail is on the pre-merge smoke. Name both commands. A Helmsman command of `none`, or no Helmsman runner at all, is not the first of two.

## What to inspect

Prove each capability from a file or a job. Inspect what the repo actually has:

- `.github/workflows/` and the required pull-request jobs
- `.github/hooks/`, `.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`
- The package-manager script manifest and `Makefile`
- `.github/CODEOWNERS` or an equivalent owners file
- `.devcontainer/`
- `.helmsman/setup.md` and `.helmsman/tools/checks/` when those files are present

Branch protection, required reviewers, and required status checks are not in a plain clone. They are a separate line, not the Owners row. When you cannot see them, that line is **unknown**. Unknown protection does not flip Owners to fail or unknown.

Owners passes when `.github/CODEOWNERS` (or an equivalent file) is present and names owners. Evidence is that file. Adapter is `native`. If the file is missing or names nobody, Owners fails.

## One gate per concern

Award the row when one command fails the commit or the pull request. Do not award a second lint for the same tree. Name the command and the job. A target nothing runs does not pass.

When the Helmsman adapter is present and a hook or CI runs it, record `helmsman`. When the repo's own job runs instead, record `native`. Do not demand the Helmsman script in a repo that has not installed it.

| Concern | Capability | Helmsman adapter, when that command runs |
| --- | --- | --- |
| Local | A person can run and watch the journey. | `Watch` in `.helmsman/setup.md`. |
| Pre-merge smoke | A pull-request check runs the critical-path smoke and fails the pull request when that smoke runs. A path filter or a `run-e2e` label counts. The exhaustive suite does not. | `.helmsman/tools/checks/e2e-smoke.sh` runs the `E2E smoke` line when that command is the smoke. |
| Post-deploy / full | The exhaustive suite runs after a non-production deploy, on main, or nightly. | The deploy, main, or nightly workflow calls it. It does not have to be `e2e-smoke.sh` on the pull request. |
| Integration | CI runs the integration against the real local service when the app has a database, queue, or emulator. No such boundary: `n/a`. | `.helmsman/tools/checks/integration.sh` runs the `Integration` line. |
| Lint and format | Lint errors fail the pull request. Format fails when a formatter is installed. No formatter: format is `n/a`. | `pnpm lint`, and `pnpm format:check` when Prettier, rustfmt, or Ruff is present. |
| Types | Typecheck errors fail the pull request, and strict mode is on. | `pnpm typecheck`, or `.helmsman/tools/tsc/check.sh --strict`. A build (`next build`, `expo export`, `cargo build`) is extra evidence when the app has one. |
| Pure unit | Pure-function tests fail the pull request. This does not clear end-to-end or integration. | `pnpm test`, the test job, or `make check` when that is the test gate. |
| Lockfile | A clean install fails when the lockfile is stale. | `pnpm install --frozen-lockfile` in the pull-request job. `pnpm-lock.sh` also fails a `pnpm/action-setup` version other than the exact `packageManager` field when that script runs. |
| Pre-commit | Format, lint, secrets, and dead-code or import checks run on commit. | Lefthook or `.pre-commit-config.yaml` runs `pnpm setup:check`, `pnpm diff:guard`, `pnpm plain:language`, and `pnpm lint` / `pnpm format:check` / `pnpm typecheck` / `pnpm test` for the files that changed. |
| Policy | Infrastructure or application static analysis runs when those files change. No infra and no application SAST: `n/a`. | The repo's policy job. |
| Review classes | The review process uses a written set of outcomes. | `helmsman-checklist.mdc` and `helmsman-review` (Approve, Request changes, Blocker, Judo, High, Medium, Low, Fix forward, Nit). |
| Secrets and audit | Secret scan and a high production dependency audit both fail the pull request. | `.helmsman/tools/secrets/check.sh` from `pnpm setup:check` or `pnpm audit:all`, and the audit job. Rust also: `cargo audit` and `cargo deny check advisories bans sources` when `Cargo.toml` exists. |
| Suppression guard | A new lint suppression, type suppression, or skipped test fails the pull request. | `.helmsman/tools/checks/diff-guard.sh`. |
| Boundaries | An illegal import between applications, libraries, and scripts fails. | The ESLint package test or the import-boundary check `languages.sh` runs. |

Native evidence for those rows is a GitHub Actions job, a `pnpm` or `make` script the hook or CI runs, `.github/hooks/pre-commit`, or the repo's own ESLint, `tsc`, or test gate. Examples: a `lint` job, a `typecheck` job, `coverage-gate` and unit-test jobs, an integration job against local DynamoDB or OpenSearch, `.github/hooks/pre-commit` running Prettier, ESLint, a diff guard, secretlint, Knip, and an import boundary, a `checkov` job, a standards review plus the repo's review policy, a `security` job. Record adapter `native` and the job or file name.

Do not install ESLint because the repo has no ESLint config. Do not count both `web-check` and the tsc adapter. Opt-in type-aware ESLint does not stand in for `tsc`. A mocked integration boundary fails integration. Clippy does not stand in for `cargo test`. The metrics map is not a job.

Which infra tools are in the Helmsman set, when this repo vendors them: `docs/check-packages-consensus.md`. The coverage map is `docs/coverage.md`. Those notes are not a score of another repository.

A cloud agent on one GitHub repository cannot clone a private repository in another org when the App install is repo-scoped. Detail: `docs/agent-access.md`.

### Level 1 — A bad change fails the pull request

Why: an agent that cannot run the compiler, and a critical path that does not fail the pull request, will ship something the pull request did not watch. The exhaustive suite can wait until after merge. A green pure-unit suite is not that watch.

The pre-merge smoke is required on its own. The other rows sit in the 80% count.

| Check | What | Evidence that passes |
| --- | --- | --- |
| Local | A person can run and watch a journey. | The local command and the runner config. No app: pass. |
| Pre-merge smoke | The critical-path smoke fails the pull request when it runs. Core journeys, target under about 5 minutes, preferably parallel. A path filter or a `run-e2e` label counts when the smoke can still fail the pull request. | The pull-request job, the path filter, or the label trigger. Or `e2e-smoke.sh` when that job runs the smoke. No app: pass. Duplicate runner: fail. Exhaustive suite alone: fail. |
| Setup | A human or agent can find install and the pull-request suite command. | README or a document it links. |
| Lint and format | Lint errors fail the pull request. Format fails the pull request when Prettier, rustfmt, or Ruff is the formatter. No formatter: format is `n/a` and the row follows lint. | The lint job. Format is the format job when one exists. |
| Types | Typecheck errors fail the pull request, and strict mode is on. A product `tsconfig` has `"strict": true`. Python strict is `strict = true` or `typeCheckingMode = "strict"` when a type checker is configured. When the app has a build (`next build`, `expo export`, or `cargo build`), that build is evidence too, and it is change-gated. No app build: build is `n/a`. | The typecheck job, `.helmsman/tools/tsc/check.sh --strict`, or the Python strict probe. |
| Integration | The app's database, queue, or emulator boundary runs in CI against the real local service. No such boundary: `n/a`. | The integration job, or `integration.sh` when that job runs it. |
| Pure unit | Pure-function tests run and fail the pull request. | The unit job. Does not clear the rows above. |
| Lockfile | Install fails when the lockfile is stale. | Frozen install from the lockfile in the pull-request job. |

### Level 2 — The same checks run before the commit

Why: waiting for CI is how agents burn a review on format, secrets, and dead code.

| Check | What | Evidence that passes |
| --- | --- | --- |
| One standard | One always-on rule. Other rules load only for matching files. The same rule is not copied twice. Root and nested `AGENTS.md` above 400 words warns and above 900 fails. A warning does not fail the row. The repo's own standard counts. A missing Helmsman standards file does not fail this row. | The always-on rule file, and `agents-words.sh` when `pnpm setup:check` runs it. |
| Pre-commit | Format, lint, secrets, and dead-code or import checks run on commit. | `.github/hooks/pre-commit`, `.pre-commit-config.yaml`, husky, or lefthook, and the checks that hook runs. |
| Pull-request template | A reviewer sees what the author claims. | The pull-request template. |
| Owners | The clone names who owns the paths. | `CODEOWNERS` or an equivalent file that names owners. |
| Local setup | A new agent can run the app from a document. | README or local-dev document. |
| Docs match the tree | A fenced bash or sh command exists, and a stated Node or Rust version matches the pin. | `.helmsman/tools/checks/docs-commands.sh` inside `pnpm setup:check`. |
| Scoped local check | The hook runs on the files that changed, and a local affected run exists. | Lefthook globs, and `HELMSMAN_AFFECTED=1`. |
| Pinned toolchain | The environment is an image or devcontainer, not only version numbers in a README. | `.devcontainer` or equivalent. |

### Level 3 — Security, data, and boundaries fail the pull request too

Why: lint does not catch a secret, a bad dependency, a half-written multi-item write, or a library importing a script.

| Check | What | Evidence that passes |
| --- | --- | --- |
| Secrets and dependencies | Secret scan and dependency audit both run and fail the pull request. | The pull-request security job, or the Helmsman secret and audit commands when those run. |
| Policy scan | Infrastructure or application static analysis runs when those files change. No such files: `n/a`. | The policy job. |
| Boundaries | An illegal import between applications, libraries, and scripts fails. In STAR, a domain depending on another domain fails too. A hand edit of a generated file or a lockfile fails. | The import-boundary test or lint rule, and the generated hand-edit gate. In STAR, a check over each domain's `Cargo.toml`, `package.json`, or `pyproject.toml` that fails a sibling domain dependency. |
| Suppression guard | New suppressions and skipped tests fail. | The diff guard in the hook or CI. |
| Telemetry | The running app emits logs or traces. A service also has a health endpoint the smoke hits. A deploy ping alone does not count. No running app: `n/a`. | The app's logger or tracer, and the health route when there is a service. |

### Level 4 — Feedback stays fast, and we have watched an agent work

Why: a green unit suite can still hide a flake, and a rule file does not prove an agent can finish a real task.

| Check | What | Evidence that passes |
| --- | --- | --- |
| Post-deploy / full | The exhaustive suite runs after a non-production deploy, on main, or nightly. It does not have to fail the pull request, and it does not replace the level 1 smoke. | The deploy, main, or nightly workflow calls it. |
| Fast CI | Untouched areas are skipped. | Path filters or an equivalent. |
| Review classes | Written review outcomes, and the review uses them. Helmsman's verdict is Approve or Request changes. The finding labels are Blocker, Judo, High, Medium, Low, Fix forward, and Nit. A repo's own review policy counts. | The checklist or review-policy file the review runs. A copied file nothing runs does not pass. |
| Flake control | Flaky tests are detected, quarantined with a linked issue, or retried and reported. A comment that a test might flake does not count. | CI or the test runner. |
| Task eval | At least 10 real tasks. Each run starts from a clean tree, keeps the diff, and grades it with the checks above. | A recorded suite, not a plan. |

### Level 5 — The agent is measured, sandboxed, and corrected by production

Why: one successful demo is not reliability. Delivery is the production half of this level. Do not award Outcome loop from a deploy ping. A written review that changed the harness is the evidence. If that review is not in the tree, the check is unknown.

| Check | What | Evidence that passes |
| --- | --- | --- |
| Repeated trials | The task eval reports how often all repeats pass, not a single run. | At least 3 trials. |
| Sandbox | Agent shell and network are denied unless allowed. | Agent hooks or the agent runner config. |
| Outcome loop | Change-failure or rework data is reviewed on a cadence and the harness changes because of it. Emitting a deploy event is not the loop. | A written review, with a change that followed. |
| Rules are tested | A change to agent rules is kept only when the task eval still passes. | The eval runs on rule changes. |

## Report

Show the report in the reply. That reply is the deliverable. The skill does not need `.helmsman/tools/checks/report-write.sh` or `.helmsman/setup.md`.

Write `.helmsman/reports/<UTC>/readiness.md` only when `.helmsman/tools/checks/report-write.sh` is in the tree and `.helmsman/tools/checks/report-write.sh readiness.md` exits 0. If the script is missing, skip the file. Exit 10 means chat only: do not create a file. A write needs the path gitignored and one of `HELMSMAN_WRITE_REPORTS=1`, `CURSOR_AGENT=1` (Cursor cloud agent), `GITHUB_ACTIONS=true`, or `CI=true`. A local shell sets none of these. The stamp is `HELMSMAN_REPORT_STAMP` or the current UTC minute (`date -u +%Y-%m-%dT%H%MZ`, for example `2026-09-30T0629Z`).

Every check below is a row, including a pass. Do not collapse a fail into a paragraph. Do not drop a level. Do not print one end-to-end miss in place of the three facts.

`N` is the levels earned. The plain name is the heading of that level. When `N` is 0, use the Level 1 heading.

```markdown
# Readiness

**Score:** X.X / 5
**Level:** N of 5 — <heading of the level earned>
**What the number is:** levels earned, plus the fraction of the next level, truncated to one decimal. Unknown is a fail on a scored row. Not applicable leaves that row out. Adapter is not the score. Example: levels 1–3 earned, and 3 of 5 checks on level 4, is 3.6.

**End to end:**
- Local: pass | fail | n/a. Evidence: …
- Pre-merge smoke: pass | fail | n/a. Evidence: … This row gates level 1.
- Post-deploy / full: pass | fail | unknown | n/a. Evidence: … Level 4. It does not replace the level 1 smoke.

Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly.

**Integration:** pass | fail | n/a. A pure-unit suite does not clear this.
**Safety floor:** held | capped at level 2 because …
**Owners:** pass | fail. Evidence: the owners file. Adapter: native | absent.
**Branch protection:** unknown | pass | fail. Required reviewers and required status checks. Unknown does not change Owners.

<Two sentences: what already fails the commit or the pull request, and the single next gate.>

| Level | Check | Capability | Adapter | Evidence |
| ----- | ----- | ---------- | ------- | -------- |
| 1 | End-to-end, local | pass / fail / n/a | helmsman / native / absent | file or job. No app: pass. |
| 1 | End-to-end, pre-merge smoke | pass / fail / n/a | helmsman / native / absent | file or job. No app: pass. This row gates level 1. A path filter or `run-e2e` label counts. |
| 1 | Setup | pass / fail / unknown | helmsman / native / absent | file or job |
| 1 | Lint and format | pass / fail / unknown / n/a | helmsman / native / absent | file or job. No formatter: format is n/a. |
| 1 | Types | pass / fail / unknown | helmsman / native / absent | file or job. Strict is on. Build is n/a when the app has no build. |
| 1 | Integration | pass / fail / n/a | helmsman / native / absent | file or job. No database, queue, or emulator: n/a. |
| 1 | Pure unit | pass / fail | helmsman / native / absent | file or job. Does not clear the rows above. |
| 1 | Lockfile | pass / fail / unknown | helmsman / native / absent | file or job |
| 2 | One standard | pass / fail | helmsman / native / absent | file or job |
| 2 | Pre-commit | pass / fail | helmsman / native / absent | file or job |
| 2 | Pull-request template | pass / fail | helmsman / native / absent | file or job |
| 2 | Owners | pass / fail | helmsman / native / absent | file or job |
| 2 | Local setup | pass / fail | helmsman / native / absent | file or job |
| 2 | Docs match the tree | pass / fail | helmsman / native / absent | file or job |
| 2 | Scoped local check | pass / fail | helmsman / native / absent | file or job |
| 2 | Pinned toolchain | pass / fail | helmsman / native / absent | file or job |
| 3 | Secrets and dependencies | pass / fail / unknown | helmsman / native / absent | file or job |
| 3 | Policy scan | pass / fail / unknown / n/a | helmsman / native / absent | file or job |
| 3 | Boundaries | pass / fail | helmsman / native / absent | file or job |
| 3 | Suppression guard | pass / fail | helmsman / native / absent | file or job |
| 3 | Telemetry | pass / fail / unknown / n/a | helmsman / native / absent | file or job |
| 4 | Post-deploy / full end-to-end | pass / fail / unknown | helmsman / native / absent | file or job. Does not replace the level 1 smoke. |
| 4 | Fast CI | pass / fail | helmsman / native / absent | file or job |
| 4 | Review classes | pass / fail | helmsman / native / absent | file or job |
| 4 | Flake control | pass / fail | helmsman / native / absent | file or job |
| 4 | Task eval | pass / fail | helmsman / native / absent | file or job |
| 5 | Repeated trials | pass / fail | helmsman / native / absent | file or job |
| 5 | Sandbox | pass / fail | helmsman / native / absent | file or job |
| 5 | Outcome loop | pass / fail / unknown | helmsman / native / absent | file or job |
| 5 | Rules are tested | pass / fail | helmsman / native / absent | file or job |

### Next

1. …
2. …
```

This repository pins the level arithmetic in `eval/readiness.mjs`. An adopting repo does not need that file. Follow this skill.

## Licence

Unscored. Record `present` or `absent`. Flag an absent licence only when the repository is public.

## Agent compatibility (cross-check)

Unscored. Run `.helmsman/tools/checks/agent-compat.sh` from this skill or the nightly report. Do not run it from CI or from `pnpm setup:check`. The config ignores the path prefixes `eval/fixture`, `eval/scenarios`, `fixture`, and `node_modules`. The scanner makes no network calls. The script uses `npm exec --offline` and does not download the package. If Node, npm, or the local install is missing, the script prints `cross-check unavailable (tool environment)` and exits 0.

A presence score of 81 or higher is required before readiness level 1 can be treated as enough, and it still does not earn that level by itself. Readiness at level 1 or above with a presence score below 60 points to docs or presence gaps. Keep the two scores apart.

## The other readings

This score does not say how much unnecessary code is already in the repo, or what recent delivery cost. Run [helmsman-slop](../helmsman-slop/SKILL.md) for the readiness score beside the Slop Density Index and the P0–P4 list. Run [helmsman-security](../helmsman-security/SKILL.md) for security findings. Run [helmsman-delivery](../helmsman-delivery/SKILL.md) for delivery and rework. Read a repository against its own last Helmsman report. Do not rank people.
