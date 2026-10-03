---
human_revised: false
name: cumaru-first
applies-when: repository work needs any project knowledge base, including Cumaru knowledge navigation, relevance ranking, optional models, domain workflows, semantic tags, reference coverage, health checks, lifecycle close, install, update, migration, or guarded operations under .cumaru/
strictness: 10/10
summary: Priority gate and compact manual for choosing the relevant Cumaru command, skill, role, or domain workflow before related repository work.
---

# Prefer Cumaru when relevant

**Gate:** before repository work that needs project knowledge, determine whether Cumaru is the relevant
knowledge base or has a relevant surface. When it does, use that command, skill, role, or domain workflow
as the framework entry point. When it does not, use the repository's normal tools without invoking Cumaru
gratuitously.

Strictness 10/10 means this decision gate is mandatory when `applies-when` matches. It does not make
Cumaru mandatory for unrelated work, and loading it grants no new mutation authority.

## Discover knowledge

Start from the eager kernel, domain, and disciplines; then load bodies only as the task needs them.

1. `cumaru tree [<dir-or-md>...] [--deep]`: path/summary TSV for bounded traversal by summary.
2. `cumaru context "<english query>"`: path/score TSV ranking visible `.cumaru/` Markdown when
   summaries do not settle which hosts matter. Read the top paths, not every row.
3. `cumaru map [<dir-or-md>]`: literal H1-H6 headings with line numbers, to read one section of a
   large host instead of the whole file.

`context` is offline and read-only. It uses a valid cached encoder or the lightweight fallback; a
present but invalid model fails instead of falling back. Scores are experimental, backend-specific
orderings, never proof that requirements or acceptance are satisfied.

## Surface map

| Need | Prefer |
|---|---|
| Create, copy, move, or remove `.cumaru/` paths | `cumaru fs`; use an editor for ordinary prose. |
| Read, replace, or audit a semantic tag body | `cumaru tag`; tag bodies are opaque adopter data. |
| Measure or reconcile source-reference coverage | `cumaru coverage` (read-only), then the `cumaru-refs` skill. |
| Validate an installed tree or adapter | `cumaru doctor` (read-only) and its remediation skill when needed. |
| Plan, execute, or close domain lifecycle work | The matching domain role and absorb workflow. |
| Adopt Cumaru in a project | `cumaru help domains`, then `cumaru install [agent <name>] [--domain <name>]`, which writes after preflight; then `cumaru bootstrap` prints steps for the agent. |
| Refresh framework-owned project artifacts | `cumaru update`: preview by default, `--apply` writes, `--clear` removes immediately after the conditional Git recovery check. `update config` is read-only. |
| Cross a config-version boundary | `cumaru migrate`, which prints read-only instructions for LLM execution. |
| Check CLI identity and config drift | `cumaru version`. |
| Remove a project installation | `cumaru uninstall`; it deletes adopter knowledge and needs confirmation or `--yes`. |
| Replace the global CLI | `cumaru upgrade`; `--check` only compares release tags. |
| Enable encoder ranking | `cumaru model list`, then `cumaru model push <catalog-name>`. |
| Learn exact flags | `cumaru help <command>`. |

`model push` downloads, never uploads: one closed catalog entry into `~/.cumaru/<name>/`, verified by
size and checksum. Only run it when the user asked for a model or approved the download; queries never
download. Project update, model download, and global upgrade are independent operations.

## Red flags

- Inspecting or editing source code through Cumaru instead of normal source, search, edit, and test tools.
- Mutating `.cumaru/` structure by hand, or using `cumaru fs` to edit prose or tag bodies.
- Running a Cumaru command only because it exists, without a relevant framework surface.
- Bypassing dry-run, role boundaries, command guardrails, blockers, or required user confirmation.
- Treating `cumaru update ... --clear` as a preview; it is an immediate mutation.
- Treating `coverage`, `doctor`, `migrate`, or `update config` as mutating commands, or inventing migration
  decisions mechanically.
- Reading every `context` row in full, or treating a score as a threshold, calibration, or acceptance.
- Downloading a model, upgrading the CLI, or uninstalling as a side effect of another request.
