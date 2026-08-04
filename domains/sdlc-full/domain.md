---
human_revised: false
targets: [meta]
summary: Framework guidance for SDLC domain (software-development workflow) and its required workflow.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# SDLC domain (software-development workflow)

This file declares the SDLC domain's specifics — pillars, roles, entry, and domain context — pulled into context as the root `index.md`'s `depends-on`. The kernel rules (the node model, the loading rule, conduct, language) live in `index.md` and are identical across all domains.

## Pillars (root's children)

```
.cumaru/
├── index.md      ← kernel (identical across domains)
├── config.yaml   ← canonical contract
├── domain.md     ← this file (this domain's specifics)
├── intake/       ← tracker-agnostic mirror of work items
├── plans/        ← active execution plans (each: a plan + its tasks/handoffs/delta-draft)
├── specs/        ← living spec; areas nest subareas; the ground truth of the system
├── exploring/    ← pre-plan ideas in incubation (never loaded by default)
├── issues/       ← locally authored issues, ready to become plans (never loaded by default)
├── roles/        ← agent roles (lead, dev, ghost)
└── templates/    ← entity templates
```

- **`intake/` — what is asked.** A flat, **tracker-agnostic** mirror of work items: each lives at `intake/<KEY>.md`, carries `key`, `type`, and scalar `tracker` provenance, and links to others via `relates` (many-to-many, non-blocking). No enforced hierarchy or project-wide tracker registry.
- **`plans/` — how we will do it.** One `plans/<PLAN-ID>/` per active plan. Its `index.md` declares `scope` (which `specs/` paths it touches) and links to intake via `key` (optional for slug-based `maintenance-<slug>` plans). Tasks, handoffs, and the delta-draft live inside.
- **`specs/` — what is true now.** The living spec. Areas nest subareas to any depth; `depends-on` is the strongest load signal, `relates` is "consider". On plan close the delta is absorbed into the area whose scope actually owns it; `git log` is the only cross-reference back to the plan.
- **`exploring/` — pre-plan ideas.** Incubators with no commitment; transient. Never loaded by default.
- **`issues/` — locally authored work items.** Contextual bugs, features, improvements, and chores created in chat rather than mirrored from a tracker. They carry a concise issue contract and are transient. Never loaded by default.

## Flow

```mermaid
flowchart LR
  issues[issues/] --> plans[plans/]
  exploring[exploring/] --> plans
  intake[intake/] --> plans
  plans -->|absorb| specs[(specs/)]
  specs -. guarded cleanup .-> cleanup[Remove plan and confirmed consumed sources]
```

Tracker items mirrored in `intake/`, locally authored issues in `issues/`, and ideas from `exploring/` feed into
`plans/`. On close the finalized plan delta is absorbed directly into `specs/`.
Once absorbed, the plan directory is removed. Intake, issue, and
exploring sources are removed only when this plan consumed them and no active
work or unresolved provenance still depends on them. Only `specs/` — the
living spec — remains as the durable system record.

## Roles

- **Lead** — primary author of `.cumaru/`. Plans work, maintains specs, runs the absorption flow, dispatches Dev sub-agents, owns `exploring/` and `issues/`.
- **Dev** — implements tasks inside the active plan. Bounded writes: own `t<N>.md`, `handoff-t<N>.md`, and `delta-draft.md` at close. Never writes elsewhere in `.cumaru/`.
- **Ghost** — IDE-pair agent for ad-hoc help. Read-only by default; never writes inside `.cumaru/`.

`intake/` is a tracker mirror — syncing it is mechanical, not a role responsibility. Roles only **read** intake.

### Shallow indexes per role (this domain's entry into the loading rule)

| Role  | Shallow indexes loaded                                                     | Rationale |
|-------|----------------------------------------------------------------------------|-----------|
| Lead  | `plans/index.md`, `specs/index.md`, `intake/index.md`, `issues/index.md` | Orchestrates — needs the full map. |
| Dev   | none                                                                       | Operates inside a dispatched `plans/<PLAN-ID>/`. |
| Ghost | none                                                                       | Ad-hoc, read-only; pulls a shallow only when the question requires it. |

### Plan-scoped entry

For dispatched work, begin with the active plan and assigned task. Load the
canonical acceptance source (`intake/<KEY>.md` for tracker-backed work or the
maintenance plan's own criteria), explicitly linked required evidence and
`aux:` inputs, prerequisite handoffs named by `depends-on:`, and spec candidates
named by plan `scope:` or task `concerns:`. Follow only relevant semantic
dependencies; proximity does not authorize unrelated pillar content.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the pillars, which hold *what*
the project is. Every modular file in `disciplines/` is loaded at context start; `applies-when:`
controls when its rules apply, never whether its body is loaded. `disciplines/index.md` defines how
`strictness:` controls required consideration. Disciplines absorbed from external skills
are MIT-attributed in each file's `source:`; the engineering-principle disciplines (DRY / KISS /
YAGNI / SOLID) are authored in-house and carry no `source:`.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
| code-comments | code or related artifacts are written, edited, reviewed, refactored, or documented where comments may be affected | `disciplines/code-comments.md` |
| engineering | performing software engineering work or reporting technical results | `disciplines/engineering.md` |
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

New disciplines are produced with the repo's `skill-to-discipline` skill (distill an external
`SKILL.md` → gate + cycle + red flags).

## Domain context (web/software)

> The framework was first applied to a web/software workflow. This is reference; the kernel itself is not software-specific.

- **vs. OpenSpec** — OpenSpec keeps specs monolithic per capability; `.cumaru/` splits by concern, allows per-component divergence and slug-based plans, and separates pre-plan ideas in `exploring/`.
- **vs. GitHub Spec Kit** — Spec Kit recreates intake locally and grows verbose; `.cumaru/` mirrors the tracker instead and curates the absorption so it never loads by default.
- **vs. Kiro / requirements notation** — `.cumaru/` accepts EARS and RFC 2119 for acceptance criteria as a **warning**, not a blocker; narrative sections stay free prose.
- **vs. memory bank (Cline / Roo)** — memory bank focuses on session state; `.cumaru/` focuses on durable system state (living spec) + operational plan + curated absorption + pre-plan ideation.
