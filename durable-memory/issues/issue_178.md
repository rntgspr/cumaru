---
name: vault-memory-domain-relations-tag
description: Make the shipped vault-memory domain.md satisfy its own required relations tag so a fresh install passes doctor
status: open
priority: medium
---

# Issue 178: Vault-memory domain.md lacks its required relations tag

`domains/vault-memory/config.yaml` declares
`domain.md: {framework: true, tags: [components, root, relations, authority]}`,
but `domains/vault-memory/domain.md` has no `<!-- cumaru:relations -->` marker.
The string appears only inside inline code in the Memory Graph prose, which is
not a marker. `cumaru doctor` on a copy of the source tree reports
`[error] Configured v9 tree contracts` / `domain.md: missing required tag
'relations'`, at `66cc891` and at `7a1d02a` alike. The mismatch dates from
`04fe81c`. No other shipped domain has a configured `domain.md` tag missing.

## Risk

- A fresh vault-memory install fails doctor before the adopter edits anything,
  teaching adopters to ignore doctor errors.
- Agents following the documented health check stop on a framework defect.

## Required invariant

Every tag a shipped domain's `config.yaml` requires on a framework file exists
as a balanced marker in that source file, so doctor on a fresh install reports
no configured-tree error.

## Work

1. Decide the intent: add an empty `<!-- cumaru:relations -->` table to
   `domains/vault-memory/domain.md` (matching `templates/memory.md`), or drop
   `relations` from the `domain.md` selector in `config.yaml`. Dropping it is
   preferred if `domain.md` is not a graph node.
2. Add a source-domain check, native or ShellSpec, that every required tag on a
   framework file is present in each shipped domain, so the defect cannot
   recur.

## Tests

- Doctor on a copy of `domains/vault-memory/` (skills and commands removed)
  reports no `Configured v9 tree contracts` error.
- The new source-domain check fails when a required tag marker is removed from
  any shipped domain file, and passes on the current tree.

## References

- `domains/vault-memory/config.yaml`
- `domains/vault-memory/domain.md`
- `durable-memory/specs/configuration.md`
- `durable-memory/specs/doctor.md`
