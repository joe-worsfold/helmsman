# Secrets

`.helmsman/tools/secrets/check.sh` is the secret gate. `.helmsman/tools/checks/languages.sh` runs it on every commit and in CI.

Three layers, in this order:

1. Built-in patterns on tracked files: cloud access-key prefixes, a private-key block, and common token prefixes. `eval/scenarios/` is excluded because the fail patches contain the patterns on purpose.
2. `gitleaks detect` when `gitleaks` is on `PATH`. A `.gitleaks.toml` without the binary fails the commit.
3. `secretlint` when a `.secretlintrc*` file is present. The binary must already be installed (`secretlint` or `npx --no-install secretlint`). A config without the binary fails the commit.

The built-in scan does not replace gitleaks when gitleaks is installed. A clean built-in run with gitleaks absent is a narrower gate. Say so when you score the readiness.

This package does not start from a product name. A secretlint config is the opt-in for a repo that already uses that tool.
