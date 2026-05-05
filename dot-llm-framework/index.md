---
human_revised: false
generated: false
apps: [meta]
framework-version: 2
---

<!-- llm:components -->
| Key | Folder | Stack / Notes |
|---|---|---|
| `webapp` | `web-app/` | (replace with your actual stack) |
| `api`    | `api/`    | (replace with your actual stack) |
<!-- /llm:components -->

<!-- llm:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /llm:root -->

# `.llm/`

Entry point for any LLM (or human) interacting with this repository. Organized as **five pillars** plus supporting directories.

> **Load only what is declared. Everything else stays on disk but out of context.**

Every structural choice — declared `scope:` in plans, `aux:` in tasks, generated indexes, archive and exploring never-default — serves that rule. The LLM reads only what the active task points to; the rest lives in version control but does not enter the prompt.

## Vision — how context flows

Context starts at the **ticket**, not at the framework. The framework only structures *how* context attaches to a ticket once it arrives.

1. **Both `index.md` and `schema.yaml` are loaded by default.** Other framework files (`templates/`, `roles/`) are loaded only when required by the current role or task. The framework specifies *the rules*, not *the work*. Skills are not included within the framework by default; they are published separately and can be added per project (`llm install --with <name>`) or globally to your Claude (Code / claude.ai).

2. **Context is born from the ticket.** A working session begins with either:
   - a Jira-backed ticket — mirrored under `intake/<type>/<KEY>/index.md`, plus a `plans/<KEY>/` directory authored against it;
   - or a slug-based initiative — `plans/maintenance-<slug>/`, with Overview and AC inline.

3. **The plan opens the context.** Reading `plans/<PLAN-ID>/index.md` brings in: the linked `intake/<type>/<KEY>/index.md` (when Jira-backed); the `scope:` paths under `specs/<area>/` — only those declared; and any `aux:` files at the plan or task level.

4. **Tasks announce what to do.** Each `t<N>.md` declares `concerns:` (which spec concerns to load), `files:` (predicted edits), and `depends-on:` (which prior task hand-offs to read).

5. **Adjacent context (`archive/`, `specs/`) enters only by reference.** The shallow `archive/index.md` and `specs/index.md` advertise what exists — they are the only opportunistic entry points. Drill into a `<PLAN-ID>/` or a spec area only when the active plan declares it (`scope:`, `deltas:`), the spec's `deltas:` frontmatter points to it, or the user asks for it explicitly.

## Structure

```
.llm/
├── index.md           ← this file
├── schema.yaml        ← canonical schema (frontmatter contract)
├── intake/            ← local mirror of Jira (epics, stories, tickets)
├── plans/             ← active execution plans (one directory per ticket or initiative)
├── archive/           ← completed plans (curated; never loaded by default)
├── specs/             ← living spec and ground truth of the system
├── exploring/         ← pre-plan ideas in incubation (never loaded by default)
├── reviews/           ← optional review artifacts (one file per reviewed plan)
├── roles/             ← agent roles (lead, dev, ghost)
└── templates/         ← templates for plans, tasks, specs, deltas, reviews, explorations
```

Skills, when present in a project, live at `.llm/skills/<name>/SKILL.md` and are opt-in per project via `llm install --with <name>`. They are not part of the framework starter; the dot-llm repo publishes them separately under `skills/` (Anthropic format).

## The five pillars

The first four form the canonical work cycle (`intake → plans → archive → specs`); `exploring/` sits beside the cycle as an incubator for pre-plan ideas. Each pillar has its own shallow `index.md` — the only opportunistic entry point into that pillar.

### `intake/` — what the ticket asks
Local mirror of Jira hierarchy (epics → stories → tickets). Each ticket file carries `## Overview` and `## Acceptance Criteria (EARS)` — these are **authored locally** from the Jira description (translated to English and refined), not copied verbatim. Plans for a Jira ticket reference these sections instead of repeating them. Re-sync from Jira when the upstream description changes materially. Stories with more than one active plan also carry a `## Coordination` section.
**See `intake/index.md`** for the ticket catalog.

### `plans/` — how we will do it
One directory per active ticket or internal initiative. Each plan declares its `scope:` (which `specs/` paths it touches) and a DAG of tasks. The plan body carries **`## Plan / DAG`, `## Out of scope`, `## Risks`** only — for Jira-backed plans, Overview and Acceptance Criteria live in `intake/tickets/<KEY>/index.md`. Slug-based plans (no Jira) keep Overview and AC inside the plan body since they have no intake counterpart.
**See `plans/index.md`** for the active plan catalog.

### `archive/` — what we did
Completed plans, moved here on close by the Lead. Never loaded into LLM context by default; drilling into `<PLAN-ID>/` requires explicit instruction.
**See `archive/index.md`** for the catalog of completed plans.

### `specs/` — what is true now
The living spec of the system: product features, platform conventions, integrations, and durable decisions. Plans reference paths in `specs/` via their `scope:` field. When a plan archives, its delta is **absorbed** into the spec body (current state); the spec's frontmatter `deltas:` list adds the plan ID as a reference. Verbose change wording stays in `archive/<PLAN-ID>/delta.md` — drill there when historical detail is needed.
**See `specs/index.md`** for the spec area catalog.

### `exploring/` — pre-plan ideas
Incubator for ideas that are **not yet plans**: free-form notes outside the canonical work cycle. Entries (`exploring/<slug>/`) have no Jira ticket, no commitment, and never enter LLM context by default. Each exploration is **transient by design** — it either matures into a plan or gets dropped (explorations never migrate to `archive/`; only completed plans do). The Lead owns this area; Dev and Ghost don't write here.
**See `exploring/index.md`** for what goes in, structure, lifecycle, and the current incubation list.

## Universal rules

- **Every entity is a directory containing `index.md`.** No bare files representing entities. Sub-entities (tasks, concerns) are sibling files with structured names.
- **Aux files load only when declared** in the entity's frontmatter `aux: [...]`. Undeclared aux is treated as scratch and ignored by the LLM.
- **Nothing loads by physical proximity.** Always by declaration (`scope`, `aux`, `concerns`, `files`).
- **Drill-into rule for a referenced `index.md`.** When the active context references an `index.md` (via `scope:`, `deltas:`, or explicit instruction), inspect the markdown files it lists:
  - **Direct match** — if a listed file's name or one-line description clearly relates to the context, load **only that file** (or those files).
  - **No direct match** — load **all** the markdown files in that directory; the relation may live inside a file whose name doesn't surface it.
  Example: the active context is *"the login button"*. A plan's `scope:` resolves to `specs/auth/index.md`, which lists `logout.md` and `structure.md` — neither name matches "login". Load all `.md` files under `specs/auth/` to find where login lives. If the index also listed `login.md`, load only `login.md`.
- **Tags right after frontmatter.** Every `<!-- llm:NAME -->` block lives **immediately after the YAML frontmatter, before any prose** (including the `# H1`). The frontmatter is the stable anchor; prose is framework-owned and may be rewritten between versions. Project-owned content lives inside the markers, above the prose, so it survives `llm sync` regardless of how the framework's narrative evolves. NAME is a single token (`intake`, `components`, `root`) or a `kind:tag` pair when the kind needs qualification (`files:touched`). Each tag's format is declared under `tags:` in `schema.yaml`.
- **Default directory depth ≤ 2 levels.** Deeper nesting requires justification.
- **Plans may exist without a Jira ID.** Slug-based plan IDs are valid and **must use the `maintenance-` prefix** (e.g., `plans/maintenance-cleanup-deprecated-helpers/`). When `jira:` is absent in the plan frontmatter, the directory name is the plan ID.
- **`exploring/` slugs have no prefix.** Pure kebab-case slug. No Jira ticket may live in `exploring/`.
- **Multi-component task naming:** see the Multi-component section below.
- **Generated indexes** (`intake/index.md`, `plans/index.md`, `archive/index.md`, `specs/index.md`, `exploring/index.md`) carry `generated: true` in their frontmatter and will be produced by the CLI when it lands. Static indexes (this file, `reviews/index.md`) carry `generated: false`.
- **Schema and validator.** The canonical schema lives at `schema.yaml`. A bash validator (gitignored, project-local) reads it: `bash llm.sh` from the repo root checks frontmatter conformance, valid `apps:` values, framework-version match, and warns on non-EARS acceptance criteria.
- **Skill-gated capabilities.** Some operations default to **read-only** for every role and are unlocked only when a matching skill is present under `.llm/skills/<name>/SKILL.md`. The skill describes how mutating operations should be performed; without it, the role keeps to read-only.
  - `.llm/skills/git/SKILL.md` — without it, every role uses git only for reading (`status`, `log`, `diff`, `blame`, `show`). With it present, mutating commands (`commit`, `push`, `reset`, `checkout`, ...) are allowed as the skill instructs. Add via `llm install --with git` (at install time) or copy the file in manually.
- **`human_revised:` frontmatter flag.** Every markdown under `.llm/` carries `human_revised: false` by default; flip to `true` after a human eyeballs the file end-to-end. Signals that an LLM-authored or LLM-modified file has had a human pass. New files start at `false`. The flag never blocks anything (no validator check yet) — it's a marker so reviewers can spot what still needs review without re-reading everything.

## Multi-component (apps + monorepo)

Edit this section to describe your repository's components. The framework defaults to two reserved keys:

| Key | What |
|---|---|
| `platform` | the monorepo as a whole — repo layout, build, conventions, integrations, anything that crosses components |
| `meta` | `.llm/` framework files — indexes, templates, role definitions, skills stubs (metadata of the framework itself, not system content) |

Add one row per component your project ships to the `<!-- llm:components -->` block at the **top of this file** (right after the frontmatter). The `llm sync` command preserves the body of any `<!-- llm:NAME -->` block across upgrades.

Then list those keys in `schema.yaml` under `apps.values`.

Every entity carries `apps: [...]` in its frontmatter:

- Single-component: `apps: [<component>]`.
- Multi-component: list explicitly, e.g. `apps: [<a>, <b>]`.
- Monorepo-level (any cross-cutting infrastructure or process): `apps: [platform]`.
- Framework metadata (the `.llm/` plumbing): `apps: [meta]`.

Inside an entity directory, `<component>.md` files appear **only when content meaningfully diverges per component**. Otherwise `index.md` carries everything.

A note on multi-component task naming: in plans declared with multiple components in `apps:`, tasks targeting a single component are suffixed `t<N>-<component>.md`. Single-component plans use plain `t<N>.md`.

## Loading rule

The LLM loads only what is **declared** — never what is physically near. Declarations come from three sources: the active plan, the role on duty, and explicit user instruction.

### When a plan is active

Plans declare `scope:` referencing paths under `specs/`:

```yaml
# plans/<PLAN-ID>/index.md
scope:
  - auth/state
  - auth/integration
  - platform/routing
```

Resolves to:

```
specs/auth/index.md
specs/auth/state.md
specs/auth/integration.md
specs/platform/routing/index.md
```

Plus any `aux:` declared at the plan level or in the active task's `t<N>.md`. For Jira-backed plans, the linked `intake/<type>/<KEY>/index.md` also enters context.

### When no plan is active (planning, ad-hoc)

Initial load depends on the role on duty:

| Role  | Shallow indexes loaded                                                       | Rationale |
|-------|------------------------------------------------------------------------------|-----------|
| Lead  | `plans/index.md`, `specs/index.md`, `intake/index.md`, `archive/index.md`    | Lead orchestrates — needs the full map to plan, dispatch, and reference history. |
| Dev   | none                                                                         | Dev operates inside a dispatched `plans/<PLAN-ID>/`. With no active plan there is no task to execute — **recommend the user switch to Lead** to plan and dispatch first. |
| Ghost | none                                                                         | Ad-hoc and read-only; pulls a shallow only when the user's question requires it. If the question outgrows ad-hoc help (multi-step, touches specs, needs a plan), **recommend the user switch to Lead**. |

Shallow indexes are tables of *what exists* — cheap in tokens. They are **maps**, not content. Drilling into a `<PLAN-ID>/`, `<KEY>/`, `<area>/`, or `<slug>/` is a separate step (see below).

### Drill-into (deep load)

Deep paths enter context **only** when one of the following declares them:

- the active plan (`scope:`, `aux:`, `concerns:`, `files:`),
- a spec's `deltas:` frontmatter (points to an archived plan),
- a plan's `jira:` field (points to an intake ticket),
- explicit user instruction.

`archive/<PLAN-ID>/` and `exploring/<slug>/` are never drilled by physical proximity. Their shallow root indexes describe what exists; the bodies require explicit reference or instruction.

## Linearity rules

- **Stories are linear:** only one plan from a story is active at a time. Cross-ticket coordination happens in the story's `## Coordination` section before dispatch.
- **Tasks within a plan may run in parallel** when `depends-on:` is satisfied and `files:` predictions do not overlap. The Lead verifies and reconciles cascades manually until orchestration tooling lands.

## Roles

- **Lead** — primary author of `.llm/`. Plans tickets, maintains specs, runs the archive flow on close, dispatches sub-agents within a plan, maintains `exploring/`.
- **Dev** — implements tasks specified in `plans/<PLAN-ID>/`. Has **bounded write access inside the active plan**: may update own `t<N>.md` (`status`, `aux`, body) and create `handoff-t<N>.md` (per task) and `delta-draft.md` (at plan close). Never writes elsewhere in `.llm/`.
- **Ghost** — IDE-pair agent for ad-hoc help. Read-only by default; writes only when the user explicitly asks. Never writes inside `.llm/`. No plan, no scope, no hand-off.

`intake/` is a Jira mirror — syncing it is a **mechanical operation**, not a role responsibility. Anyone (Lead, the user, the CLI when it lands) can trigger the sync; roles only **read** intake.

## Language

All content authored inside this directory is written in **English**. This includes index files, plans, specs, archive deltas, reviews, roles, templates, skills, and frontmatter strings (`purpose`, `summary`, etc.).

Mirrored Jira content in `intake/` keeps its original language for fields that come straight from Jira. Locally authored notes still use English.

The user-facing chat language is set by the project's `CLAUDE.md` or system prompt and is independent of this rule. The English rule applies only to files written under `.llm/`.

## Workflow scenarios

Four canonical interactions. Each maps to a role and a phase.

### 1. Planning session (Lead)

1. User asks to attack a ticket or initiative.
2. Lead reads `index.md` and `plans/index.md`; syncs `intake/` if relevant data is stale.
3. Lead identifies the scope: which `specs/` areas the work touches.
4. Lead authors `plans/<PLAN-ID>/index.md` with frontmatter, EARS criteria, and the task DAG.
5. Lead authors `t1.md`, `t2.md`, ... declaring `files:`, `depends-on:`, `parallel-safe:`.
6. Lead updates `plans/index.md`.

### 2. Implementation with parallelism (Lead + Dev sub-agents)

1. User asks for implementation.
2. Lead identifies tasks with `parallel-safe: true`, `depends-on:` satisfied, and no overlap in `files:`.
3. Lead dispatches N Dev sub-agents in parallel, one per task.
4. Each Dev: loads scope + task + concerns; flips `t<N>.md` to `in-progress`; implements; flips to `done`; writes `handoff-t<N>.md`.
5. Lead reconciles each `handoff-t<N>.md` and dispatches the next wave.
6. When the final task closes, the last Dev writes `plans/<PLAN-ID>/delta-draft.md` proposing changes to `specs/`.

### 3. IDE-pair session (Ghost)

1. User asks an ad-hoc question ("why is this build failing?", "how does X work?").
2. Ghost reads only what the question requires (code, the referenced spec area).
3. Ghost suggests in chat; applies a change only when the user explicitly asks.
4. No plan, no hand-off, no `.llm/` write. If the question grows into structured work, Ghost suggests switching to Lead.

### 4. Plan close (Lead)

1. All tasks `done`; Dev has written `delta-draft.md`.
2. Lead reads the draft and validates: every EARS in the plan covered? changes consistent with declared `scope:`? no `Removed Requirements` orphan a `depends-on:` elsewhere?
3. Lead finalizes as `archive/<PLAN-ID>/delta.md` (drops `status: draft`, tightens wording).
4. Lead absorbs into the affected specs: updates body and appends the plan ID to the spec's frontmatter `deltas:` list. The list is the canonical reference; `archive/<PLAN-ID>/delta.md` carries the verbose wording.
5. Lead deletes `plans/<PLAN-ID>/delta-draft.md` (intermediate; finalized version lives in archive).
6. Lead moves the rest of `plans/<PLAN-ID>/` → `archive/<PLAN-ID>/` (handoffs travel along).
7. Lead updates frontmatter (`status: done`, `completed-at`, `delta: delta.md`) and regenerates the shallow indexes.

## Instruction to the LLM

When starting any interaction:

1. Read this file to recall structural rules.
2. **Identify the role on duty** (Lead, Dev, or Ghost) and read the matching `roles/<role>.md`. Apply the per-role initial load defined in the [Loading rule](#loading-rule).
3. Identify the current scope: a plan in `plans/<PLAN-ID>/`, a spec area in `specs/<area>/`, an exploration in `exploring/<slug>/`, or a request that does not yet have a plan.
4. Load only what the plan declares (`scope`, `aux`, `concerns`, `files`). Do not browse `specs/` opportunistically.
5. Do not consult `archive/` or `exploring/` unless explicitly asked or the current plan references a past entry directly.
6. As Dev, persist your progress: keep `t<N>.md` `status:` current, write `handoff-t<N>.md` at task end, and `delta-draft.md` at plan close.
7. As Lead, reconcile each `handoff-t<N>.md` before dispatching dependent tasks; on plan close, validate the `delta-draft.md`, finalize as `delta.md`, absorb into specs, move plan to archive, regenerate indexes.

## Project context

Adopter-specific orientation the LLM should keep in mind while applying the rules above: stack, monorepo layout, conventions not yet captured in `specs/`, important external links, current focus, hard constraints. Edit the `<!-- llm:root -->` block at the **top of this file** — its body is preserved across `llm sync` upgrades.
