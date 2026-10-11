# STAR: verify before trusting

Not loaded by agents. Claims in `.cursor/rules/helmsman-star.mdc` and `helmsman-data.mdc` that came from memory or inference, not from docs read during design. Check each against current versions (ideally with a second model) before relying on it.

## Tooling

- Turborepo directory filter syntax `--filter='./packages/<name>/*'`.
- Turborepo native uv/Cargo support (reported experimental) vs the `package.json` wrapper fallback.
- Ruff banned-import rules and import-linter for Python boundaries; Cargo dependency declarations for Rust boundaries.
- `sst.config.ts` auto-discovery with computed `import()` paths (docs only show static paths).
- SST Rust and Python runtimes are community supported; confirm on your SST v4 version.
- SST Workflow component fit for `apps/workflows`.
- Cargo workspace `members` globs (`packages/*/rs`, including `packages/platform/rs`, and `apps/*`) and pnpm workspace globs covering every STAR root without a root edit per domain. No root `platform` member.
- `cargo generate-lockfile` after a rebase keeps unrelated pins stable enough; otherwise prefer `cargo update -p <crate>`.

## Schemas and generation

- utoipa + openapi-typescript/orval pipeline, and a Python generator (e.g. datamodel-code-generator) from the same schema.
- Rust axum + utoipa Lambda build through SST.
- Generated TS client consumption from both Vite and Expo (Metro) without a second client.

## MCP and API

- Rust MCP server crate choice and Lambda fit (e.g. rmcp, turul-mcp-aws-lambda).
- Streaming for MCP: Function URL `RESPONSE_STREAM` vs API Gateway REST (reported Nov 2025) vs HTTP API (unconfirmed).
- Use Streamable HTTP, not legacy HTTP+SSE.

## SurrealDB

- Exact index and KNN syntax on your SurrealDB version (`<|K,EF|>`, HNSW parameters, DiskANN 3.1+), and `search::rrf` arguments.
- Whether `DEFINE ACCESS` / `PERMISSIONS` can enforce `owns` at database level per domain (an idea, not verified).
- SurrealDB Rust SDK from Lambda to Surreal Cloud: connection reuse, latency, auth.
- Surreal Cloud data residency and the account boundary.
- Embedded MCP behaviour and read-only options in 3.1+.

## AWS and data

- Bedrock EU inference profile keeps requests in EU regions; prompt caching availability; Converse vs InvokeModel for tool search; embedding model choice.
- Own MCP client over IAM on private endpoints.
- Inbound email availability in your region.
- Small-extractor accuracy (e.g. gline-rs/GLiNER) on your own documents.
- Retention and erasure for immutable decision records.

## Read from docs during design

SST v4 config shape (`app()`/`run()`, global components, dynamic imports); SST v4 is a one-way state migration from v3; `turbo boundaries` is experimental and JS/TS only; MCP Streamable HTTP replaced HTTP+SSE; tool selection degrades past 30-50 tools; LangSmith self-hosted needs Postgres, ClickHouse and S3 and is an Enterprise add-on; SurrealDB HNSW/DiskANN, KNN filter pushdown, hybrid RRF, SurrealMCP variants and scopes.
