---
name: cumaru-doctor-specification
description: "Current v9 installed-tree validation and migration routing"
type: project
status: implemented
version: 9
---

# Cumaru doctor specification

## Purpose

`cumaru doctor` checks an installed adopter tree against the deterministic v9
configuration and reports structural or metadata defects without editing it.

The [native Rust doctor contract](rust.md#native-doctor) records the detailed
check order, daily-cached main drift reference, ASCII presentation, installed
workflow-skill boundary, default invocation, and verification.

## Public surface

```text
cumaru doctor [--quiet]
.cumaru/config.yaml
.cumaru/**/*.md
```

## Invariants

1. An older supported integer config version is directed to `cumaru migrate`
   before the active v9 shape validator rejects its historical structure.
   Malformed or invalid current config is still rejected before tree checks.
2. The shared v9 resolver determines selectors, literal-over-wildcard
   precedence, path overrides, containment, and effective global rules.
   Doctor reports a missing required literal entry; a glob may match nothing.
3. For every resolved Markdown host, doctor checks required frontmatter fields,
   declared `targets` against domain metadata, configured H1 rules, balanced
   marker syntax, and required tag names. An empty frontmatter field object
   requires presence; `optional: true` removes that presence requirement.
4. Tags are arrays of marker names. Doctor does not validate tag-body formats
   or EARS/Gherkin prose through config.
5. Invalid optional workflow graphs or workflow skills absent from an
   installed supported-adapter skill tree fail configuration preflight. Graph
   validation does not execute a skill.
6. The remaining installed-tree checks cover indexes, summaries, discipline
   metadata, balanced and unknown/nested markers, stale work markers, RAW
   blocks, retained file references, external tools, adapter instructions,
   absent `meta.context` paths (a warning; `context` skips them silently), and
   configuration drift. Checks never edit adopter files.
7. The single side effect is opt-in and runs after the checks: when the report
   passes and `meta.doctor.after.warm` is `true`
   ([configuration](configuration.md)), doctor warms only the `adopter`
   [context scope](../../docs/context.md#vector-cache), writing under
   `.cumaru/.cache/` and possibly the `.gitignore` entry. A failed report, or a
   false/absent flag, writes nothing. Any warm failure, including a missing
   listed `meta.context.adopter` path, fails doctor; no enabled encoder is not
   a failure. Warm progress goes to stderr; the report on stdout is unchanged.
8. Drift compares against the domain `config.yaml` on GitHub main, read at most
   once per UTC calendar day and written to `.cumaru/.cache/config-<date>.yaml`
   (atomic, symlinks refused, older files deleted). Offline it uses a stale
   matching file with a dated warning, or degrades to schema-only validation
   with a non-failing warning. A newer reference `version` turns the drift
   check into an error after every other check is reported (exit 1), directing
   `cumaru upgrade`, then `cumaru migrate`; it is the only blocking drift outcome. Resolution order is canonical in
   [the public doctor doc](../../docs/doctor.md#configuration-drift-reference).

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml` | adopter | Effective v9 structural, metadata, and workflow contract. |
| Installed Markdown and tag bodies | adopter/framework by explicit ownership | Inspected without mutation. |
| Domain config on GitHub main (daily cache) | framework | Compared to local config for drift reporting. |

For a valid custom domain with no matching source on main, doctor skips drift
with a warning and relies on schema validation. Its direct
tree, rules, targets, and workflows remain adopter-owned, and workflow skills
must exist in an installed supported-adapter skill tree. Distributed domains
also receive the main-HEAD source-default drift comparison.

## Execution and failure

1. Require an installed `.cumaru/` tree and inspect its integer config version.
2. Validate config shape and semantics, then resolve the configured v9 tree.
3. Report configured-tree defects before the remaining cached whole-tree checks.
4. Return nonzero on errors; warnings remain visible without changing files.

## Implementation and verification

| Artifact | Responsibility |
|---|---|
| [`../../src/commands/doctor.rs`](../../src/commands/doctor.rs) | Version routing, config preflight, workflow validation, cached checks, reporting, drift, and opt-in warm, with unit tests. |
| [`../../src/config_tree.rs`](../../src/config_tree.rs) | Shared v9 tree resolution into per-host contracts. |
| [`../../src/references.rs`](../../src/references.rs) | Retained reference rows and the source-file rule. |
| [`../../src/adapter.rs`](../../src/adapter.rs) | Expected instruction sets for discovery. |
| [`../../tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Warm opt-in, daily reference cache, offline drift, and update postchecks. |

Remaining legacy doctor and tree-resolution scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Differences from the retired Bash CLI

- Drift compares against the domain config on main, cached daily, instead of
  a local source snapshot.
- Workflow skill availability uses installed supported-adapter skill files, not
  same-domain membership in a source package.
- Output uses ASCII `[ok]`/`[warn]`/`[error]` lines without colors.
- The former retired-adapter-state check has no native counterpart.

```bash
cargo test --locked
bash tests/run.sh
```
