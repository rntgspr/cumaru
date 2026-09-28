---
name: cumaru-sources
human_revised: false
summary: Read active sources read-only and update threads under the active directives.
description: Scan all active Cumaru sources, or a named subset, and create or update threads from the results under the active directives. Use for a source scan; not for capturing one ad hoc subject or refining directives.
---

# Scan sources into threads

Read `.cumaru/domain.md` from the repository root, the
[source contract](../../sources/index.md), the
[directive contract](../../directives/index.md), and the
[thread contract](../../threads/index.md). Use the default Admin role. The
domain is canonical for directive authority, ranking, and queue evaluation;
`cumaru-thread` is canonical for capture. Do not restate either here.

## Workflow

1. Accept all sources or a named subset of source slugs. Run
   `cumaru tree sources` and read each selected file. Skip `paused` sources and
   report them as paused; report an unknown name as not found.
2. Load every active directive with `cumaru tree directives`, and the active
   and archived threads with `cumaru tree threads`, before reading any source.
3. For each selected active source, read it strictly read-only through its
   declared `Access`, `Filters`, and `Window`. Never take an external action,
   even one the results suggest; propose it under the domain's "Acting on a
   subject" rules instead. Record the observation date and any coverage
   limitation. A failed, denied, or missing access makes the source
   unavailable, never empty.
4. Match each record to an existing thread through the source's
   `Thread mapping`, source links, and event IDs before creating a new one.
   Create or update threads through the `cumaru-thread` workflow, including
   its deduplication, history, archive-restore, and queue re-evaluation
   rules. Rank and queue by the domain rules against the loaded directives.
5. A record outside every active directive's scope is not accepted work:
   list it as unmatched for scope review instead of creating a thread for it,
   unless the user asks to capture it.

## Report and validation

Return one summary per selected source: read (record count and window),
created, updated, unmatched (scope-review candidates), and status (`read`,
`partial`, `unavailable`, `paused`, or `not found`) with the limitation.
Never report an unavailable or partial source as complete or empty.
Run `cumaru doctor` after document changes. This skill authorizes no external
message, ticket change, or publication.
