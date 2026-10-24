import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fillsBody, GH_WRITE, MARK, realPath, watermarkArgs, withWatermark } from "./gh.mjs";

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
  for (const get of [["-X", "GET"], ["--method", "get"], ["-XGET"], ["--method=GET"]]) {
    assert.deepEqual(watermarkArgs(["api", ...get, "search", "-f", "body=x"], line), ["api", ...get, "search", "-f", "body=x"]);
  }
});

test("gh api body fields get the watermark", () => {
  const wm = `body=${line}\n\nx`;
  assert.deepEqual(watermarkArgs(["api", "r/comments", "-f", "body=x"], line), ["api", "r/comments", "-f", wm]);
  assert.deepEqual(watermarkArgs(["api", "r/comments", "--raw-field", "body=x"], line), ["api", "r/comments", "--raw-field", wm]);
  assert.deepEqual(watermarkArgs(["api", "r/comments", "-F", "body=x"], line), ["api", "r/comments", "-F", wm]);
  assert.deepEqual(watermarkArgs(["api", "r/comments", "--field=body=x"], line), ["api", "r/comments", `--field=${wm}`]);
  assert.deepEqual(watermarkArgs(["api", "r/comments", "-fbody=x"], line), ["api", "r/comments", `-f${wm}`]);
  assert.deepEqual(watermarkArgs(["api", "graphql", "-f", "query=q", "-f", "body=x"], line), ["api", "graphql", "-f", "query=q", "-f", wm]);
});

test("gh api body=@file and --input are copied with the watermark", () => {
  const field = watermarkArgs(["api", "r", "-F", "body=@in.md"], line, () => "from file");
  assert.match(field[3], /^body=@.*helmsman-wm-/);
  assert.equal(readFileSync(field[3].slice(6), "utf8"), `${line}\n\nfrom file`);
  const input = watermarkArgs(["api", "r", "--input", "in.json"], line, () => '{"body":"hi","event":"COMMENT"}');
  assert.deepEqual(JSON.parse(readFileSync(input[3], "utf8")), { body: `${line}\n\nhi`, event: "COMMENT" });
  assert.deepEqual(watermarkArgs(["api", "r", "--input", "in.json"], line, () => '{"title":"t"}'), ["api", "r", "--input", "in.json"]);
  assert.deepEqual(watermarkArgs(["api", "r", "--input", "in.bin"], line, () => "not json"), ["api", "r", "--input", "in.bin"]);
  const stdin = watermarkArgs(["api", "r", "--input", "-"], line, () => "not json");
  assert.equal(readFileSync(stdin[3], "utf8"), "not json");
});

test("--fill with no body is edited after create", () => {
  assert.ok(fillsBody(["pr", "create", "--fill"]));
  assert.ok(fillsBody(["pr", "create", "-f", "--base", "main"]));
  assert.ok(!fillsBody(["pr", "create", "--fill", "--body", "x"]));
  assert.ok(!fillsBody(["pr", "create", "--fill", "--body=x"]));
  assert.ok(!fillsBody(["issue", "create", "--fill"]));
});

test("the real gh is found with every watermark bin directory off PATH", () => {
  assert.equal(realPath("/r/.helmsman/tools/watermark/bin:/u/helmsman/watermark/bin/:/opt/bin:/usr/bin"), "/opt/bin:/usr/bin");
});

test("GH_WRITE matches a gh write anywhere in the command", () => {
  const yes = [
    "gh pr create --body x",
    "cd a && gh pr comment 5 -b x",
    "x=1; gh issue create -t t -b b",
    "gh pr edit 3 --body \"$(cat <<'EOF'\nhi\nEOF\n)\"",
    "cd a\ngh pr review 5",
    "echo $(gh pr create)",
    'bash -c "gh pr comment 5 -b x"',
    "command gh pr create",
    "printf 5 | xargs gh pr comment -b x",
    "gh api repos/o/r/issues/5/comments -f body=x",
    "gh api repos/o/r/pulls/5/reviews --input review.json",
    "gh api graphql -f query=q \\\n  -f body=x",
  ];
  const no = ["gh pr view 5", "gh issue list", "ghost pr create", "git log", "gh api repos/o/r/check-runs/1"];
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

// A fake gh that appends its arguments, one call per line, and prints a pull request URL on create.
function fakeGh() {
  const bin = mkdtempSync(join(tmpdir(), "helmsman-fakegh-"));
  const log = join(bin, "calls.txt");
  const script = [
    "#!/bin/sh",
    `printf '%s|' "$@" >> '${log}'; printf '\\n' >> '${log}'`,
    'case "$1 $2" in',
    `  "pr create") echo https://github.com/o/r/pull/7 ;;`,
    `  "pr view") echo "from commits" ;;`,
    'esac',
    'case "$*" in *--body-file*) eval "f=\\${$#}"; cat "$f" >> ' + `'${log}'` + '; printf "\\n" >> ' + `'${log}'` + ' ;; esac',
  ].join("\n");
  writeFileSync(join(bin, "gh"), `${script}\n`);
  chmodSync(join(bin, "gh"), 0o755);
  return { bin, log };
}

test("the hook's command reaches the wrapper from a subshell and bash -c", () => {
  const { bin, log } = fakeGh();
  const hook = new URL("./hook.mjs", import.meta.url).pathname;
  const command = `(gh pr comment 5 --body one); bash -c "gh pr comment 6 --body two"; command gh pr view 5`;
  const event = JSON.stringify({ tool_name: "Bash", tool_input: { command } });
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, HELMSMAN_DRIVER: "a" };
  const out = spawnSync("node", [hook], { input: event, env, encoding: "utf8" });
  const rewritten = JSON.parse(out.stdout).hookSpecificOutput.updatedInput.command;
  assert.match(rewritten, /^export HELMSMAN_WATERMARK=/);
  const again = spawnSync("node", [hook], { input: JSON.stringify({ tool_name: "Bash", tool_input: { command: rewritten } }), env, encoding: "utf8" });
  assert.equal(again.stdout, "");
  assert.equal(spawnSync("bash", ["-c", rewritten], { env }).status, 0);
  const calls = readFileSync(log, "utf8").trim().split("\n");
  for (const n of [5, 6]) {
    assert.ok(calls.some((c) => c.startsWith(`pr|comment|${n}|--body|> Sent by an agent for @a.`)), calls.join("\n"));
  }
  assert.equal(calls.at(-1), "pr|view|5|");
});

test("gh pr create --fill edits the filled body to start with the watermark", () => {
  const { bin, log } = fakeGh();
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, HELMSMAN_WATERMARK: line };
  const run = spawnSync("node", [new URL("./gh.mjs", import.meta.url).pathname, "pr", "create", "--fill"], { env, encoding: "utf8" });
  assert.equal(run.status, 0);
  assert.equal(run.stdout, "https://github.com/o/r/pull/7\n");
  const calls = readFileSync(log, "utf8");
  assert.match(calls, /^pr\|create\|--fill\|\npr\|view\|https:\/\/github.com\/o\/r\/pull\/7\|--json\|body\|-q\|\.body\|\npr\|edit\|https:\/\/github.com\/o\/r\/pull\/7\|--body-file\|.*\n> Sent by an agent for @a\. Model: m\. Skills: none\.\n\nfrom commits\n$/);
});
