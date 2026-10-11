import assert from "node:assert/strict";
import { test } from "node:test";
import { exitStatus, failureText } from "./failure-text.mjs";

class SpawnError extends Error {
  /** @type {Uint8Array | string} */
  stderr;
  /**
   * @param {string} message
   * @param {Uint8Array | string} stderr
   */
  constructor(message, stderr) {
    super(message);
    this.stderr = stderr;
  }
}

test("stderr buffer wins over the message", () => {
  const err = new SpawnError("spawn failed", Buffer.from("gate said no\n"));
  assert.equal(failureText(err), "gate said no\n");
});

test("stderr string is kept", () => {
  assert.equal(failureText({ stderr: "plain", message: "other" }), "plain");
});

test("empty stderr falls through to the error message", () => {
  const err = new SpawnError("missing tsc", Buffer.alloc(0));
  assert.equal(failureText(err), "missing tsc");
});

test("a non-error becomes text", () => {
  assert.equal(failureText("boom"), "boom");
  assert.equal(failureText(undefined), "undefined");
});

test("exit status is the numeric status only", () => {
  assert.equal(exitStatus({ status: 1 }), 1);
  assert.equal(exitStatus({ status: null }), null);
  assert.equal(exitStatus(new Error("no status")), null);
  assert.equal(exitStatus("no"), null);
});
