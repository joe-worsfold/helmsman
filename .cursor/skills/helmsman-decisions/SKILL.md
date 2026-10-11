---
name: helmsman-decisions
description: >-
  Append one row per decision on a long or unattended run. Use when an agent
  works overnight, or when a person will review the run after stepping away.
user-invocable: true
---

# helmsman-decisions

Keep one log of decisions. It is a TSV file. One row is one decision. A cell is one line. Evidence is a pointer, not a paragraph.

## Columns

| Column | What it holds |
| --- | --- |
| ts | UTC time, written by the script |
| phase | The phase, or `start` for the first row of a new run |
| decision | What was chosen, one line |
| why | The reason in plain words |
| evidence | A commit SHA, a pull request number, `file:line`, or a path |
| result | What happened: `tests passed`, `reverted`, `open`, `inconclusive` |

Log a fork, a finished unit and how you checked it, a revert and what triggered it, and a blocker. Do not log every command.

## Where it lives

The default path is `.helmsman/reports/decisions.tsv`. That directory is gitignored. Do not commit the log unless a reviewer needs the trail to trust the result. When several efforts run at once, use `.helmsman/reports/decisions-<task>.tsv`.

## A new run

A run is one agent conversation. A later agent, or a new chat, is a new run. Before appending, read the last rows. If another run wrote since this conversation started, the first new row uses phase `start`. That row names the time range it did not write, and its evidence names this run. Do not use `start` for anything else.

## The script

```bash
.helmsman/tools/checks/decision-log.sh .helmsman/reports/decisions.tsv <phase> <decision> <why> <evidence> <result>
```

The script writes the header on first use, strips tabs and newlines from cells, and prefixes a cell that starts with `=`, `+`, `-`, or `@` with a single quote so a spreadsheet does not treat it as a formula.

Write the row the way you would tell a teammate. Follow [helmsman-writing](../../rules/helmsman-writing.mdc).

## Sources

cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/show-me-your-work/SKILL.md` and `pstack/skills/show-me-your-work/scripts/log.sh`. MIT.
