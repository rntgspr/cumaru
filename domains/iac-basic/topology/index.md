---
human_revised: false
apps: [meta]
summary: Framework guidance for Topology and its required workflow.
---

# Topology

The **living infrastructure topology** — what is true right now about providers, accounts, stacks, modules, and the durable decisions behind them. Authored and refactored by the Lead; deltas are absorbed here on change close.

## Rules

- **Topology, not a code copy.** Each `topology/<area>/index.md` describes the stack's purpose, inputs/outputs, trust boundaries, decisions/trade-offs, and cost & security posture — **never** a paste of the HCL/YAML. The `.tf`/manifest is the executable spec; this is the intent the code can't carry.
- **`depends-on:` is the apply order.** A stack's `depends-on` lists the stacks that must be provisioned first (networking → compute → app). It is both the strongest load signal and the apply sequence. `relates:` is "consider".
- **This pillar is the record.** There is no second store of absorbed work — no ledger, no per-area list of the changes that built it. `topology/` states what is true now, and that claim stands on its own.
- **Bootstrap on demand.** An area is created the first time a changeset declares it in `scope:`. Don't seed empty areas.
- **Stacks split into concerns / subareas** as they grow (per-provider, per-account, per-region), recursively — same shape as areas.
- **Authoring is the Lead's.** Dev never writes inside `topology/` directly; absorption happens during the archive flow, driven by the Dev's `delta-draft.md`.

## When to use

- A changeset declares a `topology/` path in `scope:` → load the area and the concerns the active step touches.
- Determining apply order → read the `depends-on` DAG.
- Tracing why infra is shaped the way it is → read the relevant area, then use `git log` (see **History** below).

## History

The pillar carries no history of its own. Git is the cross-reference, in both
directions:

```bash
# which topology files did this ticket change?
git log --all --grep=<KEY> --name-only -- .cumaru/topology/
# which tickets built this topology?
git log --follow --oneline -- .cumaru/topology/<path>
```

This makes the absorption commit **message** load-bearing: it must name every
KEY it absorbs. Messages survive rebase and squash; SHAs do not.

## When NOT to use

- A change in flight → `plans/<PLAN-ID>/`.
- A repeatable operation → `runbooks/`.
- Active close-out details → `archive/<KEY>/delta.md` only while absorption is in flight.
- Mirror of tracker items → `intake/`.
