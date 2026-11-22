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

The [native installer](rust.md#project-installation) and
[update](rust.md#native-project-update) record the detailed adapter publication
and refresh execution. Claude and Codex use skills directly and receive no
separate command files.

## Public surface

```text
cumaru install [agent <none|claude|codex|opencode>]
cumaru update agent <none|claude|codex|opencode> [--skills] [--apply|--clear]
cumaru update skills|commands|agent --clear
cumaru uninstall [-y|--yes]
cumaru hooks session|prompt|pretool
```

## Invariants

1. An omitted adapter argument selects the generic adapter. Adapter choice is
   never persisted in config.
2. Install and update use the explicit adapter argument, doctor discovers
   complete instruction sets, and uninstall removes every Cumaru-owned adapter
   surface without consulting config.
3. Bootstrap order is kernel, domain, the discipline index, every remaining
   installed discipline, then the root `cumaru tree .` projection where a
   SessionStart hook is supported. Hook-capable adapters also receive a
   per-prompt discipline digest through `UserPromptSubmit`.
4. Cumaru merges or removes only its owned adapter artifacts; adopter-owned
   instructions, hooks, skills, commands, and configuration remain intact.
5. Generic and OpenCode commands forward `$ARGUMENTS` to a required namesake
   skill. The command contains no workflow recipe, and source validation rejects
   command-without-skill packages before adapter writes. Claude and Codex
   reject a separate commands refresh; legacy Claude commands under
   `.claude/commands/cumaru/` remain Cumaru-owned for clear and uninstall.

## Adapter matrix

| Adapter target | Instructions | Skills | Commands | Hooks |
|---|---|---|---|---|
| generic (`none`) | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` | none |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | none | `.claude/settings.json` |
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

1. Validate the explicit adapter name, `.cumaru/config.yaml`, its domain and
   version agreement with main, and the installed discipline index.
2. Resolve the complete expected skills, supported commands, instructions, and
   canonical hook shape, and require unchanged original bytes for every
   native merge, before mutation. Malformed adopter JSON or instruction blocks
   fail before writes.

### Preview

1. `cumaru update agent <name>` reports add/replace/remove classifications for
   the target surfaces.
2. It creates no staging tree, lock, config write, or adapter mutation.

### Apply

1. Replace and prune only Cumaru-owned skill and command namespaces for the
   selected adapter.
2. Merge target instructions and supported hooks, preserving unrelated native
   entries; do not write adapter selection into config.
3. Run the native doctor inspection in quiet mode after mutation. An existing
   Git work tree must provide a clean committed recovery boundary; a non-Git
   project proceeds with a warning and no Git recovery point.

## Bootstrap order

1. Load `.cumaru/index.md` as the framework kernel.
2. Load `.cumaru/domain.md` for pillars, roles, and discipline triggers.
3. Load every regular `.cumaru/disciplines/*.md` body.
4. On Claude and Codex, SessionStart runs `cumaru hooks session`, which emits
   the required discipline index, every body, and the captured
   `cumaru tree .` projection as one payload within a 65536-byte budget;
   Codex entries set `additionalContextLimit: 0`. `UserPromptSubmit` runs
   `cumaru hooks prompt` before every prompt: the kernel `summary:` line, then
   the discipline digest. Their static instruction
   block imports kernel and domain only and keeps a fallback pointer to read
   every discipline when hook context is missing; generic and OpenCode have no
   supported hook injection and rely on ordered static instructions.

The universal `cumaru-role` skill repeats kernel, domain, discipline-index,
remaining-discipline, and root-candidate order before loading the requested
role. It changes context only and never writes active-role state.

The canonical hooks are exactly one Cumaru SessionStart entry, matcher
`startup|resume|clear|compact|fork`, type `command`, and `cumaru hooks session`
(the retired inline shell command is still recognized as owned),
plus exactly one matcherless `UserPromptSubmit` entry running
`cumaru hooks prompt` (the retired `cumaru hooks disciplines` command is still
recognized as owned and replaced), plus exactly one `PreToolUse` entry, matcher
`Bash`, running `cumaru hooks pretool`, which denies shell reads of `.cumaru/`
Markdown through `hookSpecificOutput.permissionDecision: "deny"` and points to
`cumaru map` and `cumaru get` ([`docs/agent-adapters.md`](../../docs/agent-adapters.md)). Other hook events and adopter entries survive
merges and uninstall.

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

| Artifact | Responsibility |
|---|---|
| [`../../src/adapter.rs`](../../src/adapter.rs) | Adapter paths, ordered instruction blocks, OpenCode entries, and owned hook merge/cleanup. |
| [`../../src/artifacts.rs`](../../src/artifacts.rs) | Owned skill/command namespaces, clear planning, exact JSON merges, and direct publication. |
| [`../../src/commands/install.rs`](../../src/commands/install.rs) | Project install and initial adapter materialization. |
| [`../../src/commands/update.rs`](../../src/commands/update.rs) | Preview, conditional Git recovery check, direct adapter mutation, clear, and postcheck. |
| [`../../src/commands/uninstall.rs`](../../src/commands/uninstall.rs) | Removal of every Cumaru-owned adapter artifact. |
| [`../../src/commands/hooks.rs`](../../src/commands/hooks.rs) | Session, prompt-digest, and pre-tool hook payloads. |
| [`../../src/commands/doctor.rs`](../../src/commands/doctor.rs) | Installed instruction-set discovery. |

## Principal methods

| Method | Contract |
|---|---|
| `adapter::markdown` | Merge canonical eager bootstrap content into a Markdown instruction file without replacing adopter content. |
| `adapter::opencode` | Merge exact kernel, domain, and discipline entries into `opencode.json` instructions. |
| `adapter::hooks` | Merge the canonical SessionStart, UserPromptSubmit, and PreToolUse entries, replacing recognized retired commands. |
| `adapter::clear` | Remove only exact Cumaru-owned instruction and hook entries. |
| `artifacts::clear_plan` | Plan removal of one owned surface for one adapter. |
| `doctor::instruction_issues` | Require at least one complete current instruction set. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/adapter.rs` unit tests | Exact owned clear, adopter-surface preservation, session/prompt/pre-tool hook merges, and hook adapters skipping static bodies. |
| [`../../tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Four stateless adapters through install/uninstall, offline clear, integration refresh, repeated refresh idempotence, and dirty-Git refusal. |
| `src/commands/doctor.rs` unit tests | Instruction-set health diagnostics. |

Remaining adapter matrices are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`architecture.md`](architecture.md)
- [`disciplines.md`](disciplines.md)
