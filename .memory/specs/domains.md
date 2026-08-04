---
name: domains-specification
description: "Self-contained v7 domain sources, universal mirrors, installation, and adapter selection"
type: project
status: implemented
version: 7
---

# Domains specification

## Purpose

Define how Cumaru packages one self-contained knowledge model per domain and
installs exactly one validated domain plus one agent adapter into a project.

## Public surface

```text
cumaru help domains
cumaru install [agent <none|claude|codex|opencode>]
               [--domain <name>] [--with <skill>...]
domains/__base/
domains/{sdlc-full,sdlc-light,iac-basic,qa-basic,vault-memory}/
```

## Invariants

1. A domain is self-contained; installation does not merge or inherit domain
   trees at runtime. `base` resolves to `domains/__base/`.
2. Each source `config.yaml` validates against the global v7 model and names
   its domain, integer version, entities, tags, rules, and initial values.
3. Kernel `index.md`, universal skills, universal commands, and universal
   disciplines are authored in `__base` and mirrored byte-identically, except
   declared domain-owned artifacts such as `cumaru-install` and indexes.
4. Domain-specific pillars, roles, lifecycle, skills, and commands live only
   in that domain. `domain.md` carries domain semantics.
5. Install validates the complete source before project writes, copies the
   selected domain, excludes source-only skills/commands/migration prose from
   `.cumaru/`, then installs native artifacts separately.
6. Missing or null `agent` means generic; explicit values are `claude`,
   `codex`, and `opencode`.
7. Every `commands/cumaru/<name>.md` requires a regular
   `skills/cumaru-<name>/SKILL.md` in the same source domain. Commands are thin
   argument-forwarding launchers; skills own every workflow recipe.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/<domain>/config.yaml` | framework/domain author | Valid initial v7 configuration. |
| `domains/<domain>/domain.md` | framework/domain author | Pillars, lifecycle, roles, and domain context. |
| Universal mirrors | framework | Must match `__base` under distribution integrity checks. |
| Domain skills and commands | framework/domain author | Installed only when the selected domain ships them. |
| `--with <skill>` | user | Opt-in top-level skill, validated before writes. |
| `.cumaru/config.yaml` after install | adopter | Effective configuration; `agent` is persisted last. |

## Execution

### Preflight

1. Parse domain, adapter, and opt-in skill arguments.
2. Refuse unsafe or non-interactive replacement of an existing install.
3. Resolve and fully validate the source domain and every requested opt-in.
4. Distribution installation checks universal mirror drift before linking the
   CLI snapshot.

### Dry-run

1. Domain discovery and help read source metadata without mutation.
2. Project install has no dry-run mode; confirmation and validation are its
   pre-mutation boundary.

### Apply

1. Copy the selected domain to `.cumaru/` and prune source-only artifacts.
2. Install domain `cumaru-*` skills, supported commands, and requested opt-ins
   into the selected adapter paths.
3. Wire ordered kernel, domain, and discipline instructions plus SessionStart
   where supported.
4. Persist normalized `agent` state last and print doctor-oriented next steps.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage, unknown domain/agent/skill | `2` or `1` as classified by CLI | none before copy |
| Invalid source config | `1` | none |
| Existing install without accepted confirmation | `1` | none |
| Kernel drift during tool installation | nonzero | tool snapshot not linked |
| Adapter write failure | `1` | install may be incomplete; `agent` is not persisted early |

## Transaction and recovery

Project installation is ordered but is not the update transaction. It writes
adapter state only after the domain and native artifacts exist. Existing
install replacement requires explicit confirmation; recovery is user-owned.
`cumaru upgrade` is machine-global and destructive to `~/.cumaru`, and is not
run or regression-tested without explicit authorization.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `src/cmd_install.sh` | Project install parsing, domain copy, skills, commands, and help discovery. |
| `src/agent_adapter.sh` | Adapter normalization, paths, instructions, hooks, and cleanup. |
| `src/schema.sh` | Complete source-domain validation. |
| `src/install.sh` | Tool installation and distribution drift check. |
| `domains/*/config.yaml` | Domain initial configuration. |
| `domains/*/domain.md` | Domain-specific model and lifecycle prose. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_install` | Validate and install one domain and adapter. |
| `_install_list_domains` | Discover public domains and summarize their `domain.md`. |
| `_framework_install_skills` | Install domain and universal managed skills. |
| `_framework_copy_commands` | Copy only commands supported by the selected adapter. |
| `schema_validate_domain` | Validate config and selected-domain agreement. |
| `_agent_wire_instructions` | Materialize canonical bootstrap for one adapter. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/integration/schema_spec.sh` | Every domain config and semantic constraints. |
| `tests/spec/integration/agent_adapters_spec.sh` | Domain artifacts across all adapters. |
| `tests/spec/contracts/documented_contracts_spec.sh` | Domain help and universal mirror contracts. |
| `tests/spec/cli/doctor_spec.sh` | Installed domain and adapter acceptance. |

## Known gaps

- `domains/qa-basic/domain.md` says `coverage/index.md` records an absorbed
  campaign SHA, contradicting the v7 no-ledger, durable-pillar-only contract.
  This specification records but does not resolve that source contradiction.

## Verification

```bash
shellspec tests/spec/integration/schema_spec.sh tests/spec/integration/agent_adapters_spec.sh
bash tests/run.sh
```

## References

- [`../../src/cmd_install.sh`](../../src/cmd_install.sh)
- [`../../src/install.sh`](../../src/install.sh)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`install-upgrade.md`](install-upgrade.md)
- [`disciplines.md`](disciplines.md)
