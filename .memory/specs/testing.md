---
name: testing-specification
description: "Current contract for retained ShellSpec reference, Ubuntu native CI, and manual real-project benches."
type: project
status: implemented
version: 9
---

# Testing specification

## Purpose

The native test system combines Rust unit tests beside implementations with
selected ShellSpec process regressions and source-independent artifact contracts.
The complete legacy-file disposition and outstanding port gaps are canonical in
[the native inventory](../../tests/native/README.md); issue 139 remains open.

The supported native CLI is checked by cargo unit tests, formatting, and release
build in its own Ubuntu 24.04 CI job, followed by a release-binary version and help
smoke, followed by the selected process suite in default and randomized order.
CI prepares SHA-256-verified ShellSpec 0.28.1. Release target validation remains
separate. Unselected ShellSpec scenarios retain the deleted Bash CLI/source-module
contract and cannot run unchanged. The canonical native unit scope remains in
the [Rust specification](rust.md#regression-coverage).

## Public surface

`tests/run.sh` selects `tests/native/` and five reviewed artifact suites, never
the entire legacy directory. It requires an actual absolute executable path
(`CUMARU_TEST_BINARY`, default `rust/target/release/cumaru`) and fails with a build
instruction when absent. Every process fixture isolates HOME and project state;
the closed cURL stub permits only one main identity/inventory and SHA-pinned raw
source reads. Unknown URLs fail without real network access. No deprecated CLI
module, actual home cache, inference service or global installer is invoked.
`--ci` emits TAP and `--random` reorders the same selection. The remaining sections
retain historical Bash details where explicitly identified.

```text
bash tests/run.sh
bash tests/run.sh --ci
bash tests/run.sh --random
.github/workflows/tests.yml
```

## Invariants

1. `tests/run.sh` is the canonical non-interactive entry point and requires
   ShellSpec 0.28+.
2. Every example is isolated and may pass independently or in random order;
   no example may depend on state left by another.
3. Fixtures under `tests/fixtures/` are framework-neutral and are not regenerated
   by test execution.
4. The retired Bash CI ran the TAP suite on macOS 14 for Bash 3.2 compatibility;
   no current CI job runs it.
5. Tests invoke no LLM or provider API; adapter names exercise local files only.

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `tests/spec/**/*.sh` | framework | ShellSpec examples grouped by CLI, contracts, integration, and update. |
| `tests/fixtures/` | framework | Stable reusable inputs; tests copy rather than mutate canonical fixtures. |
| `tests/report/` | generated | Ignored ShellSpec output. |
| Real bench project | maintainer | Git history remains read-only; install artifacts may be reset during the cycle. |
| `.github/workflows/tests.yml` | framework | Ubuntu 24.04 native Rust formatting, unit tests, release build/smoke, and selected default/random process and artifact regressions. |

## Execution

### Preflight

1. Selected native regressions require ShellSpec, Bash, Git, and ordinary POSIX
   fixture tools. Retained unselected Bash scenarios have additional jq/yq/rg
   requirements; those are not native runtime dependencies.
2. Examples create private temporary state and register cleanup through
   ShellSpec hooks/helpers.

### Dry-run

There is no test-runner dry-run. Product dry-run contracts are tested by
snapshotting every managed surface and proving byte and metadata non-mutation.

### Apply

1. Local `bash tests/run.sh` executes ShellSpec with documentation formatting.
2. `bash tests/run.sh --ci` executes the same discovered examples with TAP.
3. `bash tests/run.sh --random` verifies order independence for the same selected
   suite. Its environment script routes ShellSpec 0.28.1's example list to the
   harness temporary directory instead of the repository root.

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

Tests that exercise managed-surface snapshots compare filesystem content, type,
mode, and symlink targets where contract-relevant. Update tests assert warned
non-Git mutation, dirty-Git rejection, direct mutation behavior, and absence of
project-local lock/staging/backup/recovery debris.

## Implementation map

| Script or artifact | Responsibility |
|---|---|
| [`../../tests/run.sh`](../../tests/run.sh) | Argument validation and local/TAP ShellSpec dispatch. |
| [`../../.shellspec`](../../.shellspec) | ShellSpec repository configuration. |
| [`../../tests/spec/spec_helper.sh`](../../tests/spec/spec_helper.sh) | Shared suite initialization. |
| [`../../tests/spec/`](../../tests/spec/) | CLI, contract, integration, and transaction examples. |
| [`../../.github/workflows/tests.yml`](../../.github/workflows/tests.yml) | Ubuntu 24.04 native Rust CI, triggers, concurrency, and binary smoke. |

## Principal methods

| Method | Contract |
|---|---|
| `tests/run.sh` | Accept optional `--ci` or `--random`; execute only the reviewed native/artifact selection. |
| ShellSpec `Before`/`After` hooks | Establish and clean isolated per-example state. |
| Integration/update helpers | Copy fixtures, invoke production CLI, and compare streams/snapshots. |

## Regression coverage

Native Rust unit tests and their current scope are recorded in the
[Rust CLI specification](rust.md#regression-coverage). They run separately
through `cargo test`; selected native process scenarios exercise actual CLI
streams/status, safe partial output, four adapters, preview/config non-mutation,
update/clear ownership and opaque body preservation, Git recovery and source
failures. Retained unselected scenarios still require a deliberate port.
The current native suite has 81 routine unit tests and one ignored prepared-model
smoke, separately exercised as recorded in [context and models](context.md).
The selected harness has 57 process cases and 18 artifact cases. Local macOS ARM
verification uses ShellSpec 0.28.1/Bash 3.2. Disposable mutation wrappers for wrong
status, stream routing, unsafe acceptance and copy source loss each fail the
reused fs regressions. No production binary was changed. Default/random execution
and missing-binary/legacy-invocation diagnostics are checked separately. Remote CI
execution requires publication; local success does not establish complete legacy
parity, Linux behavior or permission to delete unselected `src/` consumers.

| Test | Covered behavior |
|---|---|
| [`../../tests/spec/cli/`](../../tests/spec/cli/) | Tree, doctor, fs, and coverage public CLI contracts. |
| [`../../tests/spec/contracts/`](../../tests/spec/contracts/) | Help, migration, and shipped artifact contracts. |
| [`../../tests/spec/integration/`](../../tests/spec/integration/) | Global config model and agent adapters. |
| [`../../tests/spec/update/`](../../tests/spec/update/) | Content ownership, tags, dry-run, versions, conditional Git recovery, and direct mutation behavior. |

## Design workflow verification

`tests/spec/contracts/design_artifacts_spec.sh` resolves domain-owned skill and
template dependencies and checks entity metadata against config. Pair it with
command launcher, schema, and universal mirror checks. An isolated installation
smoke verifies shipped artifacts, tree navigation, and doctor acceptance.

Independent forward evaluation of the design recipes checks realistic acceptance,
review, source-refresh, and cleanup decisions. It is semantic evaluation, not an
automated tracker-to-browser-to-absorption test. Completion evidence for issues
046–048 distinguishes these boundaries and records actual runner availability.

## Corrected workflow scenarios

`tests/spec/contracts/workflow_scenarios_spec.sh` composes only the cross-step
boundaries not already owned by focused suites. It models a pre-dispatched Dev
task through canonical acceptance, task status, handoff evidence, and
Lead-owned DAG reconciliation for SDLC Full, IaC, and QA. It also performs a
real local install and doctor failure after a durable edit, proving transient
work remains intact while the pending durable edit is not automatically rolled
back.

The scenario suite does not execute an agent, browser, tracker, cloud provider,
Terraform provider, or external API. Semantic choices remain bounded contract
evaluation; deterministic installation, file transitions, checksums, and doctor
failure are automated. Existing focused suites remain authoritative for mixed
tracker provenance, template destinations, complete uninstall, required
ripgrep behavior, malformed tags, and Git recovery inventories.

## Known limit

The completed [native recipe review](skill-cli-contracts.md) records the 99-skill
inventory, launcher checks, and disposable offline CLI verification. It does not
replace the separate test-scope audit or claim live agent behavior was tested.

Skill tests assert local artifact structure, distribution, launchers, and some
written gates; they do not prove that an agent follows a skill in a real task.
[Issue 065](../issues/issue_065.md) tracks a measured coverage and test-scope
audit. Automated tests remain deterministic and offline.

## Verification

```bash
bash tests/run.sh
bash tests/run.sh --ci
bash tests/run.sh --random
```

## References

- [`../../.github/workflows/tests.yml`](../../.github/workflows/tests.yml)
- [`../../docs/doctor.md`](../../docs/doctor.md)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/update.md`](../../docs/update.md)
- [`install-upgrade.md`](install-upgrade.md)
