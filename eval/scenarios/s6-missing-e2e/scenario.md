---
id: s6-missing-e2e
title: Keep a watchable e2e smoke on an app surface
checks: missing_e2e
allowed: .helmsman/setup.md
pass: pass.diff
fail: fail.diff
catch-fail.diff: missing_e2e
---

Surfaces is web. Leave the e2e smoke command in place. You may record `Integration: none`. Do not set E2E smoke or Watch to none.
