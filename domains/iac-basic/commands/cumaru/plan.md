---
version: 1
description: Bootstrap, grow, or advance a changeset in `.cumaru/plans/` — new changeset (tracker-backed or slug-based, with blast radius / rollback / promotion path), add apply step, write handoff, draft topology delta, ready-for-archive. Drives the `cumaru-plan` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <plan-id-or-action>
summary: Bootstrap, grow, or advance a changeset in `.cumaru/plans/` — new changeset (tracker-backed or slug-based, with blast radius / rollback / promotion path), add apply step, write handoff, draft topology delta, ready-for-archive. Drives the `cumaru-plan` skill.
---

Arguments: `$ARGUMENTS`

Load the installed `cumaru-plan` skill and follow its workflow using the
arguments above. The skill is the canonical source; do not duplicate or bypass
its recipe here.
