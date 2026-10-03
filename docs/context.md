# `cumaru context`

Rank visible Markdown inside the current project's `.cumaru/` against an English
query. It is read-only and offline, needs no config or summaries, and returns
paths and scores rather than generated text or retrieved fragments.

```bash
cumaru context "look for egg recipes"
```

Output is headerless TSV: relative path, then a score from `0.00` to `10.00` with
exactly two decimal places. Sort order is descending displayed score, with byte-order
paths for ties. A Markdown `index.md` is evaluated like every other visible host.

## Backend selection

- Valid `~/.cumaru/bge-micro-v2/`: verify the local manifest, sizes, and checksums,
  then load the encoder with Candle on CPU.
- No supported package: use the original compact lexical/numerical scorer.
- Present invalid, damaged, unsafe, or incompatible package: fail explicitly;
  never silently switch to fallback.

The selected backend is reported on stderr. `context` downloads nothing and does
not create a cache. Install an optional encoder explicitly with
[`cumaru model push`](model.md). Other commands do not initialize inference.

The fallback uses experimental coefficients trained on disclosed synthetic examples;
it does not understand arbitrary paraphrases. The encoder uses normalized mean-pooled
vectors and `10 * clamp(cosine, 0, 1)`. Both scales are experimental, not probabilities
or calibrated absolute relevance. Scores across backends are not interchangeable.
Current encoder observations give nonzero scores to irrelevant documents; compare
ordering and inspect results rather than assuming an acceptance threshold.

## Limits and failures

Queries are limited to 1,024 UTF-8 bytes and must contain searchable terms.
Each host is limited to 1 MiB; over-budget hosts are diagnosed, not truncated.
The fallback covers paragraphs with overlapping 128-word windows. The encoder
covers paragraphs with 510-token windows plus BERT specials and 32-token overlap.
Each file retains its highest fragment score. Query embeddings cannot exceed
the model's 512-token limit. No persistent document/vector index is implemented.

Code, headings, and links remain textual signals. Links are not followed. Hidden
descendants are pruned; root/host symlinks and unsafe traversal paths are rejected.
Individual UTF-8, read, budget, or traversal failures are reported on stderr while
safe rows still emit, with status 1. Invalid queries, roots, or cached models fail
before ranking output. Empty visible inventories succeed with no rows.

Exit codes: `0` complete ranking; `1` validation/runtime/partial-result failure;
`2` malformed invocation. No project, model, adapter, or Git state is modified.

- [Model management](model.md)
- [Scorer experiments](../.memory/plans/context/lightweight/README.md)
- [Model/no-model comparison](../.memory/plans/context/comparison.md)
