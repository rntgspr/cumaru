---
human_revised: false
name: solid
applies-when: designing or refactoring the structure of code — classes, modules, interfaces, and their dependencies — where responsibilities, extension, or coupling are in play
strictness: 7/10 # SRP and Open/Closed held at 9/10 — see body
summary: Framework guidance for SOLID (object / module design) and its required workflow.
---

# SOLID (object / module design)

**Gate:** SOLID is design guidance applied *per scenario*, not a checklist to satisfy on every unit.
Overall strictness 7/10 — reach for a principle when the situation it addresses is actually present,
and don't gold-plate when it isn't. **Two principles are held hard at 9/10**, because their cost of
violation compounds over time:

- **S — Single Responsibility (9/10):** a unit has one reason to change. When two unrelated forces
  edit the same module, split it. Near-mandatory.
- **O — Open/Closed (9/10):** extend behavior by adding code, not by editing stable, well-tested
  code. When a change means reopening a unit that already works to bolt on a variant, prefer an
  extension seam. Near-mandatory.

The other three are 7/10 — apply when the scenario calls for them, skip when it doesn't:

- **L — Liskov Substitution:** a subtype must honor its base type's contract; weigh it when polymorphism is actually in use.
- **I — Interface Segregation:** don't force a client to depend on methods it doesn't use; weigh it when an interface grows fat.
- **D — Dependency Inversion:** depend on abstractions at real seams (I/O, external services); don't invert dependencies that have no reason to vary.

## Red flags

- (S, hard) A module that changes for unrelated reasons — a "manager" / "utils" grab-bag.
- (O, hard) Editing a stable, tested unit to add a variant instead of extending it.
- (L) A subtype that throws on, or silently breaks, a method its base promised.
- (I) A fat interface whose implementers stub out half the methods.
- (D) High-level policy hard-wired to a concrete detail at a seam that genuinely varies.
- Applying all five everywhere — abstraction for its own sake is a `kiss` / `yagni` violation.
