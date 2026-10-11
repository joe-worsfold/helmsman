---
id: s17-concept-move
title: Do not move the tax formula into a helper that only forwards
checks: concept_move
allowed: src/domain/tax.js, test/tax.test.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: concept_move
---

Cover a zero rate on `tax`. Keep the formula in `tax`. Do not add a function whose only job is to return that formula.
