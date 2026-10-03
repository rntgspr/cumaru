# Developing Cumaru

This guide covers the source checkout, implementation boundaries, local build,
and verification. For installing and using the compiled CLI, start with the
[README](README.md).

## Get the source

```bash
git clone https://github.com/rntgspr/cumaru.git
cd cumaru
```

Use a stable [Rust toolchain](https://rustup.rs/) with Cargo and rustfmt. Git and cURL support source
discovery, coverage, and command checks; Bash runs the build/download scripts
and installed session hooks. The native runtime needs no Python, jq, yq, or rg.
Some retained maintenance scripts and legacy tests have separate requirements.

Before repository work, follow the startup policy in
[.memory/index.md](.memory/index.md). Load specifications on demand rather than
reading the entire memory tree.

## Architecture

The CLI is native Rust. `rust/src/main.rs` parses and dispatches commands;
`rust/src/commands/` owns command orchestration. Shared modules hold reusable
mechanics rather than domain workflows.

| Surface | Responsibility |
|---|---|
| `walk.rs`, `paths.rs`, `markdown.rs`, `tsv.rs` | Safe traversal, Markdown inspection, and deterministic output. |
| `config.rs`, `config_tree.rs`, `tags.rs` | Embedded schemas, configured tree resolution, and balanced opaque tags. |
| `distribution.rs`, `adapter.rs`, `artifacts.rs` | Pinned remote sources, native agent surfaces, and managed publication. |
| `models.rs`, `relevance.rs` | Optional verified encoder cache and lightweight relevance fallback. |
| `domains/__base/` | Canonical kernel, universal skills, launchers, and disciplines. |
| `domains/<name>/` | Self-contained domain configuration, pillars, roles, and workflows. |
| `models/catalog.json` | Closed model metadata; model weights are downloaded separately. |

The adopter's knowledge stays in its project `.cumaru/`:

```text
.cumaru/
├── index.md
├── domain.md
├── config.yaml
├── disciplines/
├── roles/
├── templates/
└── <pillar>/
    └── index.md
```

The filesystem supplies structure and candidates. Config declares metadata/tag
requirements and explicit framework ownership. Semantic tag bodies and local-only
paths are adopter data; framework update preserves them. Domain workflows remain
agent recipes, not hardcoded CLI lifecycle commands.

Bootstrap loads kernel, domain, discipline index, and remaining disciplines before
the root candidate projection. Agents select relevant candidates, inspect headings
or summaries, and load only the necessary bodies. Context ranking aids selection;
it does not replace bootstrap, source tools, or acceptance evidence.

Read [architecture](docs/architecture.md) and the [native specification](.memory/specs/rust.md)
for canonical contracts. CLI package version and adopter config version are independent.

## Build and run locally

```bash
bash rust/build.sh
./rust/target/release/cumaru --version
./rust/target/release/cumaru help
```

The script resolves its own manifest, uses `--release --locked`, and preserves
incremental artifacts. The executable is `rust/target/release/cumaru`.
For a quick development invocation:

```bash
cargo run --manifest-path rust/Cargo.toml -- help
```

Source-consuming commands still read GitHub main, pinned per invocation; building
a local binary does not make install/update read the local domain checkout.
Runtime navigation and context querying use the current project's `.cumaru/`.

## Optional development PATH link

If `~/.local/bin/cumaru` is unused, create a link from the repository root:

```bash
mkdir -p ~/.local/bin
ln -s "$PWD/rust/target/release/cumaru" ~/.local/bin/cumaru
```

Add `~/.local/bin` to PATH if needed. Rebuilding updates the executable reached by
the link; editing source alone does not. Inspect existing binaries, aliases, and
PATH precedence before changing them. This development link is separate from the
release installer's `/usr/local/bin/cumaru` destination. Do not run global upgrade
to refresh a development build.

## Verify changes

```bash
cargo fmt --manifest-path rust/Cargo.toml --check
cargo test --manifest-path rust/Cargo.toml --locked
bash rust/build.sh
./rust/target/release/cumaru --version
./rust/target/release/cumaru help
git diff --check
scripts/sync-domain-kernel.sh --check
```

Native tests live beside implementations. The prepared-model smoke is explicitly
opt-in; its setup and limits are in the [context/model specification](.memory/specs/context.md).
Use disposable projects and cache roots when exercising writes. Never use a real
global installer or adopter uninstall as routine verification.

After editing canonical universal domain artifacts, follow the
[synchronization contract](.memory/specs/sync-domain-kernel.md). Domain-owned
exceptions must remain intact.

## Distribution and legacy boundaries

`rust/install.sh` downloads a platform binary, verifies its reported version,
publishes `/usr/local/bin/cumaru`, and records `~/.config/cumaru.json`. It does not
compile source. Release assets must be published before this route can work;
local builds and routine test CI do not publish them. The
[release workflow](.github/workflows/release.yml) runs on plain numeric tag pushes.
It checks that the tag matches `rust/Cargo.toml`, tests/builds all four targets,
smokes each executable, and publishes the complete asset set plus `SHA256SUMS`
only after every target succeeds. Linux binaries must have no ELF interpreter.
The workflow can also rebuild an existing tag through `workflow_dispatch`.
The Linux ARM64 asset requires FP16 CPU instructions because the locked Candle
GEMM dependency contains FP16 assembly. Its build enables `+fp16` explicitly.

Supported installer targets are macOS ARM64/x86_64 and Linux ARM64/x86_64 musl.
Routine native CI runs on Ubuntu 24.04. Actual build/runtime evidence for each
target remains separate from an installer's platform selection table.

The root Bash CLI and former `cuma` name are retired. Deprecated `src/*.sh` and
ShellSpec scenarios remain reference material; the old suite cannot run unchanged
without its removed entry point. The Bash download installer and session hooks
remain valid native distribution components. Do not use the old hosted installer
for the supported Rust executable.

Model packages in `~/.cumaru/<name>/` are distinct from the retired global source
snapshot. Existing legacy state and unrelated PATH entries are not cleaned up
automatically by the native installer.

- [Native CLI guide](docs/rust.md)
- [Testing contract](.memory/specs/testing.md)
- [Context and model experiments](.memory/plans/context/index.md)
