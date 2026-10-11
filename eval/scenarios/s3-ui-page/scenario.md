---
id: s3-ui-page
title: Add a UI page with a watchable journey
checks: diff_guard, ui_e2e, ui_selector, ui_no_sleep
allowed: src/pages/invoice.js, e2e/invoice.e2e.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: ui_e2e, ui_selector, ui_no_sleep
---

Add an invoice page a person can see. The fixture setup file says `Surfaces: web`, so add an end-to-end protected test under `e2e/`. Use a stable `data-testid`. Do not wait with a fixed sleep.
