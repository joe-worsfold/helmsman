# Surreal

`.helmsman/tools/surreal/check.sh` looks for a tracked `.surql` file or a compose file that names `surrealdb`. It does not run `docker compose`, and it does not apply the schema.

What fails the commit:

- compose names SurrealDB and no `.surql` file is tracked
- a tracked `.surql` file is empty
- schema files exist and `.helmsman/setup.md` has no `Integration` command (`Integration: none` counts as missing)

`Integration` is the integration command: schema apply against the local database, or the live-database tests. `.helmsman/tools/checks/integration.sh` runs that line in CI. Pre-commit stops at presence.

The package is generic. It does not name a product schema path.
