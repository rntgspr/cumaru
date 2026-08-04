---
human_revised: false
targets: [meta]
summary: Canonical authoring templates for design briefs, evidence, delivery, and specs.
---

# Templates

Copy the matching template, fill placeholders, and omit unused optional
sections. `config.yaml` declares entity paths and metadata; `targets:` uses its
component keys. Paths below are relative to `.cumaru/`.

| Template | Destination | Owner |
|---|---|---|
| [intake-brief.md](intake-brief.md) | `intake/<KEY>.md` for every tracker item type | Lead |
| [research.md](research.md) | `research/<slug>/index.md` | Lead or bounded Designer task |
| [concept.md](concept.md) | `concepts/<slug>/index.md` | Lead |
| [plan.md](plan.md) | `plans/<PLAN-ID>/index.md` | Lead |
| [task.md](task.md) | `plans/<PLAN-ID>/t<N>.md` | Lead |
| [handoff.md](handoff.md) | `plans/<PLAN-ID>/handoff-t<N>.md` | Designer result; Lead retains review |
| [delta-draft.md](delta-draft.md) | `plans/<PLAN-ID>/delta-draft.md` | Designer proposals; Lead consolidation |
| [spec.md](spec.md) | `specs/<area>/index.md` or `<concern>.md` | Lead |
| [asset.md](asset.md) | `assets/<slug>.md` | Lead; Designer proposes changes |
| [any-index.md](any-index.md) | Pillar or grouping `index.md` | Lead |
| [bootstrap.md](bootstrap.md) | Optional `specs/<area>/bootstrap.md` discovery notes | Lead |

Tracker-backed Overview and Acceptance Criteria live only in the brief;
maintenance keeps them in the plan. Plan coverage, task verification, handoff
results, and delta mappings reference those criteria through durable absorption.
