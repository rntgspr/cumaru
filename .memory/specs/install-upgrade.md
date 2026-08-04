---
name: install-upgrade-specification
description: "Current v7 contract separating project-domain installation from destructive global CLI upgrade."
type: project
status: implemented
version: 7
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
~/.cumaru
~/.local/bin/cumaru
```

## Invariants

1. Project install always targets `./.cumaru`, defaults to domain `sdlc-full`
   and generic `agent: null`, and validates source config before project writes.
2. Fresh installs are v7, use `.cumaru/config.yaml`, install no `.state/`, and
   exclude source-only skills, commands, and migration documents from `.cumaru/`.
3. Global upgrade is deliberately destructive: it wipes `~/.cumaru`, shallow
   clones a fresh snapshot, removes its `.git/`, verifies kernel integrity, and
   relinks `~/.local/bin/cumaru` without touching project `.cumaru/` trees.
4. Existing project trees cross versions only through `cumaru migrate`, not
   reinstall or global upgrade.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/<domain>/` | framework | Validated source copied as the project starter. |
| `skills/<name>/SKILL.md` selected by `--with` | framework | Optional skill copied into the selected adapter. |
| Existing project adapter siblings | adopter | Preserved except exact Cumaru-owned entries. |
| `~/.cumaru` | framework installation | Wholesale replacement target of global upgrade. |
| Project `.cumaru/` after install | adopter plus framework ownership rules | Updated later through `cumaru update`, never by upgrade. |

## Execution

### Preflight

1. Install requires Bash, cURL, Git, `jq`, and Mike Farah `yq` v4; validates
   the selected domain and every requested opt-in skill.
2. Replacing an existing `.cumaru/` requires an interactive confirmation;
   non-interactive overwrite is refused.
3. Upgrade performs no project preflight because its target is global; its
   downloaded snapshot must pass universal-artifact byte-drift checks.

### Dry-run

Neither command has a dry-run mode. Project replacement requires confirmation;
global upgrade is immediate and must not be invoked without explicit user
authorization.

### Apply

1. Install copies the validated domain, prunes source-only directories/files,
   installs domain and opt-in skills, wires instructions and supported commands,
   registers hooks where supported, and writes `agent` last.
2. Upgrade removes `~/.cumaru`, clones the repository at depth one, removes
   `.git`, checks `index.md` plus universal skills, commands, and disciplines
   against `domains/__base`, then updates the executable symlink.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Install usage, domain, skill, dependency, or source validation failure | nonzero | no project write before validation |
| Non-interactive project overwrite | nonzero | existing project preserved |
| Upgrade kernel drift | `1` | global snapshot already replaced; executable is not relinked |
| Clone or global filesystem failure | nonzero | global installation may be absent or partial |

## Transaction and recovery

Project install is ordered but not the steady-state clean-Git update flow; state
selection is persisted last. Global upgrade has no rollback transaction and
deletes `~/.cumaru` before cloning. Recovery is rerunning the installer after
correcting the failure. This destructive boundary is why agents must never run
upgrade without an explicit request.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/cmd_install.sh`](../../src/cmd_install.sh) | Project install parsing, source validation, copy, pruning, and adapter installation. |
| [`../../src/install.sh`](../../src/install.sh) | Destructive global snapshot replacement, drift check, and symlink. |
| [`../../cumaru`](../../cumaru) | Dispatches `install` and `upgrade`. |
| [`../../src/agent_adapter.sh`](../../src/agent_adapter.sh) | Native adapter artifact wiring. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_install` | Validate options/domain and materialize one v7 project install. |
| `_framework_install_skills` | Install domain universal skills plus requested opt-ins into the active adapter path. |
| `_framework_copy_commands` | Install only commands supported by the adapter. |
| `src/install.sh` integrity loops | Require every non-exempt universal mirror to equal `__base` byte-for-byte. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Project-install fixtures and all adapter artifact matrices. |
| [`../../tests/spec/integration/schema_spec.sh`](../../tests/spec/integration/schema_spec.sh) | Every source domain config validates under the v7 global model. |
| [`../../tests/spec/contracts/documented_contracts_spec.sh`](../../tests/spec/contracts/documented_contracts_spec.sh) | Public install/upgrade help and documented surface. |

`cumaru upgrade` is intentionally not automated-tested. It destroys the
machine-global `~/.cumaru`; isolating that behavior was explicitly rejected.
Changes to upgrade require direct review of `src/install.sh`, not a regression
test that risks the active development installation.

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
