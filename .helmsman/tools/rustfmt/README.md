# Helmsman rustfmt

Copy `rustfmt.toml` to the crate root only when `rustfmt.toml` and `.rustfmt.toml` are absent. Do not replace a file that is already there.

If `make check` or `make lint` already runs, that command is the format gate. Do not add a second format config beside it.

`.helmsman/tools/checks/languages.sh` runs this only when neither target exists:

```bash
cargo fmt --all -- --check
```

`edition` is `2024`. `cargo fmt` also reads the edition from `Cargo.toml`. Set that to 2024 when the key is absent. Do not rewrite an edition that is already set. Edition 2024 needs Rust 1.85. The toolchain channel is stable, in `.helmsman/tools/clippy/rust-toolchain.toml`. The MSRV is `rust-version = "1.85"`.

`max_width` is 100. `newline_style` is `Unix`. `use_field_init_shorthand` and `use_try_shorthand` are on.

`imports_granularity` and `group_imports` are not set. They need nightly rustfmt.

## Sources

Stable options: [rustfmt configuration](https://rust-lang.github.io/rustfmt/?version=stable). `edition = "2024"` was accepted by rustfmt 1.8 (Rust 1.83). The edition itself stabilised in Rust 1.85.
