#!/usr/bin/env node
// Wraps `gh` so pr and issue bodies, and `gh api` body fields, start with the watermark in
// HELMSMAN_WATERMARK. hook.mjs puts bin/gh first on PATH, so the shell has already expanded
// heredocs and quotes and the body arrives here as a plain argument. A PATH entry, unlike a
// shell function, also reaches subshells, `bash -c`, `xargs`, `command gh`, and scripts.
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

export const MARK = "> Sent by an agent";

export function hasWatermark(body) {
  return body.trimStart().startsWith(MARK);
}

export function withWatermark(body, line) {
  if (!line || hasWatermark(body)) return body;
  const rest = body.trim();
  return rest ? `${line}\n\n${rest}` : line;
}

// gh anywhere in the command, not only in command position: `bash -c "gh pr create"` posts too.
// A false match only costs the transcript read, because the gh on PATH passes every other call
// through unchanged. `gh api` counts only with a body field or --input, so reads stay cheap.
export const GH_WRITE = /\bgh\s+(?:(?:pr|issue)\s+(?:create|edit|comment|review)\b|api\b(?=.*(?:\bbody=|--input\b)))/s;

const WRITES = new Set(["create", "edit", "comment", "review"]);
const FILL = new Set(["--fill", "-f", "--fill-first", "--fill-verbose"]);
const BODY = new Set(["--body", "-b", "--body-file", "-F"]);
const FIELD = new Set(["-f", "--raw-field", "-F", "--field"]);

const readStdinOrFile = (p) => readFileSync(p === "-" ? 0 : p, "utf8");

function tempFile(dirs, text) {
  const dir = mkdtempSync(join(tmpdir(), "helmsman-wm-"));
  dirs.push(dir);
  const file = join(dir, "body.md");
  writeFileSync(file, text);
  return file;
}

// One `body=` field value. -F/--field reads `body=@file` from the file, so that gets a copy.
function watermarkField(flag, field, line, readBody, dirs) {
  const value = field.slice("body=".length);
  if (!(flag === "-F" || flag === "--field") || !value.startsWith("@")) return `body=${withWatermark(value, line)}`;
  return `body=@${tempFile(dirs, withWatermark(readBody(value.slice(1)), line))}`;
}

// A JSON --input with a string body gets a marked copy. Anything else is sent as it was. Stdin
// has been read by then, so it is passed on as a copy too.
function watermarkInput(source, line, readBody, dirs) {
  const text = readBody(source);
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    // Not JSON, so there is no body field to mark.
  }
  if (typeof json?.body === "string") return tempFile(dirs, JSON.stringify({ ...json, body: withWatermark(json.body, line) }));
  return source === "-" ? tempFile(dirs, text) : source;
}

// `gh api` sends a field named body as the message text: -f/--raw-field body=..., -F/--field body=...
// or body=@file, and a JSON --input whose top-level body is a string. Text inside a GraphQL query= is not read.
function watermarkApi(args, line, readBody, dirs) {
  const out = [...args];
  const get = out.some((a, i) => /^(?:-X|--method=?)GET$/i.test(a) || (["-X", "--method"].includes(a) && /^GET$/i.test(out[i + 1] ?? "")));
  if (get) return out;
  for (let i = 1; i < out.length; i++) {
    const a = out[i];
    const joined = a.match(/^(--raw-field|--field)=(body=.*)$/s) ?? a.match(/^(-f|-F)(body=.*)$/s);
    if (FIELD.has(a) && out[i + 1]?.startsWith("body=")) {
      out[i + 1] = watermarkField(a, out[i + 1], line, readBody, dirs);
      i++;
    } else if (joined) {
      const sep = joined[1].startsWith("--") ? "=" : "";
      out[i] = `${joined[1]}${sep}${watermarkField(joined[1], joined[2], line, readBody, dirs)}`;
    } else if (a === "--input" && i + 1 < out.length) {
      out[i + 1] = watermarkInput(out[i + 1], line, readBody, dirs);
      i++;
    }
  }
  return out;
}

export function watermarkArgs(args, line, readBody = readStdinOrFile, dirs = []) {
  if (!line) return args;
  if (args[0] === "api") return watermarkApi(args, line, readBody, dirs);
  if (!["pr", "issue"].includes(args[0]) || !WRITES.has(args[1])) return args;
  const out = [...args];
  for (let i = 2; i < out.length; i++) {
    const a = out[i];
    if ((a === "--body" || a === "-b") && i + 1 < out.length) {
      out[i + 1] = withWatermark(out[i + 1], line);
      i++;
    } else if (a.startsWith("--body=")) {
      out[i] = `--body=${withWatermark(a.slice(7), line)}`;
    } else if ((a === "--body-file" || a === "-F") && i + 1 < out.length) {
      out[i + 1] = tempFile(dirs, withWatermark(readBody(out[i + 1]), line));
      i++;
    }
  }
  return out;
}

// `gh pr create --fill` with no body writes the body from the commits after this wrapper has run,
// so the wrapper creates the pull request, then edits its body to start with the watermark.
export function fillsBody(args) {
  if (args[0] !== "pr" || args[1] !== "create") return false;
  const rest = args.slice(2);
  return rest.some((a) => FILL.has(a)) && !rest.some((a) => BODY.has(a) || a.startsWith("--body="));
}

// PATH without any watermark bin directory, the repo's or the user install's, so gh is the real one.
export function realPath(path) {
  return path
    .split(delimiter)
    .filter((p) => !/[\\/]watermark[\\/]bin[\\/]?$/.test(p))
    .join(delimiter);
}

function run(given, line, dirs) {
  const env = { ...process.env, PATH: realPath(process.env.PATH ?? "") };
  const args = watermarkArgs(given, line, undefined, dirs);
  if (!line || !fillsBody(given)) return spawnSync("gh", args, { stdio: "inherit", env }).status;
  const create = spawnSync("gh", args, { stdio: ["inherit", "pipe", "inherit"], env, encoding: "utf8" });
  process.stdout.write(create.stdout ?? "");
  const url = create.stdout?.match(/https:\/\/\S+\/pull\/\d+/)?.[0];
  if (create.status !== 0 || !url) return create.status;
  const body = spawnSync("gh", ["pr", "view", url, "--json", "body", "-q", ".body"], { env, encoding: "utf8" });
  if (body.status !== 0) return body.status;
  const file = tempFile(dirs, withWatermark(body.stdout.replace(/\n$/, ""), line));
  return spawnSync("gh", ["pr", "edit", url, "--body-file", file], { stdio: ["inherit", "ignore", "inherit"], env }).status;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dirs = [];
  let status;
  try {
    status = run(process.argv.slice(2), process.env.HELMSMAN_WATERMARK ?? "", dirs);
  } finally {
    for (const dir of dirs) rmSync(dir, { recursive: true, force: true });
  }
  process.exit(status ?? 1);
}
