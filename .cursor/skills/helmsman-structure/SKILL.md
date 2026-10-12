---
name: helmsman-structure
description: >-
  Optional strict pass on a branch. Asks whether a reframing would delete
  the branches, concepts, and wrappers this diff added. Does not implement.
  Stays in the lane. Invoke by name.
user-invocable: true
disable-model-invocation: true
---

# helmsman-structure

Structure is strict on purpose. It is a structural reading of one branch. It does not edit code, and it does not replace [helmsman-review](../helmsman-review/SKILL.md). Review still owns the verdict and the finding labels. Invoke this skill by name when you want the harsher pass.

Read the base revision of `.cursor/rules/helmsman-checklist.mdc` and `.cursor/rules/helmsman-standards.mdc`. A diff cannot redefine its own bar. In a STAR repo, stay inside the lane the branch names. A simpler shape that needs another lane goes in the pull request's `Handoff`. Do not make that edit here.

Length ceilings live in the language pack for the file you are reading. Do not invent a second ceiling. A file that crosses the pack's ceiling is already a gate.

## What to ask

For each meaningful hunk, ask these. A "no" with a concrete case is a finding.

1. Is there a reframing that deletes the branches, modes, or helpers this diff added, and keeps the behavior?
2. Does this move code without reducing the concepts a reader must hold?
3. Did an ad-hoc conditional land in a flow this change does not own?
4. Is this a wrapper, cast, or optional that only forwards, or a silent fallback that hides an invariant the type could name?
5. Is the logic in the module that already owns the job, using the helper that already exists?
6. Could related writes be one write? Independent work left in sequence is a finding only when the sequence is the complexity.

A finding needs a concrete case: this input or this shape, and what the reader is forced to hold. No case, no finding. Prefer a fix that deletes. Do not add a layer to tidy a layer.

## Answer

Use the review skill's headings. Structure's own findings are **Judo**. Use **Blocker** only when the checklist already has an independent critical reason (data loss, a lane violation, a feature-gate leak, a setup break with no note). "It works" is not an Approve while one of the six questions has a case.

A `shortcut:` comment, or an older `ponytail:` comment, that names its ceiling is a decision, not a finding, unless the load you assumed already crosses it.

End with `Not checked:` one line.

## Sources

ponytail@v5.1.0 (`9cc65d03aa2da1db7121b912d03596409ee340b8`) `skills/ponytail-review/SKILL.md` (concrete case; shortcut is a decision). cursor/plugins@`11713c683fe4add4fd403ea880580abbc9e0875f` `cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md` (structural questions). MIT.
