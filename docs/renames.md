# Old names

This file is the history of the nautical names Helmsman used before the plain-language rename. New text does not use those names. The plain-language check allows this file, the brand name Helmsman, and the `.helmsman/` directory.

`upstream` is not in this table. It means a pinned third-party source.

## Skills

| Old | New | What it does |
| --- | --- | --- |
| helmsmans-rig | helmsman-setup | Copies rules, skills, and checks into a repo and writes the setup file |
| helmsmans-keel | helmsman-readiness | Scores how ready a repo is for agentic coding: whether its checks can actually fail a commit or a pull request |
| helmsmans-bilge | helmsman-slop | Scores the slop in production code. The intermediate name was helmsman-maintain |
| helmsmans-caulk | helmsman-security | Records security findings and how to fix them |
| helmsmans-bail | helmsman-fix-forward | Works through one fix-forward issue or finding. The intermediate name was helmsman-fix |
| helmsmans-wake | helmsman-delivery | Measures delivery cost |
| helmsmans-bearings | helmsman-tests | Chooses an end-to-end smoke, an integration test, or a unit test |
| helmsmans-review | helmsman-review | Reviews a diff |
| helmsmans-gale | helmsman-structure | Optional strict structural pass |
| helmsmans-reef | helmsman-shortcuts | Ledger of `shortcut:` comments |

## Automations

| Old | New | What it does |
| --- | --- | --- |
| helmsmans-nightwatch | helmsman-nightly | Nightly readiness, slop, and security reports. The fixer stays off until `Nightly fix: yes` |
| helmsmans-lookout | helmsman-upstream | Weekly diff of pinned third-party sources |
| helmsmans-review | helmsman-review | Advisory pull-request review |

## Rules

| Old | New |
| --- | --- |
| helmsmans-bearings.mdc | helmsman-tests.mdc |
| helmsmans-checklist.mdc | helmsman-checklist.mdc |

## Scripts and commands

| Old | New |
| --- | --- |
| rigging.sh | setup-check.sh |
| sail.sh | integration.sh |
| crows-nest.sh | e2e-smoke.sh |
| pnpm rigging | pnpm setup:check |
| pnpm test:sail | pnpm test:integration |
| lefthook `1_helmsman-rigging` | lefthook `1_helmsman-setup` |

## CI jobs

| Old | New |
| --- | --- |
| rigging | setup |
| test (sail) / test-sail | test (integration) / test-integration |
| test (mast) / test-mast | test (unit) / test-unit |

## Files

| Old | New |
| --- | --- |
| .helmsman/rigging.md | .helmsman/setup.md |
| docs/self-keel.md | docs/readiness.md |
| keel.md | readiness.md |
| water.md | slop.md |
| leaks.md | security.md |
| eval/scenarios/s6-missing-nest | eval/scenarios/s6-missing-e2e |
| eval/scenarios/s9-sail-mock | eval/scenarios/s9-integration-mock |
| fail-mast.diff | fail-unit.diff |
| fail-knot.diff | fail-protected.diff |

## Setup-file keys

| Old | New |
| --- | --- |
| # Rigging | # Setup |
| Crow's nest | E2E smoke |
| Sail | Integration |
| Bail | Fix |
| Lookout PR | Upstream PR |

`Watch` was already a plain key. It stays.

## Review answers

| Old | New |
| --- | --- |
| Sail | pass |
| sink | block |
| beached | revise |

`sink` in this row is the old review answer. An injection sink is a different word and stays.

## Review vocabulary

The first rename used pass, block, and revise. The current words match a thermonuclear review, and the verdict matches GitHub's review states.

| Older | Current | Role |
| --- | --- | --- |
| pass (Sail before that) | Approve | Verdict when nothing must be fixed before merge |
| block (sink before that) | Blocker | Finding. A presumptive blocker. Fix before merge. The verdict is Request changes |
| revise (beached before that) | Judo | Finding. A restructuring that deletes complexity. Fix before merge unless the comment justifies the current shape. Unjustified Judo is Request changes |
| | High, Medium, Low | Finding priority. The evidence scale sits beside the label. High and Medium request changes. Low does not |
| a pass leftover | Fix forward | Finding. Deferred. The script opens a `fix-forward` issue |
| | Nit | Cosmetic finding. Optional |
| | Request changes | Verdict when a Blocker, an unjustified Judo, a High, or a Medium finding is open |

Readiness scores stay `pass`, `fail`, `unknown`, and `n/a`. Those are not review verdicts.

## Eval check ids

| Old | New |
| --- | --- |
| sail_unmocked | integration_unmocked |
| ui_nest | ui_e2e |
| mast_knot | unit_test |
| knot_law | protected_test |
| missing_nest | missing_e2e |
| bilgeMode | slopMode |

## Words

| Old | New |
| --- | --- |
| mast | unit test |
| sail | integration test |
| crow's nest | e2e smoke |
| rigging | setup |
| knot | protected test |
| bearings | tests |
| keel | readiness |
| bilge | slop |
| caulk | security |
| bail | fix |
| wake | delivery |
| gale | structure |
| reef | shortcuts |
| lookout | upstream watch |
| nightwatch | nightly |
| north star | quality of what shipped |

## Later names

An earlier pass on this branch used these intermediate names. Re-running setup renames them to the current name. A second run changes nothing.

| Intermediate | Current |
| --- | --- |
| helmsman-maintain | helmsman-slop |
| maintain.md | slop.md |
| maintainMode | slopMode |
| maintainability, when it names this score | slop |
| helmsman-fix | helmsman-fix-forward |
| Kept test | protected test |
| kept_test | protected_test |
| fail-kept.diff | fail-protected.diff |
