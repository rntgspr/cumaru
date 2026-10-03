# `cumaru upgrade`

Replace the global `cumaru` binary with the latest release. It never touches a
project's `.cumaru/`, its adapter artifacts, or its config version.

```text
cumaru upgrade [--check]
```

Bare `upgrade` resolves the highest plain `X.Y.Z` release tag once with
`git ls-remote`, then runs the embedded `rust/install.sh` with that version.
The installer downloads the `cumaru-<target>` asset for the detected platform,
verifies that its `--version` equals `cumaru <version>`, publishes it to
`/usr/local/bin/cumaru` (using sudo only for destination writes when needed),
and records `{"version":"X.Y.Z"}` in the invoking user's
`~/.config/cumaru.json`. There is no `main` fallback and no source snapshot.
Bare `upgrade` does not compare versions first: it installs the latest release
tag even when the running build is newer, so run `upgrade --check` before it.

Supported targets are `aarch64-apple-darwin`, `x86_64-apple-darwin`,
`aarch64-unknown-linux-musl`, and `x86_64-unknown-linux-musl`. Compiled assets
are available from [GitHub Releases](https://github.com/rntgspr/cumaru/releases).
Linux ARM64 requires FP16 CPU instruction support. HTTP 404 names a missing
asset and URL. A failed download,
unsupported platform, or version mismatch leaves the existing binary and JSON
in place.

## Version and staleness check

```text
cumaru --version        # offline: CLI build identity only
cumaru version          # CLI identity; inside a project, installed and latest config at main HEAD
cumaru upgrade --check  # network: compare the CLI build with the latest release tag; installs nothing
```

Two version identities are independent:

- **CLI** — the build-time package version, for example `0.10.0`, compared by
  `upgrade --check` with plain `X.Y.Z` release tags.
- **Config** — the integer `config.version` (`9`) of an installed project,
  compared by `cumaru version` and gated by `cumaru update` with the domain
  config at HEAD of `main`. It changes only through `cumaru migrate`.

`upgrade --check` prints `installed`, `latest`, `status`, and the upgrade
command. Both `behind` and `up to date` exit `0`. Missing tags, unavailable Git
or network, or an invalid build version print `cannot check` on stderr and exit
`1`. Neither field says anything about a project's config. `cumaru doctor`
never checks staleness; it stays offline.

## Kernel integrity

Universal artifacts must be byte-identical across every shipped domain. That is
a source-repository property, enforced by `scripts/sync-domain-kernel.sh --check`
in CI rather than at upgrade or install time; see
[architecture](architecture.md#reuse-mechanism).

## Scope

| Concern | Command |
|---|---|
| The global `cumaru` binary and `~/.config/cumaru.json` | `cumaru upgrade` |
| An installed project tree (`.cumaru/`, its skills, commands, instructions) | [`cumaru update`](update.md) |

Upgrading the binary does not migrate or refresh any project. A legacy
`~/.cumaru` snapshot, another PATH entry, or a former `cuma` binary is neither
removed nor replaced; resolve PATH precedence deliberately. A local development
symlink to `rust/target/release/cumaru` is managed by rebuilding, not by
`upgrade`; see the [native CLI guide](rust.md).

## Related

- [`cumaru update`](update.md) — steady-state update of an installed `.cumaru/` tree.
- [Native CLI guide](rust.md) — build, distribution, and verification.
