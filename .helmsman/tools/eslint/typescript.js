import tseslint from "typescript-eslint";
import helmsman from "./index.js";

const typeChecked = tseslint.configs.recommendedTypeChecked.map((config) => ({
  ...config,
  files: ["**/*.{ts,tsx,mts,cts}"],
}));

/** @type {import("eslint").Linter.Config[]} */
export default [
  ...helmsman,
  ...typeChecked,
  {
    name: "helmsman/typescript",
    files: ["**/*.{ts,tsx,mts,cts}"],
    languageOptions: {
      parserOptions: {
        projectService: true,
      },
    },
  },
];
