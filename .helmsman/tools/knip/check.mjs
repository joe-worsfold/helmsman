import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const knip = path.join(here, "node_modules", "knip", "bin", "knip.js");
const config = path.join(here, "knip.jsonc");

function run(fixture) {
  return spawnSync(
    process.execPath,
    [
      knip,
      "--config",
      config,
      "--directory",
      path.join(here, "fixture", fixture),
      "--no-progress",
    ],
    { encoding: "utf8" },
  );
}

const failures = [];

function check(name, result, ok) {
  if (!ok) {
    failures.push(
      `${name} exit ${result.status}\n${result.stdout}\n${result.stderr}`,
    );
  }
}

const clean = run("clean");
check("clean", clean, clean.status === 0);

const dirty = run("dirty");
check(
  "dirty",
  dirty,
  dirty.status === 1 && dirty.stdout.includes("Unused files"),
);

const cycle = run("cycle");
check(
  "cycle",
  cycle,
  cycle.status === 1 && cycle.stdout.includes("Circular dependencies"),
);

if (failures.length > 0) {
  console.error(failures.join("\n\n"));
  process.exit(1);
}

console.log("helmsman: knip package check ok.");
