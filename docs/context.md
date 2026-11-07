# `cumaru context`

Rank visible Markdown inside the current project's `.cumaru/` against an English
query. It is offline, never changes knowledge files, needs no config or summaries, and returns
paths and scores rather than generated text or retrieved fragments.

```bash
cumaru context "look for egg recipes"
cumaru context --full "look for egg recipes" # every ranked file, not the best 16
cumaru context --warm          # build or refresh the vector cache only
cumaru context --reset [QUERY] # delete and rebuild the vector cache
```

Output is headerless TSV: a [`cumaru get`](get.md) selector, then a score from
`0.00` to `10.00` with exactly two decimal places, the same selector form that
[`cumaru map`](map.md) prints:

```text
disciplines/kiss.md:9,28	6.80
index.md:14,41	6.12
```

With the encoder, the range is the innermost `map` section containing the paragraph whose chunk scored best (the paragraph itself before any heading); with the
lightweight scorer it is the whole file (`path:1,N`), and an empty file prints
its bare path. Sort order is descending displayed score, with byte-order
selectors for ties; only the best 16 rows print unless `--full` is given. A Markdown `index.md` is evaluated like every other visible
host. A QUERY is required unless `--warm` or `--reset` is given (status 2).

## Backend selection

- Enabled, valid `~/.cumaru/bge-micro-v2/`: verify the local manifest, sizes, and checksums,
  then load the encoder with Candle on CPU.
- No supported package or an explicitly released package: use the original compact lexical/numerical scorer.
- Present invalid, damaged, or incompatible enabled package, unsafe cache paths,
  or an invalid release marker: fail explicitly;
  never silently switch to fallback.

The selected backend is reported on stderr. `context` downloads nothing. Install an optional encoder explicitly with
[`cumaru model pull`](model.md). `cumaru model release` restores lightweight ranking
without deleting cached files; pull verifies and re-enables them. Other commands
do not initialize inference.

## Vector cache

With the encoder enabled, vectors are cached per chunk in
`.cumaru/.cache/context/<model>@<revision>.v<format>.json`. Each chunk is keyed
by the SHA-256 of the exact token IDs fed to the model, so unchanged paragraphs
are reused across edits, renames, and documents, edited paragraphs are
re-embedded, and chunks no longer present are pruned. A chunking or tokenizer
change produces new keys on its own; a model or format change uses a new file,
and files for other models or formats are removed on save. A missing,
unreadable, or mismatched cache is rebuilt silently; a failed save only warns
on stderr. Rankings are identical with or without the cache. Hidden paths are
never ranked, so the cache never appears in results.

Building is reported on stderr, so stdout stays pure TSV: a start notice, one
line per file that needed new embeddings, and a summary. On a terminal the
per-file line is rewritten in place.

```text
cumaru context: building vector cache in .cumaru/.cache/context/
cumaru context: [  1/119] disciplines/acceptance-testing.md (+8 chunks)
cumaru context: cached 992 chunks (992 new from 119 files) in 22.1s
```

`--warm` builds without ranking and reports `vector cache is up to date` when
nothing changed; without an enabled encoder it reports that there is nothing to
cache and exits 0. `--reset` deletes `.cumaru/.cache/context/` first.
`cumaru update --apply` warms the cache after a successful publication or an
up-to-date check, warning instead of failing.

When it writes the cache, `context` appends this entry to the project
`.gitignore`, creating the file if needed, unless a line already names
`.cumaru/.cache/`, active or commented out. Comment the line to version the
cache:

```text
# Cumaru local cache (context vectors); comment out the next line to version it.
.cumaru/.cache/
```

On a 119-document, ~300 KB tree (991 unique chunks, 4.5 MB cache), the first
encoder run took ~22 s, later runs ~0.22 s, and a one-paragraph edit ~0.24 s.

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
