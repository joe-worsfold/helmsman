---
name: helmsman-setup
description: >-
  Setup a new STAR repo. Copies every Helmsman rule, skill, automation, hook,
  CI gate, and .helmsman/tools into it, writes the pinned root files at the
  publisher's latest stable versions, and writes .helmsman/setup.md. No apps
  and no domains. Use when starting a new STAR project.
user-invocable: true
---

# helmsman-setup

[Helmsman](../../../README.md) steers one stack: STAR (`.cursor/rules/helmsman-star.mdc`). Setup makes a new repo ready for agents on the first prompt. It does not build the product, add an app, add a domain, or choose a test.

Run it in the new project's folder. Install this skill once in `~/.cursor/skills/helmsman-setup/` so it works in any folder.

## Ask

One question at a time. Do not invent an answer.

1. **Helmsman source.** The local Helmsman checkout. Confirm it has `.cursor/rules/helmsman-star.mdc`.
2. **Name.** The product name, lowercase, for `package.json` and `sst.config.ts`.
3. **Issues and CI.** Default `github` for both.
4. **Night run.** May it file issues? May it fix? Both default `no`.

## Resolve versions

Resolve each version from its publisher during this run. Never from memory, and never from what an older repo uses. Record what each command printed.

| Tool | Source |
| --- | --- |
| pnpm | `npm view pnpm dist-tags.latest` |
| Node | `https://nodejs.org/dist/index.json`, newest entry without a `-` |
| turbo, sst, typescript, @types/node, lefthook | `npm view <name> version` |
| Rust | `https://static.rust-lang.org/dist/channel-rust-stable.toml`, `version` under `[pkg.rust]` |
| Python | `https://endoflife.date/api/python.json`, `latest` of the first cycle |

Vite, React, Expo, Playwright, and Maestro are not installed here. The agent that adds `apps/web` or `apps/mobile` resolves them the same way.

## Copy

From the Helmsman source, unchanged:

- `.cursor/rules/`, `.cursor/automations/`, and every `.cursor/skills/helmsman-*/`
- `.helmsman/tools/`, without any `node_modules/` and without `upstream/`
- `lefthook.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`

Not copied: `eval/`, `docs/`, Helmsman's own `README.md`, `CONTEXT.md`, `package.json`, `.helmsman/setup.md` (write a new one), `.helmsman/reports/`, and `.helmsman/tools/upstream/`. The upstream pin stays in the Helmsman repository. A consumer gets Helmsman's wording only. The `Helmsman:` sha in the setup file is the pin. `.helmsman/tools/` is the harness copy. The rest of `.helmsman/` is not.

## Write

Replace each `<…>` with the resolved value. Exact pins, no ranges.

`package.json`:

```json
{
  "name": "<name>",
  "private": true,
  "packageManager": "pnpm@<pnpm>",
  "engines": { "node": ">=<node>" },
  "scripts": {
    "prepare": "lefthook install",
    "build": "turbo run build",
    "lint": "bash .helmsman/tools/checks/pnpm-task.sh lint",
    "format:check": "bash .helmsman/tools/checks/pnpm-task.sh format",
    "typecheck": "bash .helmsman/tools/checks/pnpm-task.sh typecheck",
    "unused": "bash .helmsman/tools/checks/pnpm-task.sh unused",
    "test": "bash .helmsman/tools/checks/pnpm-task.sh test",
    "test:integration": "bash .helmsman/tools/checks/pnpm-task.sh integration",
    "e2e:smoke": "bash .helmsman/tools/checks/pnpm-task.sh smoke",
    "audit:all": "bash .helmsman/tools/checks/pnpm-task.sh audit",
    "setup:check": "bash .helmsman/tools/checks/pnpm-task.sh setup",
    "diff:guard": "bash .helmsman/tools/checks/pnpm-task.sh diff-guard",
    "plain:language": "bash .helmsman/tools/checks/pnpm-task.sh plain",
    "review:current": "bash .helmsman/tools/checks/review-current.sh",
    "fix:forward": "bash .helmsman/tools/checks/fix-forward.sh",
    "ci:paths": "bash .helmsman/tools/checks/ci-paths.sh",
    "ci:ok": "bash .helmsman/tools/checks/ci-ok.sh",
    "eslint:package": "node .helmsman/tools/eslint/check.mjs",
    "knip:package": "node .helmsman/tools/knip/check.mjs",
    "check": "bash .helmsman/tools/checks/pnpm-task.sh check",
    "generate": "turbo run generate"
  },
  "devDependencies": {
    "@types/node": "<types-node>",
    "lefthook": "<lefthook>",
    "sst": "<sst>",
    "turbo": "<turbo>",
    "typescript": "<typescript>"
  }
}
```

`pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
  - "packages/*/rs"
  - "packages/*/ts"
  - "packages/*/py"
allowBuilds:
  lefthook: false
```

`prepare` installs the git hook, so lefthook's own install script is denied. pnpm fails an install while any build script is unapproved.

`turbo.json`:

```json
{
  "$schema": "https://turborepo.com/schema.json",
  "globalDependencies": ["Cargo.lock", "pnpm-lock.yaml", "uv.lock"],
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "generate": { "dependsOn": ["^generate"] },
    "lint": { "dependsOn": ["generate"], "outputs": [] },
    "format": { "dependsOn": ["generate"], "outputs": [] },
    "typecheck": { "dependsOn": ["generate", "^build"], "outputs": [] },
    "test": { "dependsOn": ["generate", "^build"], "outputs": [] },
    "unused": { "outputs": [] }
  }
}
```

Empty `outputs` cache the task result without copying Rust `target/`. rust-cache stores `target/`. A missing lockfile in `globalDependencies` is fine. The root script is `format:check`. The Turbo task name is `format`.

No `Cargo.toml`. Cargo fails on a workspace with no members, and on a member glob that matches nothing. The change that adds the first Rust crate writes it, as `helmsman-star.mdc` says. `.helmsman/tools/checks/ensure-rust-tasks.sh` then writes `package.json` beside each `packages/*/rs` crate, including `packages/platform/rs`, and beside `apps/*/Cargo.toml`. Do not add a root `platform` workspace entry.

A TypeScript package script block:

```json
{
  "scripts": {
    "lint": "eslint .",
    "format": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  }
}
```

A Python package script block:

```json
{
  "scripts": {
    "lint": "ruff check . && ruff format --check .",
    "typecheck": "ty check",
    "test": "pytest"
  }
}
```

The harness is not a workspace package. `pnpm-workspace.yaml` globs and Turborepo's package discovery do not match a dot-directory. The root scripts call `.helmsman/tools/checks/pnpm-task.sh`. Pre-commit calls those same scripts. A consumer `package.json` that still names `tools/helmsman` is rewritten by the migration below.

Do not copy a workflow by hand. When CI is `github`, `.helmsman/tools/ci/emit.sh` writes `.github/workflows/helmsman.yml` for the languages and features this repo has. A later edit to the workflow is drift: `emit.sh --check` fails until you run the emitter again. The workflow triggers on pull request `opened`, `ready_for_review`, `synchronize`, `reopened`, and `edited`, and on push to `main`. Every job is skipped while the pull request is a draft. `edited` skips every job except `prove (web)`, and that job runs only when the body changed and `apps/web` exists. Wall clock for a pull request stays under 5 minutes: jobs run in parallel after `changes`, and a job starts only when its path output is true.

`pnpm lint:actions` runs [actionlint](https://github.com/rhysd/actionlint) v1.7.12. `.helmsman/tools/checks/actionlint.sh` installs it with the official download script pinned to commit `914e7df21a07ef503a81201c76d2b11c789d3fca`. The first local run, and the setup step below, download the binary into the user cache. The CI job calls the same script and passes that pin. Lefthook runs it only when `.github/workflows/**` or `.github/actions/**` is staged.

`rust-toolchain.toml`:

```toml
[toolchain]
channel = "<rust>"
components = ["clippy", "rustfmt"]
profile = "minimal"
```

`.nvmrc` holds `<node>`. Do not write `.node-version`. If `.node-version` is present and `.nvmrc` is not, write `.nvmrc` with that same version and delete `.node-version` in the same change, so one file is the pin. `.python-version` holds `<python>`. A root `pyproject.toml` and its uv workspace (`members = ["packages/*/py"]`) are written by the first domain that needs Python, not here.

`sst.config.ts`:

```ts
/// <reference path="./.sst/platform/config.d.ts" />
export default $config({
  app(input) {
    return { name: "<name>", home: "aws", removal: input?.stage === "production" ? "retain" : "remove" };
  },
  async run() {},
});
```

`.gitignore`, in this order: `.helmsman/*`, `!.helmsman/setup.md`, `!.helmsman/tools/`, `!.helmsman/tools/**`, then `node_modules/`, `target/`, `.sst/`, `.turbo/`, `.venv/`, and `dist/`. Reports stay ignored. The harness is tracked. Git does not list files inside an ignored directory, so the tools exceptions are required. The last matching pattern wins, so `node_modules/` stays after the tools exception and a package install under the harness is not committed.

`.helmsman/setup.md`:

```markdown
# Setup

Helmsman: <helmsman commit sha>
Languages: rust, typescript
API: HTTP JSON, MCP
Surfaces: none
E2E smoke: none
Watch: none
Integration: none
CI integration: no
CI e2e smoke: no
Issues: <issues>
CI: <ci>
File issues: <yes|no>
Fix: <yes|no>
Upstream PR: no
Correct PR: no
Review model: none
```

`Surfaces` stays `none` until an app exists. The change that adds `apps/web` sets `Surfaces`, `E2E smoke`, and `Watch` to its Playwright commands. The change that adds `apps/mobile` does the same for Maestro. The change that adds the first SurrealDB schema sets `Integration`.

`CI integration` and `CI e2e smoke` only control whether the workflow emits those jobs. A missing line means no. `Integration` and `E2E smoke` stay the local commands. Re-setup writes each key as `yes` when that local command is not `none`, and `no` when it is `none`, so a repo that already emits the job keeps it. When you set `E2E smoke` or `Integration` to a command that should fail the pull request, set the matching CI key to `yes`.

## Review before ready

Every agent PR finishes in order: (1) run helmsman-review on the full diff against base, (2) fix every Blocker, unjustified Judo, High, and Medium finding, (3) prove it locally with the pre-commit hook and `pnpm check`, (4) post the review as a pull request comment saying what was fixed and what remains Fix forward or Nit and why, (5) mark ready only after that comment. Marking ready is when CI runs. Do not merge until that run is green. The review catches what the standards missed, including when the change was written to them.

Agents work in draft. Prove the change locally with `pnpm check` and the pre-commit hook before pushing. CI runs when the pull request is marked ready, and on push to main. A draft pull request does not run CI.

`.helmsman/tools/checks/install-review-ready.sh` appends that section to `AGENTS.md` when the heading is missing, and appends the draft sentence when the heading is already there without it. A second run changes nothing.

## Run

In order. Each must pass before the next.

1. `git init` when the folder is not a repo.
2. The installed `node -v` and `pnpm -v` match the pins. `.helmsman/tools/checks/toolchain-latest.sh` fails otherwise. If they do not match, say which and stop. Installing a tool version on the machine is the user's call.
3. `pnpm install`. It writes `pnpm-lock.yaml`, and `prepare` installs the lefthook pre-commit hook.
4. `.helmsman/tools/ci/emit.sh` when CI is `github`.
5. `pnpm lint:actions`. It installs actionlint on the first run and lints `.github/workflows` when that directory exists.
6. `pnpm exec lefthook run pre-commit --force`. It runs every Helmsman gate the hook runs; without `--force` lefthook skips them when nothing is staged.
7. Commit: `chore(setup): setup STAR with Helmsman <short sha>`. The hook runs again; never bypass it.

## Stop

Report what ran and each resolved version. If a command fails, stop there and name it. Do not skip a step, do not lower a pin to make a command pass, and do not start feature work.

## Re-setup

An existing STAR repo takes the Copy list again. Do not replace its apps, domains, or lockfiles. Do not copy `.helmsman/tools/upstream/`. Copy `.helmsman/tools/` first (no `node_modules/`, no `upstream/`), then from the target repo root run:

```bash
.helmsman/tools/checks/migrate-layout.sh
```

That script is the move. A checkout of this repository can run it in the target without copying first:

```bash
bash /path/to/helmsman/.helmsman/tools/checks/migrate-layout.sh
```

It moves `tools/helmsman/` to `.helmsman/tools/` when the new directory is absent. When the new directory is already there, it keeps those files, moves across any file that exists only in the old tree, and removes `tools/helmsman/`. It rewrites remaining `tools/helmsman` path references in lefthook, workflows, root ESLint and Knip configs, `package.json` scripts, Makefiles, and rules. It does not rewrite this skill, the migration script, its bats test, lockfiles, or the upstream snapshots. It un-ignores `.helmsman/tools/` when `.gitignore` ignores `.helmsman/*`, and it leaves `.helmsman/reports/` ignored. It appends `## Review before ready` to `AGENTS.md` when that heading is missing, appends the draft CI sentence when that heading is already there without it, and it sets the root `package.json` scripts CI calls (`lint`, `lint:actions`, `format:check`, `typecheck`, `unused`, `test`, `test:integration`, `e2e:smoke`, `audit:all`, `setup:check`, `diff:guard`, `plain:language`, `review:current`, `fix:forward`, `ci:paths`, `ci:ok`, `check`). `build` and `generate` are left as they are. It then runs `.helmsman/tools/checks/migrate-names.sh`, which renames old skill folders, rule files, setup keys, lefthook commands, workflow job names, and pnpm script keys. It adds `Correct PR: no` and `Review model: none` when those lines are missing. A second run of either script changes nothing.

If a root `platform/` crate exists, move it to `packages/platform/rs` and drop the `platform` workspace entry. Do not recreate root `platform/`. Then, from the target repo root:

```bash
.helmsman/tools/checks/ensure-rust-tasks.sh
.helmsman/tools/ci/emit.sh
```

`ensure-rust-tasks.sh` writes the Turbo scripts beside each crate. `emit.sh` rewrites the workflow for the languages and features the repo has. Do not hand-edit that workflow.

If the repo has `.node-version` and no `.nvmrc`, write `.nvmrc` with the same version and delete `.node-version`. Point its Helmsman workflow at `node-version-file: .nvmrc`. Do not change an existing `.nvmrc`. Upstream changes reach that repo only after they have landed here and you re-setup. `helmsman-upstream` does not run there: the pin is not in the tree.
