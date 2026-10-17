#!/usr/bin/env node
// Pre-tool hook for Claude Code (PreToolUse) and Cursor (preToolUse).
// Rewrites the tool input so every message an agent sends starts with a quoted line naming
// the driver's GitHub login, the model, and the skills loaded this session.
//   shell: `gh pr|issue create|edit|comment|review` runs through gh.mjs
//   MCP:   string body fields on Slack, Jira, GitHub, and similar send/post tools
// Anything else passes through untouched.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { GH_WRITE, hasWatermark, MARK, withWatermark } from "./gh.mjs";

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

// The GitHub login: from the environment, the local gh config (no network), or a noreply email.
function login() {
  if (process.env.HELMSMAN_DRIVER || process.env.GITHUB_ACTOR) return process.env.HELMSMAN_DRIVER || process.env.GITHUB_ACTOR;
  try {
    const user = execFileSync("gh", ["config", "get", "-h", "github.com", "user"], { encoding: "utf8" }).trim();
    if (user) return user;
  } catch {
    // gh missing or not logged in: try the email next.
  }
  const email = event.user_email || git("user.email");
  return email.match(/^(?:\d+\+)?([\w-]+)@users\.noreply\.github\.com$/)?.[1] ?? "";
}

// GitHub links @login itself. Slack and other markdown get a link to the GitHub profile.
function driver(surface) {
  const user = login();
  if (!user) return git("user.name") || process.env.USER || "unknown";
  const url = `https://github.com/${user}`;
  if (surface === "github") return `@${user}`;
  if (surface === "slack") return `<${url}|@${user}>`;
  return `[@${user}](${url})`;
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
      // A plugin skill runs as /plugin:skill. Built-in commands never contain a colon.
      if (name.includes(":") || isSkill(name)) skills.add(name);
    }
  }
  return { model: model || "unknown", skills: [...skills] };
}

function watermark(surface) {
  const { model, skills } = session();
  return `${MARK} for ${driver(surface)}. Model: ${model}. Skills: ${skills.join(", ") || "none"}.`;
}

const quote = (s) => `'${s.replaceAll("'", `'\\''`)}'`;

function rewrite(name, input) {
  if (typeof input?.command === "string" && GH_WRITE.test(input.command)) {
    const wrapper = fileURLToPath(new URL("./gh.mjs", import.meta.url));
    const prefix = `export HELMSMAN_WATERMARK=${quote(watermark("github"))}; gh() { node ${quote(wrapper)} "$@"; }; `;
    return { ...input, command: prefix + input.command };
  }
  // Cursor's matcher passes only Shell and MCP tools, and its docs do not say whether tool_name keeps the MCP: prefix.
  const mcp = cursor ? name !== "Shell" : name.startsWith("mcp__");
  const server = `${name} ${event.mcp_server_name ?? ""}`;
  if (!mcp || !MESSAGING.test(server) || !SENDS.test(name) || NOT_A_MESSAGE.test(name)) {
    return null;
  }
  const fields = typeof input === "string" ? JSON.parse(input) : input;
  const field = BODY_FIELDS.find((f) => typeof fields?.[f] === "string" && !hasWatermark(fields[f]));
  if (!field) return null;
  const surface = /slack/i.test(server) ? "slack" : /github/i.test(server) ? "github" : "markdown";
  const updated = { ...fields, [field]: withWatermark(fields[field], watermark(surface)) };
  return typeof input === "string" ? JSON.stringify(updated) : updated;
}

const updated = rewrite(event.tool_name ?? "", event.tool_input);
if (cursor) {
  process.stdout.write(JSON.stringify(updated ? { updated_input: updated } : {}));
} else if (updated) {
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "PreToolUse", updatedInput: updated } }));
}
