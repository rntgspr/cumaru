---
name: install-upgrade-specification
description: "Current v9 contract separating project-domain installation from the machine-global binary installer and upgrade."
type: project
status: implemented
version: 9
---

# Install and upgrade specification

## Purpose

`cumaru install` adopts Cumaru in the current project by creating `.cumaru/`
and one agent adapter. `cumaru upgrade` replaces the machine-global `cumaru`
executable with the latest release binary; it never updates an adopter project.

The [Rust specification](rust.md) records the detailed
[project-install](rust.md#project-installation), binary installer
([execution items 9-12](rust.md#execution)), and
[uninstall](rust.md#native-project-uninstall) contracts. The retired Bash
snapshot distribution is summarized under [Historical](#historical-bash-snapshot-distribution).

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>] [--domain <name>]
cumaru upgrade
cumaru upgrade --check
cumaru version
/usr/local/bin/cumaru
~/.config/cumaru.json
curl -fsSL https://raw.githubusercontent.com/rntgspr/cumaru/main/src/install.sh | bash
```

The branding URL `https://pixelpunk.works/cumaru/install.sh` only delegates to
the canonical GitHub URL above. A legacy Bash `cumaru upgrade` reaches the same
native installer.

## Invariants

1. Project install always targets `./.cumaru`, defaults to domain `__base` and
   the generic adapter target, and validates the remote source config before
   project writes.
2. Fresh installs are v9, use `.cumaru/config.yaml`, install no `.state/`, and
   exclude source-only skills, commands, and migration and bootstrap documents
   from `.cumaru/`. Optional skills are added later through `update`.
3. The global installation is binary-only: `src/install.sh` downloads the
   release asset `cumaru-<target>` for macOS ARM64/x86_64 or Linux
   ARM64/x86_64 musl, verifies that `--version` reports the selected version,
   and publishes `/usr/local/bin/cumaru` with mode 755, using `sudo` only when
   the destination is not writable. No domain, skill, or source snapshot is
   installed globally.
4. After binary publication the invoking user's `~/.config/cumaru.json` is
   replaced with `{"version":"X.Y.Z"}` at mode 600. It records that user's
   installation; `version` and `upgrade --check` use the build identity.
5. `src/install.sh` on `main` is the single installer source for direct curl
   installation. Bare `cumaru upgrade` selects the latest release once and runs
   the copy embedded in the binary with that version as its argument.
6. Release selection uses only `git ls-remote --tags --refs` of the public
   repository and the highest plain `X.Y.Z` tag by numeric components. There is
   no `main` fallback; no valid tag fails.
7. Existing project trees cross config versions only through `cumaru migrate`,
   not reinstall or global upgrade.
8. Two versions coexist independently: the CLI package version (`X.Y.Z`, baked
   in at build time) and the integer `config.version` framework contract.
   Neither is derived from the other.
9. `upgrade --check` reads release tags, prints installed, latest, status, and
   upgrade lines, and never writes. `version` prints the CLI identity and, when
   an adopter exists, compares its config with the domain config on main.
10. The installer ends with a warning when an earlier `PATH` entry, such as a
    legacy `~/.local/bin/cumaru` link, shadows the published executable.
11. A Homebrew installation owns its binary: its launcher rejects bare
    `cumaru upgrade` ([Homebrew distribution](rust.md#homebrew-distribution)).

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/<domain>/` at main HEAD | framework | Validated source whose config selects the project starter. |
| Existing project adapter siblings | adopter | Preserved except exact Cumaru-owned entries. |
| `/usr/local/bin/cumaru` | machine installation | Replaced by the installer and bare upgrade. |
| `~/.config/cumaru.json` | invoking user | Replaced with the installed version after binary publication. |
| Project `.cumaru/` after install | adopter plus framework ownership rules | Updated later through `cumaru update`, never by upgrade. |

## Execution

### Preflight

1. Install validates the domain and adapter arguments and refuses any existing
   `.cumaru` entry before network access, then resolves main HEAD and validates
   the complete selected source and native merges before writes. Remote source
   access needs cURL only.
2. An existing `.cumaru/` is never replaced by install. Same-domain refresh and
   opt-in additions use update; domain replacement requires uninstall first.
3. The installer resolves the release, detects the platform, downloads to a
   temporary directory, and verifies the binary version before touching the
   global destination.

### Preview

Neither command has a preview mode. Project install refuses an existing tree;
bare global upgrade is immediate and must not be invoked without explicit user
authorization. `upgrade --check` is the read-only freshness probe.

### Apply

1. Install exclusively creates `.cumaru/`, publishes the selected files,
   installs domain skills and supported commands, and merges instructions and
   supported hooks without persisting adapter selection.
2. The installer stages `~/.config/cumaru.json`, stages the verified binary
   beside `/usr/local/bin/cumaru`, renames it over the previous executable
   without truncating a running one, then renames the config into place.
   Temporary files are removed on exit.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Install invalid domain, adapter, or option | `2` | none |
| Install existing `.cumaru`, source, network, config, adapter, or preflight failure | `1` | no project write |
| Install filesystem failure after publication begins | `1` | partial install may remain; no automatic rollback |
| `upgrade --check`: installed version equals or exceeds the latest tag | `0`, `status: up to date` | none |
| `upgrade --check`: newer remote tag | `0`, `status: behind` | none |
| `upgrade --check`: no tags, unavailable Git or network, or non-release binary | `1`, `cannot check` on stderr | none |
| `upgrade` with extra arguments | `2` | none; installer not run |
| Download, unsupported platform, HTTP 404, or version verification failure | `1` | existing binary and user JSON preserved |
| Binary or config publication failure | `1` | published binary may be newer than the user JSON |
| Successful upgrade or direct installation | `0` | global binary and invoking user's JSON replaced |

## Transaction and recovery

Project install is ordered but not the steady-state conditional-Git update
flow; adapter selection is stateless. The global installer downloads and
verifies before publication, and binary and config writes are separate renames
with no rollback. Recovery is rerunning the installer after correcting the
failure. Because it replaces a machine-global executable, possibly through
`sudo`, agents never run it without an explicit request
([destructive installer discipline](../disciplines/install_sh_destructive.md)).

## Implementation map

| Artifact | Responsibility |
|---|---|
| [`../../src/commands/install.rs`](../../src/commands/install.rs) | Project install arguments, remote selection, preflight, and publication. |
| [`../../src/install.sh`](../../src/install.sh) | Release resolution, platform asset download, version verification, global binary publication, user JSON, and PATH shadow warning. |
| [`../../src/commands/upgrade.rs`](../../src/commands/upgrade.rs) | `upgrade` arguments, `--check` comparison, and installer dispatch. |
| [`../../src/release.rs`](../../src/release.rs) | Build-time `VERSION` and plain numeric release parsing and selection. |
| [`../../src/distribution.rs`](../../src/distribution.rs) | Release-tag listing, main-HEAD domain access, and embedded installer execution. |
| [`../../src/commands/version.rs`](../../src/commands/version.rs) | CLI identity and adopter config version/drift report. |
| [`../../src/adapter.rs`](../../src/adapter.rs) | Native adapter artifact wiring. |

## Principal methods

| Method | Contract |
|---|---|
| `install::validate_disciplines` | Reject invalid selected source discipline metadata before writes. |
| `upgrade::check` | Compare the build version with the highest remote release without writing. |
| `distribution::latest_release` | List tags and select the highest plain `X.Y.Z` release. |
| `distribution::install` | Run the embedded installer for the selected release with inherited streams. |
| `release::release_parts` | Parse a plain numeric release version. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/release.rs` unit tests | Plain release grammar and highest numeric selection. |
| `src/commands/version.rs` unit tests | CLI-only output, installed identity, older contracts, malformed metadata, unsafe layouts, and shipped config alignment. |
| `src/commands/install.rs` unit tests | Install arguments, source disciplines, and project preflight preservation. |
| [`../../tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Stateless adapter installs, existing-install refusal, truncated inventories, and missing remote assets. |

Bare `cumaru upgrade` and the real `src/install.sh` are intentionally not
automated-tested against the machine-global destination. Installer behavior was
verified only on scratch copies with destinations rewritten and the network
stubbed ([binary installer verification](rust.md#current-boundaries)); process
installer cases remain in the [native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
bash -n src/install.sh
```

Do not run `src/install.sh` or `cumaru upgrade` as verification without explicit
authorization.

## Historical Bash snapshot distribution

Historical, retained only in tag 0.10.0: the Bash installer replaced a global
`~/.cumaru` source snapshot unpacked from a release tarball (falling back to
`main`), wrote `~/.cumaru/VERSION`, checked kernel mirror drift at upgrade time,
and relinked `~/.local/bin/cumaru`. `src/cmd_install.sh` and `src/cmd_version.sh`
owned project install and the offline version report. None of this is current
behavior: the native installer creates and removes no `~/.cumaru` snapshot, and
mirror integrity is enforced in CI by `scripts/sync-domain-kernel.sh --check`.

## References

- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/upgrade.md`](../../docs/upgrade.md)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`agent-adapters.md`](agent-adapters.md)
- [`testing.md`](testing.md)
