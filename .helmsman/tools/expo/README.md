# Expo and React Native

Maestro is an e2e smoke runner, the same slot as Cypress and Playwright. One runner. The setup-file line for a mobile app that already uses it is `pnpm mobile:e2e` (or `pnpm mobile:e2e:headless` when that is what a person watches). `.helmsman/tools/checks/e2e-smoke.sh` prints that the runner is Maestro when the command contains `maestro` or `mobile:e2e`. Do not add a second Maestro job beside that script.

`mobile:e2e` is not part of the default check. A root `package.json` `check` script that lints and typechecks does not run Maestro, and Helmsman does not run it from `languages.sh`.

`.helmsman/tools/expo/doctor.sh` is opt-in. It exits 0 unless `HELMSMAN_EXPO_DOCTOR=1`. Then it runs `mobile:doctor` or `expo:doctor` when that script exists, otherwise `npx --no-install expo-doctor`.

Do not install ESLint for a tree whose typecheck is `tsc` and whose check command already ran.
