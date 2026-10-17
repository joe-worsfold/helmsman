import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { MARK, watermarkArgs, withFooter } from "./gh.mjs";

const footer = `${MARK} Driver: a. Model: m. Skills: none.`;

test("the footer goes after a blank line, once", () => {
  assert.equal(withFooter("hi\n\n", footer), `hi\n\n${footer}`);
  assert.equal(withFooter(`hi\n\n${footer}`, footer), `hi\n\n${footer}`);
});

test("a body that quotes the footer mid-text still gets one", () => {
  const body = `It appends \`${MARK} Driver: ...\` to the message.\n\nMore text.`;
  assert.equal(withFooter(body, footer), `${body}\n\n${footer}`);
});

test("no footer leaves the body alone", () => {
  assert.equal(withFooter("hi", ""), "hi");
});

test("--body, -b, and --body= get the footer", () => {
  assert.deepEqual(watermarkArgs(["pr", "comment", "5", "--body", "x"], footer), ["pr", "comment", "5", "--body", `x\n\n${footer}`]);
  assert.deepEqual(watermarkArgs(["issue", "create", "-b", "x"], footer), ["issue", "create", "-b", `x\n\n${footer}`]);
  assert.deepEqual(watermarkArgs(["pr", "edit", "--body=x"], footer), ["pr", "edit", `--body=x\n\n${footer}`]);
});

test("--body-file is copied with the footer", () => {
  const args = watermarkArgs(["pr", "create", "-F", "in.md"], footer, () => "from file");
  assert.equal(readFileSync(args[3], "utf8"), `from file\n\n${footer}`);
});

test("reads and other commands pass through", () => {
  assert.deepEqual(watermarkArgs(["pr", "view", "5", "--body", "x"], footer), ["pr", "view", "5", "--body", "x"]);
  assert.deepEqual(watermarkArgs(["api", "repos/x", "-F", "a=b"], footer), ["api", "repos/x", "-F", "a=b"]);
});
