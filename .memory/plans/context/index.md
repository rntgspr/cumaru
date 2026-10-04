---
status: in-progress
summary: Deliver local relevance ranking with an optional cached encoder and an independent closed model catalog.
---

# Context

## Acceptance criteria

1. `cumaru context "look for egg recipes"` reads visible, safe Markdown files
   inside the current project's `.cumaru/` and ranks their contents against the query.
2. Output is headerless TSV: relative file path, then a finite score from `0.00`
   through `10.00` inclusive, formatted with exactly two decimal places and a
   decimal point. Sort by displayed score descending with byte-order path ties.
   Emit no `/10` suffix, explanations, or document bodies.
3. Scores use one fixed conversion independent of the other candidates. An
   irrelevant candidate set must not acquire a perfect score by normalization.
4. Use a compatible locally installed encoder when available; with no installed
   encoder, use the initial lightweight scorer. A present but invalid model is an
   explicit error, not a silent fallback. Queries download nothing automatically.
   Invocation requires no Python, server, or GPU.
5. Model management is independent: `cumaru model list` reads a closed catalog
   from GitHub; `cumaru model push <name>` downloads an allowed model into
   `~/.cumaru/<name>/`. Weights are not embedded in the CLI. Model resources can
   serve future commands; existing unrelated commands do not initialize inference.
6. Ranking preserves code, headings, and links as input signals. Oversized files
   are evaluated through bounded text fragments, without silent truncation.
7. Ranking never modifies adopter files. Unsafe paths and read failures are reported.
8. Fixed features, optional numerical weights, preprocessing, and runtime settings provide reproducible
   ranking in a fixed environment. Cross-platform bitwise equality is not promised.

## Decisions

- Documentation is English; the first experiment uses English queries.
- The fallback is an in-process lightweight scorer inspired by
  [System1](https://github.com/steph4n-gh/system1): fixed text features and a compact
  numerical head. This is an architectural
  reference, not a requirement to install its Python package or port its full engine.
- Compare an untrained lexical baseline with a small learned head on held-out
  relevance pairs. Do not equate lexical overlap with unrestricted semantic understanding.
- Feature design, training examples, fragment boundaries, aggregation, maximum
  input budget, and score conversion remain experimental decisions.
- TinyBERT/MiniLM results are historical comparisons, not the selected encoder.
- [Encoder/no-encoder comparison](comparison.md) preserves the original scorer.
  The user subsequently selected optional externally stored models plus the
  lightweight fallback; the [model-management plan](model-management.md) owns
  catalog, download, and cache behavior independently of context querying.
- BM25 is an authorized third experiment: an in-memory lexical index without
  pretrained weights or teaching. Its corpus-dependent scores conflict with the
  fixed pair-score invariant; document that difference before any adoption.
- Reuse `Walk` for contained inventory; keep relevance scoring outside navigation.
- Work is based on branch `rust`, commit `a2df3c6`. Existing uncommitted changes
  carried into this branch remain outside this plan's implementation scope.

## Execution order

1. [Lightweight scorer feasibility](01-feasibility.md).
2. [Independent model management](model-management.md).
3. [Native context command implementation](02-command.md).
4. [Verification and documentation](03-verification.md).

Each stage requires the preceding stage's evidence. Keep plans open until the
acceptance criteria are demonstrated. Do not publish releases or change global
installation as part of this plan.

## References

- [Native CLI specification](../../specs/rust.md)
- [Shared walker](../../../src/walk.rs)
- [CLI dispatch](../../../src/main.rs)
- [System1 architecture reference](https://github.com/steph4n-gh/system1)
