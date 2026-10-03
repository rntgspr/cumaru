# Native Rust CLI

The supported executable is `cumaru`, built at `rust/target/release/cumaru`.
The former `cuma` name is retired. The root `./cumaru` Bash entry point has been
removed. Deprecated `src/*.sh` CLI modules and ShellSpec scenarios remain as
reference for the later test port; that suite cannot run unchanged without its
former entry point. No wrapper silently redirects Bash scenarios to Rust.

## Build and run

```bash
bash rust/build.sh
./rust/target/release/cumaru --version
./rust/target/release/cumaru help
```

The build script works from any directory and preserves incremental artifacts.
For local development, link this checkout's release binary from `~/.local/bin/cumaru`
and include `~/.local/bin` in PATH. Every successful local release build then
updates the executable used by the terminal; source edits alone do not rebuild it.

## Command contracts

All 16 CLI command families are native. The [Rust specification](../.memory/specs/rust.md)
is canonical for their arguments, ownership rules, failure behavior, tests,
and differences from Bash. The command guides in this directory describe the
native contract.

Navigation uses TSV by default, with `--markdown` available. `map` preserves
literal H1-H6 headings and their `#` markers. Neither navigation command needs
config or exposes the former `--pillars`/`--domain` filters. Tag bodies remain
opaque; typed `tag all --rows` is not supported.

Install defaults to `base`, with an explicit stateless adapter target. Domain
content is downloaded from HEAD of `main` and pinned to one commit per invocation.
Optional skills belong to `update skills <agent> --with <name>`, not install.
Source-consuming commands do not support `--from` or local snapshot sources.
Doctor and bare invocation are offline; `help domains` uses cURL against main.

`cumaru version` prints the CLI version and, inside an adopter, the installed
`domain:` and `config:` version read from `.cumaru/config.yaml`. These are
independent identities: upgrading the binary does not migrate the config.
Inside an adopter, it also consults `domains/<domain>/config.yaml` at main HEAD,
printing `source:`, `latest config:`, `config status:`, and `config drift:`.
A lower installed integer is `outdated`; equal versions can still have drift
from missing defaults or incompatible properties. Valid local choices and YAML
formatting do not cause drift. Network/config failures return 1 while retaining
the installed identity; no files are changed. Without an adopter it stays offline.
`--version` prints only the package identity and always stays offline.

## Distribution and transition

[`cumaru context`](context.md) ranks local Markdown offline, using a cached
encoder or the lightweight fallback. [`cumaru model`](model.md) separately lists
the closed GitHub catalog and explicitly installs a model in `~/.cumaru/<name>/`.
These are model packages, not the retired global CLI source snapshot. The binary
does not embed pretrained weights. List/push require the catalog to be published
on main; local prepared-package verification does not establish live availability.

The binary installer remains a Bash script at `rust/install.sh`; Bash also
runs installed session hooks. Deprecating the Bash CLI does not remove those
native distribution components.

The installer publishes `/usr/local/bin/cumaru` and records only the version
in `~/.config/cumaru.json`. It does not remove or replace a legacy `~/.cumaru`
snapshot, another PATH entry, or the former `cuma` binary. Resolve old aliases
and PATH precedence deliberately when switching executables.

Platform release assets still need publication before remote binary installation
can work. A release build and offline smokes do not prove live release availability.
Previously installed `cuma` session hooks are recognized during native refresh
and cleanup so they can be replaced without duplicating Cumaru-owned entries.

## Verification

```bash
cargo test --manifest-path rust/Cargo.toml --locked
cargo fmt --manifest-path rust/Cargo.toml --check
bash rust/build.sh
```

Routine CI runs on Ubuntu 24.04: native tests, formatting, release compilation,
and a release-binary version/help smoke. It does not verify macOS runtime
behavior or build Apple release assets. The Bash job was
removed with its CLI entry point. Retained ShellSpec scenarios do not establish
native parity and require a deliberate port before reuse.
