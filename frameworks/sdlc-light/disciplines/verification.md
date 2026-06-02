---
human_revised: false
name: verification
applies-when: about to claim work is complete, fixed, or passing; before a commit, PR, or handoff
source:
  plugin: obra/superpowers
  skill: verification-before-completion
  url: https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md
  license: MIT
---

# Verification before completion

**Gate:** never claim done / passing / fixed without running the proving command in THIS message
and reading its actual output. An unverified claim is a guess stated as fact.

## Cycle

1. **Identify** the command that proves the claim — the test, build, lint, or diff.
2. **Run it now**, in the same message you intend to claim completion.
3. **Read** the real output. Do not infer success from "it should".
4. **Then claim**, citing the evidence. For a regression fix, prove both directions: revert the
   fix → it must fail; restore → it must pass.

## Red flags

- "should work", "looks correct", "this fixes it" — written before the command ran.
- "Done!" / "Perfect!" with no fresh command output in the same message.
- Reusing an earlier run's output as if it were current after further edits.
