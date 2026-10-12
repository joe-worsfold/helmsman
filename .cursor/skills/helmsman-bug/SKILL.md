---
name: helmsman-bug
description: >-
  Fix a bug by reproducing it first on the same surface. Use when a report
  describes a wrong result and the cause is not yet proven.
user-invocable: true
---

# helmsman-bug

This is the sequence for a bug. [helmsman-fix-forward](../helmsman-fix-forward/SKILL.md) edits one finding that is already filed. This skill is how you find the cause.

Every line you keep traces to a run you watched. A guess that "might help" does not land. When a run refutes a guess, revert what that guess motivated. The smallest change the evidence supports is the fix.

A change that only hides the symptom is not the fix. That includes a guard on the null that crashed, a catch that drops the error, a cast that silences the type, a retry, a sleep or a longer timeout, a skipped test, a weaker assertion, an updated snapshot, or a special case. Name the cause before you edit.

1. Reproduce it on the same surface the report used. Ask a person only when that surface cannot reach the target, and say why, after you have driven it as far as it goes. If it will not reproduce, tighten the conditions or add a log until it does.
2. Name the candidate causes. Rule them out until one remains. Each pass, take the split that removes the most remaining causes. Read the log from a run. Do not guess the mechanism.
3. Confirm that mechanism with a run before editing. If the fix crosses a function boundary, grep every caller and fix the shared code once.
4. Verify on the same surface. Follow [helmsman-prove](../helmsman-prove/SKILL.md): one claim, a baseline and a treatment, and one verdict. UI evidence is screenshots under `.helmsman/reports/prove/<pr>/`. Backend evidence is the command output and the exit code. The original repro now passes. A run on a different surface is not a pass. A unit test shows one branch. It does not show the bug is gone.
5. When a cheap local test can fail before the fix and pass after, land that test first. Skip it when the only test would be an expensive integration with no clear assertion.
6. Open the pull request with the [template](../../../.github/PULL_REQUEST_TEMPLATE.md). Stay in draft until [review before ready](../../../AGENTS.md) is done.

Reply with what was broken, the cause, the fix, and the failing-then-passing output.

## Sources

cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/poteto-mode/playbooks/bug-fix.md` and `pstack/skills/principle-fix-root-causes/SKILL.md`. MIT.
