---
name: disciplines-specification
description: "Current execution-discipline artifact, eager delivery, applicability, and mirror contract"
type: project
status: implemented
version: 9
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
   remain outside the universal drift set. `cumaru-first` is the only
   universal discipline. `code-comments` is domain-scoped: it ships only in
   the code-oriented domains `sdlc-full`, `sdlc-light`, `iac-basic`, and
   `qa-basic`, whose copies stay byte-identical (contract-tested against
   `sdlc-full`); `__base`, `design-as-code`, `focus`, and `vault-memory` do not
   ship it. `separation-of-concerns` ships only in `sdlc-full` and `sdlc-light`,
   with byte-identical bodies: cohesive ownership, explicit boundaries, and
   deliberate dependency direction without speculative layers. Its testing
   guidance references the existing TDD and verification disciplines.
5. Every discipline except `disciplines/index.md` declares `strictness:` from
   `0/10` through `10/10`. Missing is effective `0/10` but invalid metadata.
   External adaptations also carry source URL and license metadata.
6. A discipline's `summary:` is its per-prompt digest line: a short trigger
   plus imperative action, not a topic description, targeted near 256 code
   points. The kernel `summary:` in `.cumaru/index.md` targets near 512 code
   points and leads the per-prompt payload. Native validation checks only the
   shared summary contract (32-512 code points); meaning is reviewed by
   humans. `cumaru hooks prompt` emits the kernel line, then the digest, which
   lists `cumaru-first` first, then descending strictness, then C path order,
   all within a 32768-byte budget, and fails atomically with one diagnostic
   line instead of partial context.
7. A discipline states a gate, a cycle only when the process needs one, and
   red flags. It must not compete with the Cumaru loading rule or force a
   session-start plugin.
8. Adapter reconciliation preserves adopter-owned instructions and unrelated
   hooks while maintaining one canonical Cumaru bootstrap sequence.
9. The universal strictness `10/10` `cumaru-first` discipline is the priority
   application gate when repository work has a relevant Cumaru surface; it
   does not bind unrelated work or create a separate delivery path. It is
   also the compact agent manual for all 16 native command families: bounded
   discovery through `tree`, `context`, and `map`; explicit, user-approved
   `model pull` downloads and `model release` deactivation without deleting cached files; and the mutation distinctions of install, update,
   uninstall, and upgrade. It points to `cumaru help <command>` for flags
   instead of duplicating command documentation, and grants no new authority.
10. Discipline guidance is bounded by task ownership and observed evidence.
   Existing authorization covers routine in-scope judgments; unresolved scope
   or ownership, destructive cleanup, and genuinely new authority still stop
   for user input.
11. The SDLC Full and Light `engineering` disciplines remain byte-identical.
    Their [canonical guidance](../../domains/sdlc-full/disciplines/engineering.md#context-and-posture)
    requires evidence-backed assertions and explicit `[hipotese]` labels with
    verification criteria. Temperature `0.1` is a request only when the harness
    exposes a supported control, never an inferred applied setting or a
    determinism guarantee; numerical hallucination rates must not be invented.

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

1. Install discovers the selected domain's discipline files, requires the
   discipline index, and validates every selected strictness value before
   writes. Update does not repeat that source check before publication; its
   doctor postcheck reports invalid installed strictness afterward
   ([issue 174](../issues/issue_174.md)).
2. Validate the explicit adapter target and its native instruction/hook structures.
3. Universal discipline mirror integrity across shipped domains is enforced
   in CI by `scripts/sync-domain-kernel.sh --check`
   ([sync domain kernel](sync-domain-kernel.md)), not at installation time.

### Preview

1. Agent update describes adapter and managed-surface changes without writing.
2. Discipline applicability is evaluated by the agent after eager delivery;
   no command executes merely because a discipline is loaded.

### Apply

1. Install or refresh static instructions in kernel, domain, discipline-index,
   then remaining-discipline order where the adapter controls file order.
2. Claude and Codex static blocks import kernel and domain plus a discipline
   fallback pointer; Generic receives materialized managed Markdown; OpenCode receives ordered native instruction entries.
3. Claude and Codex receive one merged SessionStart entry that emits the
   discipline index, all remaining bodies, and then runs `cumaru tree .`, plus
   one `UserPromptSubmit` entry running `cumaru hooks prompt`. Their
   static block keeps only a fallback pointer instead of discipline bodies;
   unsupported adapters rely on static delivery.
4. The universal `cumaru-role` skill reloads kernel, domain, discipline index,
   remaining discipline bodies in C-locale path order, and root candidates
   before loading a requested role; it writes no active-role state.
5. Doctor validates discipline strictness metadata and discovers at least one
   complete current instruction set. Skills, commands, and hooks are outside
   its instruction-health check.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Missing or invalid discipline strictness in a source domain during install | `1` | none before install writes |
| Missing or invalid installed discipline strictness | doctor error; effective `0/10` | none during doctor |
| Malformed adopter JSON or instruction blocks | `1` | none before reconciliation |
| Missing, duplicate, reordered, or malformed managed instructions | doctor warning | none during doctor |
| Failed adapter update | `1` | partial mutation possible after preflight; restore from Git history |

## Transaction and recovery

Discipline delivery changes made by update require a clean committed baseline
when the project already uses Git; outside Git they warn and mutate managed
files directly without a Git recovery point. Install uses ordered writes. Hook
and instruction removals target only Cumaru-owned entries; unrelated adopter
configuration remains intact.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `domains/__base/disciplines/` | Canonical universal discipline sources. |
| `domains/*/domain.md` | Domain applicability triggers and execution context. |
| [`src/adapter.rs`](../../src/adapter.rs) | Ordered static instruction blocks and owned hook merge/cleanup. |
| [`src/commands/hooks.rs`](../../src/commands/hooks.rs) | Session payload, per-prompt digest, and pre-tool hook output. |
| [`src/markdown.rs`](../../src/markdown.rs) | Shared strictness validation. |
| [`src/commands/install.rs`](../../src/commands/install.rs) | Source discipline metadata validation and initial adapter delivery. |
| [`src/commands/update.rs`](../../src/commands/update.rs) | Adapter refresh and switching from installed discipline bodies. |
| [`src/commands/doctor.rs`](../../src/commands/doctor.rs) | Installed discipline metadata and instruction-set acceptance. |

## Principal methods

| Method | Contract |
|---|---|
| `markdown::validate_strictness` | Require the canonical integer `N/10` strictness range. |
| `install::validate_disciplines` | Require the discipline index and reject invalid selected source discipline metadata before writes. |
| `adapter::markdown`, `adapter::opencode` | Write canonical static discipline delivery while preserving project entries. |
| `adapter::hooks` | Merge exactly one canonical entry per owned hook event into supported adapter JSON. |
| `adapter::clear` | Remove only Cumaru-owned native entries. |
| `hooks::session`, `hooks::prompt` | Emit the session payload and per-prompt digest from installed disciplines. |
| `doctor::instruction_issues` | Warn unless one complete current instruction set exists. |
| `cumaru-role` skill | Restore the complete ordered bootstrap before applying one role. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/adapter.rs` unit tests | Ordered delivery, session/prompt/pre-tool hook shape, hook adapters skipping static bodies, and exact owned cleanup. |
| `src/commands/install.rs` unit tests | Valid and out-of-range source strictness before writes. |
| `src/commands/doctor.rs` unit tests | Installed strictness and instruction-set diagnostics. |
| [`tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Adapter delivery, repeated refresh preservation, and uninstall symmetry. |
| [`tests/spec/contracts/auxiliary_skills_spec.sh`](../../tests/spec/contracts/auxiliary_skills_spec.sh) | Selected universal artifact contracts. |

Remaining legacy discipline and adapter scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
```

## References

- [`../../src/adapter.rs`](../../src/adapter.rs)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`agent-adapters.md`](agent-adapters.md)
- [`architecture.md`](architecture.md)
- [`../../skills/skill-to-discipline/SKILL.md`](../../skills/skill-to-discipline/SKILL.md)
