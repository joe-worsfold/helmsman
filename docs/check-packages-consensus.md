# STAR gate consensus

Shareable gates for a Helmsman STAR consumer. The coverage map is [coverage.md](coverage.md).

## What owns each gate

| Gate | Package or check | When it runs |
| --- | --- | --- |
| Setup | `.helmsman/tools/checks/setup-check.sh` | Always. An app surface with no e2e smoke command fails. |
| Diff guard | `.helmsman/tools/checks/diff-guard.sh` | Always. Added-line suppressions and skipped tests fail. |
| Plain language | `.helmsman/tools/checks/plain-language.sh` | Added lines only. Same files as the diff guard. |
| Languages | root `pnpm lint`, `pnpm format:check`, `pnpm typecheck`, `pnpm test` | The emitter writes one job per tool the repo actually has. Each job calls that script. |
| pnpm lock | `.helmsman/tools/checks/pnpm-lock.sh` | When `packageManager` is pnpm. |
| Web drift | `.helmsman/tools/checks/web-drift.sh` | When a Makefile names generated paths. |
| Rust | `.helmsman/tools/clippy`, `rustfmt`, `deny`, `rust-workspace.sh` | When `Cargo.toml` exists. |
| TypeScript lint | `.helmsman/tools/eslint` | When a root config references the Helmsman gate. |
| tsc | `.helmsman/tools/tsc` | When `scripts.typecheck` starts with `tsc` and no consumer check ran. |
| Python | `.helmsman/tools/python` | When `pyproject.toml` or `uv.lock` exists. |
| Surreal / Postgres / DynamoDB / OpenSearch | Matching `.helmsman/tools/*` | When that stack's files are tracked. |
| Expo | `.helmsman/tools/expo` | Doctor is opt-in. Maestro is the e2e smoke, not `check`. |
| Secrets | `.helmsman/tools/secrets` | Always on tracked files. |

`lefthook.yml` and the emitted workflow call the same root pnpm scripts. A missing binary fails the commit. No matching files: that stack's job is not emitted. The map is [guardrails.md](guardrails.md).

## Out of scope for STAR

Go, Nest, Terraform, Checkov, TFLint, Terrascan, and Trivy. Infrastructure is SST. Policy and SAST for application code stay on the language gates and the secret scan until a STAR consumer adds a named tool.

## Thresholds

`.helmsman/tools/metrics/README.md` is the map. A number lives in the language pack that runs. Do not copy a threshold into a second file. An existing consumer `[workspace.lints]` or lint config stays; the floor does not overwrite it.
