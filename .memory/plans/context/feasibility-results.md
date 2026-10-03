---
status: superseded
summary: Initial embedded CPU evidence for two English rerankers, fragmentation quality, and platform gaps.
---

# Context feasibility results

The user clarified that the implementation should follow a lightweight
System1-style approach. This transformer experiment is retained as historical
comparison only. Its candidate recommendations below are superseded by the
[current stage-one plan](01-feasibility.md); it does not qualify that plan.

## Scope and outcome

On 2026-10-03, an isolated Rust experiment demonstrated embedded offline CPU
inference for TinyBERT and MiniLM on macOS ARM, and TinyBERT execution through
Rosetta for a compiled macOS x86 executable. The production CLI is unchanged.
This is partial stage-one evidence, not approval to select production dependencies
or start stage two. Linux musl feasibility and score calibration remain open.

## Artifacts

| Candidate | Pinned Hugging Face revision | ONNX bytes | Tokenizer bytes |
|---|---|---:|---:|
| [TinyBERT L2](https://huggingface.co/cross-encoder/ms-marco-TinyBERT-L2-v2/tree/81d1926f67cb8eee2c2be17ca9f793c7c3bd20cc) | `81d1926f67cb8eee2c2be17ca9f793c7c3bd20cc` | 17,604,619 | 711,396 |
| [MiniLM L2](https://huggingface.co/cross-encoder/ms-marco-MiniLM-L2-v2/tree/1b5cd67b15209f24824c50370e0397743aa9b787) | `1b5cd67b15209f24824c50370e0397743aa9b787` | 62,523,411 | 711,396 |

Both model cards declare Apache-2.0. Their downloaded configs declare
`max_position_embeddings: 512` and an identity score activation: raw outputs
are logits, not calibrated probabilities. Each ONNX file loaded directly from
embedded bytes without an external weight file. Original unoptimized ONNX was
used; quantized and ORT-specific optimized variants were not evaluated.

[fetch-assets.sh](experiment/fetch-assets.sh) pins revisions and checks SHA-256
for ONNX, tokenizer, and config. The tokenizer checksum is identical for both
models. Redistribution still requires assembling model/runtime/tokenizer license
notices before delivery; this experiment does not publish a model-bearing asset.

The prototype locks Tract 0.22.1 and Tokenizers 0.22.2. Tract is an alternative
to ONNX Runtime for this experiment because it can consume embedded ONNX in-process
without an installed inference shared library. [Tract source and license](https://github.com/sonos/tract/tree/v0.22.1)
and [Tokenizers source and license](https://github.com/huggingface/tokenizers/tree/v0.22.2)
are upstream references. [ORT static linkage](https://github.com/pykeio/ort/blob/main/docs/content/setup/linking.mdx)
requires a separately built native runtime; ORT/FastEmbed was not benchmarked.
No claim is made that these are the latest runtime releases.

## Local measurements

Machine: Apple M2 Pro, 16 GB RAM, macOS 26.5.2, Rust 1.98.1. Release build,
sequential batch size one, fixed padded shape `[1, 512]`, default Tract CPU
settings. One final bench run contains five queries over seven short documents
and two long-document strategies. No warmup or repeated statistical sampling
was performed. Timing ranges are observations from that run.

| Measurement | TinyBERT | MiniLM |
|---|---:|---:|
| Initialization across seven invocations | 24.021-28.389 ms | 37.475-39.499 ms |
| Short-document inference, 43-77 document tokens | 5.638-6.716 ms | 28.065-31.612 ms |
| Peak process RSS across invocations | 84,852,736-93,356,032 bytes | 273,252,352-293,601,280 bytes |
| Long relevant document, section cuts, eight fragments | 45.920 ms | 225.361 ms |

The comparison binary is 97,025,472 bytes and embeds both models/tokenizers.
This is not the size of a production single-model CLI. `otool -L` lists only
macOS `libiconv` and `libSystem`, with no ONNX Runtime or other inference dylib.
Peak RSS is the process high-water mark, not model weights alone.

## Relevance and fragmentation

Both candidates ranked the expected file first for all four relevant short-file
queries (eggs, `rotate_refresh_token`, update preservation, safe traversal).
The unrelated neutron-star query produced negative logits for every file.
Seven hand-authored fixtures are insufficient to estimate general ranking quality.

| Egg query case | TinyBERT maximum logit | MiniLM maximum logit |
|---|---:|---:|
| Short recipe file | -2.8306162 | 0.6023104 |
| Short incidental mention | -9.680677 | -10.11897 |
| Long recipe suffix, paragraph windows | -8.018131 | -7.272001 |
| Long recipe suffix, heading cuts | 4.0048184 | 0.013493174 |
| Long incidental mention, heading cuts | -9.680677 | -9.696035 |

Heading cuts prevented unrelated database paragraphs from diluting the recipe
suffix. Maximum aggregation retained the relevant section; mean logits remained
negative (-8.651899 TinyBERT, -8.282677 MiniLM) for the same relevant long files.
This supports experimenting with section cuts and maximum aggregation, but does
not establish resistance to many incidental matches or adversarial headings.

The trial `round(10 * sigmoid(logit))` is rejected as the final conversion:
the relevant short TinyBERT recipe receives only 1/10, while small score changes
can saturate other results. A fixed mapping remains required; candidate-relative
min/max normalization must not be introduced. Choose calibration with a larger
held-out labeled corpus before finalizing integer thresholds.

## Platform and verification evidence

| Target | Observed result | Limit |
|---|---|---|
| `aarch64-apple-darwin` | Locked release build and both-model inference passed. | Local machine only. |
| `x86_64-apple-darwin` | Locked build and TinyBERT inference via Rosetta passed. | Linker emitted a section-alignment warning; no native Intel machine tested. |
| `aarch64-unknown-linux-musl` | Not validated. | Target/linker unavailable locally; Docker daemon unavailable. |
| `x86_64-unknown-linux-musl` | Not validated. | Target/linker unavailable locally; Docker daemon unavailable. |

The x86 Rosetta run initialized TinyBERT in 54.641 ms and used 101,883,904 bytes
peak RSS. Its raw logits differ slightly from ARM; this is compatible with the
plan's explicit exclusion of cross-platform bitwise equality. Timing is not a
native Intel performance estimate.

Three release unit tests passed: long-token coverage/overlap/budget, retained
heading sections, and empty documents. Formatting and shell syntax checks passed.
Two repeated ARM queries had byte-identical path/token/fragment/logit/integer
columns; timing columns were excluded. With the downloaded asset directory moved
away and `PATH=/nonexistent`, embedded inference still succeeded. `--identity`
succeeded without initializing inference. This prototype has no network client.
The unchanged production commands were not rebuilt or benchmarked in this stage.

## Next experiments and gate

1. Keep TinyBERT as the provisional candidate for its lower observed memory,
   inference time, and artifact size; do not make it a production dependency yet.
2. Expand held-out labels across real Cumaru Markdown, empty/code-heavy hosts,
   incidental headings, and multiple relevant sections. Compare short-file
   section cuts as well as long-file cuts; decide maximum aggregation and score
   thresholds from those results rather than the seven training examples here.
3. Validate both Linux musl builds and offline execution, including CPU fallback,
   static linkage, license packaging, and final single-model binary size. Report
   a concrete unsupported target if encountered rather than changing the platform
   contract silently.
4. Confirm byte/input budgets and final runtime settings, then close stage one
   only when its completion evidence is present. Stage two remains proposed.

## References

- [Stage-one plan](01-feasibility.md)
- [Reproduction and prototype boundaries](experiment/README.md)
- [Raw bench evidence](experiment/evidence/)
