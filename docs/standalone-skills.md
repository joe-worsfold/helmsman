# Standalone readiness and slop

Copy the skills. Keep the repo's own engineering standards. The copied skills are Helmsman's own wording. The pinned upstream snapshot stays in the Helmsman repository under `.helmsman/tools/upstream/` and is not part of a copy. Helmsman skills score native evidence: a command or a CI job that fails the commit or the pull request. They do not require Helmsman init, and they do not replace the repo's bar.

## Skills-only copy checklist

Copy into `<your-repo>/.cursor/skills/` for Cursor, or `<your-repo>/.claude/skills/` for Claude Code. The `SKILL.md` format is the same. Do not replace the repo's other skills or rules. Open the repo and invoke the skill by name. A skill does not load on its own.

| Copy | When |
| --- | --- |
| `.cursor/skills/helmsman-readiness/` | Readiness. Score capability, adapter, and evidence. |
| `.cursor/skills/helmsman-slop/` | Slop. Census or delta of eligible production sources. |
| `.cursor/skills/helmsman-security/` | Optional. Leaks and how to fix them. |
| `.cursor/skills/helmsman-review/` and `.cursor/rules/helmsman-checklist.mdc` | Optional. A review pass. The checklist owns Approve or Request changes. It does not load on its own. |
| `.cursor/skills/helmsman-shortcuts/` | Optional. Ledger of `shortcut:` comments. Reads only. |
| `.cursor/skills/helmsman-structure/` | Optional. Strict structural pass. Invoke by name. It does not load on its own. |

### Rules, copied lightly

The repo's own always-on standard stays the bar.

| Rule | Safe to copy? |
| --- | --- |
| `.cursor/rules/helmsman-checklist.mdc` | With review, when you want Approve or Request changes. It does not demand a setup file. |
| `.cursor/rules/helmsman-tests.mdc` | Optional, on test and end-to-end files. It follows the runner the repo already has. |
| `.cursor/rules/helmsman-standards.mdc` | Only beside the repo's own always-on rule, and only when you want that bar. It does not stop feature work because Helmsman files are missing. |
| Language packs (`helmsman-typescript.mdc` and the rest) | Only when that language's Helmsman gate is installed. Otherwise leave them. |

### Skip

These belong to a full setup. A skills-only copy leaves them out.

- `helmsman-setup`, and creating `.helmsman/setup.md`
- `.cursor/automations/helmsman-nightly.md`
- `.helmsman/tools/checks/report-write.sh` and the rest of `.helmsman/tools/`, including `.helmsman/tools/upstream/`
- `.helmsman/tools/ci/emit.sh`, `lefthook.yml`, and the check scripts (`e2e-smoke.sh`, `integration.sh`, `languages.sh`, `setup-check.sh`)
- A full `.helmsman` init

A missing `setup.md`, `Watch` line, `Integration` line, `e2e-smoke.sh`, `integration.sh`, or `languages.sh` is normal. Native evidence still scores: `pnpm test:e2e`, Playwright, Cypress, Maestro, a pull-request smoke job, `make check`, or the repo's lint and typecheck jobs.

End-to-end stays three facts: local, pre-merge critical smoke, and post-deploy or full. Only the pre-merge smoke gates level 1. A path filter or a `run-e2e` label counts when that smoke can still fail the pull request. The exhaustive suite does not replace the smoke.

## What works without init

- No `.helmsman/setup.md`.
- No `.helmsman/tools/checks/e2e-smoke.sh`, `integration.sh`, `languages.sh`, or `report-write.sh`.
- The chat reply is the report.
- A file under `.helmsman/reports/` is written only when `report-write.sh` is in the tree and its write gate allows it. A missing script skips the file. It does not skip the answer.
- GitHub issues are not filed unless a later setup file says `File issues: yes`.

## Readiness

Score capability. Record the adapter beside it. Name the evidence.

| Column | Values |
| --- | --- |
| Capability | `pass`, `fail`, `unknown`, `n/a`. This is the score. |
| Adapter | `helmsman`, `native`, `absent`. This is not the score. Missing adapter does not fail the row. |
| Evidence | The file or job that fails the commit or the pull request. |

A native command counts: a GitHub Actions job, a `pnpm` or `make` script that hook or CI runs, `.github/hooks/pre-commit`, or the repo's ESLint, `tsc`, or test gate. Helmsman scripts are the adapter when a hook or CI actually runs them. A copied package that nothing runs does not pass.

End-to-end is three facts:

| Fact | What a pass is | Level |
| --- | --- | --- |
| Local | A person can run and watch the journey. | 1. Does not gate level 1 by itself. |
| Pre-merge smoke | A critical-path smoke fails the pull request when it runs. Core journeys, target under about 5 minutes, preferably parallel. A path filter or a `run-e2e` label counts when that smoke can still fail the pull request. | 1 gate. The exhaustive suite does not pass this row. |
| Post-deploy / full | The exhaustive suite runs after a non-production deploy, on main, or nightly. | 4. Its own row. It does not earn level 1 and does not replace the smoke. |

Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly.

Print all three. Do not collapse them into one "missing end-to-end" line when a local command or a post-deploy job exists.

A sole Cypress, Playwright, or Maestro setup is the journey. A second runner fails the rule only when Helmsman already runs one journey and the repo added another.

Owners passes when `.github/CODEOWNERS` (or an equivalent file) names owners. Branch protection, required reviewers, and required status checks are a separate line. Unknown protection does not change Owners.

## Slop

| Situation | Mode |
| --- | --- |
| No prior `.helmsman/reports/**/slop.md`, a skills-only install, or the user asked for a baseline | Baseline. Census eligible production sources in the whole tree. |
| A baseline exists and the branch is a feature branch, or the user asked for a delta | Delta. `merge-base(default, HEAD)..HEAD` plus uncommitted production changes. |

If the delta has no eligible production changes, say the delta is empty. Do not print an index of 0%.

Eligible sources are application and library code people maintain. Exclude tests, generated code, declarations, fixtures, vendored code, and copied Helmsman skills and tooling.

```text
SDI: N% — band
Coverage: N% of eligible production sources
Excluded: tests, generated code, declarations, fixtures, vendored code, Helmsman tooling
```

Cyclomatic complexity above 15 is the only index threshold, and it is the same number as P2. Name the tool that counted. A warn at 15 is not a pull-request gate. Each bad row needs a path and a line. Unscored parts leave the denominator. Security and performance stay on P0–P4.

## Full setup later

`helmsman-setup` can write `.helmsman/setup.md` and you can vendor the check packages. The capability rules stay the same. A new Helmsman script awards a row only when a hook or CI runs it. Native jobs you already have keep adapter `native`.
