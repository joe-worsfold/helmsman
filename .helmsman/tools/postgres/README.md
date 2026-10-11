# Postgres

`.helmsman/tools/postgres/check.sh` looks for tracked `.sql` files, a compose service that names `postgres`, or a sqlfluff / atlas / dbmate config. It does not start the database and it does not run migrate status.

What fails the commit:

- `.sqlfluff`, `[tool.sqlfluff]`, `atlas.hcl`, or a dbmate config is present and the matching binary is missing
- `sqlfluff` is installed, SQL is tracked, and `sqlfluff lint` fails

What skips, with a message:

- SQL is tracked, sqlfluff is not installed, and there is no sqlfluff or migrate config

Compose Postgres is an integration concern. Set `Integration` in `.helmsman/setup.md` to the command that uses the live database. This package only records that the service is there.

Shaped from a project whose compose file is Postgres 16 and whose checks are `uv`, `ruff`, `ty`, and `pytest`. The package does not assume that project's layout.
