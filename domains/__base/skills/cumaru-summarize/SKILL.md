---
human_revised: false
version: 1
name: cumaru-summarize
description: Use this universal skill whenever the user wants to add, repair, curate, audit, or refresh `summary:` frontmatter across an installed `.cumaru/` tree. Trigger on phrases like "summarize .cumaru", "fill missing summaries", "fix invalid summaries", "repair summary frontmatter", "curate the tree summaries", "refresh stale summaries", "doctor reports summary errors", "summarize support files", "preencher os summaries", or any task that needs stable selection signals for `cumaru tree`.
summary: Use this universal skill whenever the user wants to add, repair, curate, audit, or refresh `summary:` frontmatter across an installed `.cumaru/` tree. Trigger on phrases like "summarize .cumaru", "fill missing summaries", "fix invalid summaries", "repair summary frontmatter", "curate the tree summaries", "refresh stale summaries", "doctor reports summary errors", "summarize support files", "preencher os summaries", or any task that needs stable selection signals for `cumaru tree`.
---

# `cumaru-summarize` - curate tree selection signals

Universal: this recipe works in every domain. It fills missing or invalid
`summary:` values across all installed Markdown without changing the knowledge
they describe. A summary is a stable navigation signal for `cumaru tree`, not a
status or progress snapshot.

## Summary contract

Every summary must be:

- a non-empty YAML string, not null, boolean, number, array, or object
- exactly one line, trimmed at both ends, with no CR, LF, or tab
- between 32 and 256 Unicode code points, inclusive
- a durable statement of the file's purpose or meaning

Prefer concrete nouns and behavior that distinguish the file from neighboring
candidates. Do not encode current status, progress, timestamps, item counts,
active apps, or dependency snapshots that will quickly become stale.

## Scope and safety

- Inventory every regular Markdown file under `.cumaru/`, not only
  schema-declared pillars. Include root files and local root-level support
  directories such as `templates/`, `roles/`, `disciplines/`, or adopter-added
  directories.
- Do not follow symlinks. Report a symlink instead of reading or editing its
  target.
- Modify only the `summary` frontmatter value. Never alter Markdown bodies,
  paths, filenames, status, any other frontmatter field, tag bodies, or semantic
  links.
- Preserve every valid summary by default. If a valid summary is stale,
  misleading, or no longer distinguishes the file, propose its replacement and
  ask the user before changing it.

## Workflow

1. Run `cumaru doctor` and retain every missing or invalid summary diagnostic.
   A non-zero result is expected while summaries are broken; do not stop at the
   first failure. Run `cumaru tree --deep` as the navigation audit when that
   command is available.
2. Build a complete Markdown inventory under `.cumaru/` without following
   symlinks. Reconcile it with the doctor diagnostics so root-level support
   directories and local files cannot be skipped.
3. Read and curate leaves first: process non-`index.md` Markdown from deepest
   paths upward. Then process directory `index.md` files deepest-first, using
   the already-curated child summaries to describe the directory. Curate the
   root `index.md` last.
4. Classify each current value as `valid`, `missing`, `invalid`, or
   `valid-but-stale`. Leave `valid` untouched. Fill `missing` and replace
   `invalid`; collect `valid-but-stale` proposals and ask before applying them.
5. Derive each value from the file's durable content and role in its containing
   directory. Do not invent meaning from the path alone and do not copy volatile
   operational metadata into the summary.
6. Make a targeted frontmatter edit for `summary` only. For a missing key, add
   only that key inside the existing frontmatter. Review the diff after each
   batch and revert any incidental formatting or content change before
   continuing.
7. Validate every changed value against the full contract, including YAML type,
   trimming, controls, and the 32-to-256 Unicode-code-point boundaries.
8. Run `cumaru doctor` when complete. Resolve remaining summary diagnostics;
   report unrelated doctor findings separately without broadening this skill's
   write scope.

## Completion report

Report the files filled, invalid values repaired, valid values preserved, and
stale replacements accepted or declined. Completion requires no remaining
summary-contract errors from `cumaru doctor`.
