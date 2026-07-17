---
human_revised: false
version: 1
name: cumaru-update
description: Use this skill when updating an installed Cumaru framework, reconciling framework-owned files, repairing agent artifacts, or reviewing a same-major framework update.
summary: Framework update workflow that replaces canonical files and rehydrates adopter tag customizations.
---

# `cumaru update`

Update framework-owned artifacts from a matching-major source. Use `cumaru migrate v6` for a major upgrade; `cumaru update --apply` refuses to cross that boundary.

## Ownership

Framework-owned files are the source copy of domain indexes, templates, roles, disciplines, framework skills, and commands. The adopter may customize only declared `<!-- cumaru:... -->` bodies.

On `--apply`, Cumaru:

1. Captures local marker bodies.
2. Replaces the full framework-owned file from source, including frontmatter and prose.
3. Rehydrates each captured body at its source marker.
4. Inserts a marker absent from the source at the top of the file, after frontmatter.

Do not preserve local prose or frontmatter in framework-owned files. Local-only entities and support paths are adopter-owned and are not updated.

## Procedure

1. Run `cumaru update --from <source>` and review the replacement diff.
2. Confirm source and local major versions match. If source is newer, run `cumaru migrate v6 --from <source>` instead.
3. Check that every retained tag body still belongs to the project; obsolete tags remain visible at the file top for explicit review.
4. Run `cumaru update --from <source> --apply` after confirmation.
5. Run `cumaru doctor --quiet` and `cumaru tree --deep`.
6. For every adopter-owned Markdown file reported with a missing or invalid
   `summary:`, fill it before declaring the update complete. Use
   `cumaru-summarize` to curate summaries leaf-first; preserve valid summaries
   unless the user agrees they are stale. Change only `summary:` — never alter
   the adopter's body, frontmatter fields, tags, paths, or relations.
7. If `CLAUDE.md` or files under `.claude/` exist, inspect them after the
   `.agents/` update and offer to align their relevant content with
   `.agents/AGENTS.md`. Explain the proposed edits and wait for confirmation;
   these files are adopter-owned compatibility surfaces and the Cumaru CLI
   must never update them automatically.

## Targeted repairs

```bash
cumaru update skills --apply
cumaru update commands --apply
cumaru update schema
```

`schema --apply` remains destructive. Preserve adopter extensions such as local pillars, `meta.apps.values`, and domain-specific metadata during a deliberate schema reconciliation.

## Structural reconciliation

When the source schema changes an adopter-owned entity from a directory to a
file, or the reverse, `cumaru update --apply` does not move it mechanically.
The LLM must inspect the local entity first, explain the proposed move, and
obtain confirmation before using `cumaru flow` to move files and remove only
an empty obsolete directory.

For the SDLC full intake flattening, reconcile
`intake/<KEY>/index.md` to `intake/<KEY>.md` only when the old directory
contains no other files. Attachments or auxiliary files are a blocker: preserve
them and ask the user to choose a destination before changing the schema.
After every structural reconciliation, update the schema deliberately, run
`cumaru tree --deep`, and run `cumaru doctor --quiet`.

## Rules

- Never manually rebuild structural index tables; navigate with `cumaru tree`.
- Tags are the only custom surface in framework-owned Markdown.
- Keep `summary:` canonical in framework-owned files. During every update,
  fill missing or invalid adopter summaries that `cumaru doctor` reports.
- Do not delete local-only files, unknown tags, or deprecated agent artifacts without confirmation.
