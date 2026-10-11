---
name: helmsman-tests
description: >-
  Choose e2e smoke, integration, or unit test before writing a test. Use when starting
  feature work, adding a journey, or deciding which test layer a change needs.
user-invocable: true
---

# helmsman-tests

[Helmsman](../../../README.md) is how you navigate agent-written code. The rule [helmsman-tests](../../rules/helmsman-tests.mdc) is the procedure once a test file is open. Do not paste that procedure here. This skill is how you choose the layer before that.

Read the journey the repo already runs. A native command counts: `pnpm test:e2e`, Playwright, Cypress, Maestro, or a pull-request smoke job. `.helmsman/setup.md` is optional. If it is missing, do not stop and do not start [helmsman-setup](../helmsman-setup/SKILL.md). A missing `Watch` line, `Integration` line, `e2e-smoke.sh`, `integration.sh`, or `languages.sh` does not block the work. Those names are the adapter when a full install runs them.

## Which layer

1. A person must be able to watch the change happen. That is an end-to-end journey, on the runner the repo already uses. End-to-end is three facts: local, pre-merge critical smoke, and post-deploy or full. Only the pre-merge smoke gates a merge. The exhaustive suite does not replace the smoke. When a native command exists, use it.
2. The change can pass that journey and still be wrong where code meets infrastructure. That is an integration test, against the real local dependency. Do not mock that boundary. An `Integration` line is the Helmsman adapter when a full install runs it. It is not required to choose this layer.
3. The change is a pure function: no I/O, clock, randomness, or hidden state. That is a pure unit test (unit). Those functions are covered completely.

In STAR: the unit test is `cargo test` on pure functions in `packages/<domain>/rs`. The integration is that domain's repository and routes against a local SurrealDB, run by the setup file's `Integration` line. The e2e smoke is Playwright for `apps/web` and Maestro for `apps/mobile`. Each test stays inside the lane it tests.

Side-effecting code does not get a pure unit test. Integration is not a start gate. A new behavior gets a new test. A passing test stays put unless the user has allowed the edit in this conversation.

A test that still passes when every import returns nothing does not pin behavior. Call the real function with one concrete input and assert the literal result. Do not assert `toBeDefined`, `toBeTruthy`, `toHaveBeenCalled`, or a value the test itself stubbed. The eval catch for that shape is `hollow_test`.

If the repo has an app and neither a native journey nor a recorded e2e smoke command exists, name the three facts that are missing. That is guidance. Do not refuse the feature in order to create a setup file.

Do not add a second end-to-end runner. In a full Helmsman install, the setup file names the one runner.

## Sources

cursor/plugins@`978ca6e9c0e012047cd5058b8e829240336e704e` `pstack/skills/principle-test-behavior-not-implementation/SKILL.md` (a test that still passes when imports return nothing). MIT.
