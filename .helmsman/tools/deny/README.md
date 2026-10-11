# Helmsman dependency gate

Copy `deny.toml` to the crate root. Install `cargo-audit` and `cargo-deny`. `.helmsman/tools/checks/languages.sh` runs both when a `Cargo.toml` exists. A missing binary is a failure, not a skip.

```bash
cargo audit
cargo deny check advisories bans sources
```

`cargo audit` fails on a RustSec advisory. `cargo deny` fails on a yanked crate, a `*` version requirement, a registry other than the default crates.io index, and a git source. Vulnerability advisories already fail in cargo-deny with no extra key. Both tools fetch the advisory database, so the gate needs a network the first time it runs.

This file has no `[licenses]` table. Running `cargo deny check` with no check names also runs the license check, and an omitted allow-list denies every license. The Helmsman command names `advisories`, `bans`, and `sources` so a license list stays a project decision.

Duplicate versions stay at cargo-deny's default, which is a warning. A warning does not fail the check.

## Sources

`cargo audit` is [RustSec](https://github.com/rustsec/rustsec). `deny.toml` keys are the [cargo-deny](https://github.com/EmbarkStudios/cargo-deny) 0.20 template: `yanked` defaults to `warn`, `wildcards` defaults to `allow`, `unknown-registry` and `unknown-git` default to `warn`. This file denies those four. The crates.io index stays the tool's default allow-registry, so the URL is not copied here.
