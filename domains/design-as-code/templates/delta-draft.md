---
human_revised: false
plan: <PLAN-ID>
status: draft
date: YYYY-MM-DD
summary: Proposed design requirement and asset changes traced to acceptance evidence.
---

# Delta draft — <PLAN-ID>

Designer proposes; Lead consolidates and absorbs through `cumaru-absorb`.
Do not edit durable files directly from a task. Account for every acceptance
criterion once through a proposed durable change or an explicit no-change
rationale; keep criteria text in its canonical source.

## Claim mapping

| Criterion | Handoff / reviewed evidence | Durable destination / requirement | Change or no-change rationale |
|---|---|---|---|
| <source link / AC-1> | <handoff and review revision> | <spec concern / R-1 or asset record> | <accepted claim or reason> |

## specs/<area>/<concern>.md

### Added Requirements

- <Proposed requirement with its criterion ID and reviewed evidence>.

### Modified Requirements

- <Existing requirement ID, proposed wording, and reason for the change>.

### Removed Requirements

- <Existing requirement ID and evidence-backed reason for removal>.

Follow `templates/spec.md` for applicable design dimensions and retained
provenance. Remove unused change sections. If no spec change is needed, state
`No spec change required — <rationale>` and keep the claim mapping and any asset
changes; review and cleanup gates still apply.

## Asset changes

Propose reusable record changes through `templates/asset.md`, or state `None`.
Identify source/license evidence and durable consumers.

## Evidence retention

Name the retained destination for necessary research, prototype/source, and
verification evidence before its transient host is removed. Identify shared
research or briefs that other active work still needs.
