---
name: index-cli-reference-expansion
description: Expand kernel index.md CLI map to a complete command reference so LLMs know the full cumaru surface before context bootstrap
status: open
priority: high
---

# Issue 033: Expand kernel index.md CLI reference

The current kernel `domains/__base/index.md` (lines 68-97) lists only 6 navigation/mutation commands in a shallow table. The full CLI surface (`install`, `update`, `migrate`, `upgrade`, `help`, `domains`, `tag`, `coverage`, `intake`, `tree`, `flow`, `doctor`) is not documented there.

## Required invariant

- The kernel `index.md` carries a **complete, domain-neutral CLI reference** (table or structured list) so any LLM loading `.cumaru/index.md` as its first eager import knows the full command surface.
- The reference must stay domain-neutral (no pillar-specific examples that would lie in `vault-memory` or `iac-basic`).
- Every domain's `index.md` is byte-identical to `__base`; the drift check must stay green after the edit.

## Work

1. Replace the current 6-row table in `domains/__base/index.md` with a complete reference covering all `cumaru <subcommand>` entry points, grouped by purpose (navigation, mutation, configuration, lifecycle, introspection).
2. Keep it a **map, not a manual** — each row says what the command is for and defers to `cumaru <subcommand> --help` for the contract.
3. Use `<pillar>/<entity>` placeholders only; never concrete pillar names.
4. Propagate verbatim to all 6 domains (`__base`, `sdlc-full`, `sdlc-light`, `iac-basic`, `qa-basic`, `vault-memory`) — the kernel drift check must pass.
5. Update `docs/architecture.md` if it references the old table.

## Tests

- `diff domains/__base/index.md domains/sdlc-full/index.md` → no diff (and same for other 4 domains).
- `bash tests/run.sh` passes (doctor check 7 validates canonical kernel drift).
- Grep confirms all 12+ subcommands appear in the new table.

## References

- `domains/__base/index.md` (lines 68-97)
- `cumaru` (CLI entry) for the canonical subcommand list
- `src/cmd_help.sh` for dynamic help generation
- `.memory/specs/architecture.md` (kernel byte-identity requirement)
