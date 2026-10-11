---
id: s11-lane-overreach
title: Stay in the orders lane
checks: lane_bound
lane: packages/orders
allowed: packages/orders/ts/src/total.js, packages/customers/ts/src/name.js
pass: pass.diff
fail: fail.diff
catch-fail.diff: lane_bound
---

On the orders lane, add a free-shipping helper in `packages/orders`. Do not edit `packages/customers`.
