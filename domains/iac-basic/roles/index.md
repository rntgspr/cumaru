---
human_revised: false
apps: [meta]
summary: Framework guidance for Roles and its required workflow.
---


# Roles

Agent role definitions. Each describes responsibilities, restrictions, and the workflow expected of an LLM acting in that capacity.

> This domain has **no Ghost role**: infrastructure work is deliberate (plan → apply → verify), so the sdlc read-only ad-hoc role earns no place here.

## When to use

The user signals the role at the start of a session (e.g. "as Lead, plan the VPC migration" or "as Dev, apply T2"). The matching role file is loaded then. Outside that signal, role files are not read by default.
