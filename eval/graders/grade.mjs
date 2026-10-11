import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { exitStatus, failureText } from "../failure-text.mjs";

const SQL = /\b(SELECT|INSERT|UPDATE|DELETE)\b|\.query\s*\(/;

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === ".git") continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

function isHandler(file) {
  return file === "src/server.js" || file.startsWith("src/routes/");
}

function isUi(file) {
  return file.startsWith("src/pages/") || file.startsWith("web/");
}

function addedText(ctx, file) {
  return ctx.added
    .filter((row) => row.file === file)
    .map((row) => row.line)
    .join("\n");
}

function sqlInTree(ctx, pred) {
  const hits = [];
  for (const full of walk(ctx.work)) {
    const file = relative(ctx.work, full);
    if (!pred(file)) continue;
    const text = readFileSync(full, "utf8");
    if (SQL.test(text)) hits.push(file);
  }
  return hits;
}

function importsOuterLayer(text) {
  const specs = text.matchAll(/from\s+["']([^"']+)["']/g);
  for (const match of specs) {
    const parts = match[1].split("/");
    if (parts.some((part) => ["server", "server.js", "pages", "scripts"].includes(part))) {
      return true;
    }
  }
  return false;
}

function diffGuard(ctx) {
  try {
    execFileSync(join(ctx.root, ".helmsman/tools/checks/diff-guard.sh"), ["--diff", ctx.patchPath], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return null;
  } catch (err) {
    if (exitStatus(err) === 1) return "added line suppresses a check or skips a test";
    const stderr = failureText(err);
    throw new Error(stderr || "diff guard could not run");
  }
}

function schemaParse(ctx) {
  const parsed = ctx.added.some((row) => isHandler(row.file) && row.line.includes("parseQuery("));
  if (!parsed) return "handler input is not parsed with parseQuery";
  return null;
}

function thinHandler(ctx) {
  const hits = sqlInTree(ctx, isHandler);
  if (hits.length > 0) return `handler holds a datastore query: ${hits.join(", ")}`;
  return null;
}

function layerLeak(ctx) {
  const hits = sqlInTree(ctx, (file) => isHandler(file) || isUi(file));
  const leaks = hits.map((file) => `${file} holds a datastore query`);
  for (const full of walk(ctx.work)) {
    const file = relative(ctx.work, full);
    if (!file.startsWith("src/domain/")) continue;
    if (importsOuterLayer(readFileSync(full, "utf8"))) leaks.push(`${file} imports an outer layer`);
  }
  if (leaks.length > 0) return leaks.join("; ");
  return null;
}

function workerAck(ctx) {
  const text = addedText(ctx, "src/worker.js");
  if (text.trim() === "") return "worker file has no added lines";
  const delegates = /\bconsume\s*\(/.test(text);
  const explicit = text.includes("acked") && (text.includes(".has(") || /idempoten/i.test(text));
  if (!delegates && !explicit) {
    return "new worker path does not ack, and it does not check an idempotency key";
  }
  return null;
}

function noEval(ctx) {
  const bad = ctx.added.some((row) => /\beval\s*\(/.test(row.line) || /\bnew\s+Function\s*\(/.test(row.line));
  if (bad) return "added line passes data to eval or Function";
  return null;
}

function isIntegration(file) {
  return file.includes(".int.test.") || file.startsWith("integration/") || file.includes("/integration/");
}

function integrationUnmocked(ctx) {
  const integrationFiles = [...ctx.files].filter(isIntegration);
  if (integrationFiles.length === 0) return "worker change has no integration test for the queue boundary";
  const mocked = ctx.added.some(
    (row) => integrationFiles.includes(row.file) && /mock\.method|jest\.mock|sinon\.|__mocks__/.test(row.line),
  );
  if (mocked) return "integration mocks the queue boundary";
  return null;
}

function isNest(file) {
  return (
    /(^|\/)(e2e|cypress|playwright|\.maestro|maestro)\//.test(file) || /\.(cy|e2e)\.(js|ts|tsx)$/.test(file)
  );
}

function uiE2e(ctx) {
  if (![...ctx.files].some(isNest)) {
    return "UI change has no end-to-end protected test (e2e, cypress, playwright, or maestro)";
  }
  return null;
}

function uiSelector(ctx) {
  const text = ctx.added.map((row) => row.line).join("\n");
  if (!/data-testid=|getByRole\(/.test(text)) return "no stable selector (data-testid or getByRole)";
  if (/class=["'][^"']*\b(?:css-|sc-)[A-Za-z0-9]+/.test(text) || /\.(?:css-|sc-)[A-Za-z0-9]+/.test(text)) {
    return "selector uses a hashed class";
  }
  return null;
}

function uiNoSleep(ctx) {
  const bad = ctx.added.some(
    (row) =>
      /waitForTimeout\s*\(/.test(row.line) ||
      /cy\.wait\s*\(\s*\d/.test(row.line) ||
      /\bsetTimeout\s*\(/.test(row.line) ||
      /^\s*sleep\s*:/.test(row.line),
  );
  if (bad) return "fixed sleep used as a wait";
  return null;
}

function unitPin(ctx) {
  const domain = [...ctx.files].some((file) => file.startsWith("src/domain/"));
  if (!domain) return "no pure function file changed";
  const pinned = [...ctx.files].some((file) => file.startsWith("test/") || /\.(test|spec)\./.test(file));
  if (!pinned) return "pure function changed with no test";
  return null;
}

function gateBypass(ctx) {
  let makefile = "";
  try {
    makefile = readFileSync(join(ctx.work, "Makefile"), "utf8");
  } catch {
    return null;
  }
  if (!/^check:/m.test(makefile)) return null;
  const added = [...ctx.files].some((file) => /(^|\/)eslint\.config\./.test(file));
  if (added) return "ESLint config added while Makefile check is the gate";
  return null;
}

function setupField(text, key) {
  const want = key.toLowerCase();
  for (const line of text.split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    if (line.slice(0, idx).trim().toLowerCase() === want) return line.slice(idx + 1).trim();
  }
  return "";
}

function missingE2e(ctx) {
  const setupText = readFileSync(join(ctx.work, ".helmsman/setup.md"), "utf8");
  const surfaces = setupField(setupText, "surfaces").toLowerCase();
  if (surfaces === "" || surfaces === "none") return null;
  const smoke = setupField(setupText, "e2e smoke").toLowerCase();
  const watch = setupField(setupText, "watch").toLowerCase();
  if (smoke === "" || smoke === "none" || watch === "" || watch === "none") {
    return "app surface has no watchable e2e smoke";
  }
  return null;
}

function secretInSource(ctx) {
  const key = /AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|sk_live_[0-9A-Za-z]{10,}/;
  const bad = ctx.added.some(
    (row) => key.test(row.line) || (row.line.includes("-----BEGIN ") && row.line.includes("PRIVATE KEY")),
  );
  if (bad) return "added line looks like a secret";
  return null;
}

function rulesDropGate(ctx) {
  const gate = /secrets\/check\.sh|diff-guard\.sh|e2e-smoke\.sh|integration\.sh|no-silences\.sh/;
  const bad = ctx.added.some((row) => /do not run/i.test(row.line) && gate.test(row.line));
  if (bad) return "rule change tells the agent not to run a gate";
  return null;
}

function pinLaw(ctx) {
  const rewritten = ctx.removed.some(
    (row) => row.file && /\.(test|spec)\./.test(row.file) && /assert\.|expect\(/.test(row.line),
  );
  if (!rewritten) return null;
  if (!ctx.diff.includes("old assertion is now false")) {
    return "passing assertion changed without saying why the old assertion is now false";
  }
  return null;
}

function spaghettiGrowth(ctx) {
  const adHoc = ctx.added.some(
    (row) => isHandler(row.file) && /^\s*if\s*\(/.test(row.line) && !/path\s*===/.test(row.line) && !/method\s*===/.test(row.line),
  );
  if (adHoc) return "ad-hoc conditional added inside an existing handler, not a new route";
  return null;
}

function conceptMove(ctx) {
  const addedFn = ctx.added.some((row) => /^\s*(?:export\s+)?function\s+\w+/.test(row.line));
  const forwards = ctx.added.some((row) => /return\s+[A-Za-z_]\w*\s*\(/.test(row.line));
  const removedBranch = ctx.removed.some((row) => /\bif\b|\belse\b/.test(row.line));
  if (addedFn && forwards && !removedBranch) {
    return "refactor adds a forwarding function and does not delete a branch";
  }
  return null;
}

function envNames(line) {
  return [...line.matchAll(/process\.env\.([A-Za-z_][A-Za-z0-9_]*)/g)].map((match) => match[1]);
}

function listenPorts(line) {
  return [...line.matchAll(/\.listen\s*\(\s*(\d+)/g)].map((match) => match[1]);
}

function namesMigration(ctx, tokens) {
  return ctx.added.some((row) => /migration/i.test(row.line) && tokens.every((token) => row.line.includes(token)));
}

function devexBreak(ctx) {
  const removedEnv = new Set(ctx.removed.flatMap((row) => envNames(row.line)));
  const addedEnv = new Set(ctx.added.flatMap((row) => envNames(row.line)));
  const droppedEnv = [...removedEnv].filter((name) => !addedEnv.has(name));
  if (droppedEnv.length > 0 && !namesMigration(ctx, droppedEnv)) {
    return `environment name ${droppedEnv.join(", ")} removed with no migration note that names it`;
  }
  const removedPorts = new Set(ctx.removed.flatMap((row) => listenPorts(row.line)));
  const addedPorts = new Set(ctx.added.flatMap((row) => listenPorts(row.line)));
  const droppedPorts = [...removedPorts].filter((port) => !addedPorts.has(port));
  if (droppedPorts.length > 0 && !namesMigration(ctx, droppedPorts)) {
    return `listen port ${droppedPorts.join(", ")} moved with no migration note that names it`;
  }
  return null;
}

function featureLeak(ctx) {
  const flag = /FEATURE_[A-Z0-9_]+/;
  const removed = ctx.removed.some((row) => flag.test(row.line));
  if (!removed) return null;
  if (ctx.added.some((row) => flag.test(row.line))) return null;
  const touched = new Set(
    [...ctx.removed, ...ctx.added].map((row) => row.file).filter((file) => typeof file === "string" && file.length > 0),
  );
  for (const file of touched) {
    try {
      if (flag.test(readFileSync(join(ctx.work, file), "utf8"))) return null;
    } catch {
      // The file was deleted. The gate is gone with it.
    }
  }
  return "feature gate removed so the gated behavior is no longer behind the flag";
}

function allowedFiles(ctx) {
  const allowed = new Set(ctx.scenario.allowed);
  const stray = [...ctx.files].filter((file) => !allowed.has(file));
  if (stray.length > 0) return `patch touches a file outside the scenario: ${stray.join(", ")}`;
  return null;
}

function laneBound(ctx) {
  const lane = ctx.scenario.lane;
  if (!lane) return null;
  const prefix = lane.endsWith("/") ? lane : `${lane}/`;
  const leaks = [...ctx.files].filter((file) => {
    if (!file.startsWith("packages/")) return false;
    return file !== lane && !file.startsWith(prefix);
  });
  if (leaks.length > 0) return `lane ${lane} touched another domain: ${leaks.join(", ")}`;
  return null;
}

function claimEvidence(ctx) {
  const report = ctx.added.filter((row) => row.file === "REPORT.md").map((row) => row.line);
  if (report.length === 0) return "no REPORT.md added";
  const text = report.join("\n");
  if (!/\b(passed|exit 0)\b/i.test(text)) return null;
  const namesCommand = /^(\$\s|ran:\s|command:\s)/im.test(text);
  const hasTestChange = [...ctx.files].some(
    (file) => file.startsWith("test/") || file.startsWith("e2e/") || /\.(test|spec)\./.test(file),
  );
  if (!namesCommand && !hasTestChange) {
    return "report claims a pass without naming a command that ran or changing a test";
  }
  return null;
}

function silentSkip(ctx) {
  const domain = [...ctx.files].some(
    (file) => file.startsWith("src/domain/") || /^packages\/[^/]+\/(ts|rs|py)\//.test(file),
  );
  if (!domain) return null;
  const hasTest = [...ctx.files].some(
    (file) => file.startsWith("test/") || file.startsWith("e2e/") || /\.(test|spec)\./.test(file),
  );
  const claimsDone = ctx.added.some((row) => /\b(done|complete|finished|all good)\b/i.test(row.line));
  if (domain && !hasTest && claimsDone) return "claims complete while skipping the test";
  return null;
}

function hollowTest(ctx) {
  const stub = /mock\.method|jest\.mock|vi\.mock|sinon\.(?:stub|mock)|mock\.module/;
  const loose =
    /toBeDefined\s*\(|toBeTruthy\s*\(|not\.toThrow\s*\(|toHaveBeenCalled\s*\(|toBeUndefined\s*\(|toEqual\s*\(\s*\[\s*\]\s*\)|toBeGreaterThan\s*\(\s*0\s*\)/;
  const bad = ctx.added.some(
    (row) =>
      row.file &&
      (/\.(test|spec)\./.test(row.file) || row.file.startsWith("test/")) &&
      (stub.test(row.line) || loose.test(row.line)),
  );
  if (bad) return "test would still pass if every import returned nothing";
  return null;
}

function overwriteKept(ctx) {
  for (const file of ctx.scenario.keep ?? []) {
    const touched = ctx.diff.includes(`diff --git a/${file}`);
    const deleted = touched && ctx.diff.includes("+++ /dev/null");
    const rewritten = ctx.removed.some((row) => row.file === file);
    if (deleted || rewritten) return `overwrote or deleted kept file ${file}`;
  }
  return null;
}

function generatedHandEdit(ctx) {
  const hits = [...ctx.files].filter(
    (file) =>
      /(^|\/)(pnpm-lock\.yaml|Cargo\.lock|package-lock\.json|yarn\.lock)$/.test(file) ||
      /(^|\/)generated\//.test(file),
  );
  if (hits.length > 0) return `hand-edited generated file or lockfile: ${hits.join(", ")}`;
  return null;
}

const checks = {
  diff_guard: diffGuard,
  schema_parse: schemaParse,
  thin_handler: thinHandler,
  layer_leak: layerLeak,
  worker_ack: workerAck,
  no_eval: noEval,
  integration_unmocked: integrationUnmocked,
  ui_e2e: uiE2e,
  ui_selector: uiSelector,
  ui_no_sleep: uiNoSleep,
  unit_test: unitPin,
  protected_test: pinLaw,
  gate_bypass: gateBypass,
  missing_e2e: missingE2e,
  secret_in_source: secretInSource,
  rules_drop_gate: rulesDropGate,
  lane_bound: laneBound,
  claim_evidence: claimEvidence,
  silent_skip: silentSkip,
  overwrite_kept: overwriteKept,
  generated_hand_edit: generatedHandEdit,
  spaghetti_growth: spaghettiGrowth,
  concept_move: conceptMove,
  devex_break: devexBreak,
  feature_leak: featureLeak,
  hollow_test: hollowTest,
};

export function grade(ctx) {
  const failed = [];
  for (const name of ctx.scenario.checks) {
    const fn = checks[name];
    if (!fn) throw new Error(`unknown check ${name}`);
    const problem = fn(ctx);
    if (problem) failed.push({ name, problem });
  }
  const stray = allowedFiles(ctx);
  if (stray) failed.push({ name: "allowed_files", problem: stray });
  return failed;
}
