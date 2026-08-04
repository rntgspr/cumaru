---
name: sync-domain-kernel-specification
description: "Maintenance script that propagates canonical __base artifacts to all shipped domains"
type: project
status: implemented
version: 7
---

# Sync Domain Kernel specification

## Purpose

Provides a standalone maintenance script that deterministically copies universal kernel artifacts from `domains/__base/` into every shipped domain (`sdlc-full`, `sdlc-light`, `iac-basic`, `qa-basic`, `vault-memory`), while preserving domain-owned artifacts (`skills/cumaru-install/`, `disciplines/index.md`). This ensures kernel byte-identity across domains, which is a hard requirement for the installer drift-check.

## Public surface

```text
scripts/sync-domain-kernel.sh [--check|--apply]
```

## Invariants

1. **Byte-identity guarantee** — After `--apply`, every universal artifact in every shipped domain is byte-identical to its `__base` source.
2. **Domain-owned preservation** — `skills/cumaru-install/**` and `disciplines/index.md` are never modified.
3. **No mutation in check mode** — `--check` only reports; exits 0 when fully synchronized, 1 with a list of divergent/missing paths.
4. **Idempotent apply** — Re-running `--apply` on an already-synchronized tree produces no output and changes nothing.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/__base/index.md` | framework | Canonical kernel entry point; propagated verbatim. |
| `domains/__base/skills/cumaru-*/SKILL.md` | framework | Universal skills (doctor, update, refs, summarize); propagated verbatim. |
| `domains/__base/commands/cumaru/*.md` | framework | Universal slash commands; propagated verbatim. |
| `domains/__base/disciplines/code-comments.md` | framework | Universal discipline; propagated verbatim. |
| `domains/__base/disciplines/cumaru-first.md` | framework | Priority universal discipline; propagated verbatim. |
| `domains/__base/disciplines/index.md` | framework | **Not propagated** — domain-owned per domain. |
| `domains/__base/skills/cumaru-install/SKILL.md` | framework | **Not propagated** — domain-owned per domain. |

## Execution

### Preflight

1. Script resolves its own location to find project root and `domains/`.
2. Validates `domains/__base/index.md` exists (canonical source present).
3. Enumerates shipped domains as immediate subdirectories of `domains/` excluding `__base`.

### Dry-run (`--check`)

1. For each universal artifact in `__base`, compares against each domain's mirror using `cmp -s`.
2. Reports `missing: <path>` or `divergent: <path>` per domain.
3. Exits 0 if no differences; exits 1 if any difference found.

### Apply (`--apply`)

1. For each universal artifact in `__base`, copies to each domain's mirror (creating parent dirs as needed).
2. Skips domain-owned exclusions via case statement.
3. Reports `synced: <path>` per copied file.
4. No validation gate beyond filesystem write success.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Canonical source missing | `1` | none |
| Unknown flag / usage error | `2` | none |
| Write permission denied | `1` | partial (files before failure) |

## Transaction and recovery

No transaction — file copies are independent. On partial failure, re-run `--apply` to complete. No rollback needed because source (`__base`) is never modified.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| `scripts/sync-domain-kernel.sh` | Single-file Bash script; all logic self-contained. |

## Principal methods

| Method | Contract |
|---|---|
| `sync_file(src, dest)` | Compares via `cmp -s`; in check mode reports diff; in apply mode `cp` with `mkdir -p`. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `scripts/sync-domain-kernel.sh --check` on clean tree | Exits 0, prints synchronization message. |
| Modify one universal file, run `--check` | Exits 1, identifies exact divergent path. |
| Run `--apply` after modification | Restores byte-identity, no domain-owned files changed. |
| Run `--apply` twice | Second run produces no output, no changes. |

## Verification

```bash
# Fast verification
./scripts/sync-domain-kernel.sh --check

# Complete regression (includes installer drift-check)
bash tests/run.sh
```

## LLM Usage Protocol

**After ANY edit to a canonical file under `domains/__base/`**, the LLM must:

1. **Run the sync script in apply mode:**
   ```bash
   ./scripts/sync-domain-kernel.sh --apply
   ```

2. **Verify synchronization:**
   ```bash
   ./scripts/sync-domain-kernel.sh --check
   # Must print: "Universal domain artifacts are synchronized."
   ```

3. **Run the test suite** to confirm installer drift-check still passes:
   ```bash
   bash tests/run.sh
   ```

**Files that trigger this protocol** (canonical/universal artifacts):
- `domains/__base/index.md`
- `domains/__base/skills/cumaru-doctor/SKILL.md`
- `domains/__base/skills/cumaru-update/SKILL.md`
- `domains/__base/skills/cumaru-refs/SKILL.md`
- `domains/__base/skills/cumaru-summarize/SKILL.md`
- `domains/__base/commands/cumaru/doctor.md`
- `domains/__base/commands/cumaru/update.md`
- `domains/__base/commands/cumaru/resolve.md`
- `domains/__base/commands/cumaru/refs.md`
- `domains/__base/commands/cumaru/summarize.md`
- `domains/__base/commands/cumaru/role.md`
- `domains/__base/disciplines/code-comments.md`
- `domains/__base/disciplines/cumaru-first.md`

**Files that do NOT trigger this protocol** (domain-owned, excluded from sync):
- `domains/__base/skills/cumaru-install/SKILL.md`
- `domains/__base/disciplines/index.md`
- Any file under `domains/__base/templates/`, `domains/__base/roles/`, `domains/__base/config.yaml`, `domains/__base/migration.md`, `domains/__base/domain.md`

## References

- `scripts/sync-domain-kernel.sh`
- `src/install.sh` (drift-check enforcement)
- `.memory/specs/domains.md` (kernel byte-identity requirement)
- `.memory/specs/disciplines.md` (universal vs domain-owned disciplines)
