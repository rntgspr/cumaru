---
human_revised: false
name: dry
applies-when: writing or reviewing any code, module, config, or definition where the same knowledge, rule, or decision risks being expressed in more than one place
strictness: 8/10
summary: When the same knowledge, rule, constant, decision, or contract risks living in more than one place, give it one authoritative home and reference it. Apply DRY to knowledge, not to similar-looking text; ask whether two sites encode the same knowledge or merely look alike. Keep coincidental duplication only with a one-line note on why it differs, because a forced abstraction bent with flags to serve unrelated callers is worse than the copy. Watch for hand-synced paths and bugs fixed in only one copy.
---

# Don't repeat yourself (DRY)

**Gate:** every piece of knowledge — a rule, a constant, a decision, a contract — has ONE
authoritative home. Before duplicating, ask whether the two sites encode the *same knowledge* or
merely *look alike*. Apply DRY to knowledge, not to characters on screen.

Strictness 8/10: deduplicate by default. The rare, legitimate exception is **coincidental
duplication** — two fragments that resemble each other today but answer to different reasons and
would be wrongly coupled by a shared abstraction. When you keep such duplication, say so
explicitly (a one-line note on why these are not the same knowledge). A forced abstraction that
couples unrelated things is worse than the duplication it removes.

## Red flags

- The same constant, rule, or business decision copy-pasted across files — change one, must change all.
- Two code paths kept in sync by hand, with nothing enforcing it.
- A bug fixed in one place but still alive in its copies.
- The inverse — premature DRY: one abstraction bent with flags and branches to serve callers that
  were never the same knowledge. Prefer the duplication until the shared rule is proven.
