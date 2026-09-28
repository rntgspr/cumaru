---
human_revised: false
summary: Directive-driven triage of external signals into threads and area-based outcomes.
targets: [meta]
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# Directives, threads, and outcomes

This domain models **priority oversight over incoming work signals**: declared
directions govern scope, captured threads retain evidence, and outcomes retain
results. Write simple English Markdown; neither EARS nor RFC requirements
language is required.

Name the signal sources, priority holders, and any derived presentation in the
`root` tag above. This canonical prose defines the mechanics; the adopter
declares which systems are read and what is currently important.

## Roles

- **Admin** ([`roles/admin.md`](roles/admin.md)) — the only role in this domain, used by default for routine work and framework maintenance. Full local read/write access does not authorize an unreviewed external action. An adopter that prefers another name for this single role may rename it — `general`, `lead`, `user`, and `main` all fit — but the domain stays single-role; do not split it into owner, reviewer, or contributor roles.

## Pillars

- [Directives](directives/index.md): priority scope and direction, one file per directive.
- [Threads](threads/index.md): source context, identified by stable IDs or descriptive slugs.
- [Outcomes](outcomes/index.md): results grouped by area, identified by descriptive slugs.
- [Sources](sources/index.md): read-only access to each data source, one file per source.

## Flow

Use [cumaru-zoom](skills/cumaru-zoom/SKILL.md) to select an existing thread by
ID, filename, or prose subject and load its context for discussion.

Use [cumaru-directives](skills/cumaru-directives/SKILL.md) to generate or refine
the broad directions and their concrete decision points. Use
[cumaru-thread](skills/cumaru-thread/SKILL.md) to capture or update a thread, and
[cumaru-outcome](skills/cumaru-outcome/SKILL.md) to derive, update, or reclassify
an outcome. Use [cumaru-sources](skills/cumaru-sources/SKILL.md) to read
every active source, or a named subset, and create or update threads from the
results under the active directives. These workflows operate under Admin. They authorize local document
maintenance only, not edits to external services.

Capture context first, then record a result once supported by the thread.
Preserve source threads when deriving outcomes. One thread can support several
outcomes; one outcome can draw on several threads. Pending threads may have no
outcome yet; do not invent a result to fill the relationship.

## Directive authority and scope

Directives govern which work is in scope, how it ranks, and what counts as
value. Load the directive contract and every active directive before ranking
threads, apply their scope, status, and priority as defined there, and record
the matched directives with a short evidence-based rationale in the thread
itself. An outcome's value is assessed against the directives it serves, not
against a standalone scale: the directive states the benefit being pursued, and
the outcome measures its contribution to that benefit.

New evidence does not silently redefine the declared scope. Surface an
out-of-scope request or risk for scope review instead of treating it as accepted
work. Explain urgent exceptions to directive order; do not change a directive's
status or priority in response to activity alone. Distinguish user-established
directives from stakeholder suggestions and agent-generated proposals, and do not
infer commitments, deadlines, or implementation authority from a broad direction.

Ranking combines two weighted signals and nothing else invented on top of them:
the priority of the matched directives, and the relevant dates. A higher-ranked
directive carries more weight, and so does a nearer or more overdue date. Neither
signal overrides the other by rule; state which one dominated when they disagree.
Order inside a queue comes from this same combination. A confirmed incident,
deadline, or response obligation may take precedence, with the exception
explained.

Separate the work that needs the user's own action from the work that is only
monitored downstream. A subject handed off to another team or awaiting a
downstream step stays visible as monitoring, not as personal urgency, and
returns to the action queue only when evidence explicitly asks the user for a
correction, response, or intervention. Preserve explicit user holds.

How signals arrive is declared in [`sources/`](sources/index.md): one file per
data source states its system, access tool, filters, window, thread mapping,
and limitations, all read-only. Adopter policy over intake, such as which
workflow collects and when, stays in the `root` tag. This domain governs what
happens to a subject once it is written down.

## Acting on a subject

The domain's own workflows write local documents and never mutate an external
system on their own. Discussing a subject, however, routinely leads to a real
action: a reply to send, a ticket to move, a message to post. Those actions are
allowed, and they are never taken silently.

Before performing an external action, present it in the terminal for the user to
check: the target system and record, the exact content to be sent or the exact
field change, the recipients, and what becomes irreversible once it goes out.
Wait for the user's confirmation on that presentation. Approval covers the action
presented and nothing beyond it; a second action needs its own presentation, and
a batch is presented as the complete set before any part of it runs. Report
afterwards what actually went out, and record it in the thread's history as an
event with its own date. Reading a source never needs this ceremony.

## Thread lifecycle

Every material subject change returns its thread to queue evaluation, including
reversals, reopened discussions, new feedback, and changes after an outcome.
Choose the queue from the new evidence; a downstream monitoring change stays
monitoring rather than personal urgency. Formatting edits and repeated
observations are not new subject events. Preserve explicit user holds unless new
evidence or the user changes their basis.

Threads accumulate a dated history of state changes in every direction. Preserve
old observations and record corrections rather than overwriting the history.
Creating an outcome never deletes its source thread. When its current cycle is
settled, archive it under `threads/archive-YYYY/<name>.md`, using the local year
of archival, not the year of creation. Keep unsettled work active even when one
of its results already has an outcome. A thread has no `done` state or queue:
archival is represented by its location in the yearly archive, not by a terminal
frontmatter value. Archived threads leave the active queues; preserve their
previous queue in history rather than retaining an active `group` field. On
renewed activity, move the same thread back to `threads/<name>.md`, retaining
identity and history. Repair incoming and outgoing relative links after every
move. See the [thread contract](threads/index.md).

## Verify sources before archival

Before deciding whether to archive a thread, use the available authenticated
tools to check its related source records for current status, recent comments,
notifications, unresolved requests, dependencies, and upcoming commitments.
Consult only the sources relevant to that subject and actually accessible, and
keep every one of them read-only.

Reconcile fresh evidence with the thread history and explicit user decisions.
An outcome, an approval, a closed review, a handoff to a downstream team, an
elapsed commitment, or an absence of recent activity does not prove closure by
itself. Record the observation date, source links, coverage limitations, and the
rationale for archiving or retaining the thread.

Verification informs the decision; it does not gate it. When the check was not
possible, was skipped, or could not confirm closure, archive when that is what
was asked and raise an explicit alert naming what stayed unverified and why it
matters. Never present missing access as confirmed completion, and never
silently drop the alert.

## Outcome views

Every outcome has cumulative value, work, and policy views as defined in the
[outcome contract](outcomes/index.md). Value describes benefit to the product,
including explicitly labeled artificial estimates and later corrections. Work
tracks accumulated effort without confusing elapsed waiting time with work.
Policy tracks how feedback and comments were received, decided, and acted on,
including disagreement and reversals. Keep evidence, assumptions, unknowns, and
updates visible; never invent acceptance, time records, or measured value.

## Entry

Load the relevant pillar index, expand it with `cumaru tree`, and read selected
documents. An outcome's declared `threads` tag adds its linked source threads
to the loading traversal. Resolve those Markdown links relative to the outcome.
Use `cumaru fs` for structural changes and `cumaru tag` for existing tag bodies.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the pillars, which hold *what* the
project is. Every modular file in `disciplines/` is loaded at context start; `applies-when:` controls
when its rules apply, never whether its body is loaded. `disciplines/index.md` defines how
`strictness:` controls required consideration. This domain is knowledge-oriented and installs only
`cumaru-first`.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
