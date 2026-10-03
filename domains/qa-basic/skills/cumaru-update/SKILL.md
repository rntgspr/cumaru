---
human_revised: false
version: 1
name: cumaru-update
description: Use this skill when updating an installed Cumaru framework, reconciling framework-owned files, repairing agent artifacts, or reviewing an equal-version update.
summary: Framework update workflow that replaces canonical files and rehydrates adopter tag customizations.
---

# `cumaru update`

Update framework-owned artifacts at the same config contract version. CLI
distribution versions and domain/config contract versions are independent.

## Version checks

Run `cumaru version` from the adopter root before planning an update and report
its identities and freshness fields separately:

- `version:` is the CLI build version. `cumaru --version` confirms this binary
  identity without reading the adopter.
- `domain:` identifies the installed domain.
- `config:` is the integer read from `.cumaru/config.yaml`'s `version`, the
  installed domain/config contract. Shipped configs start at 9, aligned with
  `__base`; report the actual installed value rather than assuming that baseline.
- `source:` identifies the resolved HEAD of `main`. `latest config:` reads
  `domains/<installed-domain>/config.yaml` at that commit (`base` uses `__base`).
- `config status:` distinguishes `outdated`, `ahead`, equal-version `drift`, and
  `up to date`. `config drift:` compares contracts and reconciliation defaults,
  preserving valid local choices; formatting alone is not drift.

For example, CLI `0.9.1` and config `9` are valid independent identities. A
GitHub tag such as `0.0.0` identifies source/distribution history; it never means
the adopter config is `0.0.0`. The `version` in this skill's own frontmatter is
skill metadata, not the CLI or adopter config version.

`cumaru upgrade --check` optionally compares the CLI build with remote release
tags. Its `latest` and `behind` fields concern only the CLI. A requested CLI
upgrade is a separate `cumaru upgrade` operation; never run it implicitly as
part of project update or change config to match a binary/tag version.

The project update gate compares the installed config integer with the selected
source domain's config integer. Equal config versions permit update; a higher
source config requires `cumaru migrate`, and a lower source config is refused.
Use the command's validated config gate, not release-tag ordering, to decide.
Missing version metadata, an invalid source, or a failed remote lookup is a
blocker, not permission to invent a version or declare migration necessary.

## Ownership

Content update targets existing Markdown explicitly marked `framework: true`
in both source and installed config; ownership never inherits. Separate artifact
modes manage skills, supported commands, and instructions. Tag bodies are
adopter-owned; frontmatter and outside-tag prose are canonical only in files
selected for framework replacement.

On `--apply`, Cumaru:

1. Captures local marker bodies.
2. Replaces the full framework-owned file from source, including frontmatter and prose.
3. Rehydrates each captured body at its source marker.
4. Inserts a marker absent from the source at the top of the file, after frontmatter.

Adopter prose must live inside a tag body to survive update. Local-only entities and support paths are adopter-owned and are not updated.

## Procedure

1. Verify and report the CLI and adopter domain/config identities as described
   above. If `cumaru version` reports no adopter, stop project update; do not
   treat a CLI-only version report as installed domain/config metadata.
2. Run `cumaru update` and review the replacement diff. Native source-consuming
   commands resolve HEAD of `main` on every invocation and pin reads to that
   commit, independently of binary release tags; there is no
   `--from` or local snapshot source.
3. Confirm the command's source/local config-version gate succeeds. If the
   source config integer is higher, run `cumaru migrate` and execute its printed
   instructions under their own authorization and preservation boundaries.
4. Check that every retained tag body still belongs to the project; obsolete tags remain visible at the file top for explicit review.
5. Run `cumaru update --apply` after confirmation.
6. Apply already runs doctor after mutation. Optionally run `cumaru doctor --quiet` for a visible post-commit report, then `cumaru tree --deep` when auditing navigation.
7. For every adopter-owned Markdown file reported with a missing or invalid
   `summary:`, fill it before declaring the update complete. Use
   `cumaru-summarize` to curate summaries leaf-first; preserve valid summaries
   unless the user agrees they are stale. Change only `summary:` — never alter
   the adopter's body, frontmatter fields, tags, paths, or relations.
8. Agent artifacts are stateless. Use `cumaru update agent <agent> --apply`
   to materialize one complete instruction set. `--clear` is not a preview: it
   removes one adapter immediately, or every adapter when no agent is given,
   after the Git recovery check. Doctor reports only complete instruction sets.

## Targeted repairs

```bash
cumaru update skills claude --apply
cumaru update skills codex --with git --apply
cumaru update commands opencode --apply
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
Claude and Codex use skills directly; separate commands refresh is supported
only by Generic (`none`) and OpenCode.

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
