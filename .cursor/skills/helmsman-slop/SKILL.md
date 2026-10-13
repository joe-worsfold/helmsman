---
name: helmsman-slop
description: >-
  Helmsman slop. Score the slop in eligible production code.
  Baseline censuses the tree. Delta reads the branch after a baseline exists.
  Works standalone, with no setup file and no report-write script.
  File GitHub issues only when the setup file allows it.
  Does not edit product code. Explicit invoke only.
user-invocable: true
disable-model-invocation: true
---

# helmsman-slop

[Helmsman](../../../README.md) is a set of rules and checks for agent-written code. This skill measures unnecessary code. [helmsman-readiness](../helmsman-readiness/SKILL.md) is the readiness score. [helmsman-security](../helmsman-security/SKILL.md) records each security finding and how to fix it. [helmsman-fix-forward](../helmsman-fix-forward/SKILL.md) edits one finding. [helmsman-delivery](../helmsman-delivery/SKILL.md) measures recent delivery cost.

Do not edit product code. Do not commit the reports unless asked. Filing an issue is allowed only when `.helmsman/setup.md` says `File issues: yes`. No setup file means do not file. Say that issues were not filed. Still write the report in the reply.

The skill works when it is copied alone. It does not need Helmsman init, `setup.md`, or `.helmsman/tools/checks/report-write.sh` to answer. Adopting repos keep their own rules. A missing report script skips the file write. It does not skip the answer.

A missing gate is a harness miss. Report it on the Readiness, not here. A finding is a defect that is in the tree now.

The priority scale is P0–P4. There is no P5. P0 blocks. P1–P4 are fix-forward.

Security findings and performance findings stay on the P0–P4 list. They do not enter the Slop Density Index.

## Mode

Two modes. Say which one you ran, and why.

1. **Baseline.** Census eligible production sources in the whole tree. This is the first measure of a repo.
2. **Delta.** `merge-base(default, HEAD)..HEAD`, plus uncommitted production changes. This is a later run on a feature branch.

Choose in this order:

1. The user asked for baseline or delta. Use that.
2. No prior `.helmsman/reports/**/slop.md`, and no other slop report the user pointed at. A skills-only install with no Helmsman reports is this case. Use **baseline**.
3. A baseline already exists and the current branch is a feature branch (not the default branch). Use **delta**.
4. Otherwise use **baseline**.

An empty delta is a result. Say it in the first lines. Do not print an SDI. Do not treat "nothing to measure" as 0%. Copied Helmsman skills in the uncommitted diff are excluded, so they do not fill an empty delta.

```text
Scope: delta
Delta: empty. merge-base(default, HEAD)..HEAD has no eligible production changes, and there is no uncommitted production diff. SDI is unscored. An empty delta is not 0%.
```

## Eligible sources

Application and library code a person maintains.

Exclude, and list the exclusion on the coverage line:

- tests (`*.test.*`, `*.spec.*`, `**/__tests__/**`, `**/e2e/**`, `**/cypress/**`, end-to-end and integration tests)
- generated code (`dist/`, `build/`, `coverage/`, files marked generated)
- declarations (`*.d.ts`)
- fixtures
- vendored code and `node_modules`, including the pinned upstream snapshot at `.helmsman/tools/upstream/`
- copied Helmsman skills and tooling (`.cursor/skills/helmsman-*`, `.cursor/rules/helmsman*`, `.claude/skills/helmsman-*`, `.claude/rules/helmsman*`, `.helmsman/`, and a vendored Helmsman package tree this repo does not maintain as its product)

In the Helmsman repository those skill and package trees are the product. Still exclude tests, generated code, declarations, and fixtures there.

If a directory was not enumerated, it stays out of the percentage. Record it under excluded or not inspected. Coverage is the share of eligible files this run actually read.

```text
SDI: N% — band
Coverage: N% of eligible production sources
Excluded: tests, generated code, declarations, fixtures, vendored code, Helmsman tooling
```

## Execution

1. **Mode.** Apply the switch above. Name the default branch and the merge-base when the mode is delta.
2. **Topology.** Read the workspace manifest, package or crate manifests, container files, CI workflows, application entry points, domain code, and infrastructure. Name what this repository actually has. Do not assume a layout it does not use.
3. **Trace.** Follow ingress (request handlers, workers, UI) down to repository and integration code. Search; do not guess.
4. **Verify.** Drop the candidate if an existing control already rejects it, or if the pattern is required. Name the control you checked. Before calling code unused, grep the whole tree for the name, including tests, fixtures, config, and string or dynamic references. A search that misses a string reference is not unused.
5. **Count.** Score the index from the denominators below. An unscored part stays unscored. List every file that entered `bad`.
6. **Readiness.** Follow helmsman-readiness. Record capability, adapter, and evidence. Put the level and the score out of 5 at the top of the slop report. Do not require Helmsman filenames to pass a readiness row.
7. **Report.** Show the report in the reply. Write `.helmsman/reports/<UTC>/slop.md` only when `.helmsman/tools/checks/report-write.sh` is in the tree and `.helmsman/tools/checks/report-write.sh slop.md` exits 0. If the script is missing, skip the file. Use the same `HELMSMAN_REPORT_STAMP` as the readiness when this run is the nightly. Exit 10 means chat only. A write needs the path gitignored and one of `HELMSMAN_WRITE_REPORTS=1`, `CURSOR_AGENT=1`, `GITHUB_ACTIONS=true`, or `CI=true`. Lead with the readiness score, then the index and the scorecard.
8. **Issues.** If the setup file is missing, or `File issues` is not `yes`, stop after the report and say issues were not filed. If it is `yes` and `Issues` is `github`, file one GitHub issue per P0–P4 finding that is not already open. Search open issues for the same path and title before creating one. Label them `helmsman`. If `Issues` is not `github`, say so and do not invent another tracker client.

### Already in force — do not re-report as missing

Find the controls this repository actually runs. A native command or CI job counts. A Helmsman script counts when a hook or CI runs it. A copied script that nothing runs does not. Record each control you checked. Do not report a class as missing when a control already fails the commit or the pull request for it.

| Control | What to look for |
| --- | --- |
| Secret scanning | A pull-request security job, pre-commit, gitleaks, or secretlint. `.helmsman/tools/secrets/check.sh` when `languages.sh` runs it. |
| High production dependency advisories | The dependency audit in the pull-request security job. |
| New lint suppressions, type suppressions, skipped tests | The diff guard the hook or CI runs. `.helmsman/tools/checks/diff-guard.sh` when that is the command. |
| Unused files and dependencies | Knip or the repo's dead-code check, when that command runs. A copied `.helmsman/tools/knip` with no config and no run is not this control. |
| Illegal imports of repo-root scripts | An import-boundary test or lint rule that fails the commit or the pull request. |
| Infrastructure policy | The repo's infrastructure policy job, when one runs. |
| Lint, types, and pure unit | The pull-request jobs, `pnpm` or `make` scripts those jobs run, or `make check` / `make web-check` / a root `package.json` `check` script. |
| Integration | The integration job against the real local service, or `integration.sh` when CI runs it. |

A vulnerable pin, a secret, or a layer leak that those controls did not catch is still a finding. Say which control you checked and why it missed.

### Required, not slop

- Schema parse and null checks on request bodies, query parameters, and stored rows.
- Repository factories and data-transfer mappers. They are the storage and wire boundary.
- A comment that says why.
- An injection class the stack cannot express. Name the client you looked for.
- Pagination on a single-item read.
- A check the type does not already make dead. If the type allows null, the null check is required.

## Categories

### A. Slop

These five parts are the index.

- **Over-abstraction.** Wrapper functions, factory interfaces, or layers around a standard-library call that has one caller.
- **Defensive paranoia.** A dead `catch` or `else`, or a null check on a value the type already excludes. Required checks do not count. See the second pass below.
- **Duplicate helpers.** A second or later copy of the same helper, shown by a clone or a symbol comparison. Knip finding unused code is not a second copy.
- **Comment bloat.** A docstring that restates the function name. List each one. A count with no list is unscored.
- **Dead fallbacks.** The same dead `catch` or `else` as defensive paranoia. Do not count the branch twice.

### B. Security and infrastructure

P0–P4 only. Not the index.

- **Secrets.** Hardcoded API keys, token secrets, private keys, or credentials in config, scripts, or tests.
- **Common vulnerability classes.** Command injection, server-side request forgery, broken auth, permissive cross-origin policy, unsafe deserialization. A query-language injection only if a client for that language exists. Leaks belong to [helmsman-security](../helmsman-security/SKILL.md). On a slop-only run, a leak you already proved stays in this report. On a run that also runs security, point at `.helmsman/reports/<UTC>/security.md` and do not file it from here.
- **Containers and CI.** Unpinned image bases, running as root, missing multi-stage builds, exposed non-application ports, unpinned CI actions.

### C. Architecture

- **Layer leaks.** Datastore queries or domain writes inside UI components, request handlers, or middleware. Handlers stay thin; repositories own storage.
- **Lane leaks.** In STAR: a domain importing a domain, an `api` or `mcp` domain file importing two domains, a write to a table not in `owns`, a read outside `owns` and `reads`, a domain rule in an app, or business logic in `packages/platform/rs`.
- **Cycles.** Circular module imports, or unrelated modules that cannot change apart.
- **State.** Unmanaged global mutation, a multi-item write with no transaction boundary, or a raw stack returned to a client.

### D. Performance

P0–P4 only. Not the index.

- **Data.** N+1 queries, unindexed filters, list endpoints with no pagination.
- **Leaks.** Unclosed clients, unhandled rejections, unbounded growth in a long-running loop.

### E. Correctness

P0–P4 only. Not the index. State the load you assumed, from the README or the deploy config.

- **Bug.** A wrong result on an edge: empty, zero, the last item, rounding, or a time zone. A fix applied in one caller while the shared function stays broken.
- **Scale.** Fine for one user, wrong at the load you named: a check-then-write race, per-process state that must be shared, unbounded growth. An N+1 or a missing index already listed under Performance is not filed again. Point at that row.
- **Missing test.** A pure function with no unit test, or a user-visible journey with no end-to-end protected test. Side-effecting code does not get a unit test. The unit test covers a pure function completely. Not a coverage number.

Say which parts you did not read. That line is not a zero.

## Priority

- **P0 — Emergency.** Exposed secret, exploitable remote code execution or injection, active data loss, or a broken deploy. Block.
- **P1 — This sprint.** Architectural leak on a hot path, N+1 on a hot path, auth edge case that fails open, unpinned base image or action. Fix-forward.
- **P2 — Next sprint.** Wrapper chains, duplicate helpers, cyclomatic complexity above 15, missing index, swallowed exception. Fix-forward.
- **P3 — Backlog.** Dead paths, unused fallbacks, small duplication, missing validation on a non-critical endpoint. Fix-forward.
- **P4 — Cosmetic.** Redundant docstrings, noisy comments, file-structure noise. Fix-forward.

## Removing slop

Slop is code the change did not need. The index counts it. Delete it only when the deletion keeps the behavior.

What counts, and which index part it feeds:

- A comment that restates the name, or that the surrounding file does not use. Comment noise.
- A check or a `catch` on a path the type or the caller already makes safe. Defensive paranoia. A check on untrusted input stays.
- A cast to `any` whose only job is to silence the type checker. It is a wrapper around the type, so it counts as abstraction inflation.
- Nesting that an early return would delete. Complexity mass.
- A second helper, a forwarding wrapper, or a dead fallback. Utility sprawl, abstraction inflation, or dead fallbacks. Do not count one branch twice.

How to remove it:

- Keep the behavior, unless the line is a clear bug. A bug is a correctness finding, not a silent cleanup.
- Delete the extra code. Do not replace it with a new wrapper.
- One finding is one edit. Do not restyle the file around it.
- The next slop score drops only when the next run's `bad` count drops. Say which part lost the row.

Prose cleanup is not this score. [helmsman-writing](../../rules/helmsman-writing.mdc) owns that.

## Slop Density Index

The index is 0–100%. It is a count, not an impression. Security and performance do not enter it.

Five parts, 20 points each. Record `bad` and `inspected` with the denominators in the table. Each bad row needs a path and a line. A percentage without that list is not reviewable. List every file that entered `bad` once, under the table.

`points = 20 × bad / inspected`

If you did not enumerate a part, that part is **unscored**. Leave its denominator blank. Its 20 points leave the index denominator. Do not write 0 for "I did not look." A scored part with `inspected` of 0 is unscored.

`SDI = 100 × points earned / points available`

Truncate the displayed percent toward zero. Three parts scored, 18 points earned out of 60 available, is 30%. Say which parts were unscored.

| Part | Bad | Inspected |
| --- | --- | --- |
| Abstraction inflation | Verified wrappers that only forward a call | Functions in the eligible set |
| Complexity mass | Cyclomatic complexity inside functions over 15 | Total measured cyclomatic complexity of the eligible set |
| Defensive paranoia | Verified dead `catch` / `else`, or a null check on a value the type already excludes, after the second pass | Candidate guards in the eligible set, after the required-check exclusion |
| Comment noise | Docstrings that restate the name, each one listed with path and line | Documentation comments in the eligible set |
| Utility sprawl | Second and later copies of the same helper, from a clone or symbol comparison | Helper implementations in the eligible set |

Repository factories, wire mappers, and checks on untrusted input stay out of `bad`. A comment that says why stays out.

### Complexity threshold

One number owns the index and P2: **cyclomatic complexity above 15**.

A function at 15 is not bad. A function above 15 contributes its whole cyclomatic complexity to `bad`, and its path and line to the list. `inspected` is the sum of cyclomatic complexity for every measured function in the eligible set, including those at or under 15.

Name the tool that counted (ESLint `complexity`, a decision-point count, or another named counter).

- If the tool's rule is a **warn** at 15, say `warn threshold, not a pull-request gate`. Do not describe that warn as a gate the pull request already fails.
- If the tool **fails the commit or the pull request** at a stricter number, say `stricter gate`. Helmsman's opt-in ESLint package fails the commit at cyclomatic complexity 10 (`complexity` error in `.helmsman/tools/eslint/index.js`). That gate is not the index. The index and P2 stay at 15, so they agree. Functions above 10 and at or below 15 can fail that stricter gate and still stay out of complexity mass.

Do not use a second index cutoff such as "above 10 and more than 50 lines". Length has its own owners. It is not this part.

### Defensive paranoia, second pass

1. First pass: list candidate guards in the eligible set (`catch`, `else`, and null checks), with path and line.
2. Second pass: mark required, and drop from `bad`, any candidate that is a check on a request body, query parameter, stored row, or other untrusted input, or a null check on a value the type still allows.
3. `inspected` is the candidate count after that exclusion. `bad` is the verified dead remainder. Each bad row keeps path and line.

A text search alone is the first pass. It is not the score.

### Bands

| SDI | Band | Reading |
| --- | --- | --- |
| 0–15% | Clean | Low density. |
| 16–35% | Moderate | Occasional cleanup. Fix-forward. |
| 36–60% | High | Review is slowing. The shape of the change is eroding. |
| 61–100% | Critical | Block further feature work until a refactor. |

## Report template

Write the reply in this shape. One section per finding, P0 first. If a priority has no findings, say so. Do not invent one. On an empty delta, stop after the header. Do not fill the index with zeros. The Trend table reads every prior `.helmsman/reports/**/slop.md`, oldest first, and this run is the last row. A first run has one row. Do not invent a past score.

```markdown
# Slop

**Readiness:** Level N of 5. Score X.X / 5.
**Date:** YYYY-MM-DD
**Scope:** baseline | delta
**Why this mode:** first measure, no prior slop.md | feature branch after a baseline | user asked
**Delta:** <range and file count, or empty — SDI unscored, not 0%>
**Slop Density Index:** N% — Clean | Moderate | High | Critical | unscored
**Coverage:** N% of eligible production sources
**Excluded:** tests, generated code, declarations, fixtures, vendored code, Helmsman tooling
**Load:** the load you assumed, and where you read it
**Not read:** the parts this run did not open
**Parts scored:** K of 5

## Trend

| Date | Slop Density Index | Band |
| --- | --- | --- |
| YYYY-MM-DD | N% | Clean |

| Part | Bad | Inspected | Points | Note |
| ---- | --- | --------- | ------ | ---- |
| Abstraction inflation | n | n | n / 20 | path:line list, or unscored |
| Complexity mass | n | n | n / 20 | tool, cyclomatic > 15, warn or stricter gate |
| Defensive paranoia | n | n | n / 20 | second pass excluded required checks |
| Comment noise | n | n | n / 20 | each docstring path:line, or unscored |
| Utility sprawl | n | n | n / 20 | clone or symbol comparison, or unscored |

**Files in bad:** every path that contributed to a bad count, once.

## Executive Summary & Scorecard

- **P0 Critical:** N
- **P1 High:** N
- **P2 Medium:** N
- **P3 Tech Debt:** N
- **P4 Cosmetic:** N

Two sentences: the worst real defect, and whether the slop is local or repeated. P0 blocks. The rest is fix-forward.

## Prioritized Action Items (P0 -> P4)

### P# — Short issue title

- **Priority:** P0 | P1 | P2 | P3 | P4
- **Category:** Slop | Security | Architecture | Performance | Infra | Correctness
- **Location:** `path/to/file.ext:line`
- **Impact:** What breaks, slows down, or risks security if left unfixed.
- **Current Defect (Evidence):** fenced snippet from the repo
- **Why this is real:** Control checked, and why it does not already catch this.
- **Remediation:** Smallest change that removes the defect. No patch.
- **Acceptance:** The command or assertion that fails before the fix and passes after. No exploit.
- **Out of scope:** What the fix must not widen into.
```

This repository pins the index arithmetic in `eval/readiness.mjs`. An adopting repo does not need that file. Follow this skill.

## Issue body

The finding section above is the issue body. The title is the heading without the hashes. Shape and filing rules: [docs/issue-body.md](../../../docs/issue-body.md).

When the setup file is missing, or `File issues` is not `yes`, do not file. Say issues were not filed. The default is `no`.

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`) `skills/ponytail-audit/SKILL.md` (bug, scale, missing test; grep before unused). cursor/plugins@`11713c683fe4add4fd403ea880580abbc9e0875f` `cursor-team-kit/skills/deslop/SKILL.md` (what to delete, and that the deletion keeps the behavior). MIT. The Slop Density Index stays Helmsman's count. The other team-kit skills next to deslop (pull-request tidy, review-and-ship, weekly review) do not define this score, so they are not adopted. verify-this is adopted as helmsman-prove. The CI loop skills are adopted as the getting-CI-green section. Neither defines the slop score.
