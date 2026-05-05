---
human_revised: false
generated: false
apps: [meta]
---

# Roles

Agent role definitions. Each role describes responsibilities, restrictions, and the workflow expected of an LLM acting in that capacity.

## Available roles

- [lead.md](lead.md) — primary author of `.llm/`. Plans tickets, maintains specs, runs the archive flow on close, dispatches sub-agents within a plan, maintains `exploring/`.
- [dev.md](dev.md) — implements tasks. Bounded write access inside the active plan only. Never writes elsewhere in `.llm/`.
- [ghost.md](ghost.md) — IDE-pair agent for ad-hoc help. Read-only by default; never writes inside `.llm/`.

## When to use

The user signals the role at the start of a session (e.g., "as Lead, plan JET-X" or "as Dev, implement T2"). The matching role file is loaded then. Outside that signal, role files are not read by default.
