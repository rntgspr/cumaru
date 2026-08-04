---
name: remove-adopter-backups-and-agent-led-config-reconciliation
description: Remove persistent adopter backups and move config reconciliation to agent judgment
status: completed
priority: high
---

# Issue 042: Remove persistent adopter backups and make config reconciliation agent-led

Cumaru currently leaves persistent backup artifacts such as
`.cumaru/config.yaml.backup` and recommends `.cumaru.bak` recovery copies.
Those files accumulate as adopter-visible garbage. The `config` update target
also mutates adopter-owned choices deterministically, even though resolving
missing values and schema drift requires agent judgment.

## Risk

- Framework commands leave stale backup files that obscure the adopter tree.
- Mechanical config reconciliation can invent, drop, or normalize adopter-owned
  choices without the agent inspecting their project context.
- Removing transaction recovery snapshots accidentally would weaken rollback
  guarantees for a failed apply.

## Required invariant

No successful Cumaru command leaves a persistent backup of adopter-owned
content. The CLI exposes schema/config drift for the agent to adjudicate;
only the agent edits `config.yaml`. Temporary transaction snapshots remain
private implementation details and are removed after success or rollback.

## Work

1. Replace `cumaru update config --apply` with a read-only config/schema drift
   report that provides the agent the relevant schema, local values, and
   required adjudications without changing `config.yaml`.
2. Make `cumaru doctor` surface config drift and validation diagnostics clearly,
   directing the agent to resolve them rather than mechanically reconciling.
3. Remove persistent `config.yaml.backup` creation, publication, validation, and
   cleanup guidance from update and migration paths.
4. Remove persistent adopter backup creation from every mutation command while
   retaining only temporary staging/recovery state required for atomic rollback.
5. Update migration guidance so Git or explicit user-managed recovery remains
   outside normal command behavior.
6. Synchronize universal artifacts and remove stale backup references from
   docs, skills, commands, and regression coverage.

## Tests

- Every successful mutation leaves no `.bak`, `*.backup`, or equivalent
  persistent Cumaru backup artifact in the adopter project.
- `cumaru update config` reports schema drift without changing `config.yaml`.
- `cumaru doctor` reports invalid values and schema drift without changing
  `config.yaml`, including the schema context needed for agent resolution.
- A forced update publication failure still restores managed live surfaces and
  leaves no lock, staging, or recovery debris.
- Full update preserves `config.yaml` byte-for-byte on dry-run and apply.

## References

- `src/cmd_update.sh`
- `src/cmd_migrate.sh`
- `tests/spec/update/content_spec.sh`
- `tests/spec/update/transaction_spec.sh`
- `docs/update.md`
- `domains/__base/skills/cumaru-update/SKILL.md`
