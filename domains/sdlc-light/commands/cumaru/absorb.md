---
version: 1
description: Absorb a completed light-SDLC plan into durable specifications.
human_revised: false
summary: Framework command guidance for `/cumaru:absorb` workflow execution.
---

# `/cumaru:absorb`

Loads the `cumaru-absorb` skill and dispatches by the user's natural-language input. Covers plan close: validate delta-draft, absorb into specs, clean up plan files.

## Workflow

1. Load the installed `cumaru-absorb` skill and `.cumaru/roles/lead.md`.
2. Read `plans/index.md` and `specs/index.md`, then inspect candidates with `cumaru tree --pillars plans,specs --rows`.
3. Run the pre-checks (plan exists, delta-draft exists, all tasks done).
4. Execute Phase 1 (validate + absorb into specs) with user confirmation.
5. Execute Phase 2 (clean up plan files) with user confirmation.
6. Execute Phase 3 by running `cumaru tree plans --rows`, `cumaru tree specs --rows`, and `cumaru doctor`.
7. Run `cumaru doctor` at the end.

## Related

- [`cumaru-plan` -> `/cumaru:plan`](plan.md) — creates the plans and delta-drafts that this command closes.
- [`cumaru-doctor` -> `/cumaru:doctor`](../doctor.md) — for health checks.
