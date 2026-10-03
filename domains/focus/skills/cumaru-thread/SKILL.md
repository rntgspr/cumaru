---
name: cumaru-thread
human_revised: false
summary: Capture source context and evidence in threads with stable IDs or descriptive names.
description: Capture or update a Cumaru thread with a stable ID or descriptive slug from conversations or related external source records.
---

# Capture a thread

Use `.cumaru/domain.md` and the `.cumaru/threads/index.md` as
canonical instructions. Activate the declared Admin role through `cumaru-role
admin` when no role is active; if another role is active, honor its boundaries
before changing roles.

1. Run `cumaru tree threads`, expand yearly archives, and inspect plausible
   matches before creating a thread. Reuse a supplied existing ID only for that
   same subject; never overwrite a different thread on an ID collision.
2. Use supplied context and read related source items when access is available.
   Preserve direct links and distinguish evidence, reported claims, and open
   questions. Missing integrations do not justify invented evidence.
3. For a new thread, honor the user's descriptive slug for a large or special
   subject; otherwise select an unused uppercase hexadecimal ID of the
   default six-character width. Follow the naming contract and use
   `cumaru fs templates/thread.md copy threads/<name>.md`. Update the summary,
   title, context, and source links. For an existing thread, merge new evidence
   without discarding earlier decisions or unresolved contradictions.
   Append deduplicated state-history events, including reversals and feedback,
   and re-evaluate the queue on material changes. Restore an archived match
   instead of creating a duplicate. Follow the thread contract for yearly
   archival, collision checks, and incoming/outgoing link repair. Do not
   reconstruct missing historical transitions or reopen for formatting edits.
4. Check the filename, summary, and source attribution; run `cumaru doctor`
   and `cumaru tree threads`. Report the file and material missing evidence.

Capturing a thread does not require an immediate outcome. When the user asks to
record a supported result, continue with `cumaru-outcome`. Capture never writes
to an external source system.
