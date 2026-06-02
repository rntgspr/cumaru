---
human_revised: false
generated: false
apps: [meta]
---

# SDLC flavor (software-development workflow)

This file declares the SDLC flavor's specifics — pillars, roles, entry, and domain context — pulled into context as the root `index.md`'s `depends-on`. The kernel rules (the node model, the loading rule, conduct, language) live in `index.md` and are identical across all flavors.

## Pillars (root's children)

```
.llm/
├── index.md      ← kernel (identical across flavors)
├── schema.yaml   ← canonical contract
├── domain.md     ← this file (this flavor's specifics)
├── intake/       ← tracker-agnostic mirror of work items
├── plans/        ← active execution plans (each: a plan + its tasks/handoffs/delta-draft)
├── archive/      ← completed plans + their finalized deltas (never loaded by default)
├── specs/        ← living spec; areas nest subareas; the ground truth of the system
├── exploring/    ← pre-plan ideas in incubation (never loaded by default)
├── roles/        ← agent roles (lead, dev, ghost)
└── templates/    ← entity templates
```

- **`intake/` — what is asked.** A flat, **tracker-agnostic** mirror of work items: each lives at `intake/<KEY>/`, carries `key` + `type` (the tracker issuetype), and links to others via `relates` (many-to-many, non-blocking). No enforced hierarchy. The tracker is named once by `tracker` on `intake/index.md`.
- **`plans/` — how we will do it.** One `plans/<PLAN-ID>/` per active plan. Its `index.md` declares `scope` (which `specs/` paths it touches) and links to intake via `key` (optional for slug-based `maintenance-<slug>` plans). Tasks, handoffs, and the delta-draft live inside.
- **`archive/` — what we did.** Completed plans, moved here on close; never loaded by default.
- **`specs/` — what is true now.** The living spec. Areas nest subareas to any depth; `depends-on` is the strongest load signal, `relates` is "consider". On plan close the delta is absorbed and the plan `key` appended to the area's `deltas`.
- **`exploring/` — pre-plan ideas.** Incubators with no commitment; transient. Never loaded by default.

## Roles

- **Lead** — primary author of `.llm/`. Plans work, maintains specs, runs the archive flow, dispatches Dev sub-agents, owns `exploring/`.
- **Dev** — implements tasks inside the active plan. Bounded writes: own `t<N>.md`, `handoff-t<N>.md`, and `delta-draft.md` at close. Never writes elsewhere in `.llm/`.
- **Ghost** — IDE-pair agent for ad-hoc help. Read-only by default; never writes inside `.llm/`.

`intake/` is a tracker mirror — syncing it is mechanical, not a role responsibility. Roles only **read** intake.

### Shallow indexes per role (this flavor's entry into the loading rule)

| Role  | Shallow indexes loaded                                                     | Rationale |
|-------|----------------------------------------------------------------------------|-----------|
| Lead  | `plans/index.md`, `specs/index.md`, `intake/index.md`, `archive/index.md`  | Orchestrates — needs the full map. |
| Dev   | none                                                                       | Operates inside a dispatched `plans/<PLAN-ID>/`. |
| Ghost | none                                                                       | Ad-hoc, read-only; pulls a shallow only when the question requires it. |

### Plan-scoped entry

When a plan is active it declares `scope:` (paths under `specs/`) and `aux:`; the linked intake item (`key`) and the scoped spec areas are the **declared entry** — the loading-rule traversal starts from those nodes, nothing else.

## Domain context (web/software)

> The framework was first applied to a web/software workflow. This is reference; the kernel itself is not software-specific.

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability; `.llm/` splits by concern, allows per-component divergence and slug-based plans, and separates pre-plan ideas in `exploring/`.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; `.llm/` mirrors the tracker instead and curates the archive so it never loads by default.
- **vs. Kiro / EARS** — `.llm/` adopts EARS for acceptance criteria as a **warning**, not a blocker; narrative sections stay free prose.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state; `.llm/` focuses on durable system state (living spec) + operational plan + curated archive + pre-plan ideation.
