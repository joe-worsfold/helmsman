---
id: s2-async-worker
title: Add an async worker
checks: diff_guard, worker_ack, no_eval, integration_unmocked
allowed: src/worker.js, test/invoice.int.test.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: worker_ack, no_eval, integration_unmocked
---

Add a consumer for invoice jobs. Ack the job, and do not do the work twice for the same id. Do not pass the payload to `eval`. If you add an integration, run it against the fixture queue (`seen` and the sink). Do not mock that boundary.
