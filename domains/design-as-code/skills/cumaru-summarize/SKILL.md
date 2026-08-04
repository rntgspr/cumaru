---
human_revised: false
version: 1
name: cumaru-summarize
description: Use only when the user explicitly requests `.cumaru` `summary:` frontmatter maintenance, such as "repair missing summary frontmatter in .cumaru", "fix invalid .cumaru summaries", or "refresh stale .cumaru summary frontmatter". Do not use for general requests to summarize text, documentation, files, or a conversation.
summary: Curate installed `.cumaru` `summary:` frontmatter as stable framework navigation signals.
---

# `cumaru-summarize` - curate tree selection signals

Universal: this recipe works in every domain. It fills missing or invalid
`summary:` values across all installed Markdown without changing the knowledge
they describe. A summary is a stable navigation signal for `cumaru tree`, not a
status or progress snapshot.

## Trigger boundary

Select this skill only for an explicit request to maintain `summary:`
frontmatter in an installed `.cumaru/` tree:

- "repair missing summary frontmatter in .cumaru" selects this workflow
- "summarize this conversation" does not select this workflow

These are bounded semantic scenarios for evaluating the written trigger
contract, not proof of automatic selection by a live agent.

## Framework context

Summaries are framework selection signals with four connected consumers:

- `cumaru tree` emits candidate paths and their summaries without loading
  bodies.
- The loading rule compares those summaries with the task to select relevant
  candidates and prune the rest.
- `cumaru doctor` audits the installed Markdown inventory and enforces the
  current navigation/summary contract.
- Supported SessionStart adapters run the root `cumaru tree .` projection, so
  root summaries shape the first candidate view in every fresh context.

A useful value therefore names durable, concrete behavior or knowledge and
distinguishes neighboring candidates at selection time. Volatile status,
timestamps, counts, active targets, and dependency snapshots weaken every
consumer because they expire without changing the file's durable meaning.

## Summary contract

Every summary must be:

- a non-empty YAML string, not null, boolean, number, array, or object
- exactly one line, trimmed at both ends, with no CR, LF, or tab
- between 32 and 512 Unicode code points, inclusive
- a durable statement of the file's purpose or meaning

Prefer concrete nouns and behavior that distinguish the file from neighboring
candidates. Do not encode current status, progress, timestamps, item counts,
active targets, or dependency snapshots that will quickly become stale.

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
- Preserve every valid summary by default. Once the user explicitly authorizes
  summary maintenance for the selected scope, repair routine stale or
  misleading values without per-file confirmation. Stop only for unresolved
  meaning, ownership, scope, or a new authorization boundary.

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
   `invalid`; repair `valid-but-stale` values within the authorized scope.
5. Derive each value from the file's durable content and role in its containing
   directory. Do not invent meaning from the path alone and do not copy volatile
   operational metadata into the summary.
6. Make a targeted frontmatter edit for `summary` only. For a missing key, add
   only that key inside the existing frontmatter. Review the diff after each
   batch and revert any incidental formatting or content change before
   continuing.
7. Validate every changed value against the full contract, including YAML type,
   trimming, controls, and the 32-to-512 Unicode-code-point boundaries.
8. Run `cumaru doctor` when complete. Resolve remaining summary diagnostics;
   report unrelated doctor findings separately without broadening this skill's
   write scope.

## Completion report

Report the files filled, invalid or stale values repaired, and valid values
preserved. Completion requires no remaining
summary-contract errors from `cumaru doctor`.
