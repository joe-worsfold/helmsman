#!/usr/bin/env node
// Pre-tool hook for Claude Code (PreToolUse) and Cursor (preToolUse).
// Rewrites the tool input so every message an agent sends carries a footer naming
// the driver, the model, and the skills loaded this session.
//   shell: `gh pr|issue create|edit|comment|review` runs through gh.mjs
//   MCP:   string body fields on Slack, Jira, GitHub, and similar send/post tools
// Anything else passes through untouched.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { hasFooter, MARK, withFooter } from "./gh.mjs";

const GH_WRITE = /\bgh\s+(pr|issue)\s+(create|edit|comment|review)\b/;
const MESSAGING = /slack|jira|atlassian|confluence|github|linear|teams|discord/i;
const SENDS = /send|post|create|add|comment|reply|update|edit|schedule/i;
const NOT_A_MESSAGE = /file|branch|repo|label|reaction|upload/i;
const BODY_FIELDS = ["text", "body", "message", "comment", "commentBody", "markdown_text"];

const event = JSON.parse(readFileSync(0, "utf8") || "{}");
const cursor = "cursor_version" in event;

function git(key) {
  try {
    return execFileSync("git", ["config", key], { encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}

function driver() {
  if (process.env.HELMSMAN_DRIVER) return process.env.HELMSMAN_DRIVER;
  const name = git("user.name") || process.env.GITHUB_ACTOR || process.env.USER || "unknown";
  const email = event.user_email || git("user.email");
  return email ? `${name} (${email})` : name;
}

function transcript() {
  const path = event.transcript_path;
  if (!path || !existsSync(path)) return [];
  return readFileSync(path, "utf8")
    .split("\n")
    .flatMap((line) => {
      try {
        return [JSON.parse(line)];
      } catch {
        return [];
      }
    });
}

function toolUses(entry) {
  const content = entry.message?.content;
  return Array.isArray(content) ? content.filter((c) => c?.type === "tool_use") : [];
}

function isSkill(name) {
  const root = process.env.CLAUDE_PROJECT_DIR || event.cwd || process.cwd();
  return [join(root, ".claude/skills"), join(root, ".cursor/skills"), join(homedir(), ".claude/skills")].some((dir) =>
    existsSync(join(dir, name, "SKILL.md")),
  );
}

function session() {
  let model = event.model_id || event.model || "";
  const skills = new Set();
  for (const entry of transcript()) {
    if (!cursor && entry.type === "assistant" && entry.message?.model) model = entry.message.model;
    for (const use of toolUses(entry)) {
      if (use.name === "Skill" && use.input?.skill) skills.add(use.input.skill);
      // Cursor loads a skill by reading its SKILL.md. Claude Code loads one only through the Skill tool.
      const read = cursor && use.name === "Read" && JSON.stringify(use.input ?? {}).match(/skills\/([\w.-]+)\/SKILL\.md/);
      if (read) skills.add(read[1]);
    }
    const text = typeof entry.message?.content === "string" ? entry.message.content : "";
    for (const [, name] of text.matchAll(/<command-name>\/([\w:.-]+)<\/command-name>/g)) {
      if (isSkill(name)) skills.add(name);
    }
  }
  return { model: model || "unknown", skills: [...skills] };
}

function footer() {
  const { model, skills } = session();
  return `${MARK} Driver: ${driver()}. Model: ${model}. Skills: ${skills.join(", ") || "none"}.`;
}

const quote = (s) => `'${s.replaceAll("'", `'\\''`)}'`;

function rewrite(name, input) {
  if (typeof input?.command === "string" && GH_WRITE.test(input.command)) {
    const wrapper = fileURLToPath(new URL("./gh.mjs", import.meta.url));
    const prefix = `export HELMSMAN_WATERMARK=${quote(footer())}; gh() { node ${quote(wrapper)} "$@"; }; `;
    return { ...input, command: prefix + input.command };
  }
  // Cursor's matcher passes only Shell and MCP tools, and its docs do not say whether tool_name keeps the MCP: prefix.
  const mcp = cursor ? name !== "Shell" : name.startsWith("mcp__");
  const server = `${name} ${event.mcp_server_name ?? ""}`;
  if (!mcp || !MESSAGING.test(server) || !SENDS.test(name) || NOT_A_MESSAGE.test(name)) {
    return null;
  }
  const fields = typeof input === "string" ? JSON.parse(input) : input;
  const field = BODY_FIELDS.find((f) => typeof fields?.[f] === "string" && !hasFooter(fields[f]));
  if (!field) return null;
  const updated = { ...fields, [field]: withFooter(fields[field], footer()) };
  return typeof input === "string" ? JSON.stringify(updated) : updated;
}

const updated = rewrite(event.tool_name ?? "", event.tool_input);
if (cursor) {
  process.stdout.write(JSON.stringify(updated ? { updated_input: updated } : {}));
} else if (updated) {
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "PreToolUse", updatedInput: updated } }));
}
