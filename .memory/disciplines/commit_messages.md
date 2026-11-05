---
name: commit-message-style
description: "Write commits only on explicit request, as one-line gitmoji messages under 120 chars"
metadata:
  type: feedback
---

Commit message rule for this repo:

- Must follow gitmoji style.
- Must be exactly one line.
- Must be shorter than 120 characters, counting from the emoji.
- Any emoji is acceptable.

This applies only when the user explicitly asks for a commit, since git mutations remain opt-in.
