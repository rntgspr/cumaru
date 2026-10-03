---
status: proposed
summary: Implement context argument handling, safe Markdown inventory, bounded inference, and TSV ranking.
---

# Native command implementation

## Dependency

Complete [feasibility](01-feasibility.md) before selecting production dependencies.

## Work

1. Add `context` to native dispatch and help with one required query argument.
   Specify empty-query and token-overflow failures before starting inference.
2. Reuse the deep walker to inventory regular visible Markdown, including indexes,
   without requiring summaries or loading configuration. Preserve existing containment
   and symlink protections.
3. Read content and prepare token-aware fragments using the validated strategy.
   Initialize the embedded model only inside this command and batch evaluations.
4. Aggregate fragment scores and apply the fixed conversion. Sort by displayed
   score descending and relative path in byte order for ties; emit through TSV.
5. Define and implement partial-result behavior for individual read/traversal defects,
   and fail clearly if model initialization or inference fails. Diagnostics go to stderr.
6. Keep model initialization, runtime resources, and relevance rules outside `Walk`,
   `tree`, and `map`. Document every new function under repository conventions.

## Completion evidence

- Acceptance example runs offline with embedded artifacts.
- Other commands work without creating an inference session.
- Empty inventory, oversized input, malformed UTF-8, symlinks, and runtime failures
  have explicit observable outcomes and preserve adopter bytes.

## References

- [Acceptance criteria](index.md)
- [Walker](../../rust/src/walk.rs)
- [TSV writer](../../rust/src/tsv.rs)
