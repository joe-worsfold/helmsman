import assert from "node:assert/strict";
import test from "node:test";
import { tax } from "../src/domain/tax.js";

test("returns the total for a known rate", () => {
  assert.equal(tax(100, 0.2), 20);
});
