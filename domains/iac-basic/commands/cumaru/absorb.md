---
version: 1
description: Close a changeset — finalize `plans/<KEY>/delta-draft.md`, absorb its claims into `topology/`, and clean up. Drives the `cumaru-absorb` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
summary: Close a changeset — finalize its delta, absorb its claims into `topology/`, and clean up. Drives the `cumaru-absorb` skill.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-absorb` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
