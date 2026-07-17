---
human_revised: false
apps: [meta]
summary: Framework guidance for Topology and its required workflow.
---

<!-- cumaru:absorptions -->
| SHA | KEY | Description |
|-----|-----|-------------|

_No absorbed changes yet. Each row records the commit SHA that absorbed a change delta into topology, the change key, and a one-line summary of what became durable._
<!-- /cumaru:absorptions -->

# Topology

The **living infrastructure topology** — what is true right now about providers, accounts, stacks, modules, and the durable decisions behind them. Authored and refactored by the Lead; deltas are absorbed here on change close.

## Rules

- **Topology, not a code copy.** Each `topology/<area>/index.md` describes the stack's purpose, inputs/outputs, trust boundaries, decisions/trade-offs, and cost & security posture — **never** a paste of the HCL/YAML. The `.tf`/manifest is the executable spec; this is the intent the code can't carry.
- **`depends-on:` is the apply order.** A stack's `depends-on` lists the stacks that must be provisioned first (networking → compute → app). It is both the strongest load signal and the apply sequence. `relates:` is "consider".
- **`deltas:` frontmatter is the local trace.** Each area lists the change IDs whose deltas built its current state. The durable cross-topology ledger is `cumaru:absorptions` on this index.
- **Bootstrap on demand.** An area is created the first time a changeset declares it in `scope:`. Don't seed empty areas.
- **Stacks split into concerns / subareas** as they grow (per-provider, per-account, per-region), recursively — same shape as areas.
- **Authoring is the Lead's.** Dev never writes inside `topology/` directly; absorption happens during the archive flow, driven by the Dev's `delta-draft.md`.

## When to use

- A changeset declares a `topology/` path in `scope:` → load the area and the concerns the active step touches.
- Determining apply order → read the `depends-on` DAG.
- Tracing why infra is shaped the way it is → follow the area's `deltas:`, find the corresponding KEY in `cumaru:absorptions`, and inspect the recorded SHA.

## When NOT to use

- A change in flight → `plans/<PLAN-ID>/`.
- A repeatable operation → `runbooks/`.
- Active close-out details → `archive/<KEY>/delta.md` only while absorption is in flight.
- Mirror of tracker items → `intake/`.
