---
status: implemented
summary: Implement context arguments, safe Markdown inventory, compact in-process scoring, and TSV ranking.
---

# Native command implementation

Implemented contract and verification are canonical in
[context and models](../../specs/context.md). Ranking quality/calibration remains
experimental; implementation does not close the full evaluation plan.

## Dependency

Complete [feasibility](01-feasibility.md) and [model management](model-management.md)
before wiring optional encoder selection into production.

## Work

1. Add `context` to native dispatch and help with one required query argument.
   Specify empty-query and input-budget failures before starting scoring.
2. Reuse the deep walker to inventory regular visible Markdown, including indexes,
   without requiring summaries or loading configuration. Preserve existing containment
   and symlink protections.
3. Read content and prepare bounded fragments using the validated strategy.
   Resolve compatible models from the shared model subsystem and initialize an
   installed encoder on demand. Without an installed model, use the lightweight
   scorer. Model absence permits fallback; corruption or incompatibility fails
   explicitly. Never download a model during a query or introduce Python.
4. Aggregate fragment scores and apply the fixed conversion. Sort by displayed
   score descending and relative path in byte order for ties; emit through TSV.
5. Define and implement partial-result behavior for individual read/traversal defects,
   and fail clearly if scorer initialization or evaluation fails. Diagnostics go to stderr.
6. Keep scorer initialization, resources, and relevance rules outside `Walk`,
   `tree`, and `map`. Document every new function under repository conventions.

## Completion evidence

- Acceptance example runs offline with a cached encoder and with no model using
  the lightweight fallback. The CLI embeds no pretrained encoder weights.
- Other commands work without initializing the scorer.
- Empty inventory, oversized input, malformed UTF-8, symlinks, and runtime failures
  have explicit observable outcomes and preserve adopter bytes.

## References

- [Acceptance criteria](index.md)
- [Walker](../../../rust/src/walk.rs)
- [TSV writer](../../../rust/src/tsv.rs)
