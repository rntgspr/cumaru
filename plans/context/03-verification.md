---
status: proposed
summary: Verify relevance quality, deterministic output, preservation, and embedded native distribution contracts.
---

# Verification and documentation

## Dependency

Complete [command implementation](02-command.md).

## Work

1. Add focused unit coverage for fragment budgets, aggregation, fixed score
   conversion, rounding, and stable ordering. Avoid tests that merely copy implementation.
2. Run disposable CLI smokes for English Markdown, code and link relevance, long
   documents, irrelevant queries, empty inventory, hidden paths, and symlink rejection.
3. Repeat identical queries under fixed CPU settings and compare output. Snapshot
   fixture bytes before and after; verify offline use without a model cache.
4. Measure final release initialization, inference, memory, and binary size against
   feasibility results. Validate each supported target or explicitly record missing evidence.
5. Run native unit tests, formatting, locked release build, and diff checks. No native
   integration-suite port, real adopter mutation, or global upgrade is included.
6. Update the canonical Rust specification and public command guide with the chosen
   model, query language, token limits, scoring semantics, failures, and measured limits.
   Update README and command inventory to reference that contract.

## Completion evidence

- All acceptance criteria have observed results or explicit unresolved blockers.
- Ranking-quality examples distinguish relevant, incidental, and unrelated content.
- Distribution claims match actual target validation; no release availability is inferred.
- Durable specifications absorb the delivered contract before these plans are retired.

## References

- [Acceptance criteria](index.md)
- [Testing specification](../../.memory/specs/testing.md)
- [Native CI](../../.github/workflows/tests.yml)
