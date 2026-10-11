# @helmsman/knip

Dead-code gate for JavaScript and TypeScript. Rust does not use Knip. A tsc-only app does not use Knip until it opts in. Adding it is a new package, not a copy of an existing config. It can sit beside `make web-check`. Copying this directory does not turn it on.

[Knip 6](https://knip.dev) already fails the process when it reports an issue (`--max-issues` defaults to 0). This file turns **import cycles** into errors as well. Knip's own default leaves cycles out of the report and, when they are included, marks them as warnings. A warning does not fail the commit. `rules.cycles` is `error` here.

`nsExports` and `nsTypes` stay excluded. Knip leaves them out unless you add them. `enumMembers` and `namespaceMembers` stay in, because they are part of Knip's default report. Remove one from `include` only when that report is noise you have read.

Build output is ignored: `dist/`, `build/`, `coverage/`, `cdk.out/`, `.next/`. The gate's own trees are ignored too (`.helmsman/tools/eslint`, `.helmsman/tools/knip`, `.helmsman/tools/checks`, `.helmsman/tools/clippy`, `.helmsman/tools/python`, `.helmsman/tools/ci`), so vendoring this repo's `packages/` does not fail the product on the gate's fixtures. Knip prints a hint when an ignore matches nothing. That hint does not fail the commit. `languages.sh` passes `--no-config-hints` so the log stays the issues.

## Wire it

Install Knip in the consumer repo (Node 26 or newer):

```bash
pnpm add -D knip@6
```

Copy `knip.jsonc` to the repo root. `.helmsman/tools/checks/languages.sh` runs `npx --no-install knip` when any of these is present:

- a root `knip.json`, `knip.jsonc`, `knip.ts`, `knip.js`, `knip.config.ts`, or `knip.config.js`
- a `knip` object in `package.json`
- a `knip` dependency, with no config yet (Knip's defaults; cycles do not fail until this config is copied)

A copy at `.helmsman/tools/knip/knip.jsonc` or `node_modules/@helmsman/knip/knip.jsonc` is not enough. The script says Knip is not wired and does not fail the commit. A configured Knip that is not installed fails the commit. `make web-check` stays the consumer's command. This script does not run it.

Pre-commit and CI call `pnpm unused` when Knip is wired. Setup runs `.helmsman/tools/ci/emit.sh`. Copy `lefthook.yml`. Do not copy a workflow by hand.

```bash
node .helmsman/tools/knip/check.mjs
```

That check runs this config on three fixtures: a used module, an unused file, and an import cycle.

## Inventory

Readable public TypeScript repos do not use Knip. A tsc-only app has no Knip config; the note is in `.helmsman/tools/eslint/README.md`. The issue list is Knip's default from [webpro-nl/knip](https://github.com/webpro-nl/knip) 6.38, plus cycles. See that ESLint note for the lint inventory.
