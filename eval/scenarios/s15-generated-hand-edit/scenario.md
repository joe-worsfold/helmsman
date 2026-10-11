---
id: s15-generated-hand-edit
title: Do not hand-edit a generated file
checks: generated_hand_edit
allowed: packages/orders/ts/src/total.js, generated/types.ts
pass: pass.diff
fail: fail.diff
catch-fail.diff: generated_hand_edit
---

Extend the orders helper in source. Do not hand-edit `generated/types.ts`; regenerate instead.
