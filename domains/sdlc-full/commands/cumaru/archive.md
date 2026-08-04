---
version: 1
description: Close a plan — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into `specs/`, and clean up. Drives the `cumaru-archive` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <PLAN-ID>
summary: Close a plan — move `plans/<KEY>/` into `archive/<KEY>/`, absorb its delta into `specs/`, and clean up. Drives the `cumaru-archive` skill.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-archive` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
