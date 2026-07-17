---
human_revised: false
version: 1
name: cumaru-doctor
description: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
summary: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
---

# `cumaru-doctor` — validate and diagnose a V6 tree

Run `cumaru doctor` first. It validates schema and version agreement, required
indexes, every Markdown `summary`, retained semantic tags, RAW markers, and the
installed context-hook wiring.

## Triage

1. Read the complete output. Do not edit merely because a warning exists.
2. For a navigation or summary failure, read that directory's `index.md`, then
   run `cumaru tree <directory> --deep` to see every candidate and defect.
3. For a retained semantic tag failure, inspect only the declared tag body.
   `reference` rows target project-root source files; custom, prose, mixed, and
   unknown tags are not structural inventories.
4. For a missing or invalid summary, use `cumaru-summarize` or edit only the
   `summary:` value. A summary is a stable selection signal, never progress.
5. Re-run `cumaru doctor` after an explicitly approved correction.

## Hard rules

- Never recreate directory inventories in marker tags. Use `cumaru tree` for
  filesystem navigation.
- Preserve semantic tags such as `absorptions`, `relations`, `reference`,
  `files`, `touched`, `components`, and `root`.
- Never delete local files, tag bodies, or unknown tags to silence a result
  without explicit user approval.
- If schema and `framework-version` disagree, stop and use the matching major
  migration; do not use steady-state update to cross the boundary.
