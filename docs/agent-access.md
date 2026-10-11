# Agent access

A Cursor cloud agent cannot read a private repository in another org. The GitHub App install is repo-scoped. `git clone` of that private repository fails. A failed clone is not an empty tree.

Two ways across that boundary:

1. Copy the skill folder into the consumer repository and invoke it there.
2. Use a multi-repo cloud environment, or grant the app access to the org.

## Reports

`.helmsman/*` stays gitignored, with `!.helmsman/setup.md` so the setup file stays tracked, and `!.helmsman/tools/` plus `!.helmsman/tools/**` so the harness stays tracked. Reports are not committed. A committed finding is a private note that should stay ignored. Git does not list files inside an ignored directory, so the tools directory has to be un-ignored before its contents.

Overnight files live in `.helmsman/reports/<UTC>/`, minute precision, for example `.helmsman/reports/2026-09-30T0629Z/readiness.md`. The same directory holds `slop.md` and `security.md`. One nightly run sets `HELMSMAN_REPORT_STAMP` so the three files share a directory.

`.helmsman/tools/checks/report-write.sh` is the write gate. It creates the directory and prints the path only when both are true:

1. `git check-ignore -q` accepts the path.
2. A write env is set: `HELMSMAN_WRITE_REPORTS=1`, or `CURSOR_AGENT=1` (Cursor cloud agent), or `GITHUB_ACTIONS=true`, or `CI=true`.

Cloud writes are opt-in via those env vars. A local shell sets none of them, so the default is chat-only unless `HELMSMAN_WRITE_REPORTS=1`. When the gate refuses, show the full report in the reply and do not create a file.

The delivery report is `DORA_OPERATIONAL_REPORT.md` under the ignore rule. It is not part of the overnight directory.

## Sidecar skills

Copy a Helmsman skill folder into the consumer's `.cursor/skills/`. Leave the consumer's rules and other skills in place. Do not replace `.cursor/` with this repository's copy. A skill folder that is already there is the consumer's; do not overwrite it.
