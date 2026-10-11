# Helmsman Clippy

This package is a floor. A crate that already has Clippy at this bar, or stricter, is left alone. Detect first. Do not overwrite, and do not raise a threshold.

1. `make -n check` succeeds: stop. Do not add a clippy.toml, and do not change the `check` recipe.
2. `Cargo.toml` already has `[workspace.lints]` or `[lints]`: do not paste `workspace-lints.toml`. `floor.sh` skips that copy.
3. `clippy.toml` or `.clippy.toml` already exists: do not replace it. `floor.sh` fails a number above this package and does not write the file. A lower number stays.
4. `scripts/check-file-length.sh` or a `lines` target already exists: do not replace it.

Copy only what is missing. `floor.sh` with no arguments checks and does not write. `floor.sh .` copies a missing `clippy.toml` and appends a missing lint table.

| File | Copy to | When |
| --- | --- | --- |
| `clippy.toml` | crate root | no clippy config yet |
| `workspace-lints.toml` | the `[workspace.lints]` tables in `Cargo.toml` | no lint table yet |
| `rust-toolchain.toml` | crate root | no toolchain file yet |
| `check-file-length.sh` | `scripts/check-file-length.sh` | no length script yet |

Set `rust-version = "1.85"` and `edition = "2024"` on the package, or on `[workspace.package]`, only when those keys are absent. Each member that should inherit the lint table sets `lints.workspace = true`.

Wire the length script only when `lines` is absent:

```make
lines:
	scripts/check-file-length.sh
```

If `check` is also absent, `check` should depend on `lines`. If `check` already exists, leave it. Tell the reader the length script is not on that path yet.

`.helmsman/tools/checks/languages.sh` runs `make check` when that target exists, and `make lint` when that is the only Makefile gate. `.helmsman/tools/checks/rust-workspace.sh` runs the levels below only when neither target exists. `cargo audit` and `cargo deny` still run either way.

## Levels

`workspace-lints.toml` is the level table.

| Lint | Level |
| --- | --- |
| `unsafe_code` | forbid |
| `clippy::all` | deny |
| `clippy::pedantic` | warn (`priority = -1`) |
| `unwrap_used`, `expect_used`, `panic`, `todo`, `unimplemented` | deny |
| `allow_attributes_without_reason` | deny |
| `cognitive_complexity`, `too_many_lines`, `too_many_arguments`, `type_complexity` | deny |

Nursery is not enabled. Pedantic stays warn. The named denies are not relaxed in tests.

## Thresholds

Do not raise these.

| Key | Value | Clippy default |
| --- | --- | --- |
| `cognitive-complexity-threshold` | 15 | 25 |
| `too-many-lines-threshold` | 50 | 100 |
| `too-many-arguments-threshold` | 6 | 7 |
| `type-complexity-threshold` | 250 | 250 |

`cognitive-complexity-threshold` is the complexity owner. It is not the slop score's cyclomatic count. File length is not this lint. It is `check-file-length.sh`: 500 lines, every tracked `.rs` file. The map is `.helmsman/tools/metrics/README.md`.

A split made only to silence Clippy still fails the standard. Delete branches and reuse first.

## Sources

Levels and thresholds are the verified Rust workspace bar: workspace lints as in the table, `clippy.toml` at 15 / 50 / 6 / 250, rustfmt edition 2024, toolchain channel stable, `rust-version` 1.85, and a separate 500-line check on every tracked `.rs` file. Lint names and Clippy defaults: [Clippy lint configuration](https://doc.rust-lang.org/clippy/lint_configuration.html). `too_many_lines` is pedantic, so the group warn does not deny it. The table denies it by name. Checked the lint names and `edition = "2024"` on Clippy and rustfmt 1.83; the MSRV for edition 2024 is 1.85.
