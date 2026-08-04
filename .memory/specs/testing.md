---
name: testing-specification
description: "Current v7 contract for isolated ShellSpec regression, macOS CI, and manual real-project benches."
type: project
status: implemented
version: 7
---

# Testing specification

## Purpose

The test system verifies Cumaru's CLI, contracts, adapters, schema, and update
transactions with isolated ShellSpec examples. A separate manual bench validates
real-project adoption flows that are inappropriate for fixture-only execution.

## Public surface

```text
bash tests/run.sh
bash tests/run.sh --ci
shellspec --random examples
.github/workflows/tests.yml
```

## Invariants

1. `tests/run.sh` is the canonical non-interactive entry point and requires
   ShellSpec 0.28+.
2. Every example is isolated and may pass independently or in random order;
   no example may depend on state left by another.
3. Fixtures under `tests/fixtures/` are framework-neutral and are not regenerated
   by test execution.
4. CI runs the TAP suite on macOS 14, preserving Bash 3.2 compatibility.
5. Tests invoke no LLM or provider API; adapter names exercise local files only.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `tests/spec/**/*.sh` | framework | ShellSpec examples grouped by CLI, contracts, integration, and update. |
| `tests/fixtures/` | framework | Stable reusable inputs; tests copy rather than mutate canonical fixtures. |
| `tests/report/` | generated | Ignored ShellSpec output. |
| Real bench project | maintainer | Git history remains read-only; install artifacts may be reset during the cycle. |
| `.github/workflows/tests.yml` | framework | macOS dependency installation and TAP execution. |

## Execution

### Preflight

1. Require `shellspec`; tested areas also require Bash, Git, `jq`, and Mike
   Farah `yq` as exercised by production commands.
2. Examples create private temporary state and register cleanup through
   ShellSpec hooks/helpers.

### Dry-run

There is no test-runner dry-run. Product dry-run contracts are tested by
snapshotting every managed surface and proving byte and metadata non-mutation.

### Apply

1. Local `bash tests/run.sh` executes ShellSpec with documentation formatting.
2. `bash tests/run.sh --ci` executes the same discovered examples with TAP.
3. `shellspec --random examples` verifies order independence.

## Manual bench

1. Use a real project, not a throwaway temporary repository.
2. Run `cumaru uninstall --yes`, then verify `.cumaru/` is absent.
3. Run the project install with the intended domain/adapter.
4. Exercise the changed command or workflow and run `cumaru doctor`.
5. Leave the bench installed; the next cycle starts by uninstalling it.
6. Do not commit or otherwise mutate the bench repository's Git history.

The destructive machine-global `cumaru upgrade` is excluded from both automated
and routine manual verification unless explicitly authorized.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Unknown `tests/run.sh` argument | `2` | none |
| ShellSpec unavailable | `1` | none |
| Any failing example | nonzero | temporary state cleaned; canonical fixtures unchanged |
| CI superseded on the same workflow/ref | cancelled | newer run continues |

## Transaction and recovery

Tests that exercise mutation snapshot content, filesystem type, mode, and
symlink targets where contract-relevant. Update tests inject deterministic
failures and assert managed-surface restoration plus absence of locks/staging
debris. Example teardown removes private temporary state even after failure.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../tests/run.sh`](../../tests/run.sh) | Argument validation and local/TAP ShellSpec dispatch. |
| [`../../.shellspec`](../../.shellspec) | ShellSpec repository configuration. |
| [`../../tests/spec/spec_helper.sh`](../../tests/spec/spec_helper.sh) | Shared suite initialization. |
| [`../../tests/spec/`](../../tests/spec/) | CLI, contract, integration, and transaction examples. |
| [`../../.github/workflows/tests.yml`](../../.github/workflows/tests.yml) | macOS 14 CI, dependencies, concurrency, and TAP run. |

## Principal methods

| Method | Contract |
|---|---|
| `tests/run.sh` | Accept only optional `--ci`; execute ShellSpec from repository root. |
| ShellSpec `Before`/`After` hooks | Establish and clean isolated per-example state. |
| Integration/update helpers | Copy fixtures, invoke production CLI, and compare streams/snapshots. |
| `CUMARU_TEST_FAIL_PHASE` | Inject deterministic update failures to prove rollback boundaries. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/cli/`](../../tests/spec/cli/) | Tree, doctor, flow, and coverage public CLI contracts. |
| [`../../tests/spec/contracts/`](../../tests/spec/contracts/) | Help, migration, and shipped artifact contracts. |
| [`../../tests/spec/integration/`](../../tests/spec/integration/) | Global config model and agent adapters. |
| [`../../tests/spec/update/`](../../tests/spec/update/) | Content ownership, tags, dry-run, versions, transaction, and rollback. |

## Verification

```bash
bash tests/run.sh
bash tests/run.sh --ci
shellspec --random examples
```

## References

- [`../../.github/workflows/tests.yml`](../../.github/workflows/tests.yml)
- [`../../docs/doctor.md`](../../docs/doctor.md)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`install-upgrade.md`](install-upgrade.md)
