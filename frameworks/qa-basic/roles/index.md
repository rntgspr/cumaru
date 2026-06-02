---
human_revised: false
generated: false
apps: [meta]
---

<!-- cumaru:roles -->
| Link | Description |
|------|-------------|
| [lead](lead.md) | QA Lead: primary author of `.cumaru/`. Plans campaigns, maintains `coverage/` and `standards/`, runs the archive flow, dispatches sub-agents. |
| [dev](dev.md) | Tester: authors/automates a campaign's cases. Bounded write access inside the active plan only; never writes elsewhere in `.cumaru/`. |
<!-- /cumaru:roles -->

# Roles

Agent role definitions. Each describes responsibilities, restrictions, and the workflow expected of an LLM acting in that capacity.

> This domain has **no Ghost role**: QA work is deliberate (plan → author cases → run → record), so the sdlc read-only ad-hoc role earns no place here.

## When to use

The user signals the role at the start of a session (e.g. "as Lead, plan coverage for checkout" or "as Dev, automate T2"). The matching role file is loaded then. Outside that signal, role files are not read by default.
