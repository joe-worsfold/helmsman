---
name: helmsman-delivery
description: >-
  Helmsman delivery. Measure deployment frequency, lead time, change-failure
  signals, restore time, and code churn from evidence you can show.
  Unknown when the data is not in the clone. Use for operational health,
  delivery metrics, rework, or the delivery report. Explicit invoke only.
user-invocable: true
disable-model-invocation: true
---

# helmsman-delivery

[Helmsman](../../../README.md) is a set of rules and checks for agent-written code. [helmsman-readiness](../helmsman-readiness/SKILL.md) asks what stops a bad change. [helmsman-slop](../helmsman-slop/SKILL.md) asks how much unnecessary code is already in the repo. This skill asks what recent delivery cost.

Answer one question: is the repository shipping reliably, or is rework showing up after merge?

Do not change code unless asked. Do not commit `DORA_OPERATIONAL_REPORT.md` unless asked.

A number you cannot show is **unknown**. Do not estimate. A proxy stays labeled a proxy. Revert commits are not change-failure rate unless you can also see the deployments they failed.

## Period

Last 90 days, unless the user names another window. Churn uses the last 30 days inside that window.

## Where to look

- `git log` for the window: merge time, revert commits, hotfix subjects
- CI workflows for deploy and release jobs
- Tags and releases, when the forge client can see them
- `CHANGELOG.md`, issue templates, and bug labels, when those files exist

Incident trackers, pager history, and deploy dashboards are not in the clone. If you cannot see them, restore time and true change-failure rate are unknown.

## Metrics

### Delivery

| Metric | Healthy signal | Warning signal | Counts when | Unknown when |
| --- | --- | --- | --- | --- |
| Deployment frequency | Several deploys a week | Fewer than one a sprint | A deploy job, release tag, or release workflow ran, and you can count the runs | You only see merges to the default branch |
| Lead time for changes | Under 24 hours from commit to production | Over 5 days | You can see when the change opened, when it merged, and the production deploy time | You can see the change time and not the deploy |
| Change failure rate | Under 5% of deploys | Over 15% | Failed deploys, or reverts tied to a deploy you can name | You only have revert commits in `git log` |
| Time to restore | Under 1 hour | Over 1 day | An incident or bug time, and the merge time of the fix | There is no incident source in what you can read |

Revert and hotfix commits are a **change-failure signal**, not change-failure rate. Report them as `reverts / merges` and say they are a signal.

### Rework

- **30-day rework.** Share of lines added in the last 30 days that a later commit in that window deletes or replaces. State the command. High is above 20%. This is a signal that merged work is being rewritten. It is not proof the cause was an agent.
- **Defect density.** Production bugs you can see, per 1,000 lines changed in the window. Unknown when bug records are not visible.
- **Escape rate.** Production bugs divided by bugs caught in pre-commit or CI. Unknown unless you can see both sides.

## Report

Show the report in the reply. Write `DORA_OPERATIONAL_REPORT.md` only when `git check-ignore -q DORA_OPERATIONAL_REPORT.md` succeeds. Otherwise do not create the file.

```markdown
# Delivery and operational impact

**Repository:** name
**Audit period:** last 90 days (state the dates)
**Helmsman:** helmsman-delivery

## Scorecard

- **Deployment frequency:** count and source, or unknown
- **Lead time for changes:** median, with the two timestamps you used, or unknown
- **Change failure rate:** percent, with failed and total deploys, or unknown
- **Change-failure signal:** reverts / merges, labeled as a signal
- **Time to restore:** median, with the incident source, or unknown

## Rework

- **30-day rework:** percent, the command, lines added, lines later removed
- **Defect density:** bugs per 1k lines, or unknown
- **Escape rate:** or unknown

## Reading

- **Status:** Healthy | At Risk | Critical | Incomplete
- Healthy needs a measured deploy frequency and either a measured change-failure rate under 5% or a revert signal you have shown is low. Incomplete means a required number is unknown.
- **What the numbers do not say:** one sentence on the proxy limits.

## Next

1. The single best measurement to un-unknown, or the single delivery change the numbers support.
```

## How the three readings sit together

Compare a repository with its previous Helmsman.

- A high readiness and a low Slop Density Index is the condition under which the delivery should stay healthy.
- A low readiness and a high Slop Density Index is a reason to expect more reverts. Fix the gates before you interpret the delivery as a people problem.
- A high readiness and a high index means the gate is newer than the slop already in the tree. Record it in the slop report, and fix it when the setup file allows. Do not add process to hide it.

Do not rank people or teams on these numbers.
