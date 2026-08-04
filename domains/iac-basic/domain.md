---
human_revised: false
apps: [meta]
summary: Framework guidance for IaC domain (infrastructure-as-code workflow) and its required workflow.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with your actual stack)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /cumaru:root -->

# IaC domain (infrastructure-as-code workflow)

This file declares the IaC domain's specifics — pillars, roles, entry, and domain context — pulled into context as the root `index.md`'s `depends-on`. The kernel rules (the node model, the loading rule, conduct, language) live in `index.md` and are identical across all domains.

> **Axis.** In this domain the universal `apps:` field enumerates **environments** (`dev` | `staging` | `prod` | `all` | `meta`), not software components. A file's `apps:` says which environments it concerns. The field name stays `apps` so `index.md` is byte-identical to the kernel; the semantic lives here. See `config.yaml`'s AXIS NOTE.

> **Tool-agnostic.** The domain models the *knowledge* around infrastructure (topology, changes, procedures), not any single tool. Terraform, OpenTofu, Pulumi, CloudFormation, Ansible, Kubernetes/Helm — each stack records its own tool in `topology/`. Tool-specific guidance ships as opt-in skills (e.g. `--with terraform`, `--with pulumi`).

## Pillars (root's children)

```
.cumaru/
├── index.md      ← kernel (identical across domains)
├── config.yaml   ← canonical contract
├── domain.md     ← this file (this domain's specifics)
├── intake/       ← tracker-agnostic mirror of change requests / incidents
├── plans/        ← active changesets (the change + its apply steps/handoffs/delta-draft)
├── archive/      ← transient close-out staging (never loaded by default)
├── topology/        ← living infra topology; the ground truth (what the code does NOT say)
├── exploring/    ← pre-change infra spikes (never loaded by default)
├── runbooks/     ← durable operational procedures (rotate-secret, scale, failover, DR)
├── roles/        ← agent roles (lead, dev)
└── templates/    ← entity templates
```

- **`intake/` — what is asked.** A flat, tracker-agnostic mirror of the tickets/incidents that drive infra change: a provisioning request, a capacity bump, an incident remediation. Each lives at `intake/<KEY>/`, with `type` + `relates`. The tracker is named once on `intake/index.md`.
- **`plans/` — the changeset.** One `plans/<PLAN-ID>/` per in-flight infra change. The plan body declares the **blast radius**, **rollback plan**, and **promotion path** (which environments, in what order); tasks are the apply steps. `scope:` names the `topology/` paths the change touches.
- **`archive/` — close-out staging.** Applied changes move here only while their delta is absorbed; the directory is removed once the delta has landed in `topology/`.
- **`topology/` — what is true now.** The living infra **topology**: providers, accounts, stacks, modules. `depends-on` is both the load signal AND the **apply order** (networking → compute → app). Carries what the code does not: high-level topology, trust boundaries, decisions/trade-offs, cost & security. It does **not** duplicate the `.tf`/manifest — that is the executable spec.
- **`exploring/` — pre-change spikes.** Infra hypotheses and sketches with no commitment; transient. Never loaded by default.
- **`runbooks/` — how we operate.** DURABLE operational procedures, one directory each (`runbooks/<slug>/index.md`, flat — no nesting). Unlike the transient work pillars, runbooks persist. `relates:` points at the `topology/` stacks they operate on.

## Lifecycle (finalize-and-delete into the durable layer)

```
intake/ ──┐
          ├──→ plans/ ──close──→ archive/ ──absorb──→ topology/
exploring/ ┘                                               │
                                                           │ relates
                                                           ▼
                                                      runbooks/

After absorb: archive/, plans/, exploring/, and intake/ entries
related to the closed plan are removed (transient cleanup).
```

Work flows `intake → plans → archive`, is distilled into the durable layer (`topology/`), then all transient content for that cycle is removed. Only the updated topology and durable runbooks remain; `git log` is the cross-reference back to the changes that built them.

## Roles

- **Lead (platform)** — primary author of `.cumaru/`. Plans changes, maintains the topology in `topology/`, runs the apply + archive flow, owns `runbooks/` and `exploring/`, dispatches Dev sub-agents.
- **Dev (operator)** — executes a changeset's apply steps inside the active plan. Bounded writes: own `t<N>.md`, `handoff-t<N>.md`, and `delta-draft.md` at close. Never writes elsewhere in `.cumaru/`.

`intake/` is a tracker mirror — syncing it is mechanical, not a role responsibility. Roles only **read** intake.

This domain drops the sdlc **Ghost** role: infrastructure work is deliberate (plan → apply → verify), not ad-hoc IDE pairing, so the read-only opportunistic role earns no place here.

### Shallow indexes per role (this domain's entry into the loading rule)

| Role  | Shallow indexes loaded                                                                          | Rationale |
|-------|-------------------------------------------------------------------------------------------------|-----------|
| Lead  | `plans/index.md`, `topology/index.md`, `intake/index.md`, `archive/index.md`, `runbooks/index.md`  | Orchestrates — needs the full map, including operational procedures. |
| Dev   | none                                                                                            | Operates inside a dispatched `plans/<PLAN-ID>/`. |

### Change-scoped entry

When a changeset is active it declares `scope:` (paths under `topology/`) and `aux:`; the linked intake item (`key`) and the scoped topology areas are the **declared entry** — the traversal starts from those nodes, nothing else.

## Execution disciplines

Framework-shipped conduct for *how* work is done — distinct from the pillars, which hold *what*
the project is. Every modular file in `disciplines/` is loaded at context start; `applies-when:`
controls when its rules apply, never whether its body is loaded. `disciplines/index.md` defines how
`strictness:` controls required consideration.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
| code-comments | code or related artifacts are written, edited, reviewed, refactored, or documented where comments may be affected | `disciplines/code-comments.md` |
| dry | same knowledge / rule risks living in more than one place | `disciplines/dry.md` |
| kiss | choosing how to implement, when a simpler option exists | `disciplines/kiss.md` |
| yagni | tempted to build beyond a present, stated requirement | `disciplines/yagni.md` |
| solid | designing / refactoring structure — responsibilities, extension, coupling | `disciplines/solid.md` |
| blast-radius | fixing scope:/files: for a change whose reach the spec graph doesn't already describe | `disciplines/blast-radius.md` |

## IaC discipline

- **Blast radius is mandatory.** Every changeset states what it can break and across which environments — not all infra changes are reversible (destroying a database, a CIDR change).
- **Rollback is explicit.** State the reversal (or why none exists) before apply, not after.
- **`depends-on` is apply order.** The topology DAG in `topology/` is also the sequence: provision a stack only after its prerequisites.
- **Promote across environments.** A change lands in `dev`, then `staging`, then `prod`; the plan records the promotion path, and each artifact's `apps:` scoping says where it has landed.
- **The code is the spec.** `topology/` carries intent and topology, never a copy of the HCL/YAML — that drifts and lies.
