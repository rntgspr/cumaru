---
name: architecture-specification
description: "Current v9 kernel, configuration, ownership, adapter, and lifecycle architecture"
type: project
status: implemented
version: 9
---

# Architecture specification

## Purpose

Define Cumaru's v9 system boundaries: a domain-neutral kernel, self-contained
domains, filesystem-backed knowledge navigation, one global configuration
model, semantic tag islands, and agent-native delivery.

The [Rust CLI contract](rust.md#port-status) records every native command and
its shared module boundaries. Rust is the only supported CLI; tag 0.10.0 keeps
the removed Bash modules as port reference. Rust uses a binary-only global
installation and remote main-HEAD domain source resolution.

## Public surface

```text
cumaru install|uninstall|update|migrate|bootstrap|upgrade|version
cumaru tree|map|get|tag|fs|coverage|doctor|help|hooks|context|model
.cumaru/{index.md,domain.md,config.yaml}
schemas/config.schema.json
domains/__base/
domains/<domain>/
```

The shipped domain catalog is canonical in [domains](domains.md).

## Invariants

1. `domains/__base/index.md` is the domain-neutral kernel and is byte-identical
   in every shipped domain.
2. `schemas/config.schema.json` is the only active configuration model;
   domain and adopter `config.yaml` files validate against it.
3. The filesystem is structural truth. Marker blocks hold semantic adopter
   data, never child inventories.
4. Frontmatter and outside-tag prose of explicitly framework-owned Markdown
   are canonical; local tag bodies and local-only files are adopter-owned.
5. Every installed Markdown file has a trimmed 32-512-code-point `summary:`;
   every non-hidden directory has `index.md`.
6. Adapter targets are explicit and stateless; only Cumaru-owned native
   artifacts may be installed, refreshed, or removed.
7. Transient lifecycle content is removed after absorption. The durable pillar
   is the sole current record; Git history is the historical cross-reference.
8. Execution disciplines load eagerly; relevance controls application, not
   delivery.
9. Every discipline except its index declares `strictness: 0/10` through
   `10/10`; missing metadata is invalid and has effective strictness `0/10`.
10. `config.version` is the sole framework version source. The direct `root`
    tree declares structure and explicit `framework: true` ownership; named
    `workflows` optionally declare skill dependency graphs.
11. Governed knowledge remains inside the adopter's `.cumaru/` tree. External
    project-root pillar mounts are intentionally out of scope; `path` overrides
    relocate entries only within that tree. This boundary does not change native
    agent-adapter artifacts or read-only references to project source files.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `schemas/config.schema.json` | framework | Closed global v9 model used by runtime validation. |
| `domains/<domain>/` | framework | Self-contained canonical source and initial config values. |
| `.cumaru/config.yaml` | adopter | Every valid present value is preserved; config reconciliation adds defaults and removes incompatible keys. |
| Explicitly framework-owned Markdown outside tags | framework | Replaced from the matching source at equal version. |
| `<!-- cumaru:NAME -->` bodies | adopter | Preserved by canonical name, independent of schema type or host. |
| Local-only files and directories | adopter | Never changed by update. |
| Adapter instructions, hooks, `cumaru-*` skills and commands | framework | Deterministically reconciled for the selected adapter. |

## Execution

### Preflight

1. The native binary embeds its schema and parses YAML, Markdown, and tags
   in-process. Domain source access (install, update, bootstrap, migrate,
   version, help domains, doctor drift) uses cURL against main HEAD. Git is
   used read-only: release tags for `upgrade --check`, `ls-files` for
   coverage, and the work-tree probe for update recovery. Bare `upgrade` runs
   the embedded `src/install.sh` through Bash. No other external runtime tool
   is spawned.
2. Validate config shape, selected domain, and integer config version before
   steady-state mutation; no Markdown `framework-version` is required.
3. Reject cross-version update; migration converges supported N directly to v9.

### Preview

1. Update modes calculate canonical content, ownership-preserving tag merges,
   adapter changes, or config reconciliation without mutation.
2. Migration only prints the current rolling instructions.
3. Read-only navigation, coverage, help, and health inspection do not create
   locks, staging trees, or backups.

### Apply

1. Install materializes the structure one validated domain config selects and
   wires one selected adapter.
2. Update checks the conditional Git recovery boundary, writes only the
   selected managed surfaces directly, then validates them with doctor.
3. `update config` reports `.cumaru/config.yaml` schema/default drift for the
   agent to reconcile deliberately; it never publishes a replacement.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage error | `2` | none |
| Invalid config, tree, source, or safety boundary | `1` | none |
| Embedded-schema or source access runtime failure | `1` | none |
| Update validation failure before mutation | `1` | none |
| Update write or post-check failure | `1` | partial mutation possible; restore from Git history |

## Transaction and recovery

Update apply checks for an existing Git work tree before mutation. Inside Git it
requires a clean committed Cumaru baseline; outside Git it warns and continues
without a Git recovery point. It then writes managed surfaces directly and runs
doctor after mutation, creating no project-local lock, staging, private backup,
or recovery directory.
Migration is read-only at the CLI layer; its LLM-executed edits require tracked
Git history before mutation.

## Implementation map

The separate [Rust CLI specification](rust.md) records the current native CLI surface,
module boundaries, and implementation limits.

| Artifact | Responsibility |
|---|---|
| [`src/main.rs`](../../src/main.rs) | Native CLI arguments and dispatch. |
| [`src/commands/`](../../src/commands.rs) | One module per command family. |
| [`src/config.rs`](../../src/config.rs) | Embedded-schema loading, validation, and read-only reconciliation. |
| [`src/config_tree.rs`](../../src/config_tree.rs) | V9 selector resolution, ownership, and per-host contracts. |
| [`src/tags.rs`](../../src/tags.rs) | Balanced tag parsing, merge, and replacement. |
| [`src/walk.rs`](../../src/walk.rs) | Contained traversal shared by navigation, tag, coverage, doctor, and update. |
| [`src/artifacts.rs`](../../src/artifacts.rs) | Owned native artifact inventories, change planning, and direct publication. |
| [`src/adapter.rs`](../../src/adapter.rs) | Native adapter paths, instructions, hooks, and cleanup. |
| [`src/distribution.rs`](../../src/distribution.rs) | Main-HEAD resolution, commit-pinned domain reads, and binary release access. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Installed-tree acceptance gate. |
| [`domains/__base/`](../../domains/__base/index.md) | Canonical kernel and universal artifacts. |

## Principal methods

| Method | Contract |
|---|---|
| `config::load` | Validate the installed single-document config against the embedded schema. |
| `config_tree::contracts` | Resolve the v9 tree into per-host frontmatter and tag contracts. |
| `tags::merge` | Fail-closed canonical Markdown merge preserving local tag bodies. |
| `update::recovery` | Enforce clean committed recovery inside Git and permit warned non-Git mutation. |
| `adapter::markdown` | Install selected adapter instructions without deleting adopter content. |
| `doctor::inspect` | Execute v9 tree validation and installed-tree checks. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| Rust unit tests beside each module | Config, tree, tags, adapters, artifacts, update, doctor, and command mechanics. |
| [`tests/native/`](../../tests/native/README.md) | Process-level navigation, fs, coverage, lifecycle, model, and domain scenarios. |
| `tests/spec/contracts/` (selected subset) | Universal artifact contracts reused by `tests/run.sh`. |

## Verification

```bash
cargo test --locked
bash tests/run.sh
bash tests/run.sh --random
```

## References

- [Design as Code domain contract](design-as-code.md) — six pillars, role boundaries, and evidence-driven delivery.

- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`../../schemas/config.schema.json`](../../schemas/config.schema.json)
- [`update.md`](update.md)
- [`navigation.md`](navigation.md)
