---
human_revised: false
summary: Source conversations and evidence retained for deriving outcomes.
targets: [meta]
---

# Threads

- Store each thread as `threads/<name>.md`. A thread the system creates on its
  own takes an unused uppercase hexadecimal ID matching `[0-9A-F]{6}`; six
  characters is that generator's width and the agent never picks another one.
  A thread the user names takes their name, as a descriptive lowercase slug
  matching `[a-z0-9]+(-[a-z0-9]+)*`, such as `release-1-14`. The adopter may
  define its own slug model for user-created threads; the hexadecimal generator
  exists so an unnamed subject still gets a stable identity. Check uniqueness
  across active and archived threads. Preserve existing names; do not create
  numeric aliases, renumber an existing thread, or duplicate threads.
- `summary` is the thread's canonical one-line description. It serves Cumaru
  navigation and is the single field any derived view reads. Write concise
  English plain text grounded in the thread, covering the relevant state, next
  action, and uncertainty, and update it whenever new evidence or a user decision
  changes what the thread communicates. Keep dated claims dated; do not
  manufacture freshness. Use an H1 for the title and plain prose for context,
  decisions, and open points. Indexes are not threads.
- Keep direct links to the related source records under `Sources`, with enough
  description to identify each one. Include only related, verified links; label
  search URLs as searches and unavailable sources as unavailable. Never fabricate
  an item URL or copy credentials.
- Retain source context when outcomes are produced. Do not rename the thread
  when its subject changes or duplicate it for each outcome.
- Outcome provenance is canonical in the outcome's `threads` tag. Find incoming
  references there instead of maintaining a second relationship list here.
- Any derived presentation of these threads is an adopter concern. Declare its
  contract and any extra frontmatter it needs in the domain root tag; this
  contract requires no publication or rendering field.

Use [the thread template](../templates/thread.md) for new entries and
`cumaru tree threads` for discovery. Capture does not itself assert completion.

## History and queue re-entry

Maintain a State history table with event identity, source occurrence time,
observation time, source, previous and new state, reason, and resulting queue.
Include forward transitions, regressions, reopenings, comments, and decisions.
Use source event IDs or canonical links to deduplicate; record corrections as
new entries referring to the corrected event. Unknown dates and states remain
unknown. Never manufacture intermediate transitions from two snapshots.

Every material subject update triggers queue evaluation and an updated `group`.
The allowed active groups are `today`, `follow`, `hold`, and `main`. Urgency
inside `today` is expressed by directive and date ordering, not by a second
queue above it; there is no separate `now`. Deferral and an explicit hold are
the same state, `hold`, distinguished by the recorded reason rather than by two
queues. Archival replaces a terminal `done` state. Follow the domain's boundary
between the user's own action and downstream monitoring. A formatting-only edit
or re-reading the same source does not reopen a subject.

## Archive and restore

Archive a settled cycle after its outcome is recorded; pending obligations or
other unfinished outcomes keep the thread active. Source verification is not a
precondition for archiving: when it was not performed or could not confirm
closure, archive as asked and raise an explicit alert naming what stayed
unverified. Never delete a source thread.
Use `threads/archive-YYYY/<name>.md`, with the local archival year and unchanged
name. Remove the active `group` field and record the archival event, preserving
the previous queue in history. The archive path identifies archival status;
do not introduce a `done` or `archived` state field. Each archive directory
needs an `index.md`; create it through `cumaru fs` when that year is first used.
Do not create empty directories for future years. Discover active and archived
matches before allocating IDs; identities are unique across all years.

Use `cumaru fs` to move, never copy, on archive or restore. On renewed material
activity, restore to `threads/<name>.md` and reclassify from evidence, including
monitoring-only updates. Check for collisions before moving. Find incoming
links with `rg`, repair outcome `threads` tags with `cumaru tag`, and repair
outgoing relative links for the new depth. Validate every link before completion.
