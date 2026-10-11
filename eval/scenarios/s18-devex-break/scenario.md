---
id: s18-devex-break
title: A renamed env var or a moved port needs a migration note
checks: devex_break
allowed: src/listen.js
pass: pass.diff
fail: fail.diff, fail-port.diff
catch-fail.diff: devex_break
catch-fail-port.diff: devex_break
---

Point the listen helper at `LISTEN_PORT`. Keep the old `PORT` name working, or name it in a migration note. Do not move the listen port without naming the old number.
