# Python

Wired. The tools are Astral's, plus pytest: `uv` for the lock, `ruff` for lint and format, `ty` for types, `pytest` for the unit test. Shaped from a Python 3.12 project that already runs those commands and keeps Postgres in compose. This package does not start Postgres.

`.helmsman/tools/checks/languages.sh` runs `.helmsman/tools/python/check.sh` when `pyproject.toml` or `uv.lock` exists, unless the consumer `make check` or `package.json` `check` recipe already mentions `ruff`, `pytest`, or `ty`.

What fails the commit:

- `uv` is missing
- `uv.lock` is stale (`uv lock --check`)
- `ruff check` or `ruff format --check`
- a ruff ceiling above this package: complexity 10, arguments 6, statements 50
- `ty` when the project names `ty` and `uv run ty check` fails
- `pytest` when tracked tests exist and the run fails

A project `ruff.toml`, `.ruff.toml`, or `[tool.ruff]` block is the config that runs. Helmsman does not overwrite it. A higher ceiling than `.helmsman/tools/python/ruff.toml` fails. A lower number stays. When the project has no ruff config, the package file is the config.

`ty` is skipped with a message when the project does not name it. Do not add a second Python linter beside ruff.
