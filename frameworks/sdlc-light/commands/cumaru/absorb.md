# `/cumaru:absorb`

Loads the `cumaru-absorb` skill and dispatches by the user's natural-language input. Covers plan close: validate delta-draft, absorb into specs, clean up plan files.

## Workflow

1. Load `.cumaru/skills/cumaru-absorb/SKILL.md` and the `roles/lead.md`.
2. Load `plans/index.md` and `specs/index.md`.
3. Run the pre-checks (plan exists, delta-draft exists, all tasks done).
4. Execute Phase 1 (validate + absorb into specs) with user confirmation.
5. Execute Phase 2 (clean up plan files) with user confirmation.
6. Execute Phase 3 (re-emit indexes).
7. Run `cumaru doctor` at the end.

## Related

- [`cumaru-plan` -> `/cumaru:plan`](plan.md) — creates the plans and delta-drafts that this command closes.
- [`cumaru-doctor` -> `/cumaru:doctor`](../doctor.md) — for health checks.
