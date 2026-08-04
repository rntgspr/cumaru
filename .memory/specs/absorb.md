---
name: absorb-specification
description: "Current transient close-out and durable-pillar single-source-of-truth contract"
type: project
status: implemented
version: 9
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
cumaru fs <src> move|copy <dst>
cumaru fs <path> remove
cumaru tag <file> get|set reference
cumaru doctor
domains/*/skills/cumaru-absorb/SKILL.md
```

## Invariants

1. The durable pillar states what is true now and is the sole durable record.
2. Plan content are transient. Exploration, issue, and intake
   sources are removed only when the closed work actually consumed them and no
   active work or unresolved provenance still depends on them.
3. There is no absorptions ledger, `deltas:`, or `consolidated-at:` metadata.
4. The absorption commit names every work key; Git history is the only
   cross-reference from durable content to the closed work.
5. Target areas are discovered from current tree summaries. Plan `scope:` is a
   hint to validate, not an authority to follow blindly.
6. A claim is merged into its exact existing owning file, including a nested
   concern or case, or a new area is created. Parent indexes do not duplicate a
   nested owner's claim; semantic conflicts stop for adjudication rather than
   being guessed.
7. Finishing an execution attempt is not plan completion. Task or plan status,
   doctor, and Git history do not replace evidence that every accepted criterion
   was implemented and verified.
8. An incomplete, infeasible, blocked, partial, or unverified plan remains open
   with all tasks, handoffs, deltas, auxiliary files, and evidence intact.
   Discard is a separate explicit user decision, never a close-out fallback.
9. Cleanup occurs only after the durable result and finalized delta have been
   semantically confirmed, mechanically validated, and committed together with
   every exact removal target.

## Design as Code close-out

The [design domain contract](design-as-code.md) extends direct absorption to
reviewed experience requirements and durable asset records. Lead resolves the
canonical brief or maintenance acceptance source, reconciles independent review
and criterion-to-claim evidence, then updates owning specs and asset records.
Missing review or required verification blocks durable edits as well as cleanup.

Consumed plans, concepts, research, and local briefs are removed only after
retaining needed evidence and satisfying Git recovery gates. Shared active
sources remain; assets and upstream tracker tickets are never cleanup targets.
Canonical template details live in the domain's template index.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| Completed plan/campaign/changeset and handoffs | adopter | Transient evidence used to derive the final delta. |
| Delta draft/final delta | adopter with LLM adjudication | Claims to merge, not a durable parallel record. |
| Durable pillar content | adopter | Canonical current truth after absorption. |
| Domain absorb skill | framework/domain | Ordered semantic recipe and cleanup gates. |
| `cumaru tree`, `fs`, `tag`, `doctor` | framework | Mechanical discovery, guarded mutation, tag editing, and validation. |
| Git commit history | adopter repository | Historical key-to-change lookup; not stored in `.cumaru/`. |

## Execution

### Preflight

1. Read the domain lifecycle and relevant absorb skill.
2. Resolve the acceptance source and verify every criterion against the actual
   implementation, handoffs, and required test or runtime evidence. Treat
   `status: done` only as a signal to inspect. Stop and preserve the complete
   active work set on any incomplete, infeasible, partial, blocked, or
   unverified result.
3. Inventory every existing transient file, including ignored tasks, handoffs,
   auxiliary inputs, and evidence. Compare the filesystem inventory exactly
   with `git ls-files --full-name`, confirm every file through
   `git show HEAD:<path>`, and require both no diff against `HEAD` and empty
   porcelain status with ignored and untracked files included before durable
   edits.
4. Enumerate the durable pillar with `cumaru tree ... --deep --rows` and
   adjudicate each claim against area summaries and loaded content.
5. Validate `scope:` against discovered ownership and surface mismatches.

### Dry-run

1. Present the proposed claim-to-file mapping, new areas, conflicts, provenance
   changes, and exact consumed transient cleanup set before irreversible removal.
2. Tree and tag reads are non-mutating; no cleanup occurs while adjudication is
   incomplete.

### Apply

1. Finalize the delta inside the plan while keeping the complete plan intact.
2. Update or create exact durable owners so each accepted claim is represented
   once as current truth; update semantic references and durable provenance
   where required.
3. Reconcile every accepted criterion with implementation evidence and a durable
   claim or explicit accepted no-change rationale, then run doctor and inspect
   the durable result. Infeasibility or missing evidence is never a no-change
   result.
4. When Git mutation is authorized, commit the verified durable result together
   with every exact cleanup target. Confirm a complete filesystem inventory of
   the removal set exists in the commit and affected paths are clean.
5. Only then remove the original plan and confirmed consumed transient entries
   prescribed by the domain, preserving shared sources, and commit the cleanup.
   The absorption commit message names every absorbed key; no ledger row or
   retained close-out record is created.

### Vault Memory provenance boundary

Vault distillation is not subject to the delivery domains' Git recovery gate.
Before an authorized inbox removal, rewrite every `derived-from` or mirrored
relation that points to the capture: retain necessary files under
`attachments/`, stable URLs in `references`, and necessary provenance facts in
the durable memory. Shared sources and unresolved provenance remain in place.
A non-Git vault may complete distillation when this retention boundary and the
user-confirmed removal boundary are satisfied.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Incomplete, infeasible, partial, blocked, or unverified implementation | workflow blocker | preserve all active and evidence files; no durable edits or cleanup |
| Missing evidence, unresolved claim, or ownership conflict | workflow blocker | no cleanup |
| Unsafe fs path or protected removal | `1` | rejected operation only |
| Usage error in a primitive | `2` | none |
| Doctor error after durable edits | `1` | cleanup must not proceed |
| Existing transient file absent from the committed baseline | workflow blocker | no durable edits or cleanup |
| Git unavailable or mutation unauthorized | workflow blocker | no cleanup and no invented history |
| Recovery commit omits durable output or any cleanup target | workflow blocker | preserve the complete plan; no cleanup |

## Transaction and recovery

Absorption is an LLM-orchestrated sequence, not a CLI-wide transaction. A
committed, exact inventory of existing transient evidence precedes durable
edits. The plan stays intact through semantic verification and doctor. A later
commit must contain both the verified durable result and
every filesystem target selected for removal; this is the required recovery
boundary before cleanup.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `domains/sdlc-full/skills/cumaru-absorb/SKILL.md` | SDLC close, absorb, validate, and cleanup recipe. |
| `domains/design-as-code/skills/cumaru-absorb/SKILL.md` | Reviewed design and asset absorption with guarded transient cleanup. |
| `domains/sdlc-light/skills/cumaru-absorb/SKILL.md` | Direct plans-to-specs absorption. |
| `domains/iac-basic/skills/cumaru-absorb/SKILL.md` | Changeset delta absorption into topology. |
| `domains/qa-basic/skills/cumaru-absorb/SKILL.md` | Campaign delta absorption into coverage. |
| `src/cmd_tree.sh` | Durable-target discovery. |
| `src/cmd_fs.sh` | Guarded transient file operations. |
| `src/cmd_doctor*.sh` | Post-edit structural acceptance. |

## Principal methods

| Method | Contract |
|---|---|
| `cmd_tree` | Enumerate durable candidates and summaries without loading bodies. |
| `cmd_fs` | Perform one contained create/copy/move/remove operation. |
| `_fs_resolve_inside` | Canonicalize parents and reject `.cumaru/` escapes. |
| `cmd_doctor_checks` | Validate navigation, tags, references, and adapter state. |
| `fm_block_replace` | Replace one validated semantic tag body when recipes require it. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `tests/spec/cli/fs_spec.sh` | Fs verbs, containment, shape, and protected removals. |
| `tests/spec/cli/tree_spec.sh` | Durable-pillar candidate discovery. |
| `tests/spec/cli/doctor_spec.sh` | Resulting navigation and semantic reference checks. |
| `tests/spec/contracts/documented_contracts_spec.sh` | Completion/evidence blockers, recovery ordering, canonical role routing, and retired-ledger prose contracts. |

## Known gaps

None currently recorded.

## Verification

```bash
shellspec tests/spec/cli/fs_spec.sh tests/spec/cli/tree_spec.sh tests/spec/cli/doctor_spec.sh
bash tests/run.sh
```

## References

- [`../../domains/sdlc-full/skills/cumaru-absorb/SKILL.md`](../../domains/sdlc-full/skills/cumaru-absorb/SKILL.md)
- [`../../domains/sdlc-light/skills/cumaru-absorb/SKILL.md`](../../domains/sdlc-light/skills/cumaru-absorb/SKILL.md)
- [`../../docs/fs.md`](../../docs/fs.md)
- [`../../docs/architecture.md`](../../docs/architecture.md)
- [`architecture.md`](architecture.md)
