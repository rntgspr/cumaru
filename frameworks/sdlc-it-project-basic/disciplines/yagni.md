---
human_revised: false
name: yagni
applies-when: deciding what to build now — tempted to add capability, generality, or structure beyond what a present, stated requirement demands
strictness: 8/10
---

# You aren't gonna need it (YAGNI)

**Gate:** build only what a present, stated requirement demands — an acceptance criterion, the
plan's `scope:`, a real bug. Do not build for an imagined future. Speculative generality is a cost
paid now against a benefit that usually never arrives, and it locks in guesses made with the least
information you will ever have.

Strictness 8/10: when the requirement is not on the table today, the answer is no. The narrow
exception is a cheap, reversible seam a *known, near-term* requirement clearly needs — and even
then, prefer adding it when that requirement actually lands.

## Red flags

- Parameters, hooks, or abstractions with a single caller and an imagined second one.
- "To be safe" / "for future use" / "in case we ever…" with no current requirement behind it.
- Configurable behavior where only one mode is ever exercised.
- Dead branches, unused options, or generality no acceptance criterion asks for.
- Building a framework when the task needs one concrete case.
