---
human_revised: false
name: receiving-code-review
applies-when: acting on code-review feedback, especially when a comment seems unclear or technically questionable
source:
  plugin: obra/superpowers
  skill: receiving-code-review
  url: https://github.com/obra/superpowers/blob/main/skills/receiving-code-review/SKILL.md
  license: MIT
---

# Receiving code review

**Gate:** verify each review point against the code before acting on it. Technical correctness
over social comfort — never answer with performative agreement.

## Cycle

1. **Read** the whole review before touching anything.
2. **Verify** each point against the actual code — is it correct? Reviewers are sometimes wrong.
3. **Clarify** every unclear item up front; don't guess at intent mid-fix.
4. **Evaluate** — push back with technical reasoning where you disagree; apply YAGNI to
   "wouldn't it be nice" suggestions instead of accepting them by default.
5. **Implement** the agreed changes one at a time, proving each (pair with the `verification`
   discipline).

## Red flags

- "You're absolutely right!" / thanking the reviewer instead of stating the fix.
- Implementing a suggestion you haven't checked against the code.
- Folding unrelated changes from one review into a single untested lump.
- Accepting a "more professional" rewrite that adds generality nothing uses yet.
