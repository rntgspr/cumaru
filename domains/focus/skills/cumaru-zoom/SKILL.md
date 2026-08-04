---
name: cumaru-zoom
description: Discuss an existing Cumaru thread interactively in the current conversation. Accept an ID, filename, or prose subject resolved with cumaru tree and cumaru map. Not a daily source scan.
human_revised: false
summary: Select an existing thread by identifier or semantic subject and load its discussion context.
---

# Zoom into one thread

Use this skill to select and discuss an existing thread. It does not run a
daily source scan and does not create or modify a thread.

Read `.cumaru/domain.md` and the [thread contract](../../threads/index.md). Honor the session's active
role; selecting context does not require switching roles or grant write access.

## Resolve the subject

Accept a hexadecimal ID, descriptive slug, Markdown filename, or prose, including
a description written in another language than the thread content.

- For an explicit ID, slug, or filename, resolve `.cumaru/threads/<name>.md`.
  Preserve exact existing slugs; normalize case only for hexadecimal IDs.
  Accept `A03F1C`, `a03f1c.md`, `release-1-14`, `release-1-14.md`, and paths prefixed
  with `threads/` or `.cumaru/threads/`. Require a regular file in
  this pillar; reject traversal, symlinks, and paths outside it. Do not execute
  the user's input as a shell command. Also check matching names inside
  `threads/archive-YYYY/` before declaring a thread absent. Accept explicit
  archive paths within this pillar; reject collisions instead of choosing one.
  Reading an archived thread does not itself restore it. If absent, report the missing thread;
  never silently substitute another one or create it.
- For prose without an explicit ID or filename, run `cumaru tree threads`.
  Expand relevant yearly archive directories as well; archived subjects remain
  discoverable and discussable.
  Compare its summaries with the subject, interpreting meaning across languages.
  Run `cumaru map threads/<name>.md` for each plausible candidate before reading
  its relevant sections. Use `cumaru map threads` if the summaries do not narrow
  the subject enough. These commands discover candidates and headings; they do
  not prove a match.
- Read candidate sections to distinguish overlapping subjects, people, tickets,
  and source links. Generic headings such as Context or Sources are not evidence
  of relevance. Select a thread only when its content supports the match.
- If multiple threads remain equally plausible, show their IDs, summaries, and
  the distinguishing detail. Leave the selection unresolved for the user instead
  of arbitrarily choosing or merging them.
- If no thread fits, report that result and any near matches. If no input was
  supplied, list available IDs and summaries with `cumaru tree threads` and
  wait for a subject; do not default to the highest-priority item.

## Interactive conversation

Discuss the selected thread directly in the conversation where this skill was
invoked. Do not automatically create a subagent, route replies through a parent
agent, or launch another session. Keep the selected ID in conversation context.

For a separate interactive context, the user can open a new local conversation
in this project and invoke `$cumaru-zoom <name>` there. Load the canonical thread
and relevant outcomes in that conversation; do not copy them into a second
context document or inherit an unrelated conversation's entire history.

## Load and discuss

Read the selected thread completely, then state its ID, title, and why it
matches. Treat its observation date and source state as a snapshot, not a live
claim. Summarize the context, pending decision, and next action briefly, and
address any question included in the invocation.

When existing outcomes are relevant, discover their areas with
`cumaru tree outcomes`, locate explicit references to the selected thread,
and read the matching outcomes' `threads` tags through `cumaru tag`.
Do not load unrelated outcomes or infer a relationship from similar names.

Refresh external sources only when the requested discussion needs current facts
or the user asks for a refresh. Reading is free; disclose unavailable sources.
An invocation to discuss does not itself authorize a local edit or an external
action.

Discussion here routinely produces a real action — a reply to send, a ticket to
move, a message to post. Those are allowed and are never taken silently. Print
the action in the terminal first: target system and record, the exact content or
field change, the recipients, and what becomes irreversible once it goes out.
Wait for the user's confirmation on that print. The approval covers exactly the
action shown; a further action needs its own print, and a batch is shown complete
before any part of it runs. Afterwards report what actually went out and append it
to the thread's state history as a dated event through `cumaru-thread`.

If the user subsequently requests a saved update, use `cumaru-thread`; for a
supported result, use `cumaru-outcome`. Preserve the selected ID throughout the
discussion and do not persist a global active-thread setting.
