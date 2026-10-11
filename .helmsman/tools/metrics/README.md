# Metric owners

File length, function size, complexity, and parameter count each have one owner per language. This file maps the metric. It does not set a second threshold. A number lives in the language pack, or it is not set.

The slop score uses one cyclomatic threshold for the index and for P2: complexity above 15. `bad` is the cyclomatic complexity inside those functions. `inspected` is the total measured cyclomatic complexity of the eligible set. Name the tool that counted. A warn at 15 is not a pull-request gate. This package's `complexity` rule is a stricter commit gate at 10 when a repo opts in. That gate is not the index. Rust's gate is cognitive complexity, which is a different count.

| Metric | TypeScript | Rust | Python |
| --- | --- | --- | --- |
| File length | `max-lines` in `.helmsman/tools/eslint/index.js`. 300 code lines. Test files are 500. | `.helmsman/tools/clippy/check-file-length.sh`. 500 lines. | Ruff `line-length` 100 in `.helmsman/tools/python/ruff.toml`, used only when the project has no ruff config. |
| Function size | `max-lines-per-function` in `.helmsman/tools/eslint/index.js`. 50 code lines. Off for test files. | Clippy `too_many_lines` in `.helmsman/tools/clippy/clippy.toml`. The value is 50. A lower number in a repo file stays. | Ruff `PLR0915` `max-statements` 50 in `.helmsman/tools/python/ruff.toml` when the project has no ruff config. A higher number in a project file fails. |
| Complexity | `complexity` 10 and `sonarjs/cognitive-complexity` 15 in `.helmsman/tools/eslint/index.js`. | `cognitive-complexity-threshold` in `.helmsman/tools/clippy/clippy.toml`. 15 is the floor. A lower number in a repo file stays. | Ruff `C901` `max-complexity` 10 in `.helmsman/tools/python/ruff.toml` when the project has no ruff config. A higher number in a project file fails. |
| Parameter count | `max-params` in `.helmsman/tools/eslint/index.js`. The value is 3. | Clippy `too_many_arguments` in `.helmsman/tools/clippy/clippy.toml`. The value is 6. A lower number in a repo file stays. | Ruff `PLR0913` `max-args` 6 in `.helmsman/tools/python/ruff.toml` when the project has no ruff config. A higher number in a project file fails. |

Do not put a second Clippy file next to an existing `clippy.toml`. ESLint and Clippy stay with their packages. The TypeScript column is the opt-in ESLint package. `tsc --noEmit` does not enforce those ceilings. Rust type complexity is `type-complexity-threshold = 250` in that same `clippy.toml`. It is not the file-length script and it is not the cognitive threshold.
