---
status: implemented
summary: Independent closed GitHub model catalog and explicit downloads into the user's Cumaru model cache.
---

# Independent model management

Implemented contract and verification are canonical in
[context and models](../../specs/context.md). Live catalog publication remains
outside this task; the work below records the implementation scope.

## Public surface

```text
cumaru model list
cumaru model push <catalog-name>
cumaru context "query"
~/.cumaru/<catalog-name>/
```

`push` means download and install locally, not upload. Model management is a
top-level command family, not a context subcommand. It works without an adopter
tree and creates no project knowledge, adapter files, or global CLI installation.

## Ownership and boundaries

1. The repository owns a fixed catalog on GitHub, with explicitly supported names.
   A candidate canonical surface is `models/catalog.json`. No arbitrary URLs,
   Hugging Face names, directory imports, or user-defined catalog extensions.
2. Each entry pins artifact revisions, HTTPS downloads, byte sizes, SHA-256,
   license/source attribution, architecture, tokenizer, pooling, and input limits.
   Runtime support must exist in the binary; catalog presence alone cannot add
   an arbitrary architecture. Resolve catalog reads to one main commit.
3. `list` reads the remote catalog without loading inference, installing files,
   or requiring `.cumaru/`. Failure reports no invented model inventory.
4. `push <name>` accepts only a catalog name and explicitly downloads its complete
   verified package into the invoking user's `~/.cumaru/<name>/`. Other models,
   legacy snapshots, symlinks, and unrelated files must not be overwritten.
5. This user's `~/.cumaru` was absent when inspected on 2026-10-03. The implementation
   must not assume that for other users; a legacy installation or symlink requires
   safe handling rather than deleting or replacing the root.
6. Download and verification precede publication. Failed downloads/checksums must
   leave any existing usable model intact. Retain a local validated manifest so
   inference is offline and can verify the installed package without a catalog fetch.
7. Only explicit `model push` performs model downloads. Neither `context` nor
   ordinary Cumaru commands install or refresh weights automatically. No pretrained
   encoder bytes belong in the distributed executable.

## Initial selection boundary

Start with the BGE Micro candidate already exercised in the comparison; its exact
catalog name and approved packaging belong to implementation. Keep the initial
catalog deliberately small. Optional models must be verified locally before use.

`context` uses a compatible installed encoder or, when none is installed, the
original lightweight scorer. A present but invalid package returns an explicit
error. The backend name may be reported on stderr, leaving ranking TSV unchanged.
The two scoring scales still need calibration; identical formatting does not imply
identical numerical meaning.

The first catalog can contain one supported encoder. Before adding multiple usable
models, define deterministic model selection or an explicit user preference; neither
directory iteration order nor an arbitrary downloaded folder selects a backend.

## Implementation shape

- `commands/model.rs` owns CLI list/push orchestration.
- A shared model module owns catalog validation, safe cache paths, verified
  artifact publication, local discovery, and supported runtime profiles.
- `commands/context.rs` owns query collection and ranking; it consumes the shared
  model module without owning model storage or catalog policy.
- Global version/config and legacy CLI upgrade behavior remain separate contracts.
  A model install must not rewrite installation-version metadata.

## Verification

- List works outside an adopter and performs no inference or model writes.
- Unknown names and unsupported architectures fail before publication.
- Downloads and metadata pin one catalog revision; checksum and interrupted-read
  failures preserve an existing usable model.
- Cache roots and packages with unsafe paths or symlinks fail without deleting
  legacy/adopter state. Repeated same-version installation is safe.
- Context uses cached weights offline, falls back only on absence, and reports
  present invalid packages. Other commands initialize no encoder.
- Tests use scratch cache roots and stubbed catalog/artifact reads, never the real
  home directory or a global CLI upgrade.

## References

- [Current ranking acceptance contract](index.md)
- [Encoder comparison and artifact hashes](comparison.md)
- [Native distribution implementation](../../../rust/src/distribution.rs)
