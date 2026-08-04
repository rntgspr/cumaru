---
name: agent-adapters-specification
description: "Current contract for selecting, installing, validating, and switching Cumaru agent adapters."
type: project
status: implemented
version: 9
---

# Agent adapters specification

## Purpose

Agent adapters expose one installed Cumaru domain through each supported
client's native instructions, skills, commands, and session-hook surfaces.
They are explicit stateless command targets and may coexist; config does not
select or persist an active adapter.

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>]
cumaru update agent <none|claude|codex|opencode> [--apply]
cumaru uninstall [--yes]
```

## Invariants

1. An omitted adapter argument selects the generic adapter. Adapter choice is
   never persisted in config.
2. Install and update use the explicit adapter argument, doctor discovers
   complete instruction sets, and uninstall removes every Cumaru-owned adapter
   surface without consulting config.
3. Bootstrap order is kernel, domain, the discipline index, every remaining
   installed discipline, then the root `cumaru tree .` projection where a
   SessionStart hook is supported.
4. Cumaru merges or removes only its owned adapter artifacts; adopter-owned
   instructions, hooks, skills, commands, and configuration remain intact.
5. Claude and OpenCode commands forward `$ARGUMENTS` to a required namesake
   skill. The command contains no workflow recipe, and source validation rejects
   command-without-skill packages before adapter writes.

## Adapter matrix

| Adapter target | Instructions | Skills | Commands | Session hook |
|---|---|---|---|---|
| generic (`none`) | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` | none |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | `.claude/commands/cumaru/` | `.claude/settings.json` |
| `codex` | `AGENTS.md` | `.agents/skills/cumaru-*` | none | `.codex/hooks.json` |
| `opencode` | `opencode.json.instructions` | `.agents/skills/cumaru-*` | `.opencode/commands/cumaru/` | none |

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| Adapter command argument | user | Explicit target for install, refresh, or scoped clear; never persisted in config. |
| `.cumaru/index.md`, `.cumaru/domain.md` | framework | Eager bootstrap instructions in this order. |
| `.cumaru/disciplines/*.md` | framework/domain | Every installed body loads eagerly; `applies-when` gates use, not loading. |
| Marked instruction blocks and exact OpenCode entries | framework | Deterministically installed, refreshed, and removed. |
| Native files outside Cumaru-owned entries | adopter | Preserved during merge, switch, update, and uninstall. |

## Execution

### Preflight

1. Validate `.cumaru/config.yaml`, its domain/version agreement, the explicit
   adapter name, source domain, and required adapter paths.
2. Resolve the complete expected skills, supported commands, instructions, and
   canonical hook shape before mutation.

### Dry-run

1. `cumaru update agent <name>` reports current and requested surfaces.
2. It creates no staging tree, lock, config write, or adapter mutation.

### Apply

1. Remove only the selected adapter's retired Cumaru-owned footprint.
2. Install target instructions, skills, commands, and SessionStart hook where
   supported; do not write adapter selection into config.
3. Run `cumaru doctor --quiet` after mutation. An existing Git work tree must
   provide a clean committed recovery boundary; a non-Git project proceeds with
   a warning and no Git recovery point.

## Bootstrap order

1. Load `.cumaru/index.md` as the framework kernel.
2. Load `.cumaru/domain.md` for pillars, roles, and discipline triggers.
3. Load every regular `.cumaru/disciplines/*.md` body.
4. On Claude and Codex, SessionStart re-emits discipline bodies and runs
   `cumaru tree . 2>/dev/null || true`; generic and OpenCode have no supported
   session-start injection and rely on ordered static instructions.

The universal `cumaru-role` skill repeats kernel, domain, discipline-index,
remaining-discipline, and root-candidate order before loading the requested
role. It changes context only and never writes active-role state.

The canonical hook has exactly one Cumaru entry, matcher
`startup|resume|clear|compact|fork`, type `command`, and the canonical command.
Other hook events and SessionStart entries survive merges.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Unknown adapter or malformed invocation | `2` | none |
| Invalid config/source or adapter state | `1` | none |
| Post-mutation doctor rejection | `1` | mutation remains for Git review/restoration |
| Write failure | `1` | partial mutation possible; restore from Git history |

## Transaction and recovery

Agent apply uses the project-local update boundary: conditional Git recovery
check, direct managed-surface mutation, and post-mutation doctor. Cumaru creates
no project-local lock, staging, private backup, or recovery directory; this is
not one filesystem-wide atomic operation.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/agent_adapter.sh`](../../src/agent_adapter.sh) | Adapter paths, instruction/hook merge, validation, and cleanup. |
| [`../../src/cmd_install.sh`](../../src/cmd_install.sh) | Project install and initial adapter materialization. |
| [`../../src/cmd_update.sh`](../../src/cmd_update.sh) | Dry-run, conditional Git recovery check, direct adapter mutation, and post-check. |
| [`../../src/cmd_uninstall.sh`](../../src/cmd_uninstall.sh) | Scoped removal of active Cumaru artifacts. |
| [`../../src/cmd_doctor.sh`](../../src/cmd_doctor.sh) | Installed instruction-set discovery. |

## Principal methods

| Method | Contract |
|---|---|
| `_agent_wire_instructions`, `_agent_refresh_instructions` | Merge canonical eager bootstrap content without replacing adopter content. |
| `_agent_wire_session_hook` | Merge one canonical Claude/Codex SessionStart entry. |
| `_agent_remove_adapter` | Remove only artifacts owned by the prior adapter. |
| `_agent_opencode_instructions_valid` | Require one kernel, domain, and discipline entry in relative order. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Install/switch/uninstall matrix, instruction preservation, hook shape, repair, and config ordering. |
| [`../../tests/spec/cli/doctor_spec.sh`](../../tests/spec/cli/doctor_spec.sh) | Adapter health diagnostics through doctor. |
| [`../../tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Non-Git mutation, dirty-Git rejection, direct mutation, and transient-debris checks. |

## Verification

```bash
shellspec tests/spec/integration/agent_adapters_spec.sh
bash tests/run.sh
```

## References

- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`architecture.md`](architecture.md)
- [`disciplines.md`](disciplines.md)
