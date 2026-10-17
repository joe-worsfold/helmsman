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

On a checkout without symlinks (`git config core.symlinks false`, the Windows default), each skill is a copied folder with a `.helmsman-copy` marker instead of a link, and `--check` fails when a copy no longer matches its source. A link that was checked out as a text file is replaced by a copy. A matching copy also passes on a checkout with symlinks, so a team on both does not flip the files back and forth.

Each generated rule carries a comment naming its source. Edit the `.mdc`, then run the emitter. A file or folder in `.claude/` without that comment, or a symlink that points elsewhere, is the repo's own and is left alone.

A `CLAUDE.md` that does not import `@AGENTS.md` fails the check. Claude reads `AGENTS.md` only when no `CLAUDE.md` exists, so that file would hide the review-before-ready steps.

## Plugin

This repository is also a Claude Code plugin (`.claude-plugin/plugin.json`) and a Cursor plugin (`.cursor-plugin/plugin.json`). A repo can load Helmsman from the plugin instead of copying `.claude/` files.

| Part | Claude Code plugin | Cursor plugin |
| --- | --- | --- |
| Skills | `.cursor/skills/`, named `helmsman:<skill>` | `.cursor/skills/` |
| Always-on rules | A `SessionStart` hook runs `emit.sh --context`. It prints each always-on rule, and a list of the file rules with the path to read before editing a match. A rule the repo already has in `.claude/rules/` is skipped | `.cursor/rules/`, with their own `alwaysApply` and `globs` |
| Watermark | `PreToolUse` hook | `preToolUse` hook in `.cursor-plugin/hooks.json` |

`.helmsman/tools/plugin/enable.sh <sha>` pins the Claude Code plugin in a repo's `.claude/settings.json`. It writes an inline catalog (`extraKnownMarketplaces`, source type `settings`) whose one entry fetches `joe-worsfold/helmsman` at that sha, and sets `enabledPlugins["helmsman@helmsman"]`. A teammate gets the plugin after accepting the folder's trust prompt. With the plugin enabled, `emit.sh` removes its generated copies, so nothing loads twice, and `hooks-install.sh` leaves the Claude hook to the plugin.

Cursor has no committed file that turns a plugin on. Teams and Enterprise plans can set it to Required in a team marketplace. Other plans install it per person, so setup keeps copying `.cursor/` for Cursor.

## Agent watermark

`.helmsman/tools/watermark/hooks-install.sh` registers one pre-tool hook, `hook.mjs`, in `.claude/settings.json` (`PreToolUse`) and `.cursor/hooks.json` (`preToolUse`). The hook rewrites the tool input. The agent does not have to remember anything. It puts this quoted line first in the message, so the message text stays the most visible part:

`> Sent by an agent for @<login>. Model: <model>. Skills: <skills or none>.`

The driver is the GitHub login. The hook reads it from `HELMSMAN_DRIVER`, then `GITHUB_ACTOR`, then `gh config get -h github.com user` (no network call), then a `users.noreply.github.com` email. GitHub links `@login` to the profile. Slack gets `<https://github.com/login|@login>`, and other markdown gets `[@login](https://github.com/login)`. With no login, the hook uses `git config user.name`, unlinked.

| Call | What the hook changes |
| --- | --- |
| `gh pr` or `gh issue` with `create`, `edit`, `comment`, or `review` | It defines a `gh` shell function in front of the command. The shell expands heredocs and quotes, then `gh.mjs` adds the line to `--body`, `-b`, `--body=`, or a copy of `--body-file`, and runs the real `gh`. |
| An MCP send, post, or comment tool on Slack, Jira, Confluence, GitHub, Linear, Teams, or Discord | The first string field among `text`, `body`, `message`, `comment`, `commentBody`, `markdown_text`. File, branch, repo, label, reaction, and upload tools are left alone. |

Cursor puts the model and the user's email in the hook input. Claude Code does not, so the hook reads the model from the last assistant entry in `transcript_path`. Skills come from the transcript: `Skill` calls and `/name` commands in Claude Code, reads of a `SKILL.md` in Cursor. A body that already starts with the line is left alone.

Not covered: `gh api`, `curl` to a webhook, and a `gh pr create --fill` with no body. In Cursor, every `SKILL.md` an agent reads counts as a skill, including one it only edited.

## Not covered by the emitter

| Cursor | Claude Code |
| --- | --- |
| `.cursor/automations/helmsman-review.md` | Run the same prompt from a GitHub Action (`anthropics/claude-code-action`) on `ready_for_review`, or invoke `/helmsman-review` before marking ready. |
| `.cursor/automations/helmsman-nightly.md` | A scheduled Claude routine (`/schedule`) with the automation file as its prompt. Set `HELMSMAN_WRITE_REPORTS=1` in that environment so `report-write.sh` writes the files. |
| `.cursor/environment.json` (cloud agent install and start) | A `SessionStart` hook in `.claude/settings.json`, or the cloud environment's setup script. |
| A rule picked by its `description` alone | No equivalent. Claude chooses skills by description, not rules. Give a rule `globs` or `alwaysApply`, or make it a skill. |

The review skill's second pass wants a different model family from the one that wrote the diff. Inside Claude Code that is another tool's CLI, or a person. When neither is available, say the second pass did not run.
