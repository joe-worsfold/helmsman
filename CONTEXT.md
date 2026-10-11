# Helmsman

Short names for the parts of this repository.

**Helmsman**
Rules, skills, and checks for agent-written code. The folder is `.helmsman/`.

**STAR**
The one stack: SurrealDB, TypeScript, Agent-first, Rust. One repo, one graph, strict domain lanes.

**Readiness**
What stops a bad change. A check counts only when a command or a CI job fails the commit or the pull request.

**Delivery**
How often work shipped, how long it took, how often it failed, how long restore took, and how much merged work was rewritten.

**Slop**
Unnecessary code, scored beside the readiness score.

**Security**
Each security finding, and how to fix it. The skill records the finding. It does not edit the code.

**Fix**
Works through one fix-forward issue, or one finding from a slop or security report.

**Setup**
Copying the rules, skills, hook, and checks into a repository, and writing `.helmsman/setup.md`.

**Tests**
Choosing an end-to-end smoke, an integration test, or a unit test before writing the test.

**Prove**
One claim on the same surface, with a baseline and a treatment. Evidence stays under `.helmsman/reports/prove/`.

**Review**
A pass over a pull request. It reads the checklist. It does not edit the code unless the author is finishing the pull request.

**Checklist**
The verdict is Approve or Request changes. Finding labels are Blocker, Judo, High, Medium, Low, Fix forward, and Nit.

**Approve**
Ok to merge. No Blocker, no unjustified Judo, and no High or Medium finding.

**Request changes**
Do not merge until those findings are fixed.

**Blocker**
A presumptive blocker. Fix it before merge.

**Judo**
A restructuring that deletes complexity. Fix it before merge unless the comment says why the simpler shape is not available.

**Fix forward**
Deferred. The fix-forward script can open an issue.

**Nit**
Cosmetic. Optional.

**E2E smoke**
The critical-path end-to-end command. A person can watch it.

**Integration**
A test that runs code against the real local service. Not a start gate.

**Unit test**
A test of a pure function. No I/O, clock, randomness, or hidden state.

**Protected test**
A passing test whose assertions stay. New behavior gets a new test.

**Lane**
One domain's package, its slice of each app, and the tables it owns.

**Handoff**
A change another lane needs. It is written in the pull request, not made in this diff.

**Upstream**
A pinned third-party source. Setup does not copy the snapshot. The snapshot is not loaded as a skill.

**Correct**
Turn a mistake agents repeat into a check that fails.

**Decision log**
One row per decision on a long or unattended run. The default file is gitignored.

**Fix-forward**
A minor finding filed as a low-priority issue for a later agent. Off unless `File issues` is `yes` and `gh` is authenticated.
