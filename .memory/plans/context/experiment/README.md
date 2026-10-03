# Embedded context feasibility experiment

This isolated crate compares two English cross-encoders without changing the
production CLI or its dependencies. Models and tokenizers use `include_bytes!`;
only an inference invocation initializes Tract. `--identity` returns before
tokenizer construction or model parsing. Model downloads happen during preparation,
not invocation. The artifact directory is outside the repository.

## Reproduce

Run from the repository root:

```bash
bash .memory/plans/context/experiment/fetch-assets.sh /tmp/cumaru-context-assets
CARGO_HOME=/tmp/cumaru-context-cargo \
CUMARU_CONTEXT_ASSETS=/tmp/cumaru-context-assets \
cargo build --release --locked --manifest-path .memory/plans/context/experiment/Cargo.toml
bash .memory/plans/context/experiment/bench.sh /tmp/cumaru-context-bench
CARGO_HOME=/tmp/cumaru-context-cargo \
CUMARU_CONTEXT_ASSETS=/tmp/cumaru-context-assets \
cargo test --release --locked --manifest-path .memory/plans/context/experiment/Cargo.toml
```

`CUMARU_CONTEXT_ASSETS` selects build-time inputs only. `CARGO_HOME` keeps new
dependency downloads in scratch storage. `CUMARU_CONTEXT_BINARY` optionally selects
a cross-target executable for the bench. `CUMARU_CONTEXT_FRAGMENTATION=sections`
enables the experimental literal heading cuts; the default prefers paragraphs.

The TSV fields are file, document token count, fragment count, maximum raw logit,
mean raw logit, experimental sigmoid integer, and total inference milliseconds.
Metrics on stderr include input names, initialization milliseconds, and peak RSS
in OS-native units (bytes on macOS). Inference timing excludes tokenization and
model initialization. Initialization includes tokenizer setup, query encoding,
ONNX parsing, optimization, and runnable construction. These are exploratory
measurements, not statistical benchmarks.

Seven synthetic Markdown files include prose, code identifiers, links, and an
incidental cooking phrase. The link in `corpus/auth.md` is intentionally synthetic.
The bench generates two long documents with 200 database paragraphs, followed by
either an incidental mention or actual egg recipes. All files are explicit inputs;
this crate does not implement safe project inventory or a production command.

Both candidates use BERT pair IDs `[CLS] query [SEP] document [SEP]`, with their
shared tokenizer, three I64 inputs, and one F32 logit. Experimental limits are
64 query tokens, 16,384 document tokens, and 512 total pair tokens. Oversized
documents fail explicitly. Windows overlap by 32 tokens; section boundaries do
not overlap. Empty documents retain one empty fragment. Literal heading cuts
also recognize heading-like lines inside code fences; this is not a semantic
Markdown section parser. No preprocessing strips code or links, although the
model's own uncased WordPiece tokenizer normalizes text.

## Recorded evidence

[Feasibility findings](../feasibility-results.md) own the decisions and limits.
Raw observations are retained in [evidence/](evidence/); generated long fixtures
can be reproduced by `bench.sh`. Model binaries are not committed.
