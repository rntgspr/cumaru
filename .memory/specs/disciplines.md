---
name: disciplines-specification
description: "V7 execution-discipline artifact, eager delivery, applicability, and mirror contract"
type: project
status: implemented
version: 7
---

# Disciplines specification

## Purpose

Define portable execution guidance that is loaded into every initial context
but applied only when its `applies-when:` condition matches. Disciplines govern
how work is performed without introducing a second session-bootstrap system.

## Public surface

```text
domains/<domain>/disciplines/*.md
.cumaru/disciplines/*.md
domains/<domain>/domain.md execution-discipline triggers
adapter instructions and SessionStart hook
```

## Invariants

1. Every installed discipline body is mandatory initial context;
   `strictness:` controls required consideration and `applies-when:` gates
   application, not loading.
2. Bootstrap order is kernel, domain, the discipline index, all remaining
   discipline bodies, then the root `cumaru tree .` projection where ordering
   is controllable.
3. A discipline is runtime-free prose. API-fetching or executable workflows
   belong in skills/scripts instead.
4. Universal disciplines are authored in `domains/__base/disciplines/` and
   mirrored byte-identically into every domain; domain-specific disciplines
   remain outside the universal drift set.
5. Every discipline except `disciplines/index.md` declares `strictness:` from
   `0/10` through `10/10`. Missing is effective `0/10` but invalid metadata.
   External adaptations also carry source URL and license metadata.
6. A discipline states a gate, a cycle only when the process needs one, and
   red flags. It must not compete with the Cumaru loading rule or force a
   session-start plugin.
7. Adapter reconciliation preserves adopter-owned instructions and unrelated
   hooks while maintaining one canonical Cumaru bootstrap sequence.
8. The universal strictness `10/10` `cumaru-first` discipline is the priority
   application gate when repository work has a relevant Cumaru surface; it
   does not bind unrelated work or create a separate delivery path.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/__base/disciplines/*.md` | framework | Canonical universal bodies and metadata. |
| Domain-only discipline files | domain author | Installed only with that domain. |
| `domain.md` trigger table | domain author | Applicability map; not the delivery mechanism. |
| `applies-when:` | discipline author | Runtime relevance condition. |
| `strictness:` | discipline author | Required-consideration priority and compliance strength when applicable. |
| Adapter instruction files | shared | Cumaru owns only its marked entries/block; adopter siblings survive. |
| SessionStart hook entry | framework | Exact merged entry for supported adapters. |

## Execution

### Preflight

1. Discover regular installed `.cumaru/disciplines/*.md` files from the
   selected domain and validate required strictness metadata before writes.
2. Validate active adapter state and its native instruction/hook structures.
3. Distribution installation verifies universal discipline mirror integrity,
   excluding declared domain-owned index content.

### Dry-run

1. Agent update describes adapter and managed-surface changes without writing.
2. Discipline applicability is evaluated by the agent after eager delivery;
   no command executes merely because a discipline is loaded.

### Apply

1. Install or refresh static instructions in kernel, domain, discipline-index,
   then remaining-discipline order where the adapter controls file order.
2. Claude receives explicit imports; Generic and Codex receive materialized
   managed Markdown; OpenCode receives ordered native instruction entries.
3. Claude and Codex receive one merged SessionStart entry that emits the
   discipline index, all remaining bodies, and then runs `cumaru tree .`;
   unsupported adapters rely on static delivery.
4. Doctor validates discipline metadata, mandatory loading, exact hook shape
   where supported, skills, commands, and adapter state.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Missing or invalid discipline strictness in a source domain | `1` | none before install/update writes |
| Missing or invalid installed discipline strictness | doctor error; effective `0/10` | none during doctor |
| Invalid adapter state | `1` | none before reconciliation |
| Missing, duplicate, reordered, or malformed managed instructions | doctor warning | none during doctor |
| Invalid required adapter state | doctor error | none during doctor |
| Failed adapter update | `1` | partial mutation possible after preflight; restore from Git history |

## Transaction and recovery

Discipline delivery changes made by update require the normal clean-Git
preflight and then mutate managed files directly. Install uses ordered writes.
Hook and instruction removals target only Cumaru-owned entries; unrelated
adopter configuration remains intact.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `domains/__base/disciplines/` | Canonical universal discipline sources. |
| `domains/*/domain.md` | Domain applicability triggers and execution context. |
| `src/agent_adapter.sh` | Static instruction and SessionStart merge/validation. |
| `src/common.sh` | Canonical managed Markdown bootstrap block. |
| `src/schema.sh` | Source-domain discipline metadata validation. |
| `src/cmd_install.sh` | Initial adapter and discipline delivery. |
| `src/cmd_update.sh` | Transactional adapter refresh and switching. |
| `src/cmd_doctor_checks.sh` | Installed discipline metadata and delivery acceptance. |

## Principal methods

| Method | Contract |
|---|---|
| `discipline_metadata_issues` | Report missing or out-of-range strictness, excluding the discipline index. |
| `schema_validate_disciplines` | Reject invalid source-domain discipline metadata before writes. |
| `_agent_wire_instructions` | Write canonical static discipline delivery for the selected adapter. |
| `_agent_refresh_instructions` | Repair Cumaru-owned entries while preserving project entries. |
| `_agent_wire_session_hook` | Merge exactly one canonical hook into supported adapter JSON. |
| `_agent_session_hook_valid` | Validate matcher, nesting, type, command, and uniqueness. |
| `_agent_opencode_instructions_valid` | Require one ordered kernel/domain/discipline sequence. |
| `_agent_remove_adapter` | Remove only Cumaru-owned native artifacts. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/integration/agent_adapters_spec.sh` | Ordered delivery, hook shape, repair, switching, and uninstall symmetry. |
| `tests/spec/integration/schema_spec.sh` | Required closed strictness metadata at the source-domain boundary. |
| `tests/spec/cli/doctor_spec.sh` | Missing strictness, drifted adapter, and mandatory-discipline diagnostics. |
| `tests/spec/update/transaction_spec.sh` | Clean-Git preflight and transient-debris boundaries. |
| `tests/spec/contracts/documented_contracts_spec.sh` | Universal artifact and public bootstrap contract. |

## Verification

```bash
shellspec tests/spec/integration/agent_adapters_spec.sh tests/spec/cli/doctor_spec.sh
bash tests/run.sh
```

## References

- [`../../src/agent_adapter.sh`](../../src/agent_adapter.sh)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`agent-adapters.md`](agent-adapters.md)
- [`architecture.md`](architecture.md)
- [`../../skills/skill-to-discipline/SKILL.md`](../../skills/skill-to-discipline/SKILL.md)
