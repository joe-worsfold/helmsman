---
name: helmsman-correct
description: >-
  Turn a mistake agents keep repeating into a check that fails. Use when the
  same correction shows up twice in commits, reverts, or review comments.
user-invocable: true
---

# helmsman-correct

A repeated agent mistake becomes a check. A paragraph that asks the agent to be careful is the last resort, and only for a judgment call.

Assume the next agent opens one file, copies the nearest example, and takes the shortest path that compiles. A change that looks right from that file has to be right for the repo.

## Find the class

Read recent commits, reverts, review comments, and comments that explain a workaround. Group the mistakes. A class counts when it has happened twice.

## Fix at the highest level that works

1. **Architecture.** One owner for each piece of state. One supported way to do the task. Hide internals so the wrong import fails. Delete the old way an agent would copy.
2. **Types.** The bad state does not compile. If it still compiles, add a lint or CI check whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more of it.
3. **A test.** Call the real code. Delete a test that would still pass if every function it calls returned nothing.
4. **Docs.** Only for a judgment call. Nothing fails when an agent skips a doc.

## Prove it

Fix the most frequent class now, in one commit. The new check must fail on a real past mistake. Run the same command locally and in CI.

An exception sits on the offending line and has all three: a reason, an expiry date, and a person's approval. An agent does not approve its own exception.

## The table

Keep [the rule table in `AGENTS.md`](../../../AGENTS.md) current. Each row is a rule and the command or job that fails when it breaks. When a person corrects you, fix the mistake and add the row. If the rule is already there and nothing enforces it, that is a repeat. Fix it at the highest level in the same change. Drop a row once the mistake cannot happen.

## Output

Write the proposal: each class, the evidence, the level you picked, and why a higher level did not work.

Do not open a pull request unless `.helmsman/setup.md` says `Correct PR: yes`. The default is `no`. A missing line means no.

## Sources

cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/correct/SKILL.md`. MIT.
