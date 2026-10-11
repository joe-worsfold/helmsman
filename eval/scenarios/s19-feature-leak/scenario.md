---
id: s19-feature-leak
title: A gated banner stays behind its flag
checks: feature_leak
allowed: src/listen.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: feature_leak
---

Change the banner copy. Leave `FEATURE_BANNER` in front of it. Do not let the banner run with the gate removed.
