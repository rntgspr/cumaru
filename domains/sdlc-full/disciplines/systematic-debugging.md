---
human_revised: false
name: systematic-debugging
applies-when: a bug, test failure, or unexpected behavior surfaces; before proposing or writing a fix
source:
  plugin: obra/superpowers
  skill: systematic-debugging
  url: https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md
  license: MIT
summary: Framework guidance for Systematic debugging and its required workflow.
---

# Systematic debugging

**Gate:** no fix before the root cause is found. A patch on the symptom is a failure, not a fix.

## Cycle

1. **Root cause** — reproduce reliably first, then trace backward from the symptom to its origin.
   No theorizing on a bug you can't reproduce.
2. **Pattern** — ask whether this is one instance of a broader class. Find every site, not just
   the one that bit you.
3. **Hypothesis** — one hypothesis and one minimal change at a time. State what you expect to
   change before you change it.
4. **Fix** — write a failing test first, then the minimal fix, then prove it (pair with the
   `verification` discipline). Resist scope creep into unrelated cleanup.

**Three-fix rule:** after three failed fixes, STOP. The design is the problem, not the next patch —
question the architecture before attempting a fourth.

## Red flags

- Editing code before the bug is reproduced.
- Several simultaneous changes ("one of these will fix it").
- "Just add a try/catch" or "add a retry" without knowing why it fails.
- A fix that makes the symptom disappear but you can't say why.
