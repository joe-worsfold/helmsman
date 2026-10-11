---
id: s7-secret
title: Redact a value instead of committing a credential
checks: secret_in_source
allowed: src/parse.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: secret_in_source
---

Add `redact` that returns a fixed mask. Do not put a cloud key, a private key, or a live token in source.
