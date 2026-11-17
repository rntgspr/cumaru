---
version: 1
description: Start local Cumaru context and assume a domain role. Validates the requested role from `.cumaru/roles/` before loading its instructions.
allowed-tools: Bash, Read
argument-hint: <role>
summary: Start local Cumaru context and assume a validated domain role.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-role` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
