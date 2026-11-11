---
human_revised: false
version: 1
name: cumaru-doctor
description: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
summary: Diagnose a `.cumaru/` tree with `cumaru doctor`, navigate reported locations with `cumaru tree`, and propose only safe, explicit fixes.
---

# `cumaru-doctor` — validate and diagnose a v9 tree

Run `cumaru doctor` first; it never edits adopter files (it may cache the main drift reference daily under `.cumaru/.cache/`). Its preflight validates
config, version, and workflow graphs; an older config version routes to
`cumaru migrate`. Its checks cover configured tree contracts, navigation and
summaries, tag balance and nesting, stale work and RAW markers, retained file
references, external tools, discovered instruction sets, and configuration drift
against the defaults embedded in the binary. Errors exit `1`; warnings alone exit
`0`. Drift here is not main-HEAD freshness: use `cumaru version` or
`cumaru update config` for that. Skills, commands, hooks,
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

## Semantic review

`cumaru doctor` checks structure, not meaning. After it passes, review the
focus contracts it cannot check, and report each finding with its file:

- Directives: an `active` leaf has a positive integer `priority`; `proposed`
  and `paused` leaves have `null`; the directives tag ranks match the leaf
  fields and sort by ascending priority; every `parent` exists without cycles.
- Sources: `status` is `active` or `paused`, and the body sections appear in
  the contract order.
- Threads: active threads carry a valid `group`, archived ones carry none; no
  template placeholder text survives; evidence rows carry a confidence value;
  no fact is repeated across sections.
- Outcomes: the `threads` tag links resolve, and kudos are nonnegative
  multiples of `5`.

Propose fixes as for any other finding; this review changes nothing by itself.

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
- If doctor reports an older config version, stop and follow `cumaru migrate`;
  do not use steady-state update to cross the boundary.
