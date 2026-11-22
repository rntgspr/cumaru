---
name: cumaru-update-specification
description: "Steady-state v9 refresh across general, scoped, artifact, configuration, and agent modes"
type: project
status: implemented
version: 9
---

# Cumaru update specification

The [native Rust update contract](rust.md#native-project-update) records the
detailed main-HEAD resolution, merge, selector, and postcheck execution. This
specification owns the capability-level invariants and public surface.

The universal `cumaru-update` skill targets the native CLI. It checks
`cumaru version` at the adopter root and reports CLI build, domain identity,
and installed/latest config integers plus drift separately. Latest config is read
from `domains/<installed-domain>/config.yaml` at the resolved HEAD of main, never
from a CLI tag. Only source/local config integers
determine migration; CLI freshness and GitHub tags never stand in for config
metadata. Global upgrade remains an explicitly requested separate operation.
The skill restricts separate commands refresh to Generic/OpenCode. Its copies
are universal mirrors.

## Purpose

`cumaru update` refreshes an installed v9 project from its selected source
domain without crossing an integer config-version boundary. It supports
general and path-scoped content refresh, dedicated skills, commands, and
configuration modes, plus adapter switching. Installation and refresh preview
by default; `--clear` is an immediate mutating exception.

## Public surface

```text
cumaru update [<path>] [--prose|--skip-prose] [--apply]
cumaru update config
cumaru update skills <agent> [--with <skill>...] [--apply|--clear]
cumaru update commands <agent> [--apply|--clear]
cumaru update agent <agent> [--prose|--skip-prose] [--skills] [--apply|--clear]
cumaru update skills|commands|agent --clear
```

`<agent>` is `none`, `claude`, `codex`, or `opencode`. Every refresh reads the
installed domain from HEAD of main; there is no `--from`, local checkout, or
snapshot source. The [public guide](../../docs/update.md#selectors) owns the
selector examples.

## Invariants

1. The installed config must be version 9, and main's domain config must name
   the same domain and integer version before any plan; any difference routes
   to `cumaru migrate`.
2. Install and refresh dry-runs create no lock, staging tree, backup, or
   managed-surface mutation. `--clear` is never a dry-run.
3. General update never changes `config.yaml`; `update config` only reports
   schema/default drift for agent-led reconciliation.
4. Local tag bodies and local-only files are adopter-owned; explicitly marked
   framework Markdown, Cumaru skills, supported commands, instructions, and
   hooks are framework-owned.
5. Every `--apply` or `--clear` mutation checks for an existing Git work tree.
   When present, it requires a clean committed baseline and uses Git history as
   recovery. Without Git or outside a work tree, it warns and continues without
   creating project-local transient recovery state.
6. Content update reports a deprecated `.cumaru/archive/` directory without
   deleting or migrating it.
7. General update resolves only entries explicitly marked `framework: true`
   in the v9 source tree. `path` overrides select their physical destinations;
   adopter-owned paths and tag bodies remain untouched. A missing
   framework-owned file is created from source unless its effective local
   entry declares `optional: true`; an existing one is refreshed regardless
   of `optional`.
8. `update skills <agent> --with <skill>` validates and installs only the
   selected top-level opt-ins. It never reinstalls the domain or refreshes
   unrelated framework/adopter skills.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` | adopter | Selects domain; validated in all modes and edited only by the agent. |
| `domains/<domain>/` | framework | Canonical source read from HEAD of main, pinned to one commit per invocation. |
| Explicitly framework-owned Markdown frontmatter and outside-tag prose | framework | Rebuilt from source; created when missing and not `optional: true` locally. |
| `<!-- cumaru:NAME -->` bodies | adopter | Preserved by canonical name with fail-closed balanced parsing. |
| Local-only files and directories | adopter | Never changed. |
| `cumaru-*` skills, supported commands, instructions, hooks | framework | Refreshed deterministically in their adapter-native paths. |

## Execution

### Preflight

1. Clap and mode validation reject unknown adapters, refresh without an
   explicit adapter, `--clear` outside artifact modes, `update config --apply`,
   `--with` outside skills mode, invalid opt-in names, and misplaced selectors
   before any source or filesystem access.
2. Require regular `.cumaru/`, `.cumaru/config.yaml`, and `.cumaru/index.md`.
   Config mode parses exactly one YAML document without schema validation;
   every other mode requires the installed config to pass the embedded schema.
3. Refresh modes resolve main HEAD and the installed domain's inventory, parse
   the remote config, and enforce domain plus integer-version agreement.
   `--clear` requires no remote lookup.
4. Content update plans only entries explicitly marked `framework: true` in
   both source and local trees; config, bootstrap/migration documents,
   source-only skills/commands, and local-only files are never content targets.
5. Mutating `--apply` and `--clear` modes probe for a Git work tree. When found,
   they require empty porcelain status, including no staged, unstaged, or
   untracked changes, an existing commit, and tracked `.cumaru/config.yaml` plus
   `.cumaru/index.md`. Otherwise they warn and proceed without Git recovery.

### Preview

1. Content mode builds canonical Markdown with local tag bodies restored, or
   with the complete local body under `--skip-prose`, and prints each change
   with its current/expected pair. Skills, commands, and agent modes report
   add/replace/remove classifications. Config mode prints removed JSON Pointers
   and the complete current/candidate documents.
2. Preview creates no transaction artifacts or managed-path mutation. Clear
   forms do not preview.

### Apply

1. An empty change set reports `up to date` without mutation. Otherwise, after
   the conditional Git recovery check, recheck the config and every planned
   original byte, then write only the requested managed surfaces directly;
   create no project-local lock, staging, backup, or recovery directory.
2. Full update refreshes Markdown and creates missing required framework-owned
   files; scoped update changes only the named source path. Dedicated modes
   change only their named surface. Agent mode merges the target adapter's
   instructions and hooks; `--skills` adds the complete integration.
3. Run the native doctor inspection in quiet mode after publication. Config
   mode has no live mutation.
4. `--clear` immediately removes the requested skills, commands, or complete
   adapter footprint after preflight. An explicit agent scopes removal to that
   adapter; an omitted agent clears the selected surface across all adapters.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage or mode/selector/adapter validation error | `2` | none |
| Missing installation, invalid config/domain, malformed tags, source or network failure | `1` | none |
| Installed or main config version differs | `1` | none; migration required |
| Config or planned file changed while planning | `1` | none |
| No Git executable or non-Git project | warning | proceeds without Git recovery |
| Dirty Git work tree or missing committed Cumaru baseline | `1` | none; no transient state |
| Post-mutation doctor failure | `1` | mutation remains for Git review/restoration |
| Write failure | `1` | partial mutation possible; inspect and restore from Git history |

## Transaction and recovery

Managed paths are `.cumaru`, `.agents`, `.claude`, `.codex`, `.opencode`,
`AGENTS.md`, `CLAUDE.md`, and `opencode.json`. Apply and clear write the
requested managed surfaces directly after the Git recovery check. They are not
filesystem-wide atomic operations, and Cumaru creates no project-local lock,
staging, private backup, or recovery directory. Existing Git projects use their
clean committed state as the recovery point; non-Git projects proceed with an
explicit warning and no framework-created recovery point.

## Implementation map

| Artifact | Responsibility |
|---|---|
| [`src/commands/update.rs`](../../src/commands/update.rs) | Argument and mode validation, version gate, content/config/artifact planning, conditional Git recovery, direct publication, and doctor postcheck. |
| [`src/config_tree.rs`](../../src/config_tree.rs) | Explicit `framework: true` update pairs, path overrides, and source selection validation. |
| [`src/config.rs`](../../src/config.rs) | Embedded-schema loading and read-only config reconciliation candidate. |
| [`src/tags.rs`](../../src/tags.rs) | Balanced tag merge for canonical prose and `--skip-prose` scaffolds. |
| [`src/artifacts.rs`](../../src/artifacts.rs) | Owned skill/command namespaces, change planning, clear planning, JSON merges, and direct publication. |
| [`src/adapter.rs`](../../src/adapter.rs) | Adapter paths, instruction blocks, and owned hook merges/cleanup. |
| [`src/distribution.rs`](../../src/distribution.rs) | Main-HEAD resolution and commit-pinned domain inventory/reads. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Post-write structural health inspection. |

## Principal methods

| Method | Contract |
|---|---|
| `update::arguments` | Classifies modes, adapters, selectors, and opt-ins before any I/O; failures exit 2. |
| `update::execute` | Validates the installation and version gate, plans, previews, rechecks, publishes, and postchecks. |
| `update::artifact_plan` | Plans skills, commands, opt-ins, and agent integration for one explicit adapter. |
| `update::recovery` | Enforces clean committed recovery inside Git; warns and succeeds outside Git. |
| `update::clear_plan` | Maps an artifact mode to the shared owned-artifact cleanup planner. |
| `config_tree::update_pairs` | Selects explicitly framework-owned source/local host pairs. |
| `tags::merge`, `tags::merge_keep_prose` | Rebuild Markdown while restoring adopter tag bodies or the complete local body. |
| `config::reconcile` | Builds the read-only complete config candidate and removed-property list. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Preview and config reconciliation non-mutation, prose refresh with opaque bodies, selectors, integration-only refresh, offline clear, malformed tag refusal, dirty/untracked Git refusal, and repeated adapter refresh. |
| `src/commands/update.rs` unit tests | Mode/target validation and adopter/concurrent-change preservation. |
| `src/tags.rs`, `src/config_tree.rs`, `src/adapter.rs` unit tests | Merge preservation, owned update pairs, and hook/instruction merges. |

Remaining legacy update scenarios and their disposition are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`docs/update.md`](../../docs/update.md)
- [`rust.md`](rust.md#native-project-update)
- [`configuration.md`](configuration.md)
- [`tags.md`](tags.md)
