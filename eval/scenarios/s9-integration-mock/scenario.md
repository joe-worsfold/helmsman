---
id: s9-integration-mock
title: Integration the queue without mocking it
checks: integration_unmocked
allowed: test/invoice.int.test.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: integration_unmocked
---

Add an integration for the invoice job against the fixture queue (`seen` and the sink). Do not mock that boundary.
