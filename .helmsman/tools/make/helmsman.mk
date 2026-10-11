# Optional include from a consumer Makefile at the repo root:
#   include .helmsman/tools/make/helmsman.mk
# Defines the target `helmsman`. It does not define `check`.
# A consumer `check` target, or a root package.json "check" script, stays theirs.

.PHONY: helmsman
helmsman:
	.helmsman/tools/checks/setup-check.sh
	.helmsman/tools/checks/diff-guard.sh
	.helmsman/tools/checks/plain-language.sh
	.helmsman/tools/checks/languages.sh
	.helmsman/tools/checks/pnpm-lock.sh
	.helmsman/tools/checks/web-drift.sh
