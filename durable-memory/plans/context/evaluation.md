---
status: proposed
summary: Required independent evaluation scenarios for lightweight System1-style context scoring.
---

# Lightweight scorer evaluation

These are required scenarios, not a claim that all tests were executed. The transformer corpus
and fragment unit tests do not establish System1-style scorer behavior. Stage one
must implement this evaluation before stage two selects production dependencies.

## Data and comparison contract

1. Store labeled English query/document pairs with explicit relevance judgments.
   Keep teaching, calibration, and held-out sets separate, including document families
   and paraphrase families; near-duplicate variants must not cross the split.
2. Compare lexical scoring and the compact feature/head scorer on the same held-out
   cases. Retain raw outputs, ranking judgments, two-decimal scores, and every failure.
3. Define quality acceptance thresholds before evaluating the held-out set. A failed
   lightweight scorer remains an unresolved feasibility result; do not silently
   replace it with TinyBERT, MiniLM, or another pretrained language encoder.
4. Fixtures and routine tests remain deterministic and offline. Training examples
   must be reviewed; runtime evaluation calls no teacher, LLM, provider API, or Python.

## Scenarios

| Scenario | Required observation |
|---|---|
| Egg recipe query | Actual cooking instructions outrank an unrelated document and an incidental egg phrase. |
| Code identifier | `rotate_refresh_token` selects the implementing code/contract rather than generic authentication prose. |
| Paths and links | Repository paths and Markdown link text remain usable features without unsafe target reads. |
| Paraphrase without shared terms | Report whether held-out equivalent intent ranks correctly; failed cases remain visible. |
| Unrelated query | A wholly irrelevant candidate set receives low scores; its best file never becomes 10 through relative normalization. |
| Output format | Headerless TSV contains exactly path and a finite score from 0.00 through 10.00 with exactly two decimal places and a decimal point; no suffix or explanations. |
| Candidate independence | Adding/removing other files leaves an unchanged query/document pair's score unchanged. |
| Long relevant suffix | A relevant late section is evaluated and not silently truncated or diluted by unrelated sections. |
| Repeated incidental terms | Repetition or many weak matching sections does not become strong relevance without supporting content. |
| Markdown signals | Code, headings, and links survive feature extraction; heading-shaped fenced content has explicit treatment. |
| Empty and over-budget input | Empty query, empty document, and oversized query/document have explicit reproducible outcomes. |
| Determinism and ties | Fixed inputs produce repeatable scores; displayed two-decimal score ties use byte-order paths. |
| Local distribution | Executable runs offline with no Python, external model files, inference dylib, server, or GPU. |
| Scoped initialization | Other Cumaru commands do not initialize scoring resources. |
| Preservation and safety | Corpus bytes remain unchanged; hidden files, symlinks, malformed UTF-8, and read defects follow the command contract. |

## Evidence

The [initial lightweight experiment](lightweight/README.md) records a six-feature
scorer, synthetic probes, tests, and unresolved quality gates. It does not provide
independent real-data holdout or calibration evidence. Required
timing includes first-call initialization and total query cost; measure memory,
artifact size, and binary size separately. Report actual target builds/execution
and residual platform gaps. Cross-platform bitwise equality is not required.

## References

- [Acceptance criteria](index.md)
- [Stage-one work](01-feasibility.md)
- [System1 reference](https://github.com/steph4n-gh/system1)
