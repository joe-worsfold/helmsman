#!/usr/bin/env node
// Wraps `gh` so pr and issue bodies carry the footer in HELMSMAN_WATERMARK.
// hook.mjs defines a `gh` shell function that calls this, so the shell has already
// expanded heredocs and quotes and the body arrives here as a plain argument.
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const MARK = "Sent by an agent.";

export function withFooter(body, footer) {
  if (!footer || body.includes(MARK)) return body;
  return `${body.trimEnd()}\n\n${footer}`;
}

const WRITES = new Set(["create", "edit", "comment", "review"]);

export function watermarkArgs(args, footer, readBody = (p) => readFileSync(p === "-" ? 0 : p, "utf8")) {
  if (!["pr", "issue"].includes(args[0]) || !WRITES.has(args[1])) return args;
  const out = [...args];
  for (let i = 2; i < out.length; i++) {
    const a = out[i];
    if ((a === "--body" || a === "-b") && i + 1 < out.length) {
      out[i + 1] = withFooter(out[i + 1], footer);
      i++;
    } else if (a.startsWith("--body=")) {
      out[i] = `--body=${withFooter(a.slice(7), footer)}`;
    } else if ((a === "--body-file" || a === "-F") && i + 1 < out.length) {
      const file = join(mkdtempSync(join(tmpdir(), "helmsman-wm-")), "body.md");
      writeFileSync(file, withFooter(readBody(out[i + 1]), footer));
      out[i + 1] = file;
      i++;
    }
  }
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = watermarkArgs(process.argv.slice(2), process.env.HELMSMAN_WATERMARK ?? "");
  const run = spawnSync("gh", args, { stdio: "inherit" });
  process.exit(run.status ?? 1);
}
