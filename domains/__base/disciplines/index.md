---
human_revised: false
summary: Execution disciplines shipped by the base kernel, delivered eagerly and applied according to task triggers.
apps: [meta]
---

# Disciplines

Execution rules for *how* work is performed, distinct from the pillars that hold *what* the project is. Every installed discipline is delivered at context start; the trigger table in `domain.md` and each `applies-when:` determine which rules bind. `cumaru-first` is the priority application gate, and domains may extend the universal set with their own disciplines.
