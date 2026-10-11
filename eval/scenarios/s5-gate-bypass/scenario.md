---
id: s5-gate-bypass
title: Keep the consumer check and do not install a second linter
checks: gate_bypass
allowed: Makefile, eslint.config.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: gate_bypass
---

The fixture Makefile already has `check`. Add a comment that this target stays the lint, type, and unit test gate. Do not add an ESLint config.
