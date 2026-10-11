# Issue body

The night run files a GitHub issue only when `.helmsman/setup.md` says `File issues: yes` and `Issues: github`. Both `File issues` and `Fix` default to `no`. A missing setup file means no issues.

The slop and security skills are what the night run follows. This page is the same shape, so a person can read it without opening the skill.

One finding, one issue. Search open issues for the same path and the same title before creating one. Label `helmsman`. Do not include a patch. Do not include steps that would make a leak succeed. Redact secrets. Record the path and the line.

The title is the finding heading without the hashes: `P2 — Short title`.

## Slop

```markdown
**Source:** slop
**Priority:** P2
**Category:** AI Slop | Security | Architecture | Performance | Infra
**Location:** `path/to/file.ext:line`
**Impact:** What breaks, slows down, or is exposed if this stays.
**Evidence:** The lines, with any secret redacted.
**Why this is real:** The control you checked, and why it does not already catch this.
**Change:** The smallest edit that removes the defect. No patch.
**Acceptance:** The command or assertion that fails before the fix and passes after.
**Out of scope:** What the fix must not widen into.
```

## Security

```markdown
**Source:** security
**Priority:** P1
**Risk:** A0N:2025 name
**Requirement:** v5.0.0-x.y.z
**Location:** `path/to/file.ext:line`
**Impact:** One sentence on what is exposed if this stays.
**Evidence:** The line, secret redacted. Name the tool if a tool found it.
**Gate checked:** The check that should have failed the pull request, and why it did not. Or "no gate".
**How to fix:** The smallest change that closes the finding. No patch and no reproduction.
**Acceptance:** The control passes, and the named gate or command fails a regression of this finding.
**Out of scope:** What the fix must not widen into.
```

Fix reads one of these issues, or one `### P#` section, and stops at `Out of scope`. The check it runs is `Acceptance`. It does not file another issue.

## Fix-forward

A Fix forward review finding, and a deferred finding from the overnight check, uses `.helmsman/tools/checks/fix-forward.sh`. The label is `fix-forward`. The priority is P4. The script skips the call when `File issues` is not `yes`, when `Issues` is not `github`, when `gh` has no auth, or when an open issue already has the same title.

```markdown
**Source:** fix-forward
**Priority:** P4
**Location:** `path/to/file.ext:line`
**What can wait:** The leftover, in one sentence.
**Why it can wait:** Why this is Fix forward, not a Blocker, a Judo, a High, or a Medium.
```
