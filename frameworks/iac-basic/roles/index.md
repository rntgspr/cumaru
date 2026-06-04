---
human_revised: false
generated: false
apps: [meta]
---

<!-- llm:roles -->
| Roles | Title | Scope | Status | Updated |
|-------|-------|-------|--------|---------|

_No custom roles yet._
<!-- /llm:roles -->

# Roles

Agent role definitions. Each describes responsibilities, restrictions, and the workflow expected of an LLM acting in that capacity.

## Available roles

- [lead.md](lead.md) — platform Lead: primary author of `.llm/`. Plans changes, maintains `topology/` and `runbooks/`, runs the archive flow, dispatches sub-agents.
- [dev.md](dev.md) — operator: applies a changeset's steps. Bounded write access inside the active plan only; never writes elsewhere in `.llm/`.

> This flavor has **no Ghost role**: infrastructure work is deliberate (plan → apply → verify), so the sdlc read-only ad-hoc role earns no place here.

## When to use

The user signals the role at the start of a session (e.g. "as Lead, plan the VPC migration" or "as Dev, apply T2"). The matching role file is loaded then. Outside that signal, role files are not read by default.
