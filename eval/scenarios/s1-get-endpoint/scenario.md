---
id: s1-get-endpoint
title: Add a new GET JSON endpoint with validation
checks: diff_guard, schema_parse, thin_handler, layer_leak
allowed: src/server.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: diff_guard, schema_parse, thin_handler, layer_leak
---

Add `GET /invoices` that returns JSON `{ id }`. Validate the `id` query with `parseQuery` before use. Keep the handler thin. Do not skip or suppress a check.
