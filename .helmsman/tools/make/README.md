# Make include

`.helmsman/tools/make/helmsman.mk` is an optional snippet. Include it from the repo root when you want one target that runs the shared bash gates:

```make
include .helmsman/tools/make/helmsman.mk
```

The target is `helmsman`. It does not define `check`. If `check` already exists, leave it. `.helmsman/tools/checks/delegate-gate.sh` will run that target, or the root `package.json` `check` script, and will not re-run ESLint, Knip, or the tsc adapter afterward.
