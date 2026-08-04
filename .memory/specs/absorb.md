---
name: absorb-specification
description: "V7 transient close-out and durable-pillar single-source-of-truth contract"
type: project
status: implemented
version: 7
---

# Absorb specification

## Purpose

Define the domain workflow that closes completed work by adjudicating its
durable claims into the owning durable pillar, then removing transient cycle
content. Cumaru provides recipes and guarded primitives; the LLM performs the
semantic adjudication.

## Public surface

```text
cumaru tree <durable-pillar> --deep --rows
cumaru flow <src> move|copy <dst>
cumaru flow <path> remove
cumaru tag <file> get|set reference
cumaru doctor
domains/*/skills/cumaru-{archive,absorb}/SKILL.md
```

## Invariants

1. The durable pillar states what is true now and is the sole durable record.
2. Archive, plan, exploration, and related intake entries are transient and
   are removed after successful absorption according to the domain lifecycle.
3. There is no absorptions ledger, `deltas:`, or `consolidated-at:` metadata.
4. The absorption commit names every work key; Git history is the only
   cross-reference from durable content to the closed work.
5. Target areas are discovered from current tree summaries. Plan `scope:` is a
   hint to validate, not an authority to follow blindly.
6. A claim is merged into an existing owning area or a new area is created;
   semantic conflicts stop for adjudication rather than being guessed.
7. Cleanup occurs only after the durable result and finalized delta have been
   confirmed and validated.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| Completed plan/campaign/changeset and handoffs | adopter | Transient evidence used to derive the final delta. |
| Delta draft/final delta | adopter with LLM adjudication | Claims to merge, not a durable parallel record. |
| Durable pillar content | adopter | Canonical current truth after absorption. |
| Domain archive/absorb skill | framework/domain | Ordered semantic recipe and cleanup gates. |
| `cumaru tree`, `flow`, `tag`, `doctor` | framework | Mechanical discovery, guarded mutation, tag editing, and validation. |
| Git commit history | adopter repository | Historical key-to-change lookup; not stored in `.cumaru/`. |

## Execution

### Preflight

1. Read the domain lifecycle and relevant archive/absorb skill.
2. Verify completion evidence, handoffs, finalized delta, and affected work
   keys; stop on unresolved blockers.
3. Enumerate the durable pillar with `cumaru tree ... --deep --rows` and
   adjudicate each claim against area summaries and loaded content.
4. Validate `scope:` against discovered ownership and surface mismatches.

### Dry-run

1. Present the proposed claim-to-area mapping, new areas, conflicts, reference
   changes, and transient cleanup set before irreversible removal.
2. Tree and tag reads are non-mutating; no cleanup occurs while adjudication is
   incomplete.

### Apply

1. For archive domains, stage the completed work under its transient archive
   entity while finalizing and applying the delta.
2. Update or create durable areas so each accepted claim is represented once
   as current truth; update semantic references where required.
3. Run validation and confirm the durable result.
4. Remove the original plan and all related transient archive, exploration,
   and intake entries prescribed by the domain.
5. When Git mutation is authorized, commit with every absorbed key in the
   commit message; do not create a ledger row.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Missing evidence, unresolved claim, or ownership conflict | workflow blocker | no cleanup |
| Unsafe flow path or protected removal | `1` | rejected operation only |
| Usage error in a primitive | `2` | none |
| Doctor error after durable edits | `1` | cleanup must not proceed |
| Git unavailable or mutation unauthorized | workflow blocker | durable edits may remain uncommitted; no invented history |

## Transaction and recovery

Absorption is an LLM-orchestrated sequence, not a CLI-wide transaction.
Non-destructive staging and validation precede removal. Tracked Git history is
the required recovery boundary before irreversible cleanup.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `domains/sdlc-full/skills/cumaru-archive/SKILL.md` | SDLC close, absorb, validate, and cleanup recipe. |
| `domains/sdlc-light/skills/cumaru-absorb/SKILL.md` | Direct plans-to-specs absorption without archive. |
| `domains/iac-basic/skills/cumaru-archive/SKILL.md` | Changeset delta absorption into topology. |
| `domains/qa-basic/skills/cumaru-archive/SKILL.md` | Campaign delta absorption into coverage. |
| `src/cmd_tree.sh` | Durable-target discovery. |
| `src/cmd_flow.sh` | Guarded transient file operations. |
| `src/cmd_doctor*.sh` | Post-edit structural acceptance. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_tree` | Enumerate durable candidates and summaries without loading bodies. |
| `cmd_flow` | Perform one contained create/copy/move/remove operation. |
| `_flow_resolve_inside` | Canonicalize parents and reject `.cumaru/` escapes. |
| `cmd_doctor_checks` | Validate navigation, tags, references, and adapter state. |
| `fm_block_replace` | Replace one validated semantic tag body when recipes require it. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/cli/flow_spec.sh` | Flow verbs, containment, shape, and protected removals. |
| `tests/spec/cli/tree_spec.sh` | Durable-pillar candidate discovery. |
| `tests/spec/cli/doctor_spec.sh` | Resulting navigation and semantic reference checks. |
| `tests/spec/contracts/documented_contracts_spec.sh` | Retired ledger and migration/update prose contracts. |

## Known gaps

- `domains/sdlc-light/domain.md` describes `plans/` as containing completed
  plans, which permits retention contrary to the architecture's transient
  cleanup rule. This specification records but does not resolve that source
  contradiction.

## Verification

```bash
shellspec tests/spec/cli/flow_spec.sh tests/spec/cli/tree_spec.sh tests/spec/cli/doctor_spec.sh
bash tests/run.sh
```

## References

- [`../../domains/sdlc-full/skills/cumaru-archive/SKILL.md`](../../domains/sdlc-full/skills/cumaru-archive/SKILL.md)
- [`../../domains/sdlc-light/skills/cumaru-absorb/SKILL.md`](../../domains/sdlc-light/skills/cumaru-absorb/SKILL.md)
- [`../../docs/flow.md`](../../docs/flow.md)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`architecture.md`](architecture.md)
