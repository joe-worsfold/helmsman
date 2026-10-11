---
id: s14-overwrite-kept
title: Do not overwrite a kept file
checks: overwrite_kept
keep: KEEP.md
allowed: packages/orders/ts/src/total.js, KEEP.md
pass: pass.diff
fail: fail.diff
catch-fail.diff: overwrite_kept
---

Add a helper in orders. Do not delete or rewrite KEEP.md; the task did not name it.
