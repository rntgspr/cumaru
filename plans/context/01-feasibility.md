---
status: proposed
summary: Measure an English reranker and prove embedded CPU inference and platform distribution feasibility.
---

# Model and distribution feasibility

## Work

1. Compare suitable small English cross-encoders using representative Cumaru
   Markdown and English queries, including irrelevant queries and code identifiers.
2. Verify redistribution license, exact model revision, tokenizer artifacts,
   ONNX operator compatibility, and any external weight files.
3. Prototype embedded artifacts and static CPU runtime linkage in isolation.
   Check the existing Apple ARM/x86 and Linux ARM/x86 musl distribution targets;
   report unsupported targets before committing to the dependency.
4. Measure executable size, peak memory, initialization time, and ranking time
   separately. Record machine, runtime settings, input tokens, and candidate count.
5. Compare section-aware token fragments and maximum-score aggregation against
   long files with incidental matches. Reserve space for query and special tokens.
6. Select a fixed score mapping and stable integer rounding using labeled examples;
   measure ordering on raw scores before integer conversion hides differences.

## Completion evidence

- Exact chosen artifacts, license, effective token limit, and checksums recorded.
- Offline embedded inference demonstrated; no inference initialization on ordinary commands.
- Platform feasibility and measured costs recorded without invented performance guarantees.
- Fragmentation, aggregation, query overflow behavior, and score mapping decided.

## References

- [Acceptance criteria](index.md)
- [Distribution implementation](../../rust/src/distribution.rs)
- [Binary installer](../../rust/install.sh)
