import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { failureText } from "./failure-text.mjs";
import { grade } from "./graders/grade.mjs";
import { readQuarantine } from "./quarantine.mjs";

const evalDir = dirname(fileURLToPath(import.meta.url));
const root = dirname(evalDir);
const fixture = join(evalDir, "fixture");

function parseScenario(text, dir) {
  const match = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) throw new Error(`${dir} scenario is missing front matter`);
  const scenario = { checks: [], allowed: [], keep: [], fails: [], catches: {}, dir };
  for (const line of match[1].split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (key === "checks" || key === "allowed" || key === "fail" || key === "keep") {
      const items = value.split(",").map((item) => item.trim()).filter(Boolean);
      if (key === "fail") scenario.fails = items;
      else scenario[key] = items;
    } else if (key.startsWith("catch-")) {
      scenario.catches[key.slice("catch-".length)] = value.split(",").map((item) => item.trim()).filter(Boolean);
    } else {
      scenario[key] = value;
    }
  }
  if (!scenario.pass) throw new Error(`${dir} is missing a pass patch`);
  return scenario;
}

function parseDiff(diff) {
  const added = [];
  const removed = [];
  const files = new Set();
  let file = null;
  for (const line of diff.split("\n")) {
    if (line.startsWith("diff --git ")) {
      const match = line.match(/ b\/(.+)$/);
      file = match ? match[1] : null;
      if (file) files.add(file);
      continue;
    }
    if (line.startsWith("+++ ")) {
      const path = line.slice(4).trim();
      file = path === "/dev/null" ? null : path.replace(/^b\//, "");
      if (file) files.add(file);
      continue;
    }
    if (line.startsWith("+") && !line.startsWith("+++")) added.push({ file, line: line.slice(1) });
    else if (line.startsWith("-") && !line.startsWith("---")) removed.push({ file, line: line.slice(1) });
  }
  return { added, removed, files };
}

function testFiles(work) {
  const out = [];
  for (const name of readdirSync(join(work, "e2e"))) {
    if (name.endsWith(".e2e.js")) out.push(join("e2e", name));
  }
  for (const name of readdirSync(join(work, "test"))) {
    if (name.endsWith(".test.js")) out.push(join("test", name));
  }
  return out;
}

function runNodeTests(work) {
  const files = testFiles(work);
  execFileSync("node", ["--test", ...files], { cwd: work, stdio: "pipe" });
}

function apply(patchPath) {
  const work = mkdtempSync(join(tmpdir(), "helmsman-eval-"));
  cpSync(fixture, work, { recursive: true });
  execFileSync("git", ["apply", "--unsafe-paths", patchPath], { cwd: work, stdio: "pipe" });
  return work;
}

function loadScenarios() {
  const dir = join(evalDir, "scenarios");
  return readdirSync(dir)
    .sort()
    .map((name) => parseScenario(readFileSync(join(dir, name, "scenario.md"), "utf8"), name));
}

function context(scenario, patchName) {
  const patchPath = join(evalDir, "scenarios", scenario.dir, patchName);
  const diff = readFileSync(patchPath, "utf8");
  const parsed = parseDiff(diff);
  const work = apply(patchPath);
  return { root, work, diff, patchPath, scenario, ...parsed };
}

const problems = [];
const quarantined = new Set();
for (const row of readQuarantine(readFileSync(join(evalDir, "quarantine.txt"), "utf8"))) {
  quarantined.add(row.id);
  console.log(`helmsman: quarantine ${row.id} ${row.url}`);
}

try {
  execFileSync(join(root, ".helmsman/tools/checks/setup-check.sh"), [join(fixture, ".helmsman/setup.md")], { stdio: "inherit" });
  runNodeTests(fixture);
  console.log("base fixture: setup ok, tests ok");
} catch (err) {
  console.error(failureText(err));
  process.exit(1);
}

for (const scenario of loadScenarios()) {
  if (quarantined.has(scenario.id)) {
    console.log(`${scenario.id}: quarantined`);
    continue;
  }
  let passWork;
  try {
    const ctx = context(scenario, scenario.pass);
    passWork = ctx.work;
    const failed = grade(ctx);
    if (failed.length > 0) {
      problems.push(`${scenario.id} pass should be clean: ${failed.map((item) => item.name).join(", ")}`);
      for (const item of failed) console.error(`  ${scenario.id} pass ${item.name}: ${item.problem}`);
    } else {
      runNodeTests(ctx.work);
      console.log(`${scenario.id} pass: ok`);
    }
  } catch (err) {
    problems.push(`${scenario.id} pass did not apply or its tests failed`);
    console.error(failureText(err));
  } finally {
    if (passWork) rmSync(passWork, { recursive: true, force: true });
  }

  for (const failName of scenario.fails) {
    let work;
    try {
      const ctx = context(scenario, failName);
      work = ctx.work;
      const failed = grade(ctx);
      const names = new Set(failed.map((item) => item.name));
      const expected = scenario.catches[failName] ?? [];
      const missed = expected.filter((name) => !names.has(name));
      if (failed.length === 0) problems.push(`${scenario.id} ${failName} was graded clean`);
      if (missed.length > 0) problems.push(`${scenario.id} ${failName} missed ${missed.join(", ")}`);
      if (failed.length > 0 && missed.length === 0) {
        console.log(`${scenario.id} ${failName}: caught ${[...names].join(", ")}`);
      } else {
        for (const item of failed) console.error(`  ${scenario.id} ${failName} ${item.name}: ${item.problem}`);
      }
    } catch (err) {
      problems.push(`${scenario.id} ${failName} could not be graded`);
      console.error(failureText(err));
    } finally {
      if (work) rmSync(work, { recursive: true, force: true });
    }
  }
}

if (problems.length > 0) {
  console.error("eval: graders did not behave");
  for (const problem of problems) console.error(`- ${problem}`);
  process.exit(1);
}

console.log("eval: graders behaved");
