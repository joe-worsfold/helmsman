---
name: helmsman-perf
description: >-
  Change performance only after a baseline measurement. Use when a task is
  slow and a number can show the before and the after.
user-invocable: true
---

# helmsman-perf

Measure first. Do not claim a limit you have not run.

1. Record a baseline on the surface that is slow. Write the number, the unit, and the command. Check what limits that number: the machine, a cold cache, an error, one run instead of several, or a metric the user does not feel. Say which of those you checked.
2. Try the cheapest change that can meet the target, and stop when it does:
   1. Do not do the work. Stop work whose result nothing uses.
   2. Do not do it again.
   3. Do less of it.
   4. Do it later.
   5. Do it when the user is not waiting.
   6. Do it at the same time as other work.
   7. Do it cheaper.
3. Record the same measurement after the change. An inconclusive run, or a run on a different surface, is not a pass. Say so.
4. Put the before number, the after number, the unit, and the command in the pull request. Stay in draft until [review before ready](../../../AGENTS.md) is done.

A sustained campaign against one metric is a series of these steps, one change at a time. Verify each attempt before the next.

## Sources

cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/poteto-mode/playbooks/perf-issue.md`. MIT.
