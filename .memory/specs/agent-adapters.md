---
name: agent-adapters-specification
description: "Current v7 contract for selecting, installing, validating, and switching Cumaru agent adapters."
type: project
status: implemented
version: 7
---

# Agent adapters specification

## Purpose

Agent adapters expose one installed Cumaru domain through each supported
client's native instructions, skills, commands, and session-hook surfaces.
The `agent` value in `.cumaru/config.yaml` selects exactly one active adapter.

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>]
cumaru update agent <none|claude|codex|opencode> [--apply]
cumaru uninstall [--yes]
.cumaru/config.yaml: agent
```

## Invariants

1. Missing or null `agent` selects the generic adapter; CLI `none` serializes
   to YAML null.
2. Install, update, doctor, and uninstall derive the active integration from
   the same validated config value and never guess after invalid explicit state.
3. Bootstrap order is kernel, domain, the discipline index, every remaining
   installed discipline, then the root `cumaru tree .` projection where a
   SessionStart hook is supported.
4. Cumaru merges or removes only its owned adapter artifacts; adopter-owned
   instructions, hooks, skills, commands, and configuration remain intact.
5. Claude and OpenCode commands forward `$ARGUMENTS` to a required namesake
   skill. The command contains no workflow recipe, and source validation rejects
   command-without-skill packages before adapter writes.

## Adapter matrix

| Config value | Instructions | Skills | Commands | Session hook |
|---|---|---|---|---|
| `null` | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` | none |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | `.claude/commands/cumaru/` | `.claude/settings.json` |
| `codex` | `AGENTS.md` | `.agents/skills/cumaru-*` | none | `.codex/hooks.json` |
| `opencode` | `opencode.json.instructions` | `.agents/skills/cumaru-*` | `.opencode/commands/cumaru/` | none |

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `.cumaru/config.yaml: agent` | adopter | Valid local selection; written last during install or switching. |
| `.cumaru/index.md`, `.cumaru/domain.md` | framework | Eager bootstrap instructions in this order. |
| `.cumaru/disciplines/*.md` | framework/domain | Every installed body loads eagerly; `applies-when` gates use, not loading. |
| Marked instruction blocks and exact OpenCode entries | framework | Deterministically installed, refreshed, and removed. |
| Native files outside Cumaru-owned entries | adopter | Preserved during merge, switch, update, and uninstall. |

## Execution

### Preflight

1. Validate `.cumaru/config.yaml`, its domain/version agreement, the requested
   adapter name, source domain, and required adapter paths.
2. Resolve the complete expected skills, supported commands, instructions, and
   canonical hook shape before mutation.

### Dry-run

1. `cumaru update agent <name>` reports current and requested surfaces.
2. It creates no staging tree, lock, config write, or adapter mutation.

### Apply

1. Stage removal of only the old adapter's Cumaru-owned footprint.
2. Install target instructions, skills, commands, and SessionStart hook where
   supported; write the new `agent` value only after artifacts exist.
3. Run `cumaru doctor --quiet` after mutation. A clean Git work tree before
   mutation is the recovery boundary.

## Bootstrap order

1. Load `.cumaru/index.md` as the framework kernel.
2. Load `.cumaru/domain.md` for pillars, roles, and discipline triggers.
3. Load every regular `.cumaru/disciplines/*.md` body.
4. On Claude and Codex, SessionStart re-emits discipline bodies and runs
   `cumaru tree . 2>/dev/null || true`; generic and OpenCode have no supported
   session-start injection and rely on ordered static instructions.

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

Agent apply uses the project-local update boundary: clean-Git preflight, direct
managed-surface mutation, and post-mutation doctor. Cumaru creates no
project-local lock, staging, private backup, or recovery directory; this is not
one filesystem-wide atomic operation.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../src/agent_adapter.sh`](../../src/agent_adapter.sh) | Adapter paths, instruction/hook merge, validation, and cleanup. |
| [`../../src/cmd_install.sh`](../../src/cmd_install.sh) | Project install and initial adapter materialization. |
| [`../../src/cmd_update.sh`](../../src/cmd_update.sh) | Dry-run, clean-Git preflight, direct adapter mutation, and post-check. |
| [`../../src/cmd_uninstall.sh`](../../src/cmd_uninstall.sh) | Scoped removal of active Cumaru artifacts. |
| [`../../src/cmd_doctor.sh`](../../src/cmd_doctor.sh) | Active adapter acceptance check. |

## Principal methods

| Method | Contract |
|---|---|
| `_agent_current`, `_agent_set` | Read the validated selection and persist it after target artifacts exist. |
| `_agent_wire_instructions`, `_agent_refresh_instructions` | Merge canonical eager bootstrap content without replacing adopter content. |
| `_agent_wire_session_hook` | Merge one canonical Claude/Codex SessionStart entry. |
| `_agent_remove_adapter` | Remove only artifacts owned by the prior adapter. |
| `_agent_opencode_instructions_valid` | Require one kernel, domain, and discipline entry in relative order. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/integration/agent_adapters_spec.sh`](../../tests/spec/integration/agent_adapters_spec.sh) | Install/switch/uninstall matrix, instruction preservation, hook shape, repair, and config ordering. |
| [`../../tests/spec/cli/doctor_spec.sh`](../../tests/spec/cli/doctor_spec.sh) | Adapter health diagnostics through doctor. |
| [`../../tests/spec/update/transaction_spec.sh`](../../tests/spec/update/transaction_spec.sh) | Clean-Git preflight, direct mutation, and transient-debris checks. |

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
