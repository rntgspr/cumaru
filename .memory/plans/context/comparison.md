---
status: evaluated
summary: Frozen scorer state and isolated comparison of lightweight ranking versus a pretrained BGE Micro encoder.
---

# Context comparison checkpoint

The user authorized a model/no-model comparison on 2026-10-03 after observing
that removing the recipe title reduced lightweight relevance from 10.00 to 1.23.
This experiment does not select a production architecture or alter the CLI.

## Saved state

- [Frozen relevance source](comparison/current-relevance.rs) is a byte-for-byte
  checkpoint of `rust/src/relevance.rs`, not a second canonical implementation.
- The original [lightweight experiment](lightweight/README.md) retains teaching
  examples, fitted coefficients, and limitations. The comparator freezes those
  coefficients; it does not retrain either variant on the comparison corpus.
- The output contract remains path plus score 0.00-10.00, two decimal places,
  descending displayed score and byte-order path ties. No generated text or
  retrieved fragments are part of the current production scope.

## Variants

| Variant | Method | Runtime requirements |
|---|---|---|
| `lightweight` | Existing six lexical features and frozen seven-coefficient head. | Rust standard library for scoring; no pretrained language encoder. |
| `encoder` | TaylorAI BGE Micro v2, Candle CPU, normalized mean-pooled vectors, cosine similarity. | Embedded pretrained weights and tokenizer, no Python/server/GPU. |
| `bm25` | In-memory postings, term-frequency saturation, corpus IDF, and length normalization. | Standard-library indexing, no pretrained weights or teaching. |

The subsequent [BM25 comparison](bm25-results.md) owns its implementation,
fresh three-way measurements, and candidate-independent score contract conflict.
The two-way observations below retain their original timing boundaries.

The phrase "without a model" means without a pretrained language model here.
The existing small learned numerical head is technically a model too; replacing
it with a plain lexical baseline would not compare the saved implementation.

Both variants receive the same paragraph fragments with bounded overlapping
128-word windows. Neither gets path features, per-query teaching, or hand-added
synonyms. Oversized inputs fail explicitly. The encoder also rejects fragments
over 512 WordPiece tokens; no silent truncation is allowed. Empty hosts score zero.

Encoder scores use `10 * clamp(cosine, 0, 1)` for the experiment only. This is
not calibrated relevance or probability, and the two variants' numeric scales
are not interchangeable. Compare ordering and failures before comparing magnitudes.

## Before-run expectations

| Query | Expected relevant files | Specific failure to inspect |
|---|---|---|
| `look for egg recipes` | `eggs.md`, `eggs-body.md` | Title removal versus cooking-body recognition; incidental nickname. |
| `renew credentials before they expire` | `auth.md`, `code.md` | Paraphrase without the exact identifier. |
| `rotate_refresh_token` | `code.md`, `auth.md` | Preserve exact code-name usefulness. |
| `orbital mechanics of binary neutron stars` | None | Unrelated set must not acquire a perfect relative score. |

The no-title subset contains only `eggs-body.md`, `incidental.md`, and
`unrelated.md`. Neither model was fine-tuned on this comparison. This authored,
previously discussed corpus is exploratory regression evidence, not a blind
benchmark or independent quality qualification. No acceptance threshold is
inferred from its results.

## Reproduce

```bash
bash .memory/plans/context/comparison/fetch-assets.sh /tmp/cumaru-bge-micro
CARGO_HOME=/tmp/cumaru-context-cargo \
CUMARU_ENCODER_ASSETS=/tmp/cumaru-bge-micro \
cargo build --release --locked --manifest-path .memory/plans/context/comparison/experiment/Cargo.toml
bash .memory/plans/context/comparison/bench.sh /tmp/cumaru-encoder-results
```

Downloads happen only during preparation. Assets are embedded with `include_bytes!`;
the executable has no network client. Main weights use FP16 storage; CPU evaluation
converts them to F32. Pooling includes every actual token, including specials,
with no padding. No query prefix or caching is introduced.

## References

- [BGE Micro v2 pinned source](https://huggingface.co/TaylorAI/bge-micro-v2/tree/3edf6d7de0faa426b09780416fe61009f26ae589)
- [Candle BERT implementation](https://github.com/huggingface/candle/blob/0.9.1/candle-transformers/src/models/bert.rs)
- [Current acceptance contract](index.md)

## Observed comparison

On Apple M2 Pro, macOS 26.5.2, Rust 1.98.1, Candle 0.9.1 CPU, one release
invocation per variant/query produced the following results. Scores use distinct,
uncalibrated scales; this table demonstrates ordering behavior, not interchangeable
absolute relevance. Raw outputs and metrics are retained in [evidence](comparison/evidence/).

| Probe | Current scorer | BGE Micro/Candle |
|---|---:|---:|
| Egg query, recipe with title | 10.00 | 9.40 |
| Egg query, same recipe without title | 1.23 | 7.60 |
| Egg query, incidental mention | 1.23 | 6.58 |
| Egg query, unrelated typography | 0.00 | 4.90 |
| Credential paraphrase, auth contract | 5.07 | 7.61 |
| Credential paraphrase, token rotation code | 2.63 | 6.82 |

The encoder recovered the recipe body's ordering without its title. Its relevant
body outranked the incidental mention by 1.02 displayed points, where the current
scorer tied them. Both variants selected auth/code first for the credential query,
but the encoder's separation from unrelated documents improved in these probes.
For the exact identifier query, the current scorer ordered auth before code
(9.82 versus 9.73); the encoder ordered implementation before auth (9.70 versus 8.94).

The unrelated neutron-star query revealed an unresolved calibration problem:
encoder scores ranged 3.96-4.39 even though no relevant file exists. The current
scorer ranged 0.00-1.23. Neither used candidate-relative normalization. A cosine
score converted linearly to 0-10 is not a calibrated rejection threshold.

| Observed cost across five invocations | Current scorer | Encoder |
|---|---:|---:|
| Initialization | 0.001-0.012 ms | 27.146-55.971 ms |
| Scoring entire query, including query embedding | 0.181-0.553 ms | 62.406-214.947 ms |
| Peak process RSS | 2,490,368-2,621,440 bytes | 185,499,648-187,924,480 bytes |

There were four eight-file queries and one three-file no-title subset. Per-query
cost includes all selected paragraph fragments. It is not per-document latency.
Ranges summarize five observations, not a statistical performance guarantee;
no warmup, caching, or GPU was used. Common runner overhead applies to both modes.

The embedded comparison executable is 40,424,800 bytes; weights alone are
34,785,664 bytes in FP16 storage. This binary contains both methods. Its lightweight
mode does not initialize or touch encoder weights. The standalone lightweight
prototype and the production CLI are separate artifacts; this is not a measurement
of added production binary size. `otool -L` lists only macOS libiconv/libSystem.

## Verification and remaining gates

- Five release unit tests passed: four checkpoint scorer tests and one common
  fragmentation test. These do not assert neural model correctness.
- All ten bench invocations completed. Independent output checks accepted exactly
  two TSV fields, two decimal places, 0-10 bounds, descending displayed scores,
  and byte-order path ties.
- Removing the prepared asset directory and setting `PATH=/nonexistent` still
  allowed encoder inference. Two identical calls emitted byte-identical ranking
  TSV. Corpus SHA-256 snapshots before/after remained identical.
- Snapshot source stayed byte-identical to `rust/src/relevance.rs`; no production
  dependencies, dispatch, installer, or global installation changed.
- Formatting, shell syntax, and diff checks passed. Only local macOS ARM behavior
  was evaluated; no other platform compatibility or live adopter behavior is claimed.

The encoder improves the tested body/paraphrase ranking at a substantial size and
memory cost. This is enough to expose the trade-off, not to choose a production
model. Remaining work is real query/file judgments, irrelevant-query calibration,
broader incidental/negation probes, and supported-target validation if adopted.
