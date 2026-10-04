---
name: reuse-legacy-tests-for-native-cli
description: Recover relevant legacy Bash regression scenarios for the supported Rust CLI
status: open
priority: high
---

# Issue 139: Reuse legacy Bash tests for the Rust CLI

[GitHub issue 17](https://github.com/rntgspr/cumaru/issues/17).

The root Bash entry point is gone. `tests/run.sh` stops with a porting diagnostic,
and retained ShellSpec helpers still select that removed executable. Native unit
tests and disposable smokes do not replace the existing end-to-end scenarios.

## Risk

- CLI stream, exit-code, adapter, ownership, and preservation regressions can
  escape unit coverage while useful legacy fixtures remain unused.

## Required invariant

Relevant legacy scenarios run against the actual Rust executable, using isolated
fixtures and current native contracts. Tests never execute deprecated CLI modules,
modify real adopters/home caches, or invoke the real global installer.

## Work

1. Map existing CLI, integration, update, and contract scenarios to native behavior
   and current coverage. Record reused, adapted, redundant, and intentionally retired
   cases with reasons; do not claim complete Bash parity.
2. Choose the smallest runnable harness. Evaluate keeping ShellSpec as a process
   harness before rewriting everything; retain useful fixtures and isolate native
   unit tests beside their implementations. Document any newly selected test layout.
3. Adapt executable resolution, TSV defaults, opaque tags, stateless adapters,
   main-SHA source stubs, config/version distinctions, and removed flags. Preserve
   negative, partial-result, containment, and byte-preservation cases.
4. Wire a documented native regression entry point into CI alongside cargo tests.
   Keep external source reads stubbed and inference/provider calls out of routine
   tests. Exercise installer behavior only through redirected scratch copies.
5. Update the testing specification and developer guide with measured coverage,
   commands, and remaining gaps. Broader test-quality audit stays in issue 065.

## Tests

- The selected scenarios pass independently and in reordered execution against
  the Rust binary; canonical fixtures remain unchanged.
- Deliberate wrong exit codes, stdout/stderr routing, unsafe-path acceptance, and
  adopter-data loss fail the relevant regressions.
- Missing binary and legacy-only invocations fail clearly; CI runs the new suite
  without relying on the removed Bash entry point or real home state.

## Implementation evidence and remaining scope

The initial port is implemented in `tests/native/`, selected by `tests/run.sh` and
CI alongside native Cargo tests. The [complete legacy inventory](../../tests/native/README.md)
records every legacy file as reused/adapted/retired/unit-covered/remaining,
including direct source consumers that block issue 140 cleanup. The harness
retains ShellSpec 0.28.1 with isolated HOME/projects and closed SHA-pinned cURL
fixtures. Fifty-seven process cases and 18 artifact cases cover the selected
contracts. Default TAP and randomized execution passed all 75 cases (20.14
seconds for the random run). Missing-binary/legacy runner probes returned 1/2.
Four disposable process mutations
each fail the fs cases (status 101); shell syntax and diff checks passed.
The four native spec files also passed independently (25/14/16/2 cases).
Random selection redirects ShellSpec's example list into its temporary directory.

This issue remains **open**: native scratch-installer/version/upgrade processes,
full doctor/schema/workflow/domain matrices, nested-tag fixture replay and tracker
preservation scenarios remain explicitly listed in the inventory. Local harness
success does not establish remote CI execution or full Bash parity. No deprecated
module was deleted, no real installer ran, and no real home cache was modified.

## References

- [Legacy runner](../../tests/run.sh)
- [Legacy scenarios](../../tests/spec/)
- [Native command contracts](../specs/rust.md)
- [Testing boundaries](../specs/testing.md)
- [Separate audit issue](issue_065.md)
- [Native CI](../../.github/workflows/tests.yml)
