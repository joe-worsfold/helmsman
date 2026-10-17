import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { MARK, watermarkArgs, withWatermark } from "./gh.mjs";

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
