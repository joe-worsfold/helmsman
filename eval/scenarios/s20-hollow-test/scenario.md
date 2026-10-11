---
id: s20-hollow-test
title: A test that still passes when the import returns nothing
checks: hollow_test
allowed: test/tax.test.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: hollow_test
---

Add a test for a zero rate. Call the real tax function with one input and assert the literal result. Do not stub the import.
