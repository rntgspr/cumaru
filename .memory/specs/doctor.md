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

The [native Rust doctor contract](rust.md#native-doctor) records its
binary-only implementation, daily-cached main drift reference, ASCII presentation, installed
workflow-skill boundary, default invocation, and verification. The Bash
implementation below retains its separate source-snapshot contract.

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
5. Invalid optional workflow graphs or unavailable referenced domain skills
   fail configuration preflight. Graph validation does not execute a skill.
6. The remaining installed-tree checks cover indexes, summaries, discipline
   metadata, markers, file references, tools, adapter instructions, retired
   adapter state, and configuration drift. Checks never edit adopter files.
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
   with a non-failing warning. A newer reference `version` fails with a
   `cumaru migrate` direction. Resolution order is canonical in
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
retain their own source-default and source-skill checks.

## Execution and failure

1. Require an installed `.cumaru/` tree and inspect its integer config version.
2. Validate config shape and semantics, then resolve the configured v9 tree.
3. Report configured-tree defects before the remaining cached whole-tree checks.
4. Return nonzero on errors; warnings remain visible without changing files.

## Implementation and verification

| Artifact | Responsibility |
|---|---|
| [`../../src/cmd_doctor.sh`](https://github.com/rntgspr/cumaru/blob/0.10.0/src/cmd_doctor.sh) | Version routing, config preflight, reporting, and drift checks. |
| [`../../src/cmd_doctor_checks.sh`](https://github.com/rntgspr/cumaru/blob/0.10.0/src/cmd_doctor_checks.sh) | Direct-tree and installed-tree checks. |
| [`../../src/common.sh`](https://github.com/rntgspr/cumaru/blob/0.10.0/src/common.sh) | Shared v9 tree resolution. |
| [`../../tests/spec/cli/doctor_spec.sh`](../../tests/spec/cli/doctor_spec.sh) | CLI health and non-mutation contracts. |
| [`../../tests/spec/integration/tree_resolution_spec.sh`](../../tests/spec/integration/tree_resolution_spec.sh) | Direct-tree contract examples. |

```bash
shellspec tests/spec/cli/doctor_spec.sh tests/spec/integration/tree_resolution_spec.sh
```
