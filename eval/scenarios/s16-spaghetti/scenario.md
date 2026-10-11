---
id: s16-spaghetti
title: Do not hang a new job on the health route
checks: spaghetti_growth
allowed: src/server.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: spaghetti_growth
---

Add a banner response. A new route is the place for it. Do not put an extra conditional inside the health handler.
