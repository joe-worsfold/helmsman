import assert from "node:assert/strict";
import { test } from "node:test";
import {
  COLLAPSED_END_TO_END,
  COMPLEXITY_THRESHOLD,
  EXCLUDED,
  RECOMMENDED_E2E,
  band,
  slopMode,
  complexityMass,
  complexityNote,
  coveragePercent,
  defensiveBad,
  deltaIsEmpty,
  emptyDeltaText,
  endToEnd,
  endToEndHeadline,
  filesInBad,
  gateRow,
  level1,
  levelGroup,
  ownersReport,
  slopDensity,
} from "./readiness.mjs";

test("native pull-request lint, typecheck, unit, and integration pass", () => {
  const lint = gateRow({ runs: true, kind: "native" });
  const types = gateRow({ runs: true, kind: "native" });
  const unit = gateRow({ runs: true, kind: "native" });
  const integration = gateRow({ runs: true, kind: "native" });
  for (const row of [lint, types, unit, integration]) {
    assert.equal(row.capability, "pass");
    assert.equal(row.adapter, "native");
  }
  const copied = gateRow({ runs: false, kind: "helmsman" });
  assert.equal(copied.capability, "fail");
  assert.equal(copied.adapter, "absent");
});

test("CODEOWNERS passes owners while branch protection stays unknown", () => {
  const report = ownersReport({ namesOwner: true }, { visible: false, required: false });
  assert.equal(report.owners, "pass");
  assert.equal(report.adapter, "native");
  assert.equal(report.protection, "unknown");
  assert.notEqual(report.owners, report.protection);
});

test("local and post-deploy without a pull-request smoke miss level 1 and keep other credit", () => {
  const facts = endToEnd({
    app: true,
    localCommand: true,
    preMergeJob: false,
    postDeployJob: true,
    helmsmanJourney: false,
    nativeJourney: true,
  });
  assert.deepEqual(facts, {
    local: "pass",
    preMerge: "fail",
    postDeploy: "pass",
    duplicate: false,
  });
  const headline = endToEndHeadline(facts);
  assert.equal(headline.includes(COLLAPSED_END_TO_END), false);
  assert.match(headline, /Local: pass/);
  assert.match(headline, /Pre-merge smoke: fail/);
  assert.match(headline, /Post-deploy \/ full: pass/);
  assert.match(headline, /critical-path smoke on the pull request/);
  assert.equal(headline.includes(RECOMMENDED_E2E), true);

  const score = level1({
    local: "pass",
    preMerge: "fail",
    setup: "pass",
    lint: "pass",
    types: "pass",
    integration: "pass",
    pureUnit: "pass",
    lockfile: "fail",
  });
  assert.equal(score.earned, false);
  assert.equal(score.fractionPasses, 6);
  assert.equal(score.fractionCount, 8);
  assert.equal(score.fraction, 0.7);
});

test("a pull-request smoke can earn level 1 while the full suite stays post-deploy", () => {
  const facts = endToEnd({
    app: true,
    localCommand: true,
    preMergeJob: true,
    postDeployJob: true,
    helmsmanJourney: false,
    nativeJourney: true,
  });
  assert.equal(facts.preMerge, "pass");
  assert.equal(facts.postDeploy, "pass");
  assert.equal(facts.duplicate, false);
  const score = level1({
    local: "pass",
    preMerge: "pass",
    setup: "pass",
    lint: "pass",
    types: "pass",
    integration: "pass",
    pureUnit: "pass",
    lockfile: "pass",
  });
  assert.equal(score.earned, true);
  assert.match(RECOMMENDED_E2E, /exhaustive suite deferred/);
});

test("a path filter or run-e2e label counts as the pull-request smoke", () => {
  const facts = endToEnd({
    app: true,
    localCommand: true,
    preMergeJob: false,
    selectiveTrigger: true,
    postDeployJob: true,
    helmsmanJourney: false,
    nativeJourney: true,
  });
  assert.deepEqual(facts, {
    local: "pass",
    preMerge: "pass",
    postDeploy: "pass",
    duplicate: false,
  });
  const score = level1({
    local: "pass",
    preMerge: "pass",
    setup: "pass",
    lint: "pass",
    types: "pass",
    integration: "pass",
    pureUnit: "pass",
    lockfile: "pass",
  });
  assert.equal(score.earned, true);
});

test("a sole journey is not a second runner", () => {
  const sole = endToEnd({
    app: true,
    localCommand: true,
    preMergeJob: true,
    postDeployJob: false,
    helmsmanJourney: false,
    nativeJourney: true,
  });
  assert.equal(sole.duplicate, false);
  assert.equal(sole.preMerge, "pass");

  const both = endToEnd({
    app: true,
    localCommand: true,
    preMergeJob: true,
    postDeployJob: false,
    helmsmanJourney: true,
    nativeJourney: true,
  });
  assert.equal(both.duplicate, true);
  assert.equal(both.preMerge, "fail");
});

test("no application passes local and pre-merge end-to-end", () => {
  const facts = endToEnd({
    app: false,
    localCommand: false,
    preMergeJob: false,
    postDeployJob: false,
    helmsmanJourney: false,
    nativeJourney: false,
  });
  assert.equal(facts.local, "pass");
  assert.equal(facts.preMerge, "pass");
  assert.equal(facts.postDeploy, "fail");
  const score = level1({
    local: "pass",
    preMerge: "pass",
    setup: "pass",
    lint: "pass",
    types: "pass",
    integration: "n/a",
    pureUnit: "pass",
    lockfile: "pass",
  });
  assert.equal(score.earned, true);
});

test("docs drift drops level 2 until the documented commands match", () => {
  const drifted = levelGroup([
    "pass",
    "pass",
    "pass",
    "pass",
    "pass",
    "fail",
    "pass",
    "fail",
  ]);
  assert.equal(drifted.count, 8);
  assert.equal(drifted.need, 7);
  assert.equal(drifted.passes, 6);
  assert.equal(drifted.earned, false);

  const fixed = levelGroup([
    "pass",
    "pass",
    "pass",
    "pass",
    "pass",
    "pass",
    "pass",
    "fail",
  ]);
  assert.equal(fixed.count, 8);
  assert.equal(fixed.need, 7);
  assert.equal(fixed.passes, 7);
  assert.equal(fixed.earned, true);
});

test("slop uses baseline for a first measure and delta after it on a feature branch", () => {
  assert.equal(slopMode({ hasPriorSlop: false, onFeatureBranch: true }), "baseline");
  assert.equal(slopMode({ hasPriorSlop: false, onFeatureBranch: false }), "baseline");
  assert.equal(slopMode({ hasPriorSlop: true, onFeatureBranch: true }), "delta");
  assert.equal(slopMode({ hasPriorSlop: true, onFeatureBranch: false }), "baseline");
  assert.equal(
    slopMode({ asked: "baseline", hasPriorSlop: true, onFeatureBranch: true }),
    "baseline",
  );
  assert.equal(
    slopMode({ asked: "delta", hasPriorSlop: false, onFeatureBranch: false }),
    "delta",
  );
});

test("an empty delta does not invent an SDI", () => {
  assert.equal(deltaIsEmpty(0, 0), true);
  assert.equal(deltaIsEmpty(1, 0), false);
  const text = emptyDeltaText();
  assert.match(text, /empty/i);
  assert.match(text, /not 0%/);
  assert.equal(text.includes("SDI: 0%"), false);
});

test("an unscored part leaves the denominator", () => {
  const result = slopDensity([
    { scored: true, bad: 1, inspected: 2 },
    { scored: false, bad: 0, inspected: 0 },
    { scored: true, bad: 0, inspected: 4 },
  ]);
  assert.equal(result.scored, 2);
  assert.equal(result.available, 40);
  assert.equal(result.percent, 25);
  assert.equal(band(result.percent), "Moderate");
  const none = slopDensity([{ scored: false, bad: 0, inspected: 0 }]);
  assert.equal(none.percent, null);
  assert.equal(band(none.percent), "unscored");
});

test("complexity mass uses one threshold of 15 and lists bad files", () => {
  assert.equal(COMPLEXITY_THRESHOLD, 15);
  const mass = complexityMass([
    { complexity: 4, path: "src/a.js", line: 1 },
    { complexity: 16, path: "src/b.js", line: 20 },
    { complexity: 15, path: "src/c.js", line: 3 },
  ]);
  assert.equal(mass.inspected, 35);
  assert.equal(mass.bad, 16);
  assert.deepEqual(filesInBad(mass.badFns), ["src/b.js"]);
  assert.match(complexityNote("warn"), /not a pull-request gate/);
  assert.equal(complexityNote("gate").includes("warn"), false);
});

test("required checks are excluded from defensive paranoia", () => {
  const result = defensiveBad([
    { path: "src/http.js", line: 12, required: true },
    { path: "src/pure.js", line: 4, required: false },
  ]);
  assert.equal(result.inspected, 2);
  assert.equal(result.bad.length, 1);
  assert.equal(result.bad[0].path, "src/pure.js");
  assert.equal(result.bad[0].line, 4);
});

test("coverage names the eligible share and the exclusion list", () => {
  assert.equal(coveragePercent(8, 10), 80);
  assert.equal(coveragePercent(0, 0), null);
  assert.match(EXCLUDED, /Helmsman tooling/);
});
