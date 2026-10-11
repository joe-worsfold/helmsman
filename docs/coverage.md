# Coverage

What Helmsman runs, what fails the commit, and what the consumer command already owns. Read this with [the morning report](morning-report.md).

Three test layers stay separate: a watchable end-to-end suite (e2e smoke), integration of code and infrastructure (integration), and pure unit tests (unit test). Test choice selects the layer. A protected test is a passing test that stays tied.

The readiness scores **capability**, not these filenames. Each row is capability (`pass`, `fail`, `unknown`, `n/a`), adapter (`helmsman`, `native`, `absent`), and the file or job that fails the commit or the pull request. Adapter is not the score. A copied script nothing runs does not pass. A native command or CI job that does run passes with adapter `native`.

End-to-end is three facts. Only the pre-merge smoke gates level 1.

| Fact | Capability passes when | Helmsman adapter, when it runs | Level |
| --- | --- | --- | --- |
| Local | A person can run and watch the journey (Cypress, Playwright, Maestro, `pnpm test:e2e`, or `Watch`). | `Watch` in `.helmsman/setup.md`. | 1, inside the 80% count. Does not gate level 1 alone. |
| Pre-merge smoke | A critical-path smoke fails the pull request when it runs. Core journeys, target under about 5 minutes, preferably parallel. A path filter or a `run-e2e` label counts when that smoke can still fail the pull request. The exhaustive suite does not. | `.helmsman/tools/checks/e2e-smoke.sh` in the pull-request job when that command is the smoke. | 1 gate. Required on its own. |
| Post-deploy / full | The exhaustive suite runs after a non-production deploy, on main, or nightly. | The deploy, main, or nightly workflow calls it. | 4. Does not earn or erase level 1, and does not replace the smoke. |

Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly.

A sole Cypress, Playwright, or Maestro setup is the journey. The duplicate-runner fail applies only when a Helmsman journey command already runs and the repo added a second runner. No app: local and the pre-merge smoke pass without a setup file.

`.helmsman/tools/checks/languages.sh` is the language and infra runner when lefthook and CI call it. It does not start a database. It is the adapter for lint, types, and policy when it is what runs. A pull-request `lint`, `typecheck`, unit, or integration job is the same capability with adapter `native`.

Owners passes on `.github/CODEOWNERS` (or an equivalent file) that names owners. Branch protection is a separate unknown when the clone cannot show it.

## Delegate

`.helmsman/tools/checks/delegate-gate.sh` runs the consumer gate before any Helmsman linter.

| Present | What runs | Exit |
| --- | --- | --- |
| Makefile `check` | `make check` | 0 when it passes |
| No `check` target, root `package.json` script `check` | `pnpm check` when the repo uses pnpm. `npm run check` only when there is no pnpm lock or field and no yarn lock. `yarn run check` is a legacy fallback. | 11 when it passes. 11 is success. |
| Neither | nothing | 10 |

`make check` wins when both exist. The delegate does not re-run ESLint, Knip, or the tsc adapter. `make web-check` stays the consumer's command. Helmsman does not invoke it.

A `package.json` check that does not call `cargo fmt` or clippy does not count as the Rust format and lint gate. `.helmsman/tools/checks/rust-workspace.sh --force` runs those tools then. It does not run `cargo test` again. `cargo audit` and `cargo deny check advisories bans sources` still run whenever `Cargo.toml` exists.

`--probe` looks only at Makefile `check` and `lint`. A package script is not a probe hit, because that script often omits fmt and clippy.

## Stack

| Stack | Package | Fails the commit | Opt-in or skip | Consumer owns it when |
| --- | --- | --- | --- | --- |
| Rust fmt, clippy, file length | `.helmsman/tools/clippy`, `.helmsman/tools/rustfmt`, `.helmsman/tools/checks/rust-workspace.sh` | `Cargo.toml` and the consumer recipe omits `cargo fmt` and clippy. The floor is 15 / 50 / 6 / 250. A higher number fails. A lower number stays. | An existing `clippy.toml` or lint table is not rewritten. | `make check`, `make lint`, or a check script that already runs `cargo fmt` or clippy. |
| Rust advisories | `.helmsman/tools/deny` | `cargo audit` and `cargo deny check advisories bans sources` when `Cargo.toml` exists. A missing binary fails. | | Still runs after the consumer check. |
| TypeScript / JavaScript lint | `.helmsman/tools/eslint` | Only when a root config references the Helmsman gate, ESLint is installed, and no consumer check ran. | No config: ESLint is not installed. A config that does not reference the gate: not installed. | `make check`, `make web-check`, or `package.json` `check`. |
| tsc | `.helmsman/tools/tsc` | `scripts.typecheck` starts with `tsc`, and both `make web-check` and the consumer check are absent. | Otherwise skipped. | `make web-check` or the consumer check. |
| Knip | `.helmsman/tools/knip` | A root config, a `knip` object, or the dependency, and no consumer check. | Not wired until one of those exists. | The consumer check. |
| Python | `.helmsman/tools/python` | `pyproject.toml` or `uv.lock`. `uv` missing: fail. Stale `uv.lock`: fail. `ruff check` and `ruff format --check`. Ceilings above 10 / 6 / 50: fail. `ty` when the project names it. `pytest` when tests are tracked. | No ruff config: `.helmsman/tools/python/ruff.toml` is the config. A project config stays. `ty` not named: skip with a message. | The consumer recipe mentions `ruff`, `pytest`, or `ty`. |
| SurrealDB | `.helmsman/tools/surreal` | Compose names SurrealDB and no `.surql` is tracked. A schema file is empty. Schema exists and `Integration` is missing or `none`. | No schema and no compose service: skip. | The Integration command. This package does not apply schema and does not start compose. |
| Postgres | `.helmsman/tools/postgres` | A sqlfluff, atlas, or dbmate config is present and the binary is missing. `sqlfluff lint` fails when sqlfluff is installed. | Tracked SQL, no binary, and no config: skip with a message. Not a pass. | The Integration command. Migrate status is not run here. |
| DynamoDB | `.helmsman/tools/dynamodb` | Tracked table JSON is invalid or lacks `TableName`, `AttributeDefinitions`, `KeySchema`, or `Resources`. | SST or CDK mentions DynamoDB and no JSON: skip. The source is the definition. | |
| OpenSearch | `.helmsman/tools/opensearch` | Tracked JSON is invalid. A mapping file has no `mappings` object. | No matching JSON: skip. | |
| Expo / React Native | `.helmsman/tools/expo` | Does not fail the default gate. | `HELMSMAN_EXPO_DOCTOR=1` runs doctor. Maestro is not run here. | E2E smoke: `mobile:e2e` or a `maestro` command. One runner. Not inside `pnpm check`. |
| Secrets | `.helmsman/tools/secrets` | Built-in patterns on tracked files. `gitleaks` when installed. `.gitleaks.toml` without the binary: fail. A secretlint config without the binary: fail. | No gitleaks: the built-in scan still runs, and the log says gitleaks is absent. | |
| Silences | `.helmsman/tools/checks/no-silences.sh` | Tracked source contains a lint silence, a skipped or focused test, or `--no-verify`. | | `make check` already runs a `no-silences` script. |
| Shell syntax | `.helmsman/tools/checks/bash-n.sh` | `bash -n` fails on a tracked `.sh` file. | No shell scripts: skip. | |
| pnpm version | `.helmsman/tools/checks/pnpm-lock.sh` | `pnpm/action-setup` version disagrees with `packageManager`. | No `package.json`, or `packageManager` is not pnpm: skip. | |
| Toolchain freshness | `.helmsman/tools/checks/toolchain-latest.sh` | A Helmsman-owned Node, TypeScript, `@types/node`, or pnpm 12 version is not the publisher's latest stable. Versions are read from the npm dist-tags and the Node release index during the run. `.nvmrc` is the Node pin. | The tree does not own `@helmsman/eslint`: skip. A TypeScript peer range caps that package at the newest stable release inside the range. | |
| Upstream pin | `.helmsman/tools/checks/upstream.sh` | A file under `.helmsman/tools/upstream/` does not match `upstream.json`. | No `upstream.json`: skip. Setup does not copy that directory. | |
| Ship / integration / e2e smoke | `.helmsman/tools/checks/setup-check.sh`, `integration.sh`, `e2e-smoke.sh` | When these scripts are installed, an app surface with no e2e smoke command fails the commit. Integration and the e2e smoke run in CI. | `Surfaces: none`: both commands are `none`. `Integration: none`: integration skips. | A native journey, integration job, or local command is the readiness capability when these scripts are absent. Do not add a second runner beside a Helmsman journey that already runs. |
| Make snippet | `.helmsman/tools/make/helmsman.mk` | Defines target `helmsman` only. | Include it. It does not define `check`. | A consumer `check` target. |

## CI weight

`.helmsman/tools/ci/emit.sh` writes `.github/workflows/helmsman.yml`. `.helmsman/tools/checks/ci-paths.sh` tells that workflow which language jobs to run. The ESLint and Knip package jobs stay skipped when the diff does not touch them. An unknown git range runs every filtered job. Audit runs when a manifest or lockfile changes. Setup runs when harness, workflow, toolchain, or source files change. The diff guard runs unless the diff is only lockfiles. A draft pull request skips every job. Push is `main` only. The script-to-job map and the minute estimate are in [guardrails.md](guardrails.md). Before changing a toolchain version, resolve the publisher's latest stable in that session. Do not invent one from memory. Setup writes `.nvmrc`, not `.node-version`. The emitted workflow reads `node-version-file: .nvmrc`.

## Not this map

PHP, Ruby, .NET, Go, Nest, and Terraform. Terrascan and Trivy. A Next.js rule. Starting compose from the commit hook.
