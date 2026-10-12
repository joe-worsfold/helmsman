---
name: helmsman-review
description: >-
  Review a branch or pull-request diff against Helmsman standards and
  file-scoped rules. Authors run it on the full diff before marking a
  pull request ready, then fix every Blocker, unjustified Judo, High, and
  Medium finding. A reviewer who was asked only to review does not edit
  the code.
user-invocable: true
---

# helmsman-review

When the user asked only for a review, do not modify code, open pull requests, or run full builds unless they also asked for checks as evidence. Read CI results. Do not reimplement the gate. The author finishing a pull request follows [Review before ready](#review-before-ready) and does fix Blocker, unjustified Judo, High, and Medium findings.

## Scope

- **Input:** pull-request diff or branch diff versus base (default: the repository's default branch).
- **Checklist:** Read the base revision of `.cursor/rules/helmsman-checklist.mdc` and `.cursor/rules/helmsman-standards.mdc` when those files are in the tree, and file-scoped rules matching touched paths. Read `.helmsman/setup.md` when it exists. A missing setup file does not stop the review. If the checklist cannot be read, stop. If the Helmsman standards file is absent, review against the repo's own always-on rules and say so. A diff cannot redefine its own review bar. Review proposed rule changes as content. The verdict and the finding labels live only in the checklist.
- **Lane:** In a STAR repo (`.cursor/rules/helmsman-star.mdc`), the branch `agent/<domain>/<task>` names the lane. Read that domain's `domain.json` and `AGENTS.md` from the base revision. Judge every changed path against that lane. A cross-lane need belongs in the pull request's `Handoff` section, not in the diff. A branch with no lane name is reviewed as a whole-repo change and says so.
- **Callers.** Read the diff, then the code it touches: callers of every changed function, and the functions it calls. When a signature or a behavior changes, grep every caller. A fix applied in one caller while the shared function stays broken is a finding.
- **Load.** State the load you assumed, from the README or the deploy config. Judge scale against that. One person and a script is not many processes.
- **Correctness.** This pass owns bugs, edges, and broken developer setup when no automated bug review is installed. Edges include empty, zero, the last item, rounding, and time zones. A symptom patch is a finding: a guard on the null that crashed, a catch that drops the error, a cast that silences the type, a retry, a sleep or a longer timeout, a skipped test, a weaker assertion, an updated snapshot, or a special case that leaves the cause in place. Name the cause before the edit. Do this pass before you read anyone else's comments. After it, do not restate a comment automated review already posted. If none is posted, the correctness findings stay in this report. Say which.
- **CI and deterministic checks:** Treat the compiler, linter, tests, unused-code check, infrastructure validation, and secret scan as authoritative. Do not restate a green check; that status is already on the change. If a required check is failing, name it under Blocker. Do not substitute a manual re-run for required gates unless the user asked you to run them for evidence.
- **Second pass.** On a diff of more than about 15 relevant files, or when the user asks, run a second pass on a different model family from the one that wrote the diff. Read `Review model` in `.helmsman/setup.md`. When that line is `none` or missing, pick a different family and name it in the comment. Do not hard-code a model slug in this skill. Weight a finding both passes raise. Map Act on to Blocker, Judo, or High. Map Consider to Medium, Low, or Fix forward. Map Noted or Dismissed to Nit, or one line with a reason. Deduplicate. The automation's time ceiling still holds. Do not start the second pass when that ceiling is already close. The single pass is the default.

## Output format

The comment a person reads uses the verdict and the finding labels. A Blocker is a presumptive blocker. A Judo finding is a restructuring that deletes complexity. High, Medium, and Low are priority, and the proof rung sits beside them. A Fix forward finding is deferred. A Nit is optional. Use these exact headings:

```markdown
## Summary

**Verdict:** Approve | Request changes

**What this change does:** two or three sentences.

**Load:** the load you assumed, and where you read it. Or `Not stated.`

**Blocker:** what must be fixed before merge, and why (data loss, auth, a broken contract, a gate bypass, a setup break, a feature-gate leak). Or `None.`

**Judo:** the restructuring that would delete complexity, and whether the comment justifies keeping the current shape. Or `None.`

**High:** a correctness break you traced end to end. Or `None.`

**Medium:** a narrower real correctness finding. Or `None.`

**Low:** a real finding that can wait. Or `None.`

**Fix forward:** what can wait, and why. Or `None.`

**Nit:** cosmetic notes. Optional. Or `None.`

## Blocker

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 1 | path:line | ... | the concrete case | cited, excluded, ran, or reproduced | the smallest fix | what remains wrong |

## Judo

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 2 | path:line | ... | the concrete case | cited, excluded, ran, or reproduced | the smallest fix | what remains wrong |

## High

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 3 | path:line | ... | the concrete case | cited, excluded, ran, or reproduced | the smallest fix | what remains wrong |

## Medium

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 4 | path:line | ... | the concrete case | cited, excluded, ran, or reproduced | the smallest fix | what remains wrong |

## Low

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 5 | path:line | ... | the concrete case | cited or higher | the smallest fix | what remains |

## Fix forward

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 6 | path:line | ... | the concrete case | cited or higher, or why it can wait | the smallest fix, or why it can wait | what remains |

## Nit

| # | Location | What this is | Problem | Proof | Fix | If we skip it |
| - | -------- | ------------ | ------- | ----- | --- | ------------- |
| 7 | path:line | ... | the cosmetic case | cited | optional | nothing that blocks merge |

Verdict: Approve
Reviewed: <full sha of HEAD>
Base: <full sha of the pull request base>
Patch: <patch-id of `git diff <base> HEAD`>

## Recommendation

One verdict. `Approve` when no Blocker, no unjustified Judo, and no High or Medium finding remains. Low, Fix forward, and Nit can still Approve. `Request changes` when any of those four is open. Name the numbers: `fix 1 and 3 first`. Advisory; not a substitute for required CI or human approval on high-risk changes. The plain `Verdict:` line matches this recommendation. `.helmsman/tools/checks/review-current.sh` reads that line.

## Not checked

One line. What mattered and was not read. Or `None.`
```

Number findings across the label sections. Every finding has all four parts. No concrete case, no finding. Prefer a fix that deletes.

Use `_None._` in a section when empty. Do not print an empty table.

Map the checklist onto the sections. Do not add a second set of headings. A bug, a setup break, or a feature-gate leak that the checklist calls Blocker goes under Blocker. A structural miss the checklist calls Judo goes under Judo. A correctness finding uses High, Medium, or Low. A leftover that can wait goes under Fix forward. A cosmetic note goes under Nit.

Do the empty-input, boundary, and concurrency assessment from the checklist. Put it in the table only when it is a finding. When it is covered or N/A, do not narrate it.

Apply the checklist's verdict and finding labels. Do not restate them here.

## Review before ready

The person finishing the pull request runs this review on the full diff against the base. Fix every Blocker, unjustified Judo, High, and Medium finding. The pre-commit hook and `pnpm check` are green. Post the review as a pull request comment that says what was fixed and what remains Fix forward or Nit and why. The comment includes a plain `Verdict:` line, then `Reviewed`, `Base`, and `Patch` for that commit. `.helmsman/tools/checks/review-current.sh` fails the pull request when a later push changes the patch, or when the latest reviewed comment has no `Verdict: Approve` or `Verdict: Request changes` line. A plain rebase that keeps the same patch-id still passes. Post a new comment before that push, or the check fails. For each Fix forward finding, run `.helmsman/tools/checks/fix-forward.sh`. It opens a low-priority issue labeled `fix-forward` when filing is allowed, and it does nothing without GitHub auth. A Nit does not get an issue. Mark the pull request ready only after that comment. Marking ready is when CI runs. Do not merge until that run is green. The review catches what the standards missed, including when the change was written to them.

Agents work in draft. Prove the change locally with `pnpm check` and the pre-commit hook before pushing. CI runs when the pull request is marked ready, and on push to main. A draft pull request does not run CI.

A reviewer who was asked only to review does not edit the code. The output format above does not change.

## Related

- Checklist: [`.cursor/rules/helmsman-checklist.mdc`](../../rules/helmsman-checklist.mdc)
- Standards: [`.cursor/rules/helmsman-standards.mdc`](../../rules/helmsman-standards.mdc)
- Pull-request automation: [`.cursor/automations/helmsman-review.md`](../../automations/helmsman-review.md)
- Strict structural pass, by name only: [helmsman-structure](../helmsman-structure/SKILL.md)

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`) `skills/ponytail-review/SKILL.md` (finding shape, concrete case, load, not checked). cursor/plugins@`11713c683fe4add4fd403ea880580abbc9e0875f` `thermos/skills/thermo-nuclear-review/SKILL.md`, `thermos/skills/thermos/SKILL.md`, and `cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md` (priority words, and a restructuring that deletes complexity). cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/interrogate/SKILL.md` and `pstack/skills/poteto-mode/playbooks/shipping.md` (a different model family, and a review that records the patch). MIT.
