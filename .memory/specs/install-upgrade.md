---
name: install-upgrade-specification
description: "Current v9 contract separating project-domain installation from destructive global CLI upgrade."
type: project
status: implemented
version: 9
---

# Install and upgrade specification

## Purpose

`cumaru install` adopts Cumaru in the current project by creating `.cumaru/`
and one agent adapter. `cumaru upgrade` replaces the machine-global Cumaru
snapshot and executable link; it never updates an adopter project.

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>] [--domain <name>] [--with <skill>...]
cumaru upgrade
cumaru upgrade --check
cumaru version
~/.cumaru
~/.local/bin/cumaru
curl -fsSL https://raw.githubusercontent.com/rntgspr/cumaru/main/src/install.sh | bash
```

The README one-liner `https://pixelpunk.works/cumaru/install.sh` is branding
only: that hosted script does nothing but delegate to the canonical GitHub URL
above, and the pixelpunk address appears only in the README.

## Invariants

1. Project install always targets `./.cumaru`, defaults to domain `sdlc-full`
   and the generic adapter target, and validates source config before project writes.
2. Fresh installs are v9, use `.cumaru/config.yaml`, install no `.state/`, and
   exclude source-only skills, commands, and migration documents from `.cumaru/`.
3. Global upgrade is deliberately destructive: it downloads and unpacks
   GitHub's tarball of the latest release tag into a temporary directory, then
   replaces `~/.cumaru` with it, verifies kernel integrity, and relinks `~/.local/bin/cumaru`
   without touching project `.cumaru/` trees.
4. The global snapshot carries runtime paths only: `cumaru`, `src/`,
   `domains/`, `skills/`, `schemas/`, `VERSION`, and `README.md`. Maintainer-only paths
   (`.memory/`, `tests/`, `.shellspec`, `docs/`, `.github/`, `.claude/`,
   `.codex/`, `report/`, `scripts/`, `.gitignore`, `.gitattributes`) are marked
   `export-ignore` in `.gitattributes`, which GitHub's archive tarballs honor,
   and never ship; adopters do not need them. The installer adds `VERSION`.
5. `src/install.sh` on `main` is the single installer source. First install
   and `cumaru upgrade` both run it from GitHub; upgrade never runs the
   installed copy, so installer fixes apply on the upgrade that fetches them.
6. The installer uses public HTTPS only and requires no SSH key. It makes no
   clone: Git is needed only for `git ls-remote --tags --refs
   https://github.com/rntgspr/cumaru.git`, and cURL downloads
   `https://github.com/rntgspr/cumaru/archive/refs/tags/<tag>.tar.gz`, or
   `.../archive/refs/heads/main.tar.gz` while no release tag exists.
7. Existing project trees cross versions only through `cumaru migrate`, not
   reinstall or global upgrade.
8. Two versions coexist. The integer `config.version` is the framework
   contract. The distribution version is a plain `X.Y.Z` Git tag (no `v`
   prefix; the first is `9.0.0`) whose major equals that contract; releases
   are tags only, cut by the maintainer. The installer installs the highest
   strictly `X.Y.Z` tag (numeric order) and falls back to `main` only when none
   exists.
9. The snapshot identity does not depend on Git history, because `main` is
   amended and force-pushed: the installer writes the resolved tag name, or
   `main` for the fallback, into `~/.cumaru/VERSION`. Tag tarballs remain
   downloadable regardless of `main`.
10. `cumaru version` is offline and exits `0`; a Git checkout without
    `VERSION` reports `development build`.
11. The network is used only by the explicit `cumaru upgrade --check`, which
    reads `git ls-remote --tags --refs` of the public repository, compares the
    installed tag with the highest remote `X.Y.Z`, and never writes. A lower
    installed tag, or `main` once any tag exists, is behind.
    `cumaru doctor` stays offline and never reports staleness.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/<domain>/` | framework | Validated source copied as the project starter. |
| `skills/<name>/SKILL.md` selected by `--with` | framework | Optional skill copied into the selected adapter. |
| Existing project adapter siblings | adopter | Preserved except exact Cumaru-owned entries. |
| `~/.cumaru` | framework installation | Wholesale replacement target of global upgrade. |
| `.gitattributes` | framework | `export-ignore` list defining what never ships in the global snapshot. |
| Project `.cumaru/` after install | adopter plus framework ownership rules | Updated later through `cumaru update`, never by upgrade. |

## Execution

### Preflight

1. Install requires Bash, cURL, Git, ripgrep (`rg`), `jq`, and Mike Farah `yq`
   v4; validates the selected domain and every requested opt-in skill.
2. An existing `.cumaru/` is never replaced by install. Same-domain refresh and
   opt-in additions use update; domain replacement requires uninstall first.
3. Upgrade performs no project preflight because its target is global; its
   downloaded snapshot must pass universal-artifact byte-drift checks.

### Dry-run

Neither command has a dry-run mode. Project install refuses an existing tree;
global upgrade is immediate and must not be invoked without explicit user
authorization.

### Apply

1. Install copies the validated domain, prunes source-only directories/files,
   installs domain and opt-in skills, wires instructions and supported commands,
   and registers hooks where supported without persisting adapter selection.
2. Upgrade fetches and runs `src/install.sh` from `main` on GitHub, never the
   installed copy. The installer resolves the latest release tag, downloads and
   unpacks its tarball (`--strip-components=1`) into a temporary directory,
   writes `VERSION`, and only then removes `~/.cumaru` and moves the snapshot
   into place. It checks `index.md` plus universal skills, commands, and
   disciplines against `domains/__base`, then updates the executable symlink.
   The temporary directory is removed on exit.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Install usage, domain, skill, dependency, or source validation failure | nonzero | no project write before validation |
| Existing project install | nonzero | existing project preserved |
| Upgrade kernel drift | `1` | global snapshot already replaced; executable is not relinked |
| Installer script fetch, tag listing, tarball download, or unpack failure | nonzero | existing global installation untouched |
| Global filesystem failure while replacing `~/.cumaru` | nonzero | global installation may be absent or partial |
| `upgrade --check`: installed tag equals or exceeds the latest remote tag | `0`, `status: up to date` | none |
| `upgrade --check`: newer remote tag, or `main` snapshot with any remote tag | `0`, `status: behind` | none |
| `upgrade --check`: remote unreachable, no `X.Y.Z` tag, or development build | `1`, `cannot check` on stderr | none |
| `upgrade --check` with extra arguments | `2` | none; installer not run |

## Transaction and recovery

Project install is ordered but not the steady-state conditional-Git update
flow; adapter selection is stateless. Global upgrade has no rollback
transaction: it downloads and unpacks before deleting `~/.cumaru`, so network
and archive failures preserve the old snapshot, but replacement or drift
failures leave it replaced or partial. Recovery is rerunning the installer after
correcting the failure. This destructive boundary is why agents must never run
upgrade without an explicit request.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/cmd_install.sh`](../../src/cmd_install.sh) | Project install parsing, source validation, copy, pruning, and adapter installation. |
| [`../../src/install.sh`](../../src/install.sh) | Latest-tag resolution, tarball download, `VERSION`, destructive global snapshot replacement, drift check, and symlink. |
| [`../../.gitattributes`](../../.gitattributes) | Maintainer-only `export-ignore` paths excluded from GitHub's archive tarballs. |
| [`../../src/cmd_version.sh`](../../src/cmd_version.sh) | `cumaru version` and the read-only `cumaru upgrade --check` comparison. |
| [`../../cumaru`](../../cumaru) | Dispatches `install` and `version`; `upgrade --check` compares, bare `upgrade` fetches and runs the installer from `main`. |
| [`../../src/agent_adapter.sh`](../../src/agent_adapter.sh) | Native adapter artifact wiring. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_install` | Validate options/domain and materialize one v9 project install. |
| `_framework_install_skills` | Install domain universal skills plus requested opt-ins into the explicit adapter path. |
| `_framework_copy_commands` | Install only commands supported by the adapter. |
| `src/install.sh` integrity loops | Require every non-exempt universal mirror to equal `__base` byte-for-byte. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Project-install fixtures and all adapter artifact matrices. |
| [`../../tests/spec/integration/schema_spec.sh`](../../tests/spec/integration/schema_spec.sh) | Every source domain config validates under the v9 global model. |
| [`../../tests/spec/contracts/documented_contracts_spec.sh`](../../tests/spec/contracts/documented_contracts_spec.sh) | Public install/upgrade help and documented surface. |
| [`../../tests/spec/cli/version_spec.sh`](../../tests/spec/cli/version_spec.sh) | A rewritten installer copy (scratch `DEST`/`BIN`, stubbed `curl`, redirected `ls-remote`): highest-tag install writing `VERSION`, `main` fallback, download failure preserving the old snapshot; `cumaru version`, development build, and `upgrade --check` behind / up to date / cannot check with HOME unchanged. |

Bare `cumaru upgrade` is intentionally not automated-tested. It destroys the
machine-global `~/.cumaru`. The installer is exercised only as a copy whose
`DEST` and `BIN` are rewritten to scratch paths with the network stubbed; the
real `src/install.sh` is never run against `~/.cumaru` by tests.

## Verification

```bash
shellspec tests/spec/integration/agent_adapters_spec.sh tests/spec/integration/schema_spec.sh
bash tests/run.sh
```

Do not run `src/install.sh` as verification without explicit authorization.

## References

- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/upgrade.md`](../../docs/upgrade.md)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`agent-adapters.md`](agent-adapters.md)
- [`testing.md`](testing.md)
- [`../disciplines/install_sh_destructive.md`](../disciplines/install_sh_destructive.md)
