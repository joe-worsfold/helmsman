import { ESLint } from "eslint";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const failures = [];

function ifs(count) {
  const lines = ["export function branched(n) {"];
  for (let i = 0; i < count; i += 1) {
    lines.push(`  if (n === ${i}) return ${i};`);
  }
  lines.push("  return -1;");
  lines.push("}");
  return lines.join("\n");
}

function nest(depth) {
  const lines = ["export function nested(n) {"];
  for (let i = 0; i < depth; i += 1) {
    lines.push(`${"  ".repeat(i + 1)}if (n > ${i}) {`);
  }
  lines.push(`${"  ".repeat(depth + 1)}return n;`);
  for (let i = depth; i > 0; i -= 1) {
    lines.push(`${"  ".repeat(i)}}`);
  }
  lines.push("  return 0;");
  lines.push("}");
  return lines.join("\n");
}

function longFunction(statements) {
  const lines = ["export function longOne() {", "  let n = 0;"];
  for (let i = 0; i < statements; i += 1) lines.push("  n += 1;");
  lines.push("  return n;");
  lines.push("}");
  return lines.join("\n");
}

function wideFile(count) {
  const lines = ["export const values = ["];
  for (let i = 0; i < count; i += 1) lines.push("  1,");
  lines.push("];");
  return lines.join("\n");
}

function runnerCall(objectName, methodName) {
  return `${objectName}.${methodName}("case", () => {\n  return 1;\n});\n`;
}

function namedCall(name) {
  return `${name}("case", () => {\n  return 1;\n});\n`;
}

const ok = `export function tax(amount, rate) {
  if (rate < 0) {
    throw new Error("rate must be zero or more");
  }
  return amount * rate;
}
`;

async function writeProject(dir, name, source) {
  await writeFile(path.join(dir, name), source);
}

async function lint(dir, name, config) {
  const eslint = new ESLint({
    cwd: dir,
    overrideConfigFile: path.join(here, config),
    errorOnUnmatchedPattern: true,
  });
  const [result] = await eslint.lintFiles([path.join(dir, name)]);
  return result;
}

function ruleIds(result) {
  return result.messages.map((message) => message.ruleId).filter(Boolean);
}

function note(name, result) {
  const detail = result.messages
    .map((message) => `${message.ruleId ?? "parse"}: ${message.message}`)
    .join("\n  ");
  failures.push(`${name}\n  ${detail || "(no messages)"}`);
}

async function expectClean(dir, name, source, config) {
  await writeProject(dir, name, source);
  const result = await lint(dir, name, config);
  if (result.errorCount !== 0 || result.warningCount !== 0) note(name, result);
}

async function expectRule(dir, name, source, config, ruleId) {
  await writeProject(dir, name, source);
  const result = await lint(dir, name, config);
  if (!ruleIds(result).includes(ruleId)) {
    note(`${name} expected ${ruleId}`, result);
  }
}

async function expectAbsent(dir, name, source, config, ruleId) {
  await writeProject(dir, name, source);
  const result = await lint(dir, name, config);
  const ids = ruleIds(result);
  if (ids.includes(ruleId) || result.errorCount !== 0 || result.warningCount !== 0) {
    note(`${name} expected no ${ruleId}`, result);
  }
}

const dir = await mkdtemp(path.join(tmpdir(), "helmsman-eslint-"));

try {
  await expectClean(dir, "ok.js", ok, "index.js");
  await expectClean(
    dir,
    "params-ok.js",
    "export function add(a, b, c) {\n  return a + b + c;\n}\n",
    "index.js",
  );
  await expectClean(
    dir,
    "nil.js",
    "export function nil(value) {\n  return value == null;\n}\n",
    "index.js",
  );
  await expectClean(dir, "branch-ok.js", ifs(6), "index.js");
  await expectClean(dir, "nest-ok.js", nest(2), "index.js");
  await expectClean(dir, "short.js", longFunction(10), "index.js");
  await expectClean(dir, "narrow.js", wideFile(20), "index.js");
  await expectClean(
    dir,
    "local-scripts.js",
    'import { tax } from "../src/scripts/migrate.js";\nexport function pay(amount) {\n  return tax(amount, 0.2);\n}\n',
    "index.js",
  );
  const pinLines = ['it("holds pins", () => {', "  let n = 0;"];
  for (let i = 0; i < 70; i += 1) pinLines.push("  n += 1;");
  pinLines.push("  return n;", "});");
  await expectClean(dir, "pins.test.js", pinLines.join("\n"), "index.js");

  await expectRule(dir, "eval.js", 'eval("1");\n', "index.js", "no-eval");
  await expectRule(
    dir,
    "implied.js",
    'setTimeout("return 1", 10);\n',
    "index.js",
    "no-implied-eval",
  );
  await expectRule(
    dir,
    "fn.js",
    'const body = new Function("return 1");\nexport default body;\n',
    "index.js",
    "no-new-func",
  );
  await expectRule(
    dir,
    "eq.js",
    "export function same(left, right) {\n  return left == right;\n}\n",
    "index.js",
    "eqeqeq",
  );
  await expectRule(
    dir,
    "params.js",
    "export function add(a, b, c, d) {\n  return a + b + c + d;\n}\n",
    "index.js",
    "max-params",
  );
  await expectRule(dir, "branch.js", ifs(12), "index.js", "complexity");
  await expectRule(dir, "deep.js", nest(6), "index.js", "max-depth");
  await expectRule(
    dir,
    "cognitive.js",
    nest(8),
    "index.js",
    "sonarjs/cognitive-complexity",
  );
  await expectRule(dir, "long.js", longFunction(60), "index.js", "max-lines-per-function");
  await expectRule(dir, "wide.js", wideFile(400), "index.js", "max-lines");
  await expectRule(
    dir,
    "wide.test.js",
    `it("grows", () => {\n  return 1;\n});\n${wideFile(520)}`,
    "index.js",
    "max-lines",
  );
  await expectAbsent(
    dir,
    "wide-ok.test.js",
    `it("grows", () => {\n  return 1;\n});\n${wideFile(400)}`,
    "index.js",
    "max-lines",
  );
  await expectRule(
    dir,
    "skip.test.js",
    runnerCall("it", "skip"),
    "index.js",
    "no-restricted-syntax",
  );
  await expectRule(
    dir,
    "only.test.js",
    runnerCall("describe", "only"),
    "index.js",
    "no-restricted-syntax",
  );
  await expectRule(
    dir,
    "xit.test.js",
    namedCall("x" + "it"),
    "index.js",
    "no-restricted-syntax",
  );
  await expectRule(
    dir,
    "pending.test.js",
    'pending("later");\n',
    "index.js",
    "no-restricted-syntax",
  );
  await expectRule(
    dir,
    "scripts.js",
    'import "scripts/run.js";\n',
    "index.js",
    "no-restricted-imports",
  );
  await expectRule(
    dir,
    "throw.js",
    'export function fail() {\n  throw "no";\n}\n',
    "index.js",
    "no-throw-literal",
  );
  await expectRule(
    dir,
    "throw-error.js",
    'export function fail() {\n  throw Error("no");\n}\n',
    "index.js",
    "unicorn/throw-new-error",
  );
  await expectRule(
    dir,
    "thenable.js",
    "export const box = {\n  then(resolve) {\n    resolve(1);\n  },\n};\n",
    "index.js",
    "unicorn/no-thenable",
  );

  const disable = ["eslint", "disable"].join("-");
  await expectRule(
    dir,
    "blanket.js",
    `/* ${disable} */\neval("1");\n`,
    "index.js",
    `unicorn/no-abusive-${["eslint", "disable"].join("-")}`,
  );

  function callbacks(depth) {
    let inner = "1";
    for (let i = 0; i < depth; i += 1) {
      inner = `step(function () { return ${inner}; })`;
    }
    return `function step(run) {\n  return run();\n}\nexport function go() {\n  return ${inner};\n}\n`;
  }
  await expectRule(dir, "callbacks.js", callbacks(6), "index.js", "max-nested-callbacks");
  await expectClean(dir, "callbacks-ok.js", callbacks(2), "index.js");

  await mkdir(path.join(dir, "ts"), { recursive: true });
  await writeFile(
    path.join(dir, "tsconfig.json"),
    JSON.stringify(
      {
        compilerOptions: {
          strict: true,
          target: "ES2022",
          module: "NodeNext",
          moduleResolution: "NodeNext",
          noEmit: true,
          rootDir: ".",
        },
        include: ["ts/**/*.ts"],
      },
      null,
      2,
    ),
  );
  await expectClean(dir, "ok.js", ok, "typescript.js");
  await expectClean(
    dir,
    "ts/ok.ts",
    "export function tax(amount: number, rate: number): number {\n  if (rate < 0) {\n    throw new Error(\"rate must be zero or more\");\n  }\n  return amount * rate;\n}\n",
    "typescript.js",
  );
  await expectRule(
    dir,
    "ts/any.ts",
    "export function take(value: any): any {\n  return value;\n}\n",
    "typescript.js",
    "@typescript-eslint/no-explicit-any",
  );
  await expectRule(
    dir,
    "ts/float.ts",
    "export function go(): void {\n  Promise.resolve(1);\n}\n",
    "typescript.js",
    "@typescript-eslint/no-floating-promises",
  );
  await writeFile(
    path.join(dir, "ts/kinds.ts"),
    'export type Kind = "a" | "b";\nexport function value(): Kind {\n  return "a";\n}\n',
  );
  await expectClean(
    dir,
    "ts/switch-ok.ts",
    'import type { Kind } from "./kinds";\nexport function label(kind: Kind): string {\n  switch (kind) {\n    case "a":\n      return "a";\n    case "b":\n      return "b";\n    default: {\n      const unreachable: never = kind;\n      return unreachable;\n    }\n  }\n}\n',
    "typescript.js",
  );
  await expectRule(
    dir,
    "ts/switch-miss.ts",
    'type Kind = "a" | "b";\nexport function label(kind: Kind): string {\n  switch (kind) {\n    case "a":\n      return "a";\n    default:\n      return "other";\n  }\n}\n',
    "typescript.js",
    "@typescript-eslint/switch-exhaustiveness-check",
  );
  await expectRule(
    dir,
    "ts/inline-import.ts",
    'export function take(kind: import("./kinds").Kind): string {\n  return kind;\n}\n',
    "typescript.js",
    "@typescript-eslint/consistent-type-imports",
  );
  await expectClean(
    dir,
    "ts/dynamic-import.ts",
    'export async function load(): Promise<string> {\n  const mod = await import("./kinds.js");\n  return mod.value();\n}\n',
    "typescript.js",
  );
} finally {
  await rm(dir, { recursive: true, force: true });
}

if (failures.length > 0) {
  console.error(failures.join("\n\n"));
  process.exit(1);
}

console.log("helmsman: eslint package check ok.");
