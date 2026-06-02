---
human_revised: false
name: kiss
applies-when: choosing how to implement anything — a function, module, abstraction, dependency, or config — whenever a simpler option would also solve the stated problem
strictness: 9/10
---

# Keep it simple (KISS)

**Gate:** ship the simplest thing that fully solves the *stated* problem. Every added part — a
layer, an abstraction, an indirection, a dependency, a config knob — must justify itself against a
real, present requirement before it earns its place. The burden of proof is on complexity, not on
simplicity.

Strictness 9/10 — a hard hand. If a plain function, a flat structure, or an inline value would do,
that is the answer. Reach for machinery only when the problem genuinely has the shape that machinery
solves, and be able to name that shape.

## Red flags

- "We might need it flexible later" — that is the `yagni` discipline's call, and the answer is no until later arrives.
- A design pattern, framework, or layer of indirection where a direct call would do.
- Cleverness that needs a second read; a newcomer should follow it on the first pass.
- Configuration, flags, or extension points nobody asked for, added "just in case".
- More moving parts, states, or branches than the problem itself has.
