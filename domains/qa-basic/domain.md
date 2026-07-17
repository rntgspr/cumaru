---
human_revised: false
apps: [meta]
summary: Framework guidance for QA domain (test-strategy & coverage workflow) and its required workflow.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# QA domain (test-strategy & coverage workflow)

This file declares the QA domain's specifics — pillars, roles, entry, and domain context — pulled into context as the root `index.md`'s `depends-on`. The kernel rules (the node model, the loading rule, conduct, language) live in `index.md` and are identical across all domains.

> **Axis.** In this domain the universal `apps:` field enumerates **test levels** (`unit` | `integration` | `e2e` | `contract` | `performance` | `all` | `meta`), not software components. A file's `apps:` says which levels it spans (e.g. `apps: [unit, e2e]`). The field name stays `apps` so `index.md` is byte-identical to the kernel; the semantic lives here. See `schema.yaml`'s AXIS NOTE.

> **Tool-agnostic.** The domain models the *knowledge* of how a system is verified (coverage, scenarios, conventions), not any single runner. Jest/Vitest, Playwright, Cypress, pytest, k6 — each coverage area records which runner exercises it. Runner-specific guidance ships as opt-in skills (e.g. `--with playwright`, `--with vitest`).

## Pillars (root's children)

```
.cumaru/
├── index.md      ← kernel (identical across domains)
├── schema.yaml   ← canonical contract
├── domain.md     ← this file (this domain's specifics)
├── intake/       ← tracker-agnostic mirror of what must be verified (requests, bug reports, requirements)
├── plans/        ← active test campaigns (the campaign + its cases / handoffs / delta-draft)
├── archive/      ← transient close-out staging (never loaded by default)
├── coverage/     ← living coverage map; the ground truth of how the system is verified
├── exploring/    ← exploratory-testing charters / spikes (never loaded by default)
├── standards/    ← durable testing conventions (mocking, data, gates, flakiness, environments)
├── roles/        ← agent roles (lead, dev)
└── templates/    ← entity templates
```

- **`intake/` — what must be verified.** A flat, tracker-agnostic mirror of the items that drive test work: a feature whose acceptance criteria need coverage, a bug report to reproduce and guard against regression, a test request. Each lives at `intake/<KEY>/`, with `type` + `relates`; its `## Acceptance Criteria (EARS / RFC 2119)` is the **requirement to verify**. The tracker is named once on `intake/index.md`.
- **`plans/` — the campaign.** One `plans/<PLAN-ID>/` per in-flight test campaign. The plan body declares the **test strategy** (which levels, why), the **scope** (the `coverage/` paths it touches), and **risks/gaps**; tasks are the cases to author or automate. `apps:` = the levels the campaign writes at.
- **`archive/` — close-out staging.** Closed campaigns move here only while their delta is absorbed; the directory is removed after the durable ledger entry is recorded.
- **`coverage/` — what is verified now.** The living **coverage map**: areas of the system-under-test, the levels each is exercised at, and the **scenarios** (Given-When-Then) that verify them. `depends-on` is both the load signal AND the **test prerequisite** order (an area's setup presumes another's — e.g. checkout presumes auth). Carries what the test code does not: strategy, why a level was chosen, known gaps. It does **not** duplicate the `.test`/`.spec` files — those are the executable verification. `coverage/index.md` carries the durable `absorptions` ledger.
- **`exploring/` — exploratory charters.** Session-based exploratory-testing charters and spikes with no commitment; transient. Never loaded by default. A charter either matures into a campaign (or a logged bug in `intake/`) or is dropped.
- **`standards/` — how we test.** DURABLE testing conventions, one directory each (`standards/<slug>/index.md`, flat — no nesting). Unlike the transient pillars, standards persist and apply ACROSS coverage areas: naming, fixtures/factories, mocking policy per level, coverage gates, flakiness policy, test environments. `relates:` points at the `coverage/` areas they govern.

## Lifecycle (finalize-and-delete into the durable layer)

```
intake/ ──┐
          ├──→ plans/ ──close──→ archive/ ──absorb──→ coverage/
exploring/ ┘


standards/  (standalone durable — governs coverage/ via relates)

After absorb: archive/, plans/, exploring/, and intake/ entries
related to the closed plan are removed (transient cleanup).
```

Work flows `intake → plans → archive`, is distilled into the durable layer (`coverage/`), then all transient content for that cycle is removed. Only the updated coverage map, its `SHA | KEY | Description` absorption ledger, and durable standards remain.

## Traceability (requirement → test → evidence)

The domain's backbone: an intake item states the requirement in **EARS or RFC 2119** (`## Acceptance Criteria (EARS / RFC 2119)`); a coverage area states the verifying scenario in **Given-When-Then** (`## Scenarios (GWT)`) and `relates:` back to the intake `<KEY>`; `coverage/index.md` records the absorbed campaign SHA. Coverage of a requirement = it has a scenario that relates to it.

## Roles

- **Lead (QA)** — primary author of `.cumaru/`. Plans campaigns, maintains the coverage map in `coverage/`, owns `standards/` and `exploring/`, runs the close/archive flow, dispatches Dev sub-agents.
- **Dev (tester)** — executes a campaign's cases inside the active plan. Bounded writes: own `t<N>.md`, `handoff-t<N>.md`, and `delta-draft.md` at close. Never writes elsewhere in `.cumaru/`.

`intake/` is a tracker mirror — syncing it is mechanical, not a role responsibility. Roles only **read** intake.

This domain drops the sdlc **Ghost** role: QA campaigns are deliberate (plan → author cases → run → record), not ad-hoc IDE pairing, so the read-only opportunistic role earns no place here.

### Shallow indexes per role (this domain's entry into the loading rule)

| Role | Shallow indexes loaded | Rationale |
|------|------------------------|-----------|
| Lead | `plans/index.md`, `coverage/index.md`, `intake/index.md`, `archive/index.md`, `standards/index.md` | Orchestrates — needs the full map, including the conventions. |
| Dev  | none | Operates inside a dispatched `plans/<PLAN-ID>/`. |

### Campaign-scoped entry

When a campaign is active it declares `scope:` (paths under `coverage/`) and `aux:`; the linked intake item (`key`) and the scoped coverage areas are the **declared entry** — the traversal starts from those nodes, nothing else.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the pillars, which hold *what*
the project is. Each discipline is a modular file in `disciplines/<name>.md`, pulled into context
by the loading rule **when the task subject matches its `applies-when:`** — the row below is the
eager index; the body loads only on relevance, never always-on. Each file carries a `strictness:`
(0–10, where 10 = inflexible/always, 0 = fully optional).

| Discipline | Applies when | File |
|---|---|---|
| dry | same knowledge / rule risks living in more than one place | `disciplines/dry.md` |
| kiss | choosing how to implement, when a simpler option exists | `disciplines/kiss.md` |
| yagni | tempted to build beyond a present, stated requirement | `disciplines/yagni.md` |
| solid | designing / refactoring structure — responsibilities, extension, coupling | `disciplines/solid.md` |
| blast-radius | fixing scope:/files: for a change whose reach the spec graph doesn't already describe | `disciplines/blast-radius.md` |

## QA discipline

- **Mind the pyramid.** Most coverage is `unit`, less `integration`, fewest `e2e`. An area's `apps:` declares its levels; a plan that adds an e2e where a unit test suffices is a smell.
- **Every requirement is traceable.** No acceptance criterion ships without a covering scenario that `relates:` back to it. Gaps are stated, not hidden.
- **Mock by level.** `unit` mocks its dependencies; `integration` uses real collaborators (containers, test DBs); `e2e` mocks nothing. The policy lives in `standards/`.
- **Flakiness is a defect.** A non-deterministic test is quarantined and fixed, never retried into green. The flakiness policy is a standard.
- **The test is the spec of behaviour** — `coverage/` carries strategy and intent, never a copy of the `.test`/`.spec` source, which drifts and lies.
