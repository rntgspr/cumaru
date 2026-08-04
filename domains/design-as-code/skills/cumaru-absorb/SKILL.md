---
human_revised: false
version: 1
name: cumaru-absorb
description: Close a completed design plan by absorbing accepted claims into specs, retaining reusable asset records, and cleaning up consumed transient work.
summary: Close design delivery with verified durable specs and asset records before removing consumed plans, concepts, research, and local briefs.
---

# Cumaru absorb — close design work

Read `.cumaru/domain.md` and apply its role routing boundary. This recipe is
owned by Design Lead; Designer and Reviewer return their results to Lead
without assuming its role. As Lead, load `roles/lead.md` and the plan identified
by invocation arguments. This is direct absorption; no archive staging is used.

## Preflight

- Require the plan index, delta draft, completed tasks, and their handoffs.
- Apply the review and readiness gate in `roles/lead.md`: require independent
  review evidence for the delivered revision and proposed delta, with findings
  reconciled in the handoffs. Missing review, unresolved findings, or missing
  required verification block absorption before any durable edits or cleanup.
- Resolve the acceptance source through `templates/plan.md`: tracker-backed
  criteria live in `intake/<KEY>.md`; maintenance criteria live in the plan.
  Follow the criterion mappings in `templates/delta-draft.md` and reviewed
  results in `templates/handoff.md`. Missing evidence, unresolved claims, or
  conflicting criteria block close-out.
- Require a Git work tree with committed, tracked transient evidence before
  editing durable content. Check `git status --short` and `git ls-files` for
  the affected paths; do not mix pending edits into this recovery baseline.
- Git writes require user authorization. If the recovery baseline is missing,
  stop and explain what must be committed; do not create a private backup.

## Discover ownership and cleanup candidates

1. Run `cumaru tree specs --rows`; select owners by summary and recurse only
   into relevant areas. Treat the plan's `scope:` as a hint to verify. Surface
   mismatched ownership or conflicting claims for adjudication before editing.
2. Read the plan's linked concept, research, and intake evidence. Use shallow
   `cumaru tree` projections and targeted reference searches across active
   plans and concepts to identify shared consumers. Missing semantic links do
   not prove that evidence is unshared.
3. Map accepted experience claims to exact spec concerns. Create a missing
   owning area through `cumaru-specs`. Use `cumaru tree assets --rows` for
   reusable asset records whose source, license, or usage guidance must survive.
4. Propose the exact transient removal set: the completed plan and consumed
   concept, research, and local intake entries. Preserve any entry still needed
   by other active work or containing unresolved claims. Assets is never a
   cleanup target. Confirm claim ownership and the proposed removal set.

## Absorb and validate

1. Apply the validated delta using `templates/spec.md` and `templates/asset.md`
   as the durable contracts. Preserve applicable design dimensions and their
   reviewed evidence, including prototype/source revisions. Retain
   accepted research findings and necessary provenance there; update reusable
   asset records in assets without duplicating the experience contract.
2. Account for every acceptance criterion through a durable requirement or an
   explicit no-spec-change rationale. A no-spec-change delta still requires
   evidence review, validation, and the same cleanup gates.
3. Replace retained links into planned removals with appropriate durable or
   original source references. Keep an entry if its evidence cannot yet be
   retained adequately. Do not place URLs or knowledge paths in source-only
   `reference` tags.
4. Run `cumaru doctor` and inspect the affected specs and assets. Doctor does
   not establish semantic completeness: verify every accepted claim and retained
   link against the evidence. Failed verification or unresolved claims block
   cleanup; leave the plan and delta draft intact.
5. Present the durable result and final removal set for confirmation. Before
   any deletion, require a committed Git recovery point containing both the
   verified durable result and every transient file to be removed. Check the
   affected paths are tracked and have no pending changes. When authorized,
   the absorption commit must name every absorbed work key. Otherwise stop
   before cleanup and request that recovery point.

## Clean up and verify

Only after the preceding gates pass, use `cumaru fs <path> remove` for each
confirmed transient entry. Remove the completed plan directory, including its
delta draft and handoffs, together. Do not retain a completed plan as a second
history record, delete tracker tickets, or remove shared evidence or assets.

Run `cumaru tree plans --rows`, the affected pillar projections, and
`cumaru doctor`. Inspect remaining links to removed entries. Report retained
shared work and any failures; recovery uses Git history, never an automatic
reset. Git mutation remains subject to the user's authorization.
