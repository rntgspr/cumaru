---
human_revised: false
generated: false
apps: [meta]
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# SDLC Light domain (simplified software-development workflow)

This file declares the SDLC Light domain's specifics — pillars, roles, entry,
and domain context — pulled into context as the root `index.md`'s `depends-on`.
The kernel rules (the node model, the loading rule, conduct, language) live in
`index.md` and are identical across all domains.

## Pillars (root's children)

```
.cumaru/
├── index.md      ← kernel (identical across domains)
├── schema.yaml   ← canonical contract
├── domain.md     ← this file (this domain's specifics)
├── plans/        ← everything: tracked items, active plans, completed plans
├── specs/        ← living spec; areas nest subareas
├── exploring/    ← pre-plan ideas in incubation (never loaded by default)
├── roles/        ← agent roles (lead)
└── templates/    ← entity templates
```

- **`plans/` — all work items.** One `plans/<PLAN-ID>/` per item: intake,
  active plan, or completed work. For tracker-backed items the `key:` field
  records the tracker id. Tasks, handoffs, and the delta-draft live inside.
  When a plan closes, its delta is absorbed directly into `specs/` — no
  separate archive pillar.
- **`specs/` — what is true now.** The living spec. Areas nest subareas to
  any depth; `depends-on` is the strongest load signal, `relates` is
  "consider". On plan close the delta is absorbed and the plan key appended
  to the area's `deltas`.
- **`exploring/` — pre-plan ideas.** Incubators with no commitment;
  transient. Never loaded by default. Promote to `plans/` when matured.

### Cycle

```
exploring/ ──promote──→ plans/ ──absorb──→ specs/
```

Tracker items (when a tracker is used) feed plans via the `key:` field, but
there is no separate `intake/` pillar — every item lives in `plans/`. Ideas
incubate in `exploring/`. Once committed, they become a plan in `plans/`. On
close, the `cumaru-absorb` skill reads the plan, updates specs, and removes both
the plan dir and the exploring entry that originated it — only `specs/` remains
as durable record.

## Roles

- **Lead** — the sole role. Unrestricted: reads and writes the entire
  `.cumaru/` tree and the repository. Owns planning, spec maintenance,
  exploration, and the absorb flow.

### Shallow indexes per role (entry into the loading rule)

| Role  | Shallow indexes loaded                                       |
|-------|--------------------------------------------------------------|
| Lead | `plans/index.md`, `specs/index.md`, `exploring/index.md`     |

### Plan-scoped entry

When a plan is active it declares `scope:` (paths under `specs/`) and
`aux:`; the scoped spec areas are the **declared entry** — the loading-rule
traversal starts from those nodes, nothing else.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the
pillars, which hold *what* the project is. Each discipline is a modular file
in `disciplines/<name>.md`, pulled into context by the loading rule **when
the task subject matches its `applies-when:`**. Each file carries a
`strictness:` (0–10, where 10 = inflexible/always, 0 = fully optional).

| Discipline | Applies when | File |
|---|---|---|
| verification | about to claim work complete; before commit / PR / handoff | `disciplines/verification.md` |
| systematic-debugging | a bug / test failure / unexpected behavior — before fixing | `disciplines/systematic-debugging.md` |
| test-driven-development | implementing a feature or bugfix, before writing code | `disciplines/test-driven-development.md` |
| receiving-code-review | acting on code-review feedback | `disciplines/receiving-code-review.md` |
| acceptance-testing | a plan is implemented and about to close — verify acceptance criteria with evidence | `disciplines/acceptance-testing.md` |
| dry | same knowledge / rule risks living in more than one place | `disciplines/dry.md` |
| kiss | choosing how to implement, when a simpler option exists | `disciplines/kiss.md` |
| yagni | tempted to build beyond a present, stated requirement | `disciplines/yagni.md` |
| solid | designing / refactoring structure — responsibilities, extension, coupling | `disciplines/solid.md` |
| blast-radius | fixing scope:/files: for a change whose reach the spec graph doesn't already describe | `disciplines/blast-radius.md` |

## Domain context (web/software)

> The framework was first applied to a web/software workflow. This is
> reference; the kernel itself is not software-specific.

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability;
  `.cumaru/` splits by concern, allows per-component divergence and slug-based
  plans, and separates pre-plan ideas in `exploring/`.
- **vs. Kiro / EARS** — `.cumaru/` adopts EARS as a **warning**, not a
  blocker; narrative sections stay free prose.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state;
  `.cumaru/` focuses on durable system state (living spec) + operational plan +
  pre-plan ideation.
