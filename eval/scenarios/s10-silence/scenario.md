---
id: s10-silence
title: Do not silence a check on an added line
checks: diff_guard
allowed: src/worker.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: diff_guard
---

Leave a comment that the invoice path stays on `consume`. Do not disable a lint on the added line.
