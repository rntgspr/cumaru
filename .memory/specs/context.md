---
name: context-and-models-specification
description: "Implemented offline context ranking and independent closed-catalog model cache management"
type: project
status: implemented
version: 1
---

# Context and models specification

## Purpose and public surface

`cumaru context QUERY` ranks visible project `.cumaru/` Markdown. Independent
`cumaru model list` and `cumaru model push NAME` manage optional encoders in
`~/.cumaru/NAME/`. Public arguments, budgets, output, and failure details are
canonical in [context](../../docs/context.md) and [model](../../docs/model.md).

## Invariants

1. Context is offline/read-only and emits only path/two-decimal score TSV.
2. A valid cached BGE Micro is preferred; absence permits the lightweight fallback;
   invalid present packages fail. There is no automatic download or model training.
3. The binary embeds a closed compatibility catalog, never pretrained weights.
   Model list/push read the GitHub catalog at one main SHA and reject entries whose
   exact metadata is unsupported by the binary. Artifact downloads pin the model SHA.
4. Shared model storage is independent of adopter config/domain/adapter selection.
   Legacy root contents, user version JSON, other models, and project files survive.
5. Complete verification precedes model publication. Valid identical installations
   are no-ops; invalid/different packages are preserved rather than replaced.
6. Context's scales remain experimental and backend-specific. Known weak paraphrases
   in fallback and positive encoder similarities for irrelevant content are not
   represented as calibrated semantic quality. BM25 remains an experiment only.

## Implementation map

| Artifact | Responsibility |
|---|---|
| `rust/src/commands/model.rs` | List/push CLI and reporting. |
| `rust/src/models.rs` | Closed catalog, cache safety, integrity/publication, offline encoder loading and token-aware inference. |
| `models/catalog.json` | Initial pinned BGE package metadata and compatibility inventory. |
| `rust/src/commands/context.rs` | Safe host inventory, backend choice, diagnostics, sorting, and TSV emission. |
| `rust/src/relevance.rs` | Dependency-free lexical features and compact numerical head. |
| `rust/src/distribution.rs` | Existing bounded cURL download shared by catalog/package reads. |
| `rust/src/walk.rs`, `tsv.rs` | Existing guarded traversal and TSV output. |

## Publication and recovery

Model push holds verified downloads in memory, then creates a private sibling
directory and publishes the complete package by rename. Existing destinations
are never intentionally replaced. Observed destination races are rejected; this
is not a filesystem lock or adversarial-race-proof transaction. Staging cleanup
is scoped to its own newly created directory. A failed publication can leave an
empty newly created cache root, but download/checksum failures write nothing.
No global installer, Git mutation, version metadata change, or project edit occurs.

## Verification and limits

On 2026-10-03, 81 native tests passed both serially and in default parallel execution,
with one explicit external-model
smoke ignored by default. That smoke was separately run with prepared pinned
artifacts: model installation into a scratch root, integrity validation, cached
CPU inference, and context ranking passed. It does not access the real home cache.

Disposable release CLI smokes used a stubbed main/catalog source to validate list,
unknown-name refusal before network access, help, offline fallback, repeated ranking,
TSV bounds/format/order, project byte preservation, and partial UTF-8/symlink failures.
Native unit tests cover closed/duplicate/incompatible catalogs, absence and invalid
packages, download/checksum non-mutation, complete/idempotent publication, legacy
root preservation, cache symlink refusal, and config-free fallback.

Locked local release build passed. The macOS ARM executable was 10,699,216 bytes,
with no model weights; its size is not a cross-platform guarantee. No real user
model cache or live catalog installation was modified. The new GitHub catalog is
not published by this task, so live list/push remain dependent on publication.
An actual read-only `model list` resolved main `cfc2664f189c3611a397c6507e8c9f17fc4676eb`
and returned the expected HTTP 404 for the absent catalog, with empty stdout.
Linux/musl and macOS x86 validation with these new dependencies remains unverified.
The existing historical fixture intermittency is not declared fixed by serial success.

Subsequent catalog availability, four-target compilation/testing, and published
binary evidence are recorded in [release verification](rust.md#release-verification).
Those distribution checks do not close the pending ranking-quality evaluation.

```bash
cargo test --manifest-path rust/Cargo.toml --locked -- --test-threads=1
cargo fmt --manifest-path rust/Cargo.toml --check
cargo build --manifest-path rust/Cargo.toml --release --locked
CUMARU_TEST_MODEL_ASSETS=/path/to/prepared-pinned-artifacts \
cargo test --manifest-path rust/Cargo.toml --locked commands::context::tests::cached_encoder_smoke -- --ignored --test-threads=1
```

## References

- [Context guide](../../docs/context.md)
- [Models guide](../../docs/model.md)
- [Native CLI contract](rust.md)
- [Plan and pending quality experiments](../plans/context/index.md)
