---
status: proposed
summary: Deliver local query relevance ranking through an embedded model initialized only by context.
---

# Context

## Acceptance criteria

1. `cumaru context "look for egg recipes"` reads visible, safe Markdown files
   inside the current project's `.cumaru/` and ranks their contents against the query.
2. Output is headerless TSV: relative file path, then an integer `0/10` through
   `10/10`, sorted by descending score with byte-order path ties.
3. Scores use one fixed conversion independent of the other candidates. An
   irrelevant candidate set must not acquire a perfect score by normalization.
4. The executable embeds the chosen model, tokenizer, and CPU inference runtime;
   invocation requires no model download, Python installation, or server.
5. Only `context` initializes inference. Other commands keep their existing behavior.
6. Ranking preserves code, headings, and links as input signals. Oversized files
   are evaluated through bounded token-aware fragments, without silent truncation.
7. Ranking never modifies adopter files. Unsafe paths and read failures are reported.
8. Fixed artifacts, preprocessing, and runtime settings provide reproducible
   ranking in a fixed environment. Cross-platform bitwise equality is not promised.

## Decisions

- Documentation is English; the first experiment uses English queries.
- Start with in-process inference. A persistent server is deferred until measured
  model initialization cost justifies a separate lifecycle.
- Model choice, fragment boundaries, aggregation, maximum input budget, and score
  conversion remain experimental decisions, not implemented contracts.
- Reuse `Walk` for contained inventory; keep relevance inference outside navigation.
- Work is based on branch `rust`, commit `a2df3c6`. Existing uncommitted changes
  carried into this branch remain outside this plan's implementation scope.

## Execution order

1. [Model and distribution feasibility](01-feasibility.md).
2. [Native command implementation](02-command.md).
3. [Verification and documentation](03-verification.md).

Each stage requires the preceding stage's evidence. Keep plans open until the
acceptance criteria are demonstrated. Do not publish releases or change global
installation as part of this plan.

## References

- [Native CLI specification](../../.memory/specs/rust.md)
- [Shared walker](../../rust/src/walk.rs)
- [CLI dispatch](../../rust/src/main.rs)
- [FastEmbed model input](https://docs.rs/fastembed/latest/fastembed/struct.UserDefinedRerankingModel.html)
- [ONNX Runtime linkage](https://github.com/pykeio/ort/blob/main/docs/content/setup/linking.mdx)
