---
human_revised: false
name: blast-radius
applies-when: "fixing a plan's scope: or a task's files: for a change whose reach the spec graph does not already describe — a shared capability/surface/flow not yet a node with edges in specs/ (or topology/)"
strictness: 9/10
summary: Framework guidance for Blast radius (keep the impact graph complete before planning) and its required workflow.
---

# Blast radius (keep the impact graph complete before planning)

**Gate:** the blast radius of a change is the set of capabilities and flows it can reach — read it
from the `depends-on` / `relates` graph in `specs/`, don't rediscover it by hand each time. Before
fixing `scope:` / `files:`, confirm the graph already describes the surface you're touching: it has
a node, and its edges name what reaches it. If it doesn't — a shared capability with no spec, or
edges that stop at the direct caller — STOP and complete the graph first (bootstrap the area's
`index.md`, declare its `depends-on` / `relates`) so the reach is in context, not assumed.

This is the *domain* blast radius — which capabilities a change crosses — not the *code* one. Every
`import` is an edge; tracing those is the compiler / LSP's job, and a gate on it would fire on
everything. The framework's job is the reach the call graph can't see: that one symbol serves two
flows that are *different capabilities* (the change reads local, ripples across a boundary nobody listed).

## Red flags

- Fixing `scope:` from the direct caller only, when the graph has no edges saying who else reaches the surface.
- "This is the <X> validator/util" — an identity assumed from one call site, not confirmed against the graph.
- A discriminator that doesn't discriminate (a flag/param two unrelated flows share) used to scope the change.
- Touching a shared capability no spec describes, and planning anyway instead of bootstrapping its node + edges first.
- Altering or removing a shared default "wholesale" without reading the graph for who depends on it.
