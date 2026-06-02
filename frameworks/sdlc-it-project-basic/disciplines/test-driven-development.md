---
human_revised: false
name: test-driven-development
applies-when: implementing any feature or bugfix, before writing implementation code
source:
  plugin: obra/superpowers
  skill: test-driven-development
  url: https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md
  license: MIT
---

# Test-driven development

**Gate:** no production code without a failing test you watched fail first. If you didn't see it
fail, you don't know it tests the right thing.

## Cycle

1. **Red** — write the smallest test for the next behavior.
2. **Verify red** — run it; confirm it fails, and for the *expected* reason (not a typo or a
   missing import). Mandatory — a test you never saw fail proves nothing.
3. **Green** — write the minimal code to pass. No more than the test demands.
4. **Verify green** — run it; confirm it passes (pair with the `verification` discipline).
5. **Refactor** — clean up with the test as the safety net; keep it green.

If production code already exists without its test, delete it and restart the cycle — don't
retrofit a test onto code you wrote first.

## Red flags

- Writing implementation before the test.
- "I'll add the test after it works."
- Skipping verify-red ("obviously it fails").
- A test that passes the first time you run it — it isn't exercising the new behavior.
