# Lightweight relevance experiment

The isolated dependency-free crate exercises [relevance.rs](../../../../src/relevance.rs)
without registering a production `context` command or introducing default weights.
The Rust source is included directly by path; no duplicate implementation exists.

## Construction

1. Prepare the query once: lowercase word/identifier tokens, a fixed small English
   stop list, distinct terms, and character trigrams. Underscores remain in tokens.
2. For each fragment compute six values: exact term coverage, exact query phrase,
   shared character trigrams, exact underscore identifiers, matching-term density,
   and an explicit nearby negation indicator.
3. In the experiment only, fit six coefficients plus a bias with deterministic
   gradient updates minimizing squared error and L2 regularization. Twelve authored
   teaching pairs provide desired 0-10 scores. They are synthetic and not user-reviewed.
4. Runtime evaluation uses `clamp(bias + sum(weight * feature), 0, 10)`. With no
   lexical/subword signal the score is zero. It is relevance evidence, not a
   probability or an understanding of arbitrary text.
5. Evaluate every paragraph in overlapping 128-word windows (16-word overlap),
   retaining the best score. Empty hosts score zero. Experimental limits reject
   queries over 1,024 UTF-8 bytes and documents over 1 MiB before evaluation.

The construction is inspired by [steph4n-gh's System1 fixed-feature numerical heads](https://github.com/steph4n-gh/system1/blob/fb518ccc37829d3a14490f0e1a5920b402e711da/docs/architecture/technical_specification.md).
This is an original reduced pair-feature implementation, not a System1 port:
no hashed 384-dimensional projector, NumPy, pretrained encoder, receipt engine,
or automatic teaching service is included. Its learned head holds seven f64
coefficients, totaling 56 bytes. Any production coefficients require separate
review, provenance, calibration, and quality gates before being embedded.

## Reproduce

```bash
cargo test --manifest-path .memory/plans/context/lightweight/Cargo.toml --locked --offline
cargo build --release --manifest-path .memory/plans/context/lightweight/Cargo.toml --locked --offline
.memory/plans/context/lightweight/target/release/cumaru-relevance-experiment
```

The executable compares plain term coverage with the learned head on nine
disclosed evaluation pairs, then measures a long file with a relevant suffix.
These probes have different queries from teaching, but share authored patterns;
they are regression probes, not independent real-world validation. No separate
calibration set exists yet. Training occurs in this experiment, not production
command execution. TSV probe columns are group, relevant label, lexical score,
learned score, and document text; this is diagnostic output, not the CLI contract.

## Initial evidence, 2026-10-03

Apple M2 Pro, Rust 1.98.1, macOS ARM release build:

- Four module tests passed for input/weight validation, code/link signals,
  candidate independence/repetition, late content, empty hosts, and explicit limits.
- Two harness tests passed for positive/negative ordering and repeatable fitting
  with disjoint query strings. These do not establish generalization.
- The first measured fit took 0.377 ms; the long-file score took 0.539 ms.
  These are individual observations, not performance guarantees.
- The experimental executable was 409,952 bytes and linked only macOS libSystem.
  This is the full prototype size, not the size added to Cumaru.
- Cooking instructions scored 9.03 versus 0.60 for an explicit negated mention;
  identifier implementation scored 9.91; a relevant update paragraph scored 9.41
  versus 1.59 for its negated counterpart. Plain lexical coverage tied those
  positive/negated examples at 10.00.
- `renew credentials` versus token rotation scored only 1.23. Shared trigrams
  supply weak accidental overlap, not evidence that synonymous intent was learned.
- A subsequent smoke of the original Markdown corpus with `look for egg recipes`
  scored `eggs.md` at 10.00, `incidental.md` at 1.23, and `unrelated.md` at 0.00.
  Removing only the recipe file's `# Egg recipes` title reduced its score to 1.23.
  The current scorer therefore relies heavily on the explicit title and fails
  to recognize the same cooking content reliably without that lexical cue.

## Open quality gates

The heuristic negation window is not a parser: double negation, unrelated negation,
and headings in separate paragraphs can defeat it. Exact phrases and density
also require repetition/adversarial checks beyond current fixtures. No spelling,
case, or stop-list design is a settled public contract yet. Arbitrary paraphrases
remain weak. The current tests do not qualify this scorer for production.

Next: reviewed real query/file judgments, grouped teaching/calibration/holdout
splits, predefined quality thresholds, heading-versus-body tests, and a measured
comparison before command integration. See the [evaluation matrix](../evaluation.md).
