import js from "@eslint/js";
import sonarjs from "eslint-plugin-sonarjs";
import unicorn from "eslint-plugin-unicorn";
import globals from "globals";

// Built so this file does not contain the diff-guard token for a blanket disable.
const blanketDisable = `unicorn/no-abusive-${["eslint", "disable"].join("-")}`;

/** @type {import("eslint").Linter.Config[]} */
export default [
  {
    name: "helmsman/ignores",
    ignores: [
      "**/dist/**",
      "**/build/**",
      "**/coverage/**",
      "**/cdk.out/**",
      "**/.next/**",
      "**/*.d.ts",
    ],
  },
  js.configs.recommended,
  {
    name: "helmsman/gate",
    files: ["**/*.{js,jsx,ts,tsx,mjs,cjs}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.node,
        ...globals.browser,
      },
    },
    plugins: {
      sonarjs,
      unicorn,
    },
    linterOptions: {
      reportUnusedDisableDirectives: "error",
    },
    rules: {
      // Ceilings are backstops. The sources, and how to lower them, are in README.md.
      complexity: ["error", 10],
      "max-depth": ["error", 4],
      "max-lines": [
        "error",
        { max: 300, skipBlankLines: true, skipComments: true },
      ],
      "max-lines-per-function": [
        "error",
        { max: 50, skipBlankLines: true, skipComments: true, IIFEs: true },
      ],
      "max-nested-callbacks": ["error", 4],
      "max-params": ["error", 3],
      "sonarjs/cognitive-complexity": ["error", 15],
      eqeqeq: ["error", "always", { null: "ignore" }],
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-new-func": "error",
      "no-throw-literal": "error",
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              // gitignore groups also match a relative path that contains "scripts".
              regex: "^(?:/)?scripts(?:/.*)?$",
              message:
                "Applications and libraries do not import repo-root scripts.",
            },
          ],
        },
      ],
      "no-restricted-syntax": [
        "error",
        {
          selector:
            "CallExpression[callee.object.name=/^(it|test|describe|context|suite)$/][callee.property.name=/^(skip|only)$/]",
          message: "A skipped or focused test fails the Helmsman gate.",
        },
        {
          selector: "CallExpression[callee.name=/^[xf](it|test|describe)$/]",
          message: "A skipped or focused test fails the Helmsman gate.",
        },
        {
          selector: "CallExpression[callee.name='pending']",
          message: "A skipped test fails the Helmsman gate.",
        },
      ],
      [blanketDisable]: "error",
      "unicorn/no-thenable": "error",
      "unicorn/throw-new-error": "error",
    },
  },
  {
    name: "helmsman/jsx",
    files: ["**/*.{jsx,tsx}"],
    languageOptions: {
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
  },
  {
    name: "helmsman/tests",
    files: [
      "**/*.{test,spec}.{js,jsx,ts,tsx,mjs,cjs}",
      "**/*.{cy,e2e}.{js,ts,tsx}",
      "**/cypress/**/*.{js,ts,jsx,tsx}",
      "**/e2e/**/*.{js,ts,jsx,tsx}",
    ],
    languageOptions: {
      globals: {
        ...globals.jest,
        ...globals.mocha,
        ...globals.vitest,
      },
    },
    rules: {
      // A describe callback holds many pins. The file ceiling still applies.
      "max-lines-per-function": "off",
      "max-lines": [
        "error",
        { max: 500, skipBlankLines: true, skipComments: true },
      ],
    },
  },
  {
    name: "helmsman/browser-tests",
    files: ["**/*.{cy,e2e}.{js,ts,tsx}", "**/cypress/**/*.{js,ts,jsx,tsx}"],
    languageOptions: {
      globals: {
        cy: "readonly",
        Cypress: "readonly",
      },
    },
  },
];
