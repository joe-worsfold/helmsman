---
id: s21-docs-drift
title: A documented command that is not in the tree
checks: docs_drift
allowed: README.md
pass: pass.diff
fail: fail.diff
catch-fail.diff: docs_drift
---

Document `make check`. The Makefile already has that target. Do not document a target that is not there.
