# Claude Code

Helmsman's rules and skills are written once, under `.cursor/`. Claude Code reads `.claude/` and `CLAUDE.md`. `.helmsman/tools/claude/emit.sh` writes the Claude side from the Cursor side. `pnpm setup:check` runs `emit.sh --check` and fails when the two drift.

## What the emitter writes

| Cursor source | Claude Code file | When Claude loads it |
| --- | --- | --- |
| `.cursor/rules/<name>.mdc` with `alwaysApply: true` | `.claude/rules/<name>.md`, no frontmatter | Every session |
| `.cursor/rules/<name>.mdc` with `globs` | `.claude/rules/<name>.md` with the same globs as `paths` | When Claude reads or edits a matching file |
| `.cursor/rules/helmsman-writing.mdc` | `.claude/rules/helmsman-writing.md`, no frontmatter | Every session. A commit message or a pull request body is not a file Claude reads, so a `**/*.md` glob would miss them |
| `.cursor/rules/helmsman-checklist.mdc` (no `globs`, not always) | Not emitted | The review skill reads the `.mdc` by path |
| `.cursor/skills/<name>/` | `.claude/skills/<name>`, a relative symlink | The skill's own `description` and `disable-model-invocation` |
| `AGENTS.md` | `CLAUDE.md` containing `@AGENTS.md`, only when no `CLAUDE.md` exists | Every session |

Each generated rule carries a comment naming its source. Edit the `.mdc`, then run the emitter. A file or folder in `.claude/` without that comment, or a symlink that points elsewhere, is the repo's own and is left alone.

A `CLAUDE.md` that does not import `@AGENTS.md` fails the check. Claude reads `AGENTS.md` only when no `CLAUDE.md` exists, so that file would hide the review-before-ready steps.

## Not covered by the emitter

| Cursor | Claude Code |
| --- | --- |
| `.cursor/automations/helmsman-review.md` | Run the same prompt from a GitHub Action (`anthropics/claude-code-action`) on `ready_for_review`, or invoke `/helmsman-review` before marking ready. |
| `.cursor/automations/helmsman-nightly.md` | A scheduled Claude routine (`/schedule`) with the automation file as its prompt. Set `HELMSMAN_WRITE_REPORTS=1` in that environment so `report-write.sh` writes the files. |
| `.cursor/environment.json` (cloud agent install and start) | A `SessionStart` hook in `.claude/settings.json`, or the cloud environment's setup script. |
| A rule picked by its `description` alone | No equivalent. Claude chooses skills by description, not rules. Give a rule `globs` or `alwaysApply`, or make it a skill. |

The review skill's second pass wants a different model family from the one that wrote the diff. Inside Claude Code that is another tool's CLI, or a person. When neither is available, say the second pass did not run.
