# tsc adapter

Optional typecheck for a TypeScript repo that does not use ESLint. A tsc-only app does not need this. Its gate is `make web-check`: `tsc --noEmit`, the `web-theme-check` script, and generated-type drift. Stories stay out of that `tsc` project.

This script does not install ESLint or Knip. Knip stays opt-in (`.helmsman/tools/knip`).

Languages runs this file by path. The product `scripts.typecheck` project stays the scan. A broad TypeScript `include` can see a dot-directory; this adapter does not point `tsc` at `.helmsman/tools`. There is no TypeScript project there.

## Opt in

Set `scripts.typecheck` to a command that starts with `tsc`:

```json
{ "scripts": { "typecheck": "tsc --noEmit" } }
```

When the repo has no Makefile `check` target and no `web-check` target, `.helmsman/tools/checks/languages.sh` runs `.helmsman/tools/tsc/check.sh`. That runs `scripts.typecheck` with no shell. `make web-check` still owns `tsc` when that target exists, and this script is not run.

A missing `tsc` binary fails the commit. The adapter prepends `node_modules/.bin` to `PATH` so a local TypeScript install is the binary it runs. It does not install one, and it does not install ESLint.

Run it directly only when you want this command to be the typecheck:

```bash
.helmsman/tools/tsc/check.sh
```

With no `scripts.typecheck`, that direct run is `tsc --noEmit --pretty false`.
