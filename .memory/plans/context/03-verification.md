---
status: in-progress
summary: Verify lightweight scorer quality, independent evaluation, deterministic output, and native distribution.
---

# Verification and documentation

Native tests, prepared-cache inference, and disposable CLI checks are recorded in
[context and models](../../specs/context.md). Real-data calibration and remaining
platform evidence are still open; passing mechanical checks does not close them.

## Dependency

Complete [command implementation](02-command.md).

## Work

1. Add focused unit coverage for fragment budgets, aggregation, fixed score
   conversion, rounding, feature stability, and stable ordering. Avoid tests that
   merely copy implementation. Execute the [evaluation matrix](evaluation.md).
2. Run disposable CLI smokes for English Markdown, code and link relevance, long
   documents, irrelevant queries, empty inventory, hidden paths, and symlink rejection.
3. Repeat identical queries under fixed CPU settings and compare output. Snapshot
   fixture bytes before and after; verify offline use without Python, a model cache,
   runtime downloads, or an external inference library. Exercise both a prepared
   model cache and the no-model fallback; cached weights are allowed inputs.
4. Measure final release initialization, scoring, memory, and binary size against
   feasibility results. Validate each supported target or explicitly record missing evidence.
5. Run native unit tests, formatting, locked release build, and diff checks. No native
   integration-suite port, real adopter mutation, or global upgrade is included.
6. Update the canonical Rust specification and public command guide with the chosen
   feature/head contract, query language, input budgets, scoring semantics, failures,
   and measured limits.
   Update README and command inventory to reference that contract.

## Completion evidence

- All acceptance criteria have observed results or explicit unresolved blockers.
- Ranking-quality examples distinguish relevant, incidental, and unrelated content.
- Held-out examples were not used to train or calibrate the head; paraphrase limits
  and lexical-baseline comparisons are reported without transformer evidence substitution.
- Distribution claims match actual target validation; no release availability is inferred.
- The closed GitHub catalog, explicit model download, cache integrity, unsupported
  name refusal, and offline context fallback follow the independent model contract.
- Durable specifications absorb the delivered contract before these plans are retired.

## References

- [Acceptance criteria](index.md)
- [Testing specification](../../specs/testing.md)
- [Native CI](../../../.github/workflows/tests.yml)
