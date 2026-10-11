---
name: helmsman-shortcuts
description: >-
  Ledger of shortcut comments. Collects every shortcut: marker and older
  ponytail: marker, with its ceiling and when to remove it. Reads only.
  Invoke by name.
user-invocable: true
disable-model-invocation: true
---

# helmsman-shortcuts

A shortcut shortens the work on purpose. You remove it when the reason is gone. A `shortcut:` comment records a known ceiling, and when to remove it. This skill reads the ledger. It does not edit product code.

An older `ponytail:` comment is the same deferral.

## Scan

Search tracked source for a comment marker. Skip `.git`, `node_modules`, `dist`, `build`, and `.helmsman/tools/upstream/` (the pin quotes the marker; it is not a shortcut in this repo).

The marker is a comment prefix, then optional space, then `shortcut:` or `ponytail:`. Prefixes: `#`, `//`, `/*`, and `--` (SQL). A sentence that only mentions the word is not a row.

```text
grep -rnE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=upstream '(#|//|--|/\*) ?(shortcut|ponytail):' .
```

Run that from the repository root. The `--exclude-dir=upstream` line is only right when it does not also hide a product directory of that name. If it does, narrow the exclude to `.helmsman/tools/upstream`.

## Ledger

One row per marker, grouped by file:

`<file>:<line>, <what was shortened>. ceiling: <the limit named>. upgrade: <when to remove it>.`

The form is `shortcut: <ceiling>, <when to remove it>`. Read the ceiling and the trigger from the comment. A marker with no comma, or nothing after the comma, gets the tag `no-trigger`. Those are the ones that rot.

End with `<N> markers, <M> with no trigger.` Nothing found: `No shortcut debt. Clean ledger.`

The reply is the ledger. Write a file only when asked. When `.helmsman/tools/checks/report-write.sh` is present and accepts `shortcuts.md`, that is the path. Otherwise the reply stays the ledger. Do not write a debt file at the repo root.

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`) `skills/ponytail-debt/SKILL.md`. MIT.
