import assert from "node:assert/strict";
import test from "node:test";
import { renderHome } from "../src/pages/home.js";

test("home journey shows the page", () => {
  const html = renderHome();
  assert.match(html, /data-testid="home-page-region"/);
});
