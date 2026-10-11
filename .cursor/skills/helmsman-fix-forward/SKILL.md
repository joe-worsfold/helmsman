---
name: helmsman-fix-forward
description: >-
  Works through one fix-forward issue, or one finding in the latest
  slop.md or security.md. Does not file issues and does not start
  feature work.
user-invocable: true
---

# helmsman-fix-forward

[Helmsman](../../../README.md) is a set of rules and checks for agent-written code. [helmsman-slop](../helmsman-slop/SKILL.md) scores the slop and, when allowed, files it. [helmsman-security](../helmsman-security/SKILL.md) records each security finding and how to fix it. This skill works through one fix-forward issue, or one finding.

## One finding

Work one issue, or one `### P#` section of the latest `.helmsman/reports/<UTC>/slop.md` or `security.md`. `.helmsman/tools/checks/report-write.sh --latest` prints that directory when one exists. Do not take the next one in the same turn unless the user, or `.helmsman/setup.md` with `Fix: yes` on a nightly run, names a list.

In a STAR repo, fix in a worktree on `agent/<domain>/fix-<finding>` for the domain that owns the defect. If the fix needs another lane, fix only your lane's part and put the rest in the pull request's `Handoff`.

Read the issue before editing. The smallest change that removes the defect is the fix. When the defect is in shared code, grep every caller first and fix the root cause once there. Do not patch one caller and leave the shared function broken. Stay inside **Out of scope**. Run the **Acceptance** check. No new feature. No drive-by rewrite. The issue shape is [docs/issue-body.md](../../../docs/issue-body.md).

A passing test is a protected test. Once a protected test is tied, keep it. Retie it only when the finding says that assertion is now false. Then say why.

When the defect is gone, run the check that proves it. If `Issues` is `github` and the issue was filed by the slop skill or by security, comment with the check that ran and stop. The nightly fixer puts `Closes #<n>` in the pull request body so a merge closes the issue. Do not close it by hand in this turn. Do not file a follow-up issue. On a security finding, the check should show the seam is tight.

If `Fix` is `no` and this is the night run, do not edit code. Say the finding is waiting.

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`) `skills/ponytail/SKILL.md` (grep callers, fix the root once). MIT.
