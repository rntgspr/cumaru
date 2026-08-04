---
human_revised: false
version: 1
name: cumaru-doctor
description: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
summary: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
---

# `cumaru-doctor` — validate and diagnose a V8 tree

Run `cumaru doctor` first. Its preflight validates config and version agreement;
its nine checks cover navigation and summaries, tag structure, work and RAW
markers, retained file references, external tools, discovered instruction sets,
retired adapter config, and configuration drift. Skills, commands, hooks,
workflow completion, acceptance, and prose quality require separate review.

## Triage

1. Read the complete output. Do not edit merely because a warning exists.
2. For a navigation or summary failure, read that directory's `index.md`, then
   run `cumaru tree <directory> --deep` to see every candidate and defect.
3. For malformed semantic tags, inspect the reported host and delimiter
   diagnostic. Missing closers and crossing delimiters fail doctor with status
   `1`; preserve the body while resolving the structure. Balanced unknown tags
   remain opaque and valid nesting only warns. For retained-reference warnings,
   `reference` rows target project-root source files; custom, prose, mixed, and
   unknown tags are not structural inventories.
4. For a missing or invalid summary, use `cumaru-summarize` or edit only the
   `summary:` value. A summary is a stable selection signal, never progress.
5. Re-run `cumaru doctor` after an explicitly approved correction.

## Hard rules

- A malformed-tag error blocks lifecycle cleanup. A green doctor result does
  not prove implementation completion or acceptance; follow the domain recipe's
  separate evidence gate before absorption or removal.
- Never recreate directory inventories in marker tags. Use `cumaru tree` for
  filesystem navigation.
- Preserve semantic tags such as `relations`, `reference`, `files`, `touched`,
  `components`, and `root`.
- Never delete local files, tag bodies, or unknown tags to silence a result
  without explicit user approval.
- If schema and config version disagree, stop and use the matching major
  migration; do not use steady-state update to cross the boundary.
