---
status: evaluated
summary: Third-option in-memory BM25 comparison with exact-word retrieval, measured costs, and score-contract conflict.
---

# In-memory BM25 comparison

## Method

The user authorized BM25 as a third option on 2026-10-03. The
[experiment module](comparison/experiment/src/bm25.rs) builds an inverted index
in RAM using Rust's standard library. Postings retain fragment IDs and term
frequencies; lengths and average length provide normalization. No pretrained
encoder, teacher, training, Python, network, or persistent index is used by BM25.

Implementation follows Robertson and colleagues' Okapi BM25 approach with
`k1=1.2`, `b=0.75`, positive smoothed IDF, unique query terms, and the comparison's
small English stop list. Case is normalized, underscores are retained, and neither
stemming nor synonyms are applied. See [the Stanford IR reference](https://nlp.stanford.edu/IR-book/html/htmledition/okapi-bm25-a-non-binary-model-1.html).

The same paragraph fragments go to all three methods. Each fragment is a BM25
document; each file retains its maximum fragment score. Display conversion is
`10 * raw / (raw + 3)`, rounded to two decimals. The fixed scale of 3 is an
experimental choice, not a calibrated relevance threshold. No query best-score
normalization is used. Raw lexical, learned-head, and cosine scores have different
semantics; displayed magnitudes are not directly comparable across methods.

## Observations

All three methods ran the same four eight-file queries and the three-file
no-title subset. Fresh raw outputs and metrics are retained in
[evidence-bm25](comparison/evidence-bm25/); the earlier two-way records remain intact.

| Egg query probe | Current scorer | BGE Micro/Candle | BM25 |
|---|---:|---:|---:|
| Recipe with title | 10.00 | 9.40 | 7.36 |
| Recipe without title | 1.23 | 7.60 | 0.00 |
| Incidental mention | 1.23 | 6.58 | 0.00 |

For `look for egg recipes`, the body has `eggs`, not the exact query term `egg`,
and lacks `recipes` once the title is removed. This implementation supplies no
stemming or learned association between cooking instructions and recipes.
The failure must not be attributed entirely to missing semantic understanding:
simple morphology normalization is an untested improvement, not present evidence.

A separate diagnostic query, `eggs`, on the no-title subset ranked the body
at 1.99, incidental mention at 0.97, and typography at 0.00. This is a diagnostic
query change, not a passing result for the original egg-recipe query.

For the exact code identifier BM25 selected auth/code, scoring them 4.60/4.22.
For the credential paraphrase it found auth (5.50) but gave code 0.00; the latter
lacks the exact query words. The unrelated neutron-star query returned 0.00 for
every file, versus nonzero incidental lexical signals in the current scorer and
nonzero cosine similarity in the encoder. These are authored regression probes,
not a statistically representative semantic-search evaluation.

## Local costs

Apple M2 Pro, macOS 26.5.2, Rust 1.98.1, release build, one invocation per query:

| BM25 measurement across five invocations | Observed range |
|---|---:|
| Index construction and initialization | 0.037-0.078 ms |
| Query scoring and output | 0.022-0.036 ms |
| Peak process RSS | 2,424,832-2,572,288 bytes |

The corpus had 23 fragments for eight-file queries and eight fragments in the
no-title subset. Shared reading/fragment preparation now precedes initialization
and scoring timers for every variant; earlier two-way metrics included file reads
in scoring and must not be compared as identical timing boundaries. RSS is the
whole-process high-water mark, not a measurement of index storage alone.

The common runner still embeds BGE weights so it can test the encoder. BM25 mode
does not initialize Candle or touch those weights, but this experiment does not
measure a standalone BM25 executable's size. No production dependencies changed.

## Contract difference and verification

BM25 uses corpus statistics: adding unrelated candidates can change an existing
pair's score. A new unit test demonstrates that difference. It conflicts with the
current candidate-independent pair-score invariant, even though the 0-10 conversion
is fixed. Adopting BM25 would require explicitly revising that invariant or defining
frozen statistics; the experiment makes neither decision.

Eight release tests passed, including new BM25 cases for exact matching, empty
and unmatched inputs, length normalization, term-frequency saturation, and corpus
dependence. Fifteen comparison runs and the plural diagnostic completed. TSV
format/bounds/order checks passed; repeated no-title output and corpus SHA-256
snapshots were identical. Formatting, shell syntax, and diff checks passed.
Only local macOS ARM behavior was exercised; the production CLI remains unchanged.

## Next comparison

BM25 is a viable small exact-term retrieval candidate. Compare an explicit English
stemming variant and real query/file judgments before treating the recipe failure
as decisive. Keep synonym/paraphrase probes, calibration, and the corpus-dependence
decision visible. The encoder remains the strongest option for the tested recipe
body, with higher measured size and memory costs; no production winner is selected.

## References

- [Saved current scorer and initial comparison](comparison.md)
- [Current context plan](index.md)
- [Shared three-way bench](comparison/bench.sh)
