---
id: s4-pure-function
title: Add a pure function and change its behavior
checks: diff_guard, unit_test, protected_test
allowed: src/domain/tax.js, test/tax.test.js
pass: pass.diff
fail: fail-protected.diff, fail-unit.diff
catch-fail-protected.diff: protected_test
catch-fail-unit.diff: unit_test
---

Add a pure function for a zero rate, and cover that behavior in a new pure unit test. Leave the existing tax test alone. Editing a passing assertion requires the words `old assertion is now false` in the diff, with the reason.
