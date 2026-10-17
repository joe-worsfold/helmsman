import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { GH_WRITE, MARK, watermarkArgs, withWatermark } from "./gh.mjs";

const line = `${MARK} for @a. Model: m. Skills: none.`;

test("the watermark is a quoted first line, then a blank line, once", () => {
  assert.equal(withWatermark("\nhi\n", line), `${line}\n\nhi`);
  assert.equal(withWatermark(`${line}\n\nhi`, line), `${line}\n\nhi`);
});

test("a body that quotes the watermark lower down still gets one", () => {
  const body = `It adds \`${MARK} for @a\` to the message.`;
  assert.equal(withWatermark(body, line), `${line}\n\n${body}`);
});

test("an empty body is the watermark alone", () => {
  assert.equal(withWatermark("", line), line);
});

test("no watermark leaves the body alone", () => {
  assert.equal(withWatermark("hi", ""), "hi");
});

test("--body, -b, and --body= get the watermark", () => {
  assert.deepEqual(watermarkArgs(["pr", "comment", "5", "--body", "x"], line), ["pr", "comment", "5", "--body", `${line}\n\nx`]);
  assert.deepEqual(watermarkArgs(["issue", "create", "-b", "x"], line), ["issue", "create", "-b", `${line}\n\nx`]);
  assert.deepEqual(watermarkArgs(["pr", "edit", "--body=x"], line), ["pr", "edit", `--body=${line}\n\nx`]);
});

test("--body-file is copied with the watermark", () => {
  const args = watermarkArgs(["pr", "create", "-F", "in.md"], line, () => "from file");
  assert.equal(readFileSync(args[3], "utf8"), `${line}\n\nfrom file`);
});

test("reads and other commands pass through", () => {
  assert.deepEqual(watermarkArgs(["pr", "view", "5", "--body", "x"], line), ["pr", "view", "5", "--body", "x"]);
  assert.deepEqual(watermarkArgs(["api", "repos/x", "-F", "a=b"], line), ["api", "repos/x", "-F", "a=b"]);
});

test("GH_WRITE matches gh in command position only", () => {
  const yes = [
    "gh pr create --body x",
    "cd a && gh pr comment 5 -b x",
    "x=1; gh issue create -t t -b b",
    "gh pr edit 3 --body \"$(cat <<'EOF'\nhi\nEOF\n)\"",
    "cd a\ngh pr review 5",
    "echo $(gh pr create)",
  ];
  const no = ['git commit -m "run gh pr create"', "echo gh pr comment", "gh pr view 5"];
  for (const c of yes) assert.ok(GH_WRITE.test(c), c);
  for (const c of no) assert.ok(!GH_WRITE.test(c), c);
});

test("running gh.mjs removes the --body-file copy", () => {
  const bin = mkdtempSync(join(tmpdir(), "helmsman-fakegh-"));
  const out = join(bin, "args.txt");
  writeFileSync(join(bin, "gh"), `#!/bin/sh\nprintf '%s' "$4" > '${out}'\n`);
  chmodSync(join(bin, "gh"), 0o755);
  const body = join(bin, "in.md");
  writeFileSync(body, "hi");
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, HELMSMAN_WATERMARK: line };
  const run = spawnSync("node", [new URL("./gh.mjs", import.meta.url).pathname, "pr", "create", "-F", body], { env });
  assert.equal(run.status, 0);
  const used = readFileSync(out, "utf8");
  assert.match(used, /helmsman-wm-/);
  assert.ok(!existsSync(used));
});
