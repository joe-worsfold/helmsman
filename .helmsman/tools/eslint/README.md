# @helmsman/eslint

Flat ESLint gate for JavaScript and TypeScript. It fails the commit on `eval`, a skipped or focused test, and the length and complexity ceilings below. The type-checked config also fails on `any` and on a promise that nothing handles.

This is a backstop, not a style guide. Lower a number to tighten. Do not raise one so a commit passes. A split made only to silence the gate still fails the standard: delete branches and reuse first.

## Ceilings

| Rule | Ceiling | Why this number |
| --- | --- | --- |
| `complexity` | 10 | [SonarJS cyclomatic complexity](https://sonarsource.github.io/rspec/#/rspec/S1541/javascript) defaults to 10. ESLint's own default is 20. [Airbnb](https://github.com/airbnb/javascript/blob/master/packages/eslint-config-airbnb-base/rules/best-practices.js) records 20 and leaves the rule off. |
| `sonarjs/cognitive-complexity` | 15 | [SonarJS cognitive complexity](https://sonarsource.github.io/rspec/#/rspec/S3776/javascript) defaults to 15. `.helmsman/tools/clippy/clippy.toml` uses the same ceiling. |
| `max-lines` | 300 code lines | ESLint's default max. Blanks and comments do not count, which is the option set [Airbnb records](https://github.com/airbnb/javascript/blob/master/packages/eslint-config-airbnb-base/rules/style.js) while leaving the rule off. |
| `max-lines` on tests | 500 code lines | Not a third-party default. Pins accumulate in one file. The source ceiling stays 300. |
| `max-lines-per-function` | 50 code lines | ESLint's default. Same skip flags as Airbnb's recorded options. Off for test files, because a `describe` callback is one function around many pins. Complexity still applies inside each test. |
| `max-params` | 3 | ESLint's default. A fourth parameter is an options object. |
| `max-depth` | 4 | ESLint's default. |
| `max-nested-callbacks` | 4 | ESLint's default is 10, which does not stop a callback pyramid. 4 matches `max-depth`. |
| `max-statements` | off | ESLint's default of 10 overlaps the function-length and complexity ceilings and fires on straight-line code. |

`eqeqeq` is error, with `== null` allowed. That is Airbnb's option, and it checks both `null` and `undefined`.

## What else fails

- `no-eval`, `no-implied-eval`, and `no-new-func`.
- Skipped or focused tests: `it`, `test`, `describe`, `context`, and `suite` called with `skip` or `only`, plus the `x` and `f` prefixes (`xit`, `xdescribe`, `xtest`, `fit`, `fdescribe`, `ftest`) and `pending()`.
- A blanket disable comment (`unicorn/no-abusive-` plus `eslint` and `disable`). A line comment cannot blanket-disable a file. Naming the rules is still a suppression. Added suppressions fail `.helmsman/tools/checks/diff-guard.sh`.
- `throw "string"` (`no-throw-literal`). `throw Error("x")` without `new` (`unicorn/throw-new-error`).
- An object with a `then` method (`unicorn/no-thenable`).
- An import specifier `scripts` or `scripts/...` (repo-root `scripts/`). A relative path such as `../src/scripts/migrate.js` is not this rule. Knip owns import cycles.

`eslint:recommended` from `@eslint/js` is the base, so unused locals and undeclared names fail too.

## Not in this gate

- **Prettier.** Line length stays with whatever formatter the repo already runs. This gate does not turn on `max-len` and does not add Prettier.
- **`eslint-plugin-unicorn` recommended** (315 rules in v76). Three bug rules are on. The rest are style.
- **SonarJS recommended** (230 rules in v4). Only cognitive complexity is on. Cyclomatic complexity is ESLint's `complexity` rule, so it is not counted twice.
- **`eslint-plugin-import-x`.** Circular imports fail Knip (`.helmsman/tools/knip`). This file does not take the import plugin's preset.
- **A generated exception.** Some Nest apps turn `@typescript-eslint/no-explicit-any` off. `typescript.js` leaves it on.

## TypeScript

`typescript.js` spreads this file, then [`typescript-eslint` `recommendedTypeChecked`](https://typescript-eslint.io/users/configs) (v8) on `*.ts`, `*.tsx`, `*.mts`, and `*.cts`. That config errors on `any`, a floating promise, and the other unsafe calls in that preset. It needs `typescript` `>=4.8.4 <6.1.0` and a `tsconfig*.json`. `projectService: true` looks for that config from the repo root. Do not set `tsconfigRootDir` to this package's directory.

JavaScript files stay on the syntax gate when you use `typescript.js`.

## A tsc-only consumer

A consumer whose web gate is `make web-check` may have no ESLint, Knip, Biome, or Prettier config. That gate is:

- `tsc --noEmit`, with `strict`, `noUnusedLocals`, and `noUnusedParameters`. Story files are excluded from that project.
- the `web-theme-check` script
- generated-types and OpenAPI drift checks

Keep that command. Do not install ESLint: there is no config, and `languages.sh` does not install it. This package sits beside `make web-check` and does not run until a root ESLint config references the Helmsman gate. `languages.sh` does not invoke `make web-check`.

`.helmsman/tools/tsc/check.sh` is the optional typecheck adapter for a repo that opts in with `scripts.typecheck`. A tsc-only app does not opt in. Knip stays a new optional package (`.helmsman/tools/knip`), not a mirror of an existing config. The pnpm Action version check is `.helmsman/tools/checks/pnpm-lock.sh`, not this package.

## Inventory

The ceilings come from the projects named in the table above, not from copying an app that has no ESLint config. Readable public TypeScript repos use ESLint 8 and `@typescript-eslint/recommended`. None of them set a complexity ceiling, Knip, SonarJS, or Unicorn.

Highly starred configs that were read and not copied in whole: [typescript-eslint](https://github.com/typescript-eslint/typescript-eslint) (recommended type-checked), [eslint-plugin-sonarjs](https://github.com/SonarSource/eslint-plugin-sonarjs), [eslint-plugin-unicorn](https://github.com/sindresorhus/eslint-plugin-unicorn), [Airbnb's base config](https://github.com/airbnb/javascript) (the recorded numbers; the rules stay off there), [Knip](https://github.com/webpro-nl/knip). [@antfu/eslint-config](https://github.com/antfu/eslint-config) was compared and not used: it is one author's preset, and this gate keeps the ceilings explicit.

## Wire it

Skip this install when the repo has no ESLint config. A tsc-only app does. From the consumer repo root, with Node 26 or newer, and only after the root config below exists:

```bash
pnpm add -D eslint@10 @eslint/js@10 eslint-plugin-sonarjs@4 eslint-plugin-unicorn@76 globals@17 typescript-eslint@8
pnpm add -D typescript@6
```

`typescript` is only required for `typescript.js`. The peer range stops before 6.1 because `typescript-eslint` 8.71 does. This package's own TypeScript devDependency is the newest stable release inside that peer. The Helmsman repo's typecheck uses the publisher's latest stable TypeScript, which is a later major. `.helmsman/tools/checks/toolchain-latest.sh` keeps those two apart.

The metric map is `.helmsman/tools/metrics/README.md`. The numbers live in this package, not in that map.

Copy this directory to `.helmsman/tools/eslint/` in the consumer, or depend on the folder. ESLint 10 walks dot-directories (`minimatch` `dot: true`), so a root `eslint .` still lints these files. That copy does not turn the gate on. Opt in with a root `eslint.config.js`, `eslint.config.mjs`, `eslint.config.cjs`, or `eslint.config.ts` that mentions `helmsman` (the spread below). `.helmsman/tools/checks/languages.sh` runs that file only. A `tsconfig` without that root config stays on `tsc --noEmit`. A Makefile `check` target still replaces this script's ESLint run; `make web-check` does not, and this script does not call `web-check`.

```js
import helmsman from "./.helmsman/tools/eslint/typescript.js";

export default [
  ...helmsman,
  { rules: { complexity: ["error", 8] } },
];
```

Use `index.js` when the repo has no `tsconfig`. A later rules block is how you tighten without editing the package. The script's `-c` path ignores that file, so a root config has to be the one the script runs.

Pre-commit and CI call `pnpm lint`. Setup runs `.helmsman/tools/ci/emit.sh` so the consumer workflow is generated, not copied. The hook fails when this gate fails.

```bash
node .helmsman/tools/eslint/check.mjs
```

That check writes a throwaway project and asserts the ceilings. It is the passing test for this package.
