# Helmsman nightly

This is the overnight half of the product loop. The per-pull-request half is [helmsman-review](helmsman-review.md): advisory, checklist, no block.

Run once a night. Reports first. The fixer is off unless the setup file says so. Do not score some other repository from this one.

## Turn the fixer on

`.helmsman/setup.md` on the default branch holds the switch. The default is off:

```text
Nightly fix: no
Nightly max PRs: 3
Nightly max tokens: 200000
Nightly max minutes: 30
```

Set `Nightly fix: yes` to open draft pull requests after the reports. The three caps are the cost ceiling for that night. A missing cap uses the number above. A cap that is not a positive integer is a bad setup, and `.helmsman/tools/checks/nightly-plan.sh` fails. That script prints the plan. It does not open a pull request.

`Fix: yes` is a different switch. It allows one in-place edit when a person asks. The nightly fixer does not use it.

## Reports

Read `.helmsman/setup.md` when that file exists. `File issues` and `Fix` default to `no`. If the setup file is missing, still follow readiness and slop and print both reports. Do not file issues and do not open a pull request. A missing `.helmsman/tools/checks/report-write.sh` means the reply is the report.

Set `HELMSMAN_REPORT_STAMP` once, to the UTC minute (`date -u +%Y-%m-%dT%H%MZ`, for example `2026-09-30T0629Z`). Readiness, slop, and security share `.helmsman/reports/$HELMSMAN_REPORT_STAMP/`.

1. Follow [helmsman-readiness](../skills/helmsman-readiness/SKILL.md). Write `readiness.md` in that directory only when `.helmsman/tools/checks/report-write.sh readiness.md` exits 0. Otherwise the reply is the report. Keep the level and the score out of 5.
2. Follow [helmsman-slop](../skills/helmsman-slop/SKILL.md). Write `slop.md` on the same gate, with the readiness score at the top. The report includes the slop score trend: every prior `slop.md`, oldest first, then this run. That report is the slop findings. File those findings only when the slop skill's own rule allows it. A security finding that security will record is not filed from here.
3. Follow [helmsman-security](../skills/helmsman-security/SKILL.md). Write `security.md` on the same gate. That report is the security findings and how to fix each one. File those findings only when `File issues: yes` and `Issues: github`. Otherwise leave the report in the reply and say issues were not filed.
4. Fix forward findings that are not already filed go through `.helmsman/tools/checks/fix-forward.sh`, one issue per finding. The label is `fix-forward` and the priority is P4. The script does nothing when `gh` has no auth, when `File issues` is not `yes`, or when an open issue already has that title. A finding that the slop skill or security already filed is not sent here again.

The write gate is `.helmsman/tools/checks/report-write.sh`. It writes only when `git check-ignore -q` accepts the path and a write env is set (`HELMSMAN_WRITE_REPORTS=1`, `CURSOR_AGENT=1`, `GITHUB_ACTIONS=true`, or `CI=true`). `CURSOR_AGENT=1` is the Cursor cloud agent. `GITHUB_ACTIONS=true` and `CI=true` are CI. A local shell sets none of those, so the default is the chat reply. Reports stay gitignored. Do not commit them.

Issue titles and bodies, when filing is allowed, follow [docs/issue-body.md](../../docs/issue-body.md). A report that is not filed is still the deliverable.

## Fixer

Run `.helmsman/tools/checks/nightly-plan.sh`. When it says the fixer is off, stop. Do not open a pull request.

When it says the fixer is on:

1. Take the open `fix-forward` issues it listed, then the top slop findings that are not already those issues. Order the slop findings P1, then P2, then P3. Skip P4 and nits. Skip a finding security already filed.
2. Stop at `max_prs`. Also stop when this run's token use reaches `max_tokens`, or when the wall clock reaches `max_minutes`. Record the stop reason and what was left.
3. Open one small draft pull request per item. Follow [helmsman-fix-forward](../skills/helmsman-fix-forward/SKILL.md) for the edit. One finding. The smallest change. No drive-by rewrite.
4. Branch `nightly/<slug>`. In a STAR repo, `agent/<domain>/fix-<finding>` for the domain that owns the defect.
5. Title `fix(<scope>): <what the fix does>`. The body links the issue and includes `Closes #<n>` when there is an issue number.
6. Each pull request follows review before ready. Run helmsman-review on the full diff. Fix every Blocker, unjustified Judo, High, and Medium finding. Post the review with `Verdict`, `Reviewed`, `Base`, and `Patch`. Prove it with the pre-commit hook and `pnpm check`. Mark it ready so CI runs, and stay until that run is green.
7. Leave the pull request open. Do not merge.

Do not start feature work.
