---
name: cumaru-outcome
human_revised: false
summary: Derive results from threads and reclassify outcomes while retaining provenance.
description: Derive or update area-based Cumaru outcomes from one or more threads, or move an outcome between areas while preserving provenance and incoming links.
---

# Derive or reclassify an outcome

Read `.cumaru/domain.md` and the
`.cumaru/outcomes/index.md`. Activate the declared
Admin role through `cumaru-role admin` when no role is active; if another role
is active, honor its boundaries before changing roles.

## Derive or update

1. Read the selected threads, following relevant sources when needed. Discover
   existing outcomes with `cumaru tree outcomes`, then expand relevant areas.
   Reuse an outcome only when it represents the same result.
2. Choose the primary area, falling back to `misc`, and a descriptive slug.
   Separate distinct results when the same threads support several outcomes.
   If the context contains only pending work, keep it in the thread instead of
   claiming an outcome has occurred.
3. For a new outcome, check for collisions and use
   `cumaru fs templates/outcome.md copy outcomes/<area>/<slug>.md`.
   Write the summary, title, and actual result in plain Markdown.
   Maintain the value, work, and policy views and their current overview using
   the outcome contract. Accumulate dated evidence and corrections without
   double-counting; distinguish artificial value, recorded versus estimated
   time, and accepted versus implemented feedback. Unknown values stay unknown.
   Maintain each ledger row's `Kudos` count under the same contract; initialize
   new rows to `0` and preserve existing counts without duplicating recognition.
4. Read existing provenance with `cumaru tag outcomes/<area>/<slug>.md get threads`.
   Merge all applicable source rows without duplicates or loss of earlier
   provenance. Write the complete table with `cumaru tag ... set threads`,
   supplying the body through a safely quoted argument or stdin. Each row uses
   a relative link to the current active or yearly archived thread path and
   explains the contribution.
5. Verify every linked thread exists and supports the result, and that at least
   one row exists. Check every new ledger row has a valid `Kudos` count and every
   increase has evidence. Run `cumaru doctor` and inspect the outcome with
   `cumaru tag`. Doctor validates the tag declaration; kudos and custom-link
   existence or meaning require separate inspection.

## Reclassify or rename

Read the outcome and locate incoming references with `rg` before moving it.
Confirm the destination area exists and the destination filename is unused;
never overwrite another outcome. Use
`cumaru fs outcomes/<old-area>/<slug>.md move outcomes/<new-area>/<slug>.md`.
Preserve the body and provenance, update incoming links, and update explicit
area metadata if present. Relative thread links remain valid for same-depth
area moves; still verify every link after the move. Run `cumaru doctor` and
check that the old path has no remaining incoming references.

Retain every source thread. After recording an outcome, archive settled source
cycles using the thread contract and the current local year. Keep sources with
remaining obligations active. Use `cumaru fs` for moves and `cumaru tag` to
repair provenance; check all incoming and outgoing links. Never delete sources
or duplicate them for archival. Later activity restores the same thread.
Never write to an external source system as part of this workflow.
Report the resulting paths, source IDs, and validation performed.
