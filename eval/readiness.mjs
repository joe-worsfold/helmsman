/**
 * Arithmetic for the readiness and the slop.
 * The skills state the same rules. An adopting repo does not need this file.
 */

/** Cyclomatic complexity above this value is complexity mass and a P2 candidate. */
export const COMPLEXITY_THRESHOLD = 15;

export const EXCLUDED =
  "tests, generated code, declarations, fixtures, vendored code, Helmsman tooling";

/** The collapsed sentence. Reports print three facts instead. */
export const COLLAPSED_END_TO_END =
  "Missing end-to-end that can run locally and in CI.";

/** Smoke on the pull request. The exhaustive suite stays off that gate. */
export const RECOMMENDED_E2E =
  "Recommended shape: a critical-path smoke on the pull request, and the exhaustive suite deferred to post-deploy, main, or nightly.";

/**
 * @param {number} value
 * @returns {number}
 */
export function truncate1(value) {
  return Math.trunc(value * 10) / 10;
}

/**
 * @param {number} passes
 * @param {number} counted
 * @returns {number}
 */
export function fractionOf(passes, counted) {
  if (counted === 0) return 0;
  return truncate1(passes / counted);
}

/**
 * @typedef {"pass" | "fail" | "unknown" | "n/a"} Capability
 * @typedef {{
 *   local: Capability,
 *   preMerge: Capability,
 *   setup: Capability,
 *   lint: Capability,
 *   types: Capability,
 *   integration: Capability,
 *   pureUnit: Capability,
 *   lockfile: Capability,
 * }} Level1Rows
 */

/**
 * @param {Capability} capability
 * @returns {boolean}
 */
function counts(capability) {
  return capability !== "n/a";
}

/**
 * @param {Capability} capability
 * @returns {boolean}
 */
function passed(capability) {
  return capability === "pass";
}

/**
 * Level 1. The pre-merge smoke is required and sits outside the 80% count.
 * Local end-to-end is inside that count. Post-deploy / full is not a level 1 row.
 * Unknown counts as a fail. Not applicable leaves the row out.
 *
 * @param {Level1Rows} rows
 */
export function level1(rows) {
  /** @type {Array<keyof Level1Rows>} */
  const eighty = ["local", "setup", "lint", "types", "integration", "pureUnit", "lockfile"];
  /** @type {Array<keyof Level1Rows>} */
  const all = ["local", "preMerge", "setup", "lint", "types", "integration", "pureUnit", "lockfile"];
  const eightyRows = eighty.filter((key) => counts(rows[key]));
  const eightyPasses = eightyRows.filter((key) => passed(rows[key])).length;
  const need = Math.ceil(0.8 * eightyRows.length);
  const fractionRows = all.filter((key) => counts(rows[key]));
  const fractionPasses = fractionRows.filter((key) => passed(rows[key])).length;
  return {
    earned: rows.preMerge === "pass" && eightyPasses >= need,
    eightyPasses,
    eightyCount: eightyRows.length,
    need,
    fractionPasses,
    fractionCount: fractionRows.length,
    fraction: fractionOf(fractionPasses, fractionRows.length),
  };
}

/**
 * Three end-to-end facts.
 * `preMergeJob` means a pull-request check runs the critical-path smoke.
 * `selectiveTrigger` means a path filter, or a label or comment such as
 * `run-e2e`, runs that same smoke and can fail the pull request when it runs.
 * Either one passes pre-merge smoke. An exhaustive suite does not.
 * `postDeployJob` means the exhaustive suite runs after deploy, on main, or nightly.
 *
 * @param {{
 *   app: boolean,
 *   localCommand: boolean,
 *   preMergeJob: boolean,
 *   selectiveTrigger?: boolean,
 *   postDeployJob: boolean,
 *   helmsmanJourney: boolean,
 *   nativeJourney: boolean,
 * }} input
 */
export function endToEnd(input) {
  if (!input.app) {
    return {
      local: "pass",
      preMerge: "pass",
      postDeploy: input.postDeployJob ? "pass" : "fail",
      duplicate: false,
    };
  }
  const duplicate = input.helmsmanJourney && input.nativeJourney;
  const smoke = input.preMergeJob || input.selectiveTrigger === true;
  const preMerge = duplicate || !smoke ? "fail" : "pass";
  return {
    local: input.localCommand ? "pass" : "fail",
    preMerge,
    postDeploy: input.postDeployJob ? "pass" : "fail",
    duplicate,
  };
}

/**
 * @param {{ local: string, preMerge: string, postDeploy: string }} facts
 * @returns {string}
 */
export function endToEndHeadline(facts) {
  return [
    `Local: ${facts.local}`,
    `Pre-merge smoke: ${facts.preMerge}`,
    `Post-deploy / full: ${facts.postDeploy}`,
    RECOMMENDED_E2E,
  ].join("\n");
}

/**
 * The command that fails the commit or the pull request.
 * A copied package with runs false does not pass.
 *
 * @param {{ runs: boolean, kind: "helmsman" | "native" | "none" }} evidence
 * @returns {{ capability: "pass" | "fail", adapter: "helmsman" | "native" | "absent" }}
 */
export function gateRow(evidence) {
  if (evidence.kind === "helmsman" && evidence.runs) {
    return { capability: "pass", adapter: "helmsman" };
  }
  if (evidence.kind === "native" && evidence.runs) {
    return { capability: "pass", adapter: "native" };
  }
  return { capability: "fail", adapter: "absent" };
}

/**
 * Owners follows CODEOWNERS. Branch protection is a separate line.
 *
 * @param {{ namesOwner: boolean }} codeowners
 * @param {{ visible: boolean, required: boolean }} protection
 */
export function ownersReport(codeowners, protection) {
  /** @type {"unknown" | "pass" | "fail"} */
  let protectionResult = "unknown";
  if (protection.visible) protectionResult = protection.required ? "pass" : "fail";
  return {
    owners: codeowners.namesOwner ? "pass" : "fail",
    adapter: codeowners.namesOwner ? "native" : "absent",
    protection: protectionResult,
  };
}

/**
 * @param {{ asked?: "baseline" | "delta", hasPriorSlop: boolean, onFeatureBranch: boolean }} input
 * @returns {"baseline" | "delta"}
 */
export function slopMode(input) {
  if (input.asked === "baseline" || input.asked === "delta") return input.asked;
  if (!input.hasPriorSlop) return "baseline";
  if (input.onFeatureBranch) return "delta";
  return "baseline";
}

/**
 * @param {number} productionCommits
 * @param {number} uncommittedProduction
 * @returns {boolean}
 */
export function deltaIsEmpty(productionCommits, uncommittedProduction) {
  return productionCommits === 0 && uncommittedProduction === 0;
}

export function emptyDeltaText() {
  return "Delta: empty. merge-base(default, HEAD)..HEAD has no eligible production changes, and there is no uncommitted production diff. SDI is unscored. An empty delta is not 0%.";
}

/**
 * Five parts, 20 points each. Unscored parts leave the denominator.
 * A scored part with nothing inspected is unscored, not zero.
 *
 * @param {Array<{ scored: boolean, bad: number, inspected: number }>} parts
 * @returns {{ percent: number | null, scored: number, available: number }}
 */
export function slopDensity(parts) {
  let earned = 0;
  let available = 0;
  let scored = 0;
  for (const part of parts) {
    if (!part.scored || part.inspected <= 0) continue;
    scored += 1;
    earned += (20 * part.bad) / part.inspected;
    available += 20;
  }
  if (available === 0) return { percent: null, scored: 0, available: 0 };
  return { percent: Math.trunc((100 * earned) / available), scored, available };
}

/**
 * @param {number | null} percent
 * @returns {string}
 */
export function band(percent) {
  if (percent === null) return "unscored";
  if (percent <= 15) return "Clean";
  if (percent <= 35) return "Moderate";
  if (percent <= 60) return "High";
  return "Critical";
}

/**
 * @param {Array<{ complexity: number, path: string, line: number }>} functions
 * @param {number} [threshold]
 */
export function complexityMass(functions, threshold = COMPLEXITY_THRESHOLD) {
  let inspected = 0;
  let bad = 0;
  /** @type {Array<{ complexity: number, path: string, line: number }>} */
  const badFns = [];
  for (const fn of functions) {
    inspected += fn.complexity;
    if (fn.complexity > threshold) {
      bad += fn.complexity;
      badFns.push(fn);
    }
  }
  return { bad, inspected, badFns, threshold };
}

/**
 * Warn at 15 is not a pull-request gate. A stricter gate is named as a gate.
 *
 * @param {"warn" | "gate"} mode
 * @returns {string}
 */
export function complexityNote(mode) {
  if (mode === "warn") {
    return "cyclomatic complexity above 15, warn threshold, not a pull-request gate";
  }
  return "cyclomatic complexity above 15, stricter gate";
}

/**
 * Second pass: required checks on untrusted input or typed-non-null stay out.
 *
 * @param {Array<{ path: string, line: number, required: boolean }>} candidates
 */
export function defensiveBad(candidates) {
  const bad = candidates.filter((row) => !row.required);
  return { bad, inspected: candidates.length };
}

/**
 * @param {Array<{ path: string }>} rows
 * @returns {string[]}
 */
export function filesInBad(rows) {
  return [...new Set(rows.map((row) => row.path))].sort();
}

/**
 * @param {number} inspectedFiles
 * @param {number} eligibleFiles
 * @returns {number | null}
 */
export function coveragePercent(inspectedFiles, eligibleFiles) {
  if (eligibleFiles <= 0) return null;
  return Math.trunc((100 * inspectedFiles) / eligibleFiles);
}
