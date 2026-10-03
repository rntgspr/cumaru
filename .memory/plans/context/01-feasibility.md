---
status: in-progress
summary: Evaluate a compact System1-style scorer against lexical baselines with independent relevance evidence.
---

# Lightweight scorer feasibility

## Work

1. Inspect System1's fixed feature extraction and numerical head, separating
   portable scoring mechanics from its Python runtime and optional integrations.
   Record attribution and license for any reused implementation or artifact.
2. Prototype a lightweight scorer in Rust. Compare a simple lexical baseline
   with fixed pair features and a small numerical head trained offline, if that
   head improves held-out query/document ranking. No pretrained language encoder.
3. Define independent teaching, calibration, and held-out evaluation examples.
   Use representative Cumaru Markdown and English queries, including code identifiers,
   lexical matches, paraphrases, irrelevant queries, and incidental mentions.
4. Measure executable size, peak memory, initialization time, and ranking time
   separately. Record machine, runtime settings, input tokens, and candidate count.
5. Compare section-aware bounded fragments and aggregation against long files
   with incidental matches. Preserve code, headings, and links. Make every input
   limit explicit; reject over-budget input rather than silently dropping content.
6. Select a fixed score mapping and stable rounding to two decimal places using
   labeled examples; measure ordering on raw scores before rounding hides differences.
7. Check Apple ARM/x86 and Linux ARM/x86 musl feasibility without external inference
   libraries. Compare costs with the historical transformer experiment, but do not
   adopt a transformer when the lightweight scorer misses a quality gate.
8. Execute and record each scenario in the [evaluation matrix](evaluation.md).
   Report weak paraphrase/generalization behavior explicitly; do not claim semantic
   ranking from training-set success or lexical fixtures alone.

## Completion evidence

- Initial lightweight implementation and explicit quality limits:
  [experiment evidence](lightweight/README.md). Not production-qualified.
- Historical transformer comparison: [feasibility results](feasibility-results.md).
  It does not satisfy the lightweight scorer's completion evidence.
- Fixed feature contract, any compact weights, provenance, license, and checksums recorded.
- Offline in-process scoring demonstrated without Python or external weights;
  ordinary commands do not initialize scoring resources.
- Separate held-out quality results and baseline comparison recorded, including failures.
- Platform feasibility and measured costs recorded without invented performance guarantees.
- Fragmentation, aggregation, query overflow behavior, and score mapping decided.

## References

- [Acceptance criteria](index.md)
- [Distribution implementation](../../../rust/src/distribution.rs)
- [Binary installer](../../../rust/install.sh)
- [System1](https://github.com/steph4n-gh/system1)
