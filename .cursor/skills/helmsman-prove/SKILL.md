---
name: helmsman-prove
description: >-
  Prove one claim on the same surface, with a baseline and a treatment.
  Use when a bug fix or a feature needs evidence a person can re-run.
user-invocable: true
---

# helmsman-prove

Prove one claim. Use the same surface the report used. Record a baseline, then the treatment, then one verdict: `verified`, `not verified`, or `inconclusive`.

A unit test that never touched the surface is not a pass. Say what you could not run.

## Evidence

Keep evidence under `.helmsman/reports/prove/<pr>/`. `<pr>` is the pull request number, or a short slug. The directory is gitignored. Do not commit it.

| Phase | What it is |
| --- | --- |
| `baseline` | The surface before the change. |
| `treatment` | The same surface after the change. |

For a UI change, save a Playwright screenshot for each phase. An optional trace is `trace.zip` in that phase directory. Point the screenshot and trace paths at that directory. List the paths in the pull request section `## How to verify locally`.

For a backend change, record the command with `.helmsman/tools/checks/prove-record.sh`:

```bash
.helmsman/tools/checks/prove-record.sh --pr 12 --phase baseline -- pnpm test
.helmsman/tools/checks/prove-record.sh --pr 12 --phase treatment -- pnpm test
```

The script writes `stdout.txt`, `stderr.txt`, and `exit-code.txt`. Name the command and the exit code in `## How to verify locally`.

When `GITHUB_ACTIONS` is `true`, the script prints `helmsman: prove capture skipped in CI.` and does not run the command. CI does not take screenshots.

## Web features

A feature pull request whose diff touches `apps/web/` includes at least one Playwright spec in that diff. The spec is an added or modified `*.spec` or `*.test` file under `apps/web/`, or a file under `e2e/` or `playwright/`. A deleted spec does not count. `## How to verify locally` or `## Prove` names a file under `.helmsman/reports/prove/<pr>/baseline/` or `treatment/`. The template sentence alone does not pass. `pnpm prove:web` checks that. It does not run Playwright. A title `feat!:` or `feat(web)!:` is a feature.

The check runs in CI only when `apps/web` exists, and only when the web path flag is true. A push skips it. A diff that is not a feature does not fail it. Locally, with no pull request body, the spec is still required and the section is checked on the pull request.

## Sources

cursor/plugins@`11713c683fe4add4fd403ea880580abbc9e0875f` `cursor-team-kit/skills/verify-this/SKILL.md`. MIT. A local browser harness and a local terminal harness are reference only. They are not adopted skills.
