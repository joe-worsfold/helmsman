# Helmsman

Helmsman is a set of rules, skills, and checks for agent-written code.

It is for two kinds of work:

- A new or existing [STAR](.cursor/rules/helmsman-star.mdc) repo (SurrealDB, TypeScript, Agent-first, Rust) that should use the same commands locally and in CI.
- An existing repo that only needs a score. Copy one skill. You do not have to install the rest.

The lane rules are [`.cursor/rules/helmsman-star.mdc`](.cursor/rules/helmsman-star.mdc). Claims in that rule that still need a check against current docs are [docs/star-verify.md](docs/star-verify.md).

## What a setup copies

A full setup copies:

- `.cursor/rules/`
- `.cursor/skills/helmsman-*/`
- `.cursor/automations/`
- `lefthook.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.helmsman/tools/`, without `upstream/` and without `node_modules/`

It then runs `.helmsman/tools/claude/emit.sh`, so Claude Code reads the same rules and skills from `.claude/` (see [docs/claude-code.md](docs/claude-code.md)). It writes root files pinned to the publisher's current stable versions, writes `.helmsman/setup.md`, and generates `.github/workflows/helmsman.yml`. It does not add an app or a domain.

It does not copy `eval/`, `docs/`, this README, or `.helmsman/tools/upstream/`.

## Prerequisites

Node 26.12.0, matching `.nvmrc` and `engines`. pnpm 12 through corepack. [bats](https://github.com/bats-core/bats-core) for the shell tests.

```bash
pnpm install --frozen-lockfile
```

## Quick start

Install the setup skill once, as a user skill:

```bash
mkdir -p ~/.cursor/skills && cp -R .cursor/skills/helmsman-setup ~/.cursor/skills/
```

For Claude Code, copy it to `~/.claude/skills/` instead.

Open an empty project folder in Cursor or Claude Code and run `/helmsman-setup`. It asks for the Helmsman checkout, the product name, and whether the night run may file issues or edit code. Both of those default to no.

## Commands

Local hooks and CI call the same root scripts. `pnpm check` is the local set: lint, format, typecheck, unused, and test. It does not run integration, end-to-end smoke, audit, the plain-language check, or the review-current check.

| Script | What it does |
| --- | --- |
| `pnpm lint` | Lint for the languages this repo has |
| `pnpm format:check` | Format check |
| `pnpm typecheck` | Typecheck |
| `pnpm unused` | Unused files, exports, and dependencies |
| `pnpm test` | Unit tests, and this repo's eval when you are in the Helmsman repo |
| `pnpm test:integration` | The `Integration` command in `.helmsman/setup.md` |
| `pnpm e2e:smoke` | The `E2E smoke` command in `.helmsman/setup.md` |
| `pnpm audit:all` | Dependency audit, secret scan, and toolchain freshness |
| `pnpm setup:check` | Setup file, tool layout, upstream pin, and workflow drift |
| `pnpm diff:guard` | Fail an added line that skips a test or suppresses a linter |
| `pnpm plain:language` | Fail an added line that brings a nautical term back |
| `pnpm review:current` | Fail when the review comment's patch is not the pull request patch |
| `pnpm lint:actions` | Lint GitHub workflow files |
| `pnpm fix:forward` | Open a fix-forward issue when GitHub auth allows it |
| `pnpm ci:paths` | List which language jobs this diff should run |
| `pnpm ci:ok` | Fail when a needed CI job failed or was cancelled |
| `pnpm check` | Lint, format, typecheck, unused, and test |

The job map, the path gates, and the minute estimate are [docs/guardrails.md](docs/guardrails.md). What fails a commit in another repo is [docs/coverage.md](docs/coverage.md).

## Set it up in a repo

Run `/helmsman-setup` in the target repo. For a repo that already has Helmsman, copy `.helmsman/tools/` again (no `node_modules/`, no `upstream/`), then from the target root run:

```bash
.helmsman/tools/checks/migrate-layout.sh
.helmsman/tools/checks/ensure-rust-tasks.sh
.helmsman/tools/ci/emit.sh
.helmsman/tools/claude/emit.sh
```

`migrate-layout.sh` moves `tools/helmsman/` to `.helmsman/tools/` when that old tree is still there. It then runs `migrate-names.sh`, which renames old paths, skills, rule files, lefthook commands, workflow job names, and pnpm scripts. A second run changes nothing. `emit.sh` rewrites the workflow. Do not hand-edit that workflow.

You can also copy one skill and leave the repo's own rules in place. The list of what to copy is [docs/standalone-skills.md](docs/standalone-skills.md).

## Upstream skills

Helmsman keeps its own wording. The files under `.helmsman/tools/upstream/` are verbatim snapshots of the texts those words came from. They are not loaded as rules or skills. Setup does not copy them.

The pin is `.helmsman/tools/upstream/upstream.json`: repo, ref, commit, file hashes, and the Helmsman files that adopted each source. `pnpm setup:check` fails if a snapshot file was edited or if an adopted path is missing. `.helmsman/tools/upstream/sync.sh` downloads a newer ref. It does not edit Helmsman skills. The weekly automation `helmsman-upstream` drafts those edits in this repository only.

## Names

Older repos used nautical names for these same checks. The old-to-new list is [docs/renames.md](docs/renames.md). Re-running setup renames them. The plain-language check blocks those old words on added lines. It allows the brand name Helmsman, the `.helmsman/` directory, and `docs/renames.md`.

## Parts

| Part | What it does |
| --- | --- |
| Readiness | Scores how ready a repo is for agentic coding: whether its checks can actually fail a commit or a pull request |
| Delivery | Delivery, failure, restore, and rework |
| Slop | The slop score for unnecessary code, and how to remove that code without changing behavior |
| Security | Security findings and how to fix them |
| Fix forward | Works through one fix-forward issue or finding |
| Setup | Installs Helmsman and writes `.helmsman/setup.md` |
| Tests | Chooses end-to-end smoke, integration, or unit before a test exists |
| Review | Reviews a pull request. A large diff gets a second pass on a different model family |
| Correct | Turns a repeated agent mistake into a check |
| Decisions | One row per decision on a long run |
| Bug | Reproduce a bug on the same surface, then fix it |
| Prove | One claim, a baseline and a treatment, and the evidence under `.helmsman/reports/prove/` |
| Performance | Measure a baseline, then change it |
| Writing | Plain English for markdown, pull request bodies, and commits |
| Checklist | Approve or Request changes. Findings are Blocker, Judo, High, Medium, Low, Fix forward, or Nit |
| Structure | Optional strict pass. Invoke it by name |
| Shortcuts | Ledger of `shortcut:` comments |
| Upstream watch | Weekly, on this repo only |

The short glossary is [CONTEXT.md](CONTEXT.md). The loop for a morning read is [docs/morning-report.md](docs/morning-report.md).

## Product loop

1. Each pull request: [helmsman-review](.cursor/automations/helmsman-review.md). Advisory. It does not block the merge by itself.
2. Overnight, [helmsman-nightly](.cursor/automations/helmsman-nightly.md): readiness, then the slop score, then security. Reports stay gitignored. The nightly fixer is off until `.helmsman/setup.md` says `Nightly fix: yes`. When it is on, the night opens one small draft pull request per fix, up to `Nightly max PRs`, `Nightly max tokens`, and `Nightly max minutes`. It does not merge.
3. GitHub issues only when `.helmsman/setup.md` says `File issues: yes`. The body is [docs/issue-body.md](docs/issue-body.md). A Fix forward finding uses `pnpm fix:forward`, which does nothing without GitHub auth.
4. Fix forward works through one finding, and only when `Fix: yes` or `Nightly fix: yes`.
5. Weekly, on this repository only: [helmsman-upstream](.cursor/automations/helmsman-upstream.md). It opens a pull request only when `Upstream PR: yes`.

Agents work in draft. Prove the change with `pnpm check` and the pre-commit hook. Post the review. Then mark the pull request ready. CI runs when it is marked ready, and on push to `main`. A draft does not run CI.

## Licence and third-party notices

MIT. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY.md](THIRD_PARTY.md). Helmsman uses those sources and keeps its own wording.

| Source | What we took |
| --- | --- |
| [Ponytail](https://github.com/DietrichGebert/ponytail) v5.1.0, Dietrich Gebert | The reuse ladder, the reach list, the caller grep, and the `shortcut:` ceiling (older comments say `ponytail:`). Trust boundaries, data loss, security, and accessibility stay in scope. |
| [Thermo-nuclear code quality review](https://github.com/cursor/plugins/blob/11713c683fe4add4fd403ea880580abbc9e0875f/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md) and [thermo-nuclear review](https://github.com/cursor/plugins/blob/11713c683fe4add4fd403ea880580abbc9e0875f/thermos/skills/thermo-nuclear-review/SKILL.md) | The structural questions, and the developer-setup and feature-flag checks. A structural miss is Request changes. |
| [Factory Agent Readiness](https://docs.factory.ai/agent-readiness/overview) | The five readiness levels. A check counts only when a command or CI job fails the commit or the pull request. |
| [DORA](https://dora.dev/guides/dora-metrics/) | Deployment frequency, lead time, change failure, and restore time. A number you cannot show stays unknown. |
| [Software Engineering at Google, ch. 11](https://abseil.io/resources/swe-book/html/ch11.html) | If you liked it, put a test on it. Test size is how the test runs. |
| [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) | Many fast unit tests, fewer journeys. A person should be able to watch the journey. |
| [Write tests. Not too many. Mostly integration.](https://kentcdodds.com/blog/write-tests) | Confidence comes from tests that resemble use. The unit test stays on pure functions. |
| [Characterization tests](https://wiki.c2.com/?CharacterizationTest) | A protected test records behavior that already passes. |
| [pstack](https://github.com/cursor/plugins/tree/978ca6e9c0e012047cd5058b8e829240336e704e/pstack) by Lauren Tan | Repeated mistakes become checks, a review records the patch, a second model family on a large diff, how far a proof got, the pull request sections, and plain English. Helmsman keeps its own wording. |
| [OWASP Top 10:2025](https://owasp.org/Top10/2025/) and [OWASP ASVS 5.0.0](https://asvs.dev/v5.0.0/) | Risk names, and what a passing security check looks like. A tool cannot claim full coverage. |

## Out of scope

Anything outside STAR is out of scope: Go, Nest, Terraform, PHP, Ruby, and .NET. Infrastructure is SST. Trivy is not wired. There is no Next.js rule. Compose is not started from pre-commit. The integration command owns that. Length and complexity limits live in `.helmsman/tools/metrics`.

## Eval

[eval/README.md](eval/README.md) checks that the written bar can fail a change. It does not replace the end-to-end smoke or the unit tests in a product repo.

```bash
./eval/run.sh
./eval/trials.sh
```
