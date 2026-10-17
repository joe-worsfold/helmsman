# Guardrails

The CI design lives in Helmsman. Setup writes it with `.helmsman/tools/ci/emit.sh`. A target repo does not hand-write `.github/workflows/helmsman.yml`. The emitter writes a job only when that language or feature is in the tree: no Python jobs without `pyproject.toml` or `uv.lock`, no Rust jobs without a `Cargo.toml`. `test (integration)` exists when `CI integration` is `yes`. `e2e smoke` exists when `CI e2e smoke` is `yes`. `Integration` and `E2E smoke` stay the local commands. A missing CI key means the job stays off.

Every job runs the same root pnpm script a developer runs locally. The workflow `run` lines are those scripts. Setup and cache steps are the rest (checkout, pnpm, Node, `pnpm install --frozen-lockfile`, Turbo cache, rust-toolchain, rust-cache, uv). `HELMSMAN_FILTER` selects one language inside the script. Unset, the script runs every language this repo has.

`pnpm check` runs lint, format, typecheck, unused, and test. It does not run integration, end-to-end smoke, or audit. Integration and smoke need services. Audit needs the network. Those three stay as their own scripts, and CI calls them by those names.

Turbo is the runner where a task exists. CI adds `--affected` when `GITHUB_ACTIONS` is `true` (the script also honors `HELMSMAN_AFFECTED=1` for a local trial). A local `pnpm check` does not pass `--affected`, so the cache is the full set. Optional remote cache is `TURBO_TOKEN` and `TURBO_TEAM`, or `TURBO_API`. It is not required. The Turbo cache does not store Rust `target/`; `Swatinem/rust-cache` does. `turbo.json` `globalDependencies` include `Cargo.lock`, `pnpm-lock.yaml`, and `uv.lock`. Lint, format, typecheck, test, and unused use empty `outputs` so the task result is cached without copying `target/`.

Push runs on `main` only. A pull request is one workflow, not a second copy from the branch push. The pull request types are `opened`, `ready_for_review`, `synchronize`, `reopened`, and `edited`. Every job is skipped while the pull request is a draft (`github.event_name != 'pull_request' || github.event.pull_request.draft == false`). A pull request `edited` event skips every job except `prove (web)`. That job runs only when the body changed and `apps/web` exists. The edited run uses its own concurrency group, so it does not cancel the suite already in progress. Agents keep the pull request draft, prove it with `pnpm check` and the pre-commit hook, and mark it ready when that proof is done. Marking ready is when CI runs.

Wall clock stays under 5 minutes. `changes` runs first, except on `edited`, where it is skipped. Every other job `needs: changes` and starts only when its path output is true. `prove (web)` uses `always()` so a body edit can run it after `changes` was skipped. Those jobs run in parallel. GitHub bills the sum of job minutes, rounded up per job. A skipped job is free. A job that starts is at least one minute. A draft costs nothing. An `edited` event with no `apps/web` starts no job.

`pnpm lint:actions` is [actionlint](https://github.com/rhysd/actionlint) v1.7.12. `.helmsman/tools/checks/actionlint.sh` installs it with the official download script pinned to commit `914e7df21a07ef503a81201c76d2b11c789d3fca`. The CI job calls that same script and passes the pin in the environment. The first local run downloads the binary into the user cache.

## Script to job

| Script | CI job | `HELMSMAN_FILTER` | When the job exists |
| --- | --- | --- | --- |
| `pnpm ci:paths` | changes | | Every run that is not a draft and is not `edited`. Outputs `ts`, `rust`, `python`, `schema`, `web`, `api`, `docs`, `setup`, `eslint`, `knip`, `harness`, `workflows`, `audit`, and `guard`. |
| `pnpm lint` | lint (eslint) | `ts` | TypeScript packages, or a root ESLint config that references Helmsman. Gated on `ts`. |
| `pnpm format:check` | format (prettier) | `ts` | TypeScript packages, or Prettier. Gated on `ts`. |
| `pnpm typecheck` | typecheck (tsc) | `ts`, or `harness` when Python is also present and the only TypeScript project is `eval/tsconfig.json` | TypeScript packages, or a root or eval `tsconfig` with no TypeScript package. `needs: changes`. Gated on `ts`. Eval `.ts`, `.tsx`, `.mts`, `.mjs`, and `eval/tsconfig.json` set `ts`. |
| `pnpm unused` | unused (knip) | | Knip is wired (config, `knip` object, or dependency). Gated on `ts`. |
| `pnpm test` | test (vitest) | `ts` | TypeScript packages, or a `vitest` dependency. Gated on `ts`. |
| `pnpm lint` | lint (clippy) | `rust` | A `Cargo.toml`. Gated on `rust`. |
| `pnpm format:check` | format (rustfmt) | `rust` | A `Cargo.toml`. Gated on `rust`. |
| `pnpm test` | test (unit) | `rust` | A `Cargo.toml`. Gated on `rust`. |
| `pnpm lint` | lint (ruff) | `python` | `pyproject.toml` or `uv.lock`. Ruff format is part of this lint. Gated on `python`. |
| `pnpm typecheck` | typecheck (ty) | `python` | `pyproject.toml` or `uv.lock`. Gated on `python`. |
| `pnpm test` | test (pytest) | `python` | `pyproject.toml` or `uv.lock`. Gated on `python`. |
| `pnpm test:integration` | test (integration) | | `CI integration` is `yes`. `needs: changes`. Gated on `rust` or `schema`. `Integration` stays the local command. |
| `pnpm e2e:smoke` | e2e smoke | | `CI e2e smoke` is `yes`. `needs: changes`. Gated on `web` or `api`. `E2E smoke` stays the local command. Playwright's browser install, when the setup line names it, stays inside the script. |
| `pnpm prove:web` | prove (web) | | `apps/web` exists. `needs: changes`. Gated on `web`, and also when the pull request body is edited. `always()` lets that run proceed when `changes` was skipped. The job checks the diff and the pull request body. It does not install dependencies, Playwright, or take screenshots. |
| `pnpm test` | test (harness) | `harness` | `eval/flake.sh` and `eval/trials.sh`. This repo only. `needs: changes`. Gated on `harness`: `.helmsman/tools/**` or `eval/**`. In CI the script runs flake and then three trials. Locally it runs `eval/run.sh` once. |
| `pnpm audit:all` | audit | | `needs: changes`. Gated on `audit`: a manifest or lockfile (`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `Cargo.toml`, `Cargo.lock`, `pyproject.toml`, `uv.lock`, `deny.toml`, `rust-toolchain.toml`, `.nvmrc`). pnpm audit, the ESLint and Knip package lock audits, cargo audit, cargo deny, the secret scan, and toolchain freshness. |
| `pnpm setup:check` | setup | | `needs: changes`. Gated on `setup`: `.helmsman/**`, `.github/**`, toolchain and workspace files, shell, and source. A docs-only diff does not set it. Setup fields, tool home, upstream pin, pnpm lock pin, web drift, shell syntax, silences, schema static checks, secrets, documented commands, env example names, `AGENTS.md` length, strict tsconfigs, and `emit.sh --check`. |
| `pnpm diff:guard` | diff guard | | `needs: changes`. Gated on `guard`. A lockfile-only diff (`pnpm-lock.yaml`, `Cargo.lock`, `uv.lock`) does not set it. |
| `pnpm plain:language` | diff guard | | Same job as `pnpm diff:guard`, as a second step. It does not add a billed minute. |
| `pnpm lint:actions` | lint (actionlint) | | Every repository whose CI is GitHub. `needs: changes`. Gated on `workflows`: `.github/workflows/**` or `.github/actions/**`. |
| `pnpm eslint:package` | eslint-package | | `.helmsman/tools/eslint/check.mjs`. Gated on `eslint`. |
| `pnpm knip:package` | knip-package | | `.helmsman/tools/knip/check.mjs`. Gated on `knip`. |
| `pnpm ci:ok` | ci-ok | | Every run that is not a draft and is not `edited`. `success` and `skipped` pass. Anything else fails. It waits on every job the emitter wrote, including the ones the path filter skipped. |
| `pnpm review:current` | ci-ok | | Same job as `pnpm ci:ok`, as a second step. It does not add a billed minute. That job asks to read issues and pull requests so it can read the review comment. It fails when the latest review comment recorded a sha and the patch changed after that. A rebase that keeps the same patch-id passes. |
| `pnpm check` | | | Local. Lint, format, typecheck, unused, and test. Not a CI job. |

`docs` is an output so a docs-only diff does not flip a language flag. No job is gated only on `docs`. An unknown git range, or a base commit that is not in the clone, fails open: every filtered job runs.

Each Rust crate directory (`packages/*/rs`, including `packages/platform/rs`, and `apps/*/Cargo.toml`) gets a `package.json` whose `lint`, `format`, and `test` scripts call `.helmsman/tools/checks/cargo-package.sh`. Turbo then tracks those packages. `.helmsman/tools/checks/ensure-rust-tasks.sh` writes them. `--check` fails when one is missing, and when a root `platform/` crate is still present.

## Where each guardrail runs

| Guardrail | Pre-commit | CI | Local | What it catches | Known gap |
| --- | --- | --- | --- | --- | --- |
| ESLint | `pnpm lint` with `HELMSMAN_FILTER=ts`, glob on product JS/TS | lint (eslint), when emitted | `pnpm lint` | Lint, including the Helmsman ceilings when the config references the gate | No job when the repo has no TypeScript package and no Helmsman ESLint config. The ESLint package does not install Prettier. |
| Prettier | `pnpm format:check`, filter `ts` | format (prettier) | `pnpm format:check` | Format | Line length stays with the repo formatter. |
| tsc | `pnpm typecheck`. The harness glob includes `eval`. | typecheck (tsc) | `pnpm typecheck` | Type errors | Rust has no separate tsc job. Clippy is the Rust lint. |
| Knip | `pnpm unused` when the glob matches | unused (knip), when wired | `pnpm unused` | Unused files, exports, dependencies | Opt-in. Unwired prints a skip and exits 0. |
| Vitest | `pnpm test`, filter `ts` | test (vitest) | `pnpm test` | Package unit tests | |
| Clippy | `pnpm lint`, filter `rust`, glob `*.rs` | lint (clippy) | `pnpm lint` | Rust lint, file length, the Clippy floor | |
| rustfmt | `pnpm format:check`, filter `rust` | format (rustfmt) | `pnpm format:check` | Rust format | |
| cargo test | `pnpm test`, filter `rust` | test (unit) | `pnpm test` | Rust unit tests: `cargo test --lib --bins`. Each `tests/*.rs` file is a Cargo integration target and runs from `pnpm test:integration` | `--affected` does not rebuild every dependent of a shared crate. A root `Cargo.toml`, `Cargo.lock`, or `rust-toolchain.toml` sets the `rust` path flag so the job runs; Turbo still selects affected packages. |
| Ruff | `pnpm lint`, filter `python` | lint (ruff) | `pnpm lint` | Lint and Ruff format | `pnpm format:check` runs Ruff only when `HELMSMAN_FILTER=python`. The CI format job for Python is the lint job. |
| ty | `pnpm typecheck`, filter `python` | typecheck (ty) | `pnpm typecheck` | Python types | Skips when the project does not name ty. |
| pytest | `pnpm test`, filter `python` | test (pytest) | `pnpm test` | Python unit tests | |
| Integration | Not on the hook | test (integration), when `CI integration` is `yes` | `pnpm test:integration` | Integration | Not inside `pnpm check`. Schema static checks still run in `pnpm setup:check` when this job is absent. |
| E2E smoke | Not on the hook | e2e smoke, when `CI e2e smoke` is `yes` | `pnpm e2e:smoke` | Critical-path smoke | Not inside `pnpm check`. One runner. |
| Prove (web) | Not on the hook | prove (web), when `apps/web` exists and `web` is true | `pnpm prove:web` | A feature diff under `apps/web/` with no Playwright spec, or no prove section | The job does not take screenshots. Evidence stays under `.helmsman/reports/prove/`. |
| Audit | Not on the hook | audit, when a manifest or lockfile changes | `pnpm audit:all` | High advisories, cargo deny, toolchain freshness, secrets | Network. Moved off the hook so the commit stays fast. Not inside `pnpm check`. |
| Setup | When the staged files match the setup glob, including Markdown | setup, when `setup` is true | `pnpm setup:check` | Missing e2e smoke on an app, root `platform/`, a tool tree outside `.helmsman/tools/`, workflow drift | A docs-only pull request skips the CI job. Pre-commit still runs it, so a secret in Markdown is caught at commit. |
| Diff guard | Any staged file except lockfiles | diff guard, when `guard` is true | `pnpm diff:guard` | An added line that suppresses a linter or skips a test | A lockfile-only diff does not run it. |
| Plain language | Same files as the diff guard | same job as the diff guard | `pnpm plain:language` | An added line that brings a nautical term back. `Helmsman`, `.helmsman`, and `docs/renames.md` are allowed | Not inside `pnpm check`. |
| actionlint | When a workflow or action file is staged | lint (actionlint), when `workflows` is true | `pnpm lint:actions` | Invalid workflow syntax | The first run downloads the pinned binary. Not inside `pnpm check`. |
| Secrets | Inside `pnpm setup:check` | setup and audit | `pnpm setup:check` | Tracked secret patterns | gitleaks only when the binary is installed. |
| Shell syntax and silences | Inside `pnpm setup:check`, and `pnpm lint` with filter `bash` | setup | `pnpm lint` | `bash -n`, a silence in tracked source | |
| pnpm lock pin | Inside `pnpm setup:check` | setup | `pnpm setup:check` | `pnpm/action-setup` `version` disagrees with `packageManager` | Generated workflows omit the version pin and read `packageManager`. |
| Harness suite | Not the full trials | test (harness), when `.helmsman/tools/**` or `eval/**` change | `pnpm test` runs `eval/run.sh` once | Rules, gates, graded patches | CI adds flake and three trials. A consumer does not get this job. |
| ci-ok | | ci-ok | `pnpm ci:ok` | A needed job failed or was cancelled | `skipped` is success, so a path filter does not fail the aggregator. |
| Review current | The pull request head | same job as ci-ok | `pnpm review:current` | The review comment's patch is not the current patch | No review line, no pull request, or no GitHub auth outside CI: pass. |

Pre-commit stays on changed files. Every lefthook command has a `glob` or an `exclude`. The glob library does not let `**/*` match a file in the repository root, so each filter lists the root pattern and the nested pattern. Product ESLint, Prettier, Knip, and Vitest exclude `.helmsman/**` and `eval/**` so harness JavaScript does not go through Turbo. The harness typecheck glob is `eval`. Setup matches source, shell, config, and harness paths, and it excludes lockfiles. The diff guard and the plain-language check match every staged file except lockfiles. actionlint matches `.github/workflows/**` and `.github/actions/**`.

A Makefile `check` target is not a CI job. The job runs the pnpm script. If that script is the Makefile target, the Makefile runs because the script says so.

## Minutes

GitHub rounds each job up to the next minute. Wall clock is the longest chain: `changes`, then the slowest job that actually started, then `ci-ok`.

Measured on this repository before the path gates, run 38153980361 (2026-10-11). Wall clock was **2 minutes 7 seconds**. Billed minutes, rounded up:

| Job | Ran | Billed |
| --- | --- | --- |
| changes | 25s | 1 |
| typecheck (tsc) | 22s | 1 |
| test (harness) | 75s | 2 |
| audit | 21s | 1 |
| setup | 25s | 1 |
| diff guard | 22s | 1 |
| eslint-package | 36s | 1 |
| knip-package | 23s | 1 |
| ci-ok | 27s | 1 |
| **Total** | | **10** |

Those jobs started together. `typecheck (tsc)`, `test (harness)`, `audit`, `setup`, and `diff guard` did not wait on `changes`.

After the gates, the ready run 38155555521 (2026-10-11, same pull request) took **2 minutes 2 seconds** of wall clock. `typecheck (tsc)` was skipped because the diff did not touch a TypeScript input. Two draft pushes of this branch concluded `skipped` and billed nothing.

| Job | Ran | Billed |
| --- | --- | --- |
| changes | 26s | 1 |
| lint (actionlint) | 22s | 1 |
| eslint-package | 29s | 1 |
| knip-package | 26s | 1 |
| test (harness) | 69s | 2 |
| audit | 25s | 1 |
| diff guard | 26s | 1 |
| setup | 20s | 1 |
| typecheck (tsc) | skipped | 0 |
| ci-ok | 21s | 1 |
| **Total** | | **10** |

Billed minutes for this diff stayed at 10: actionlint replaced the typecheck minute. Wall clock dropped from 2 minutes 7 seconds to 2 minutes 2 seconds, under the 5 minute ceiling. The harness trials waited for `changes` and were still the long pole.

A docs-only pull request runs `changes`, `diff guard`, and `ci-ok` (about 3 billed minutes). A lockfile bump runs `changes`, `audit`, `setup`, and `ci-ok`. Harness trials run only when `.helmsman/tools/**` or `eval/**` change. actionlint runs only when a workflow or action file changes. A draft push bills nothing. Push is `main` only, so a pull request is not a second run.

A full-stack warm-cache pull request still pays one minute per job that starts. TypeScript, Rust, and Python together, with integration and smoke, can be about 15 billed minutes when every language path matches, because each job still has its own runner. Cold cache is higher. Wall clock stays the slowest job after `changes`. Integration and smoke are the jobs that can push that past 5 minutes. They run only when `Integration` or `E2E smoke` is set and the path filter matches.

This repository emits `changes`, `typecheck (tsc)`, `test (harness)`, `audit`, `setup`, `diff guard`, `eslint-package`, `knip-package`, `lint (actionlint)`, and `ci-ok`. There is no Python, Rust, integration, smoke, ESLint, Prettier, Vitest, or Knip product job.

## This repo, before the split

`languages.sh` delegated to `make check` or a root `check` script and then skipped ESLint, Knip, and the tsc adapter. The setup template had no root `check` script, and `scripts.typecheck` had to start with `tsc` or the adapter did not run. `turbo run typecheck` and `turbo run test` were skipped. `cargo test` and Vitest did not run unless a consumer check already contained them. Python already ran inside `python/check.sh`. `rust-workspace.sh` was fmt and clippy, not `cargo test`. Integration and the e2e smoke were CI-only. `pnpm audit` was CI-only. `cargo audit`, `cargo deny`, and toolchain freshness ran on the hook. The new jobs are the fix: unit tests run in `pnpm test`, and the network audits run in `pnpm audit:all`.
