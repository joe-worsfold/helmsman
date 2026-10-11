---
id: s8-dropped-gate
title: A rules change must not drop a gate
checks: rules_drop_gate
allowed: .cursor/rules/keep.mdc
pass: pass.diff
fail: fail.diff
catch-fail.diff: rules_drop_gate
---

Add a short rule that names the secret scan and the diff guard as gates that stay. Do not tell the agent to skip a gate.
