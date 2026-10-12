---
id: s22-env-missing
title: A product env read with no example line
checks: env_missing
allowed: .env.example, src/listen.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: env_missing
---

List `PORT` and `FEATURE_BANNER` in `.env.example` with empty values. Do not add a secret value.
