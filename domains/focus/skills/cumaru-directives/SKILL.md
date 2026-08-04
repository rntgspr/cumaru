---
name: cumaru-directives
human_revised: false
summary: Maintain canonical directive files that govern incoming work priorities.
description: Generate or refine the main priority directives, connecting broad work scope to concrete decision points. Use for defining oversight or priority scope; not for a daily source scan.
---

# Refine priority directives

Read `.cumaru/domain.md` from the repository root, including its root policy,
linked components, and `.cumaru/directives/index.md`. Use the default Admin role.
The domain is canonical for directive authority and scope; do not duplicate
its current priority order in this skill.

## Workflow

1. Accept prose, an existing directive, or a request to review the set.
   Use `cumaru tree directives` and `cumaru map directives` for definitions,
   then `cumaru tree threads` and `cumaru map threads` for source evidence.
   Read plausible matches before proposing or creating another identity.
2. Separate user-established scope from source evidence and agent proposals.
   Use existing dated evidence first. Read external sources only when necessary
   to resolve a concrete gap; keep them read-only and disclose missing access.
3. Refine an ordered set at two levels:
   - Broad oversight: a short direction, its purpose, included work, and boundaries.
   - Concrete points: desired result, next action or decision, related thread
     links, and evidence or uncertainty. Do not invent deadlines or acceptance.
   A broad direction can contain several concrete threads; a single ticket is not
   automatically a new top-level directive.
4. Preserve explicit user ordering and holds. Merge overlapping wording without
   deleting provenance. Flag signals outside the declared scope for scope review,
   rather than silently expanding work or hiding material risks. Do not promote
   a stakeholder suggestion into a user-approved commitment.
5. For requested local changes, maintain one definition per slug in
   `.cumaru/directives/`, following its contract for status, priority, scope,
   concrete points, and evidence. Use `cumaru fs` to create or move files and
   preserve existing definitions and source thread identities. Threads retain
   conversations, not duplicate directive definitions; use `cumaru-thread`
   only when new source history needs capture. Clearly distinguish proposals
   from established directives. Use `cumaru tag` for requested root-policy
   edits and for the ordered `directives` view; do not maintain a duplicate
   ranked inventory in the root prose.

## Handoff and validation

Return the proposed or applied ordered directives, their concrete points,
and material gaps. Explain changed scope or ordering briefly.
Run `cumaru doctor` after document changes and check referenced local links.
This skill authorizes no external message, ticket change, or publication.
