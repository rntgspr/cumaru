---
name: audit-deprecated-src-removal
description: Review which deprecated Bash files under src can be safely removed
status: open
priority: medium
---

# Issue 140: Review obsolete files under src for removal

[GitHub issue 18](https://github.com/rntgspr/cumaru/issues/18).

The supported CLI lives under `rust/`, but root `src/` still contains deprecated
commands, helpers, adapter code, and the old global installer. Some tests, comments,
documentation, and archive metadata still reference those files.

## Risk

- Deleting by directory name can discard unported behavior or break retained tests
  and published references. Keeping obsolete installers can also mislead adopters.

## Required invariant

Every proposed removal has an inspected consumer inventory, a native replacement
or explicit retirement rationale, and retained regression evidence. This issue
first delivers a reviewable deletion manifest, not blanket directory removal.

## Work

1. Inventory each `src/` file and its direct/transitive consumers in tests, scripts,
   skills, docs, Rust comments, installer URLs, and distribution/archive metadata.
2. Classify entries as safe to remove, blocked by test migration, or still required;
   name the exact blocker/replacement and distinguish historical references from
   executable dependencies. Coordinate with issue 139 before removing test inputs.
3. Identify the handling of old public installer URLs and existing installations;
   do not invent compatibility requirements or silently route destructive legacy
   installation to another behavior.
4. Present exact proposed removals and reference/documentation changes with
   evidence. Apply only an approved deletion set in a separate bounded change.
   Preserve `rust/install.sh`, `rust/build.sh`, and native session-hook support.

## Tests

- Reproduce each claimed dependency using repository searches and relevant tests;
  a blocked consumer keeps its source available until migrated or retired.
- For any subsequently approved cleanup, native tests, migrated regressions,
  formatting, locked release compilation, mirror checks, and CLI smokes pass.
- Active source/docs/distribution links resolve after cleanup; no real global
  installer, project tree, or home cache is changed during the audit.

## References

- [Deprecated source](../../src/)
- [Test reuse issue](issue_139.md)
- [Native distribution contract](../specs/rust.md)
- [Archive exclusions](../../.gitattributes)
- [Developer guide](../../HOW_TO_DEV.md)

## Audit evidence, 2026-10-03

Inspected checkout `70699356246b650d2231336aa0f87df861ce1667`, including
untracked issue records; `git ls-files src` contains exactly 18 files. No source
was removed or changed. This audit completes discovery, not the removal gate.
The proposed immediate deletion set is empty. The conditional manifest below
contains all 18 paths; native command-name coverage alone does not release them.

### Consumer classes

- **B**: retained command scenarios invoke the removed root Bash `cumaru` through
  [CLI helpers](../../tests/spec/cli/support/helpers.sh),
  [integration helpers](../../tests/spec/integration/support/integration_helpers.sh),
  [update helpers](../../tests/spec/update/support/update_helpers.sh), or
  [contract helpers](../../tests/spec/contracts/spec_helper.sh). These are historical
  regression inputs, not a currently working production dispatcher. Issue 139
  must record migrated behavior or explicit retirement of each incompatible case.
- **D**: tests still directly source, inspect, or copy the named Bash files,
  independently of whether their overall suite starts successfully.
- **P**: public legacy installer URLs still deliver an executable destructive script.
  Retiring that surface requires a separate explicit decision and non-mutation check.

### Conditional deletion manifest

Paths in the first column are exact project-relative removal candidates. Test paths
are relative to `tests/spec/` unless noted otherwise. Every row remains blocked by
issue 139's regression disposition; P adds the public-surface retirement blocker.

| Candidate | Consumers and evidence | Native owner / retirement rationale | Gate |
|---|---|---|---|
| `src/agent_adapter.sh` | D: `integration/schema_spec.sh`, `integration/workflow_graph_spec.sh`, `contracts/design_artifacts_spec.sh:138,143`, `tests/manual_issue_017_agent_hooks.sh:10`; transitive install/uninstall/update/schema callers | `rust/src/adapter.rs`, `artifacts.rs`; preserve unrelated native entries and exact owned hooks | B+D |
| `src/cmd_bootstrap.sh` | B: `contracts/bootstrap_spec.sh`; Rust module header retains attribution | `rust/src/commands/bootstrap.rs`; local `--from` behavior intentionally retired | B |
| `src/cmd_coverage.sh` | B: `cli/coverage_spec.sh`; shared reference helpers in common; Rust module header | `rust/src/commands/coverage.rs`, `references.rs`; retain bucket/status/preservation cases | B |
| `src/cmd_doctor.sh` | B: `cli/doctor_spec.sh`; D: `contracts/documented_contracts_spec.sh:66`; calls `cmd_doctor_checks` and schema/common/adapter helpers | `rust/src/commands/doctor.rs`; native checks/default invocation, intentional source/runtime differences | B+D |
| `src/cmd_doctor_checks.sh` | D: `contracts/migrate_spec.sh:421`; called by `cmd_doctor.sh:718` | `rust/src/commands/doctor.rs`; tag, metadata, reference and configured-tree checks | B+D |
| `src/cmd_fs.sh` | B: `cli/fs_spec.sh`; Rust module header | `rust/src/commands/fs.rs`; preserve safe verbs, containment and byte-preservation failures | B |
| `src/cmd_help.sh` | B: `contracts/documented_contracts_spec.sh` exercises help; domain listing relies on local source helpers | `rust/src/commands/help.rs`, Clap dispatch; local snapshot inventory intentionally retired | B |
| `src/cmd_install.sh` | B: adapter/install scenarios; transitive `cmd_update.sh:21-24` expects its `_framework_*` helpers | `rust/src/commands/install.rs`, `artifacts.rs`, `adapter.rs`; install-time opt-ins intentionally move to update | B |
| `src/cmd_map.sh` | B: `cli/map_spec.sh`; shared `_tree_*` helpers in `cmd_tree.sh` | `rust/src/commands/map.rs`, `walk.rs`, `markdown.rs`; H1-H6/TSV replaces old H2/rg behavior | B |
| `src/cmd_migrate.sh` | B: `contracts/migrate_spec.sh`; D: same file at line 263 inspects source text | `rust/src/commands/migrate.rs`; read-only delivery retained, local source flags retired | B+D |
| `src/cmd_tag.sh` | D: `update/tags_spec.sh:10`; B: tag scenarios and `reference` callers | `rust/src/commands/tag.rs`, `tags.rs`; opaque bodies retained, typed `all --rows` retired | B+D |
| `src/cmd_tree.sh` | B: `cli/tree_spec.sh`; transitive map safety/filter helper consumer | `rust/src/commands/tree.rs`, `paths.rs`, `walk.rs`; old domain/pillar filters retired | B |
| `src/cmd_uninstall.sh` | B: `integration/agent_adapters_spec.sh`; uses `_agent_*` cleanup helpers | `rust/src/commands/uninstall.rs`, `artifacts.rs`; all-adapter preservation and confirmation checks | B |
| `src/cmd_update.sh` | D: `update/tags_spec.sh:9`; B: all `update/*_spec.sh`; transitive install helpers and recursive missing root `cumaru` doctor calls at lines 610,661,780,816,845,866 | `rust/src/commands/update.rs`, `tags.rs`, `artifacts.rs`; preserve ownership and explicit native differences | B+D |
| `src/cmd_version.sh` | B: `cli/version_spec.sh`; whole-tree snapshot copy includes this file | `rust/src/commands/version.rs`, `upgrade.rs`, `release.rs`; snapshot VERSION identity retired | B |
| `src/common.sh` | D: `integration/schema_spec.sh`, `integration/workflow_graph_spec.sh`, `integration/tree_resolution_spec.sh:62`, `contracts/design_artifacts_spec.sh`, `update/tags_spec.sh`, `cli/support/helpers.sh:151`, `tests/manual_issue_017_agent_hooks.sh:9`; helpers shared by old commands | `rust/src/config.rs`, `config_tree.rs`, `markdown.rs`, `tags.rs`, `references.rs`, `adapter.rs`; no single substitute for direct sourced helpers | B+D |
| `src/install.sh` | D: `cli/version_spec.sh:19,26` copies src and rewrites installer destinations; P: raw GitHub URL and branding URL; `.gitattributes` header names it | `rust/install.sh`, `rust/src/distribution.rs`; destructive snapshot replacement is retired, not silently emulated | B+D+P |
| `src/schema.sh` | D: `integration/schema_spec.sh`, `integration/workflow_graph_spec.sh`, `contracts/design_artifacts_spec.sh:138,143`; transitive common/adapter and `schemas/*.jq` readers | `rust/src/config.rs`, `config_tree.rs`, doctor/update; workflow validation and reconciliation need explicit case mapping | B+D |

### Public installer finding

Read-only HTTPS fetches confirmed both current endpoints:

- [Canonical legacy URL](https://raw.githubusercontent.com/rntgspr/cumaru/main/src/install.sh)
  still returns the deprecated snapshot installer.
- [Branding URL](https://pixelpunk.works/cumaru/install.sh) still pipes that URL to Bash.

The inspected script downloads the highest numeric tag archive, writes VERSION,
then executes `rm -rf "$DEST"` where DEST is `~/.cumaru`, and links
`~/.local/bin/cumaru` to the snapshot's root `cumaru`. `git ls-tree 0.10.0 cumaru`
returns no root entry. Therefore, if download and integrity checks succeed,
this current path replaces a cache/snapshot and leaves a dangling CLI link.
This conclusion is from source and tag inspection; the installer was never run.
The new model cache makes wholesale replacement particularly harmful.

Recommended bounded follow-up: retain `src/install.sh` as a non-mutating retirement
notice that exits nonzero and links the native installation guide, then update
the separately owned branding endpoint. An automatic redirect would authorize a
different global installation and is not implied by this audit. Existing older
installed Bash upgrade dispatchers fetch the raw main URL; do not rewrite released
tag contents or delete user installations to complete repository cleanup.

### Reference and archive changes required with removal

- Keep `rust/install.sh`, `rust/build.sh`, native hooks, the model catalog and
  embedded JSON schemas. `rust/src/distribution.rs:10` embeds `../install.sh`,
  which resolves to **rust/install.sh**, not root src. No native executable
  dependency on the deprecated directory was found.
- `scripts/` and `.github/workflows/` have no root-src consumers. Release workflow
  builds only the Rust manifest. `.gitattributes` currently excludes maintainer
  paths, but not `src/`; old files are present in the 0.10.0 tag tree. Deleting
  future source files does not remove old release archives. Correct its legacy
  installer header and decide future archive exclusion without changing tags.
- Update public `docs/rust.md` and `HOW_TO_DEV.md` retirement descriptions. Preserve
  source attribution in Rust module headers using a pinned historical link if the
  source vanishes: `config.rs`, and commands fs/coverage/bootstrap/migrate.
- Retarget active issue 040's adapter reference and issue 064's migration/install/
  update references to native owners. Update legacy implementation tables and
  links in memory specs architecture, navigation, domains, agent-adapters,
  configuration, coverage, tags, disciplines, workflows, absorb, doctor, migration,
  update, install-upgrade and sync-domain-kernel. Distinguish historical contracts
  from current owners instead of claiming full Bash parity.
- Keep ordinary adopter source examples (`src/session.ts`, `src/util/logger.ts`,
  template `<src/path/to/file>`, coverage globs) in docs, domains and fixtures.
  They are not references to Cumaru's deprecated directory. No shipped domain or
  optional skill was found executing a deprecated root-src file.
- Coordinate direct-source test replacements before deletion; do not rewrite all
  Bash invocations to execute a Rust ELF/Mach-O binary through `/bin/bash`.

### Verification boundary

`bash tests/run.sh` returned status 1 with its intentional removed-Bash-entry-point
diagnostic before ShellSpec ran. This proves the runner boundary, not migrated
regression coverage. Searches covered `src/`, `rust/`, `tests/`, `scripts/`,
`.github/`, skills, domains, docs, memory, archive metadata and root guides.
Public scripts were fetched as text only. No installer, sudo, model download,
adopter mutation, Git mutation, or source deletion occurred. Actual cleanup remains
open until the conditional manifest and URL retirement are approved and verified.

All 18 retained scripts passed `bash -n`. The table's extracted path set matched
`git ls-files src` byte-for-byte after C-locale sorting, and `git diff --check`
passed. Native replacement paths were checked against the filesystem. No native
test/build rerun was needed for this audit-only Markdown edit; that evidence is
required again when actual removal is implemented.
