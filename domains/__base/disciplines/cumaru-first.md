---
human_revised: false
name: cumaru-first
applies-when: repository work needs any project knowledge base, including Cumaru knowledge navigation, domain workflows, semantic tags, reference coverage, health checks, lifecycle close, update, migration, or guarded operations under .cumaru/
strictness: 10/10
summary: Priority gate for choosing the relevant Cumaru command, skill, role, or domain workflow before related repository work.
---

# Prefer Cumaru when relevant

**Gate:** before repository work that needs project knowledge, determine whether Cumaru is the relevant
knowledge base or has a relevant surface. When it does, use that command, skill, role, or domain workflow
as the framework entry point. When it does not, use the repository's normal tools without invoking Cumaru
gratuitously.

Strictness 10/10 means this decision gate is mandatory when `applies-when` matches. It does not make
Cumaru mandatory for unrelated work.

## Surface map

| Need | Prefer |
|---|---|
| Discover relevant knowledge or context | The eager kernel, domain, and disciplines, then `cumaru tree` for bounded traversal. |
| Create, copy, move, or remove `.cumaru/` paths | `cumaru flow`; use an editor for ordinary prose. |
| Read or replace a semantic tag body | `cumaru tag`. |
| Measure or reconcile source-reference coverage | `cumaru coverage`, then the `cumaru-refs` skill for adjudication. |
| Validate an installed tree or adapter | `cumaru doctor` and its remediation skill when needed. |
| Plan, execute, or close domain lifecycle work | The matching domain role and skill, including archive or absorb workflows. |
| Refresh framework-owned project artifacts | `cumaru update`, which previews unless `--apply` is explicit. |
| Cross a framework-version boundary | `cumaru migrate`, which prints read-only instructions for LLM execution. |

## Red flags

- Inspecting or editing source code through Cumaru instead of normal source, search, edit, and test tools.
- Mutating `.cumaru/` structure by hand, or using `flow` to edit prose or tag bodies.
- Running a Cumaru command only because it exists, without a relevant framework surface.
- Bypassing dry-run, role boundaries, command guardrails, blockers, or required user confirmation.
- Treating `coverage` or `migrate` as mutating commands, or inventing migration decisions mechanically.
