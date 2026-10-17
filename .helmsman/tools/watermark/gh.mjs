#!/usr/bin/env node
// Wraps `gh` so pr and issue bodies start with the watermark in HELMSMAN_WATERMARK.
// hook.mjs defines a `gh` shell function that calls this, so the shell has already
// expanded heredocs and quotes and the body arrives here as a plain argument.
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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

export const GH_WRITE = /(?:^|[;&|({\n])\s*gh\s+(pr|issue)\s+(create|edit|comment|review)\b/;

const WRITES = new Set(["create", "edit", "comment", "review"]);

export function watermarkArgs(args, line, readBody = (p) => readFileSync(p === "-" ? 0 : p, "utf8"), dirs = []) {
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
      const dir = mkdtempSync(join(tmpdir(), "helmsman-wm-"));
      dirs.push(dir);
      const file = join(dir, "body.md");
      writeFileSync(file, withWatermark(readBody(out[i + 1]), line));
      out[i + 1] = file;
      i++;
    }
  }
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dirs = [];
  const args = watermarkArgs(process.argv.slice(2), process.env.HELMSMAN_WATERMARK ?? "", undefined, dirs);
  const run = spawnSync("gh", args, { stdio: "inherit" });
  for (const dir of dirs) rmSync(dir, { recursive: true, force: true });
  process.exit(run.status ?? 1);
}
