---
name: doctor-graph-integrity-checks
description: Let doctor detect alias collisions, unresolved disputes, and missing reciprocal edges in graph-shaped domains such as vault-memory
status: open
priority: medium
---

# Issue 177: Doctor cannot verify memory-graph integrity

The vault-memory disambiguation conventions
([plan](../plans/vault-memory-disambiguation.md), `domains/vault-memory/domain.md`
Disambiguation) rely on `aliases`, `status`, and reciprocal edges, but doctor
checks frontmatter presence only ([doctor](../specs/doctor.md) Invariant 3).
Two nodes may claim the same alias, a `disputed` node may stay open forever, a
`superseded` node may lack `superseded-by`, and `contradicts` may exist on one
side only, all with a clean doctor report.

## Risk

- Duplicate or ambiguous company knowledge passes as healthy; the "one node per
  fact" guarantee depends only on agent discipline.
- Agents that trust doctor stop checking for open conflicts.

## Required invariant

When a domain config declares graph rules, `cumaru doctor` reports:

- a value of a unique field (such as `aliases`) claimed by two nodes, as an error;
- a node whose `status` is `superseded` without `superseded-by`, as an error;
- a node whose `status` is `disputed`, as a warning;
- a reciprocal edge (`contradicts`, `similar-to`, `supersedes` /
  `superseded-by`) present on one side only, as a warning.

## Work

1. Choose the declaration surface: generic per-field config attributes (for
   example `unique: true`, `inverse: <field>`) in the v9 model, preferred so
   any domain can opt in, versus vault-memory-specific doctor code. Record the
   choice in `specs/configuration.md` and `specs/doctor.md`.
2. If config attributes are chosen, extend `schemas/config.schema.json` with a
   versioned snapshot and check compatibility with released binaries
   ([issue 161](issue_161.md)).
3. Implement the checks in `src/commands/doctor.rs`, resolving edge values as
   node paths under the selector's pillar.
4. Declare the rules in `domains/vault-memory/config.yaml` and drop the
   "doctor checks field presence only" caveat from its `domain.md`.

## Tests

- Two memories with a shared alias: doctor exits `1` and names both paths.
- `status: superseded` without `superseded-by`: doctor exits `1`.
- `contradicts` on one side only and an open `disputed` node: doctor warns and
  exits `0`.
- An intact graph, and a domain without graph rules: doctor stays clean and
  modifies no file.

## References

- `src/commands/doctor.rs`
- `schemas/config.schema.json`
- `domains/vault-memory/config.yaml`
- `domains/vault-memory/domain.md`
- `durable-memory/plans/vault-memory-disambiguation.md`
- `durable-memory/specs/doctor.md`
