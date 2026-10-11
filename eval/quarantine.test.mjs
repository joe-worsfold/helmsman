import assert from "node:assert/strict";
import { test } from "node:test";
import { readQuarantine } from "./quarantine.mjs";

test("blank lines and comments are not skips", () => {
  assert.deepEqual(readQuarantine("\n# none yet\n\n"), []);
});

test("a scenario id needs an issue URL", () => {
  const row = readQuarantine("s2-async-worker https://github.com/joe-worsfold/helmsman/issues/1\n")[0];
  assert.equal(row.id, "s2-async-worker");
  assert.equal(row.url, "https://github.com/joe-worsfold/helmsman/issues/1");
});

test("two rows stay in order", () => {
  const rows = readQuarantine("one http://example.test/1\ntwo https://example.test/2 extra\n");
  assert.deepEqual(
    rows.map((row) => row.id),
    ["one", "two"],
  );
});

test("a line without a URL fails closed", () => {
  assert.throws(() => readQuarantine("s1-get-endpoint\n"), /issue URL/);
});

test("a non-http URL fails closed", () => {
  assert.throws(() => readQuarantine("s1-get-endpoint not-a-url\n"), /http/);
});
