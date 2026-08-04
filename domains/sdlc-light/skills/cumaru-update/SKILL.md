---
human_revised: false
version: 1
name: cumaru-update
description: Use this skill when updating an installed Cumaru framework, reconciling framework-owned files, repairing agent artifacts, or reviewing an equal-version update.
summary: Framework update workflow that replaces canonical files and rehydrates adopter tag customizations.
---

# `cumaru update`

Update framework-owned artifacts at the same integer version. Use `cumaru migrate` when the source integer is higher; update refuses every different version.

## Ownership

Framework-owned files are the source copy of domain indexes, templates, roles, disciplines, framework skills, and commands. Tag bodies are adopter-owned. Frontmatter and outside-tag prose are always canonical.

On `--apply`, Cumaru:

1. Captures local marker bodies.
2. Replaces the full framework-owned file from source, including frontmatter and prose.
3. Rehydrates each captured body at its source marker.
4. Inserts a marker absent from the source at the top of the file, after frontmatter.

Adopter prose must live inside a tag body to survive update. Local-only entities and support paths are adopter-owned and are not updated.

## Procedure

1. Run `cumaru update --from <source>` and review the replacement diff.
2. Confirm source and local integer versions match. If source is newer, run `cumaru migrate --from <source>` instead and execute the instructions it prints.
3. Check that every retained tag body still belongs to the project; obsolete tags remain visible at the file top for explicit review.
4. Run `cumaru update --from <source> --apply` after confirmation.
5. Apply already runs doctor after mutation. Optionally run `cumaru doctor --quiet` for a visible post-commit report, then `cumaru tree --deep` when auditing navigation.
6. For every adopter-owned Markdown file reported with a missing or invalid
   `summary:`, fill it before declaring the update complete. Use
   `cumaru-summarize` to curate summaries leaf-first; preserve valid summaries
   unless the user agrees they are stale. Change only `summary:` — never alter
   the adopter's body, frontmatter fields, tags, paths, or relations.
7. Agent artifacts are stateless. Use `cumaru update agent <agent> --apply`
   to materialize one complete instruction set. `--clear` is not a preview: it
   removes one adapter immediately, or every adapter when no agent is given,
   after the Git recovery check. Doctor reports only complete instruction sets.

## Targeted repairs

```bash
cumaru update skills claude --apply
cumaru update skills codex --with git --apply
cumaru update commands claude --apply
cumaru update config
cumaru update agent opencode --apply
cumaru update skills claude --clear
cumaru update agent --clear
```

Install and refresh forms preview without `--apply`. Clear forms mutate
immediately without `--apply`: name an agent for scoped removal or omit it to
clear that artifact surface across every supported adapter. In a Git work tree,
every clear requires a clean committed baseline. Outside Git, Cumaru warns and
continues without a Git recovery point.

Use `cumaru update skills <agent> --with <skill>` to add or refresh explicit
top-level opt-ins after adoption. This path preserves `.cumaru/`, validates all
requested skills before mutation, and does not refresh unrelated skill folders.

`config` reports reconciliation context for the agent: the global schema, domain
defaults, model-incompatible properties, and a candidate diff. It never mutates
`config.yaml`; the agent adjudicates adopter choices and edits it deliberately.

## Structural reconciliation

When the source config changes an adopter-owned entity from a directory to a
file, or the reverse, `cumaru update --apply` does not move it mechanically.
The LLM must inspect the local entity first, explain the proposed move, and
obtain confirmation before using `cumaru fs` to move files and remove only
an empty obsolete directory.

For the SDLC full intake flattening, reconcile
`intake/<KEY>/index.md` to `intake/<KEY>.md` only when the old directory
contains no other files. Attachments or auxiliary files are a blocker: preserve
them and ask the user to choose a destination before changing the config.
After every structural reconciliation, update the config deliberately, run
`cumaru tree --deep`, and run `cumaru doctor --quiet`.

## Rules

- Never manually rebuild structural index tables; navigate with `cumaru tree`.
- Tags are the only adopter-owned regions inside framework Markdown.
- Keep `summary:` canonical in framework-owned files. During every update,
  fill missing or invalid adopter summaries that `cumaru doctor` reports.
- Do not delete local-only files, unknown tags, or deprecated agent artifacts without confirmation.
- Do not create persistent backups or private recovery snapshots. Mutating
  `--apply` and `--clear` modes require a clean committed baseline only when the
  project is already in a Git work tree. Outside Git, continue after the
  explicit warning; do not initialize a repository implicitly.
