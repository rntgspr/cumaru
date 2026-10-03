---
name: cumaru-first-compact-cli-manual
description: Make cumaru-first a compact agent manual for every native command, context ranking, and optional model installation
status: open
priority: high
---

# Issue 137: Review cumaru-first as a compact native CLI manual

[GitHub issue 14](https://github.com/rntgspr/cumaru/issues/14).

`cumaru-first` currently provides a partial surface map. It omits the implemented
`context` and `model` families and incorrectly says installation previews unless
`--apply` is present. Claude will implement this review after the native context
and model changes are available; this issue does not implement the discipline.

## Risk

- Agents miss relevance ranking or optional models and load unnecessary context.
- An agent confuses model downloads, project installation, and global binary upgrade.
- A verbose or stale discipline competes with canonical command contracts.

## Required invariant

The eagerly loaded universal `cumaru-first` discipline is a compact, accurate
agent-facing manual for choosing and composing all 16 native command families.
It teaches bounded knowledge discovery and explicit model installation without
duplicating full command documentation, inventing capabilities, or bypassing
ownership, evidence, and existing authorization boundaries.

## Work

1. Inspect native dispatch/help, current command implementations, public guides,
   and the installed bootstrap contract. Review `version`, `tree`, `map`, `fs`,
   `tag`, `coverage`, `doctor`, `install`, `uninstall`, `bootstrap`, `migrate`,
   `update`, `upgrade`, `help`, `context`, and `model`. Keep one compact surface
   map with actionable command forms and pointers to canonical workflows.
2. Explain when relevance ranking, candidate summaries, or heading maps are useful.
   Preserve kernel/domain/discipline bootstrap order and bounded body loading.
   `context` emits path/score TSV, not generated text; it is offline/read-only and
   uses a cached encoder or the lightweight fallback. Scores are experimental,
   backend-specific, and never proof that requirements or acceptance are satisfied.
3. Teach `cumaru model list` and `cumaru model push <catalog-name>`: a fixed GitHub
   catalog, explicit download into `~/.cumaru/<name>/`, no pretrained weights in
   the executable, no Python/server/GPU requirement, and no download during queries.
   `push` downloads; it does not upload. Valid cached models are verified locally;
   invalid present packages fail rather than silently selecting fallback. Reuse
   existing scope authorization and preserve legacy cache contents.
4. Correct mutation distinctions. Install writes after preflight; update normally
   previews, apply writes, and clear removes immediately. Config reconciliation,
   migration instruction delivery, coverage, and doctor are read-only. Uninstall
   removes adopter knowledge under its explicit confirmation contract. Global
   upgrade replaces the CLI and is separate from project update and model download.
5. Keep native arguments/output accurate: TSV navigation, literal H1-H6 map,
   opaque tags, stateless explicit adapters, pinned main sources, independent
   CLI/config identities, and no retired flags or unsupported commands. Skills
   own semantic workflows; commands do not replace role routing or source tools.
6. Edit only the canonical base discipline and directly affected docs/specs.
   Preserve applicability and strictness metadata, then synchronize universal
   mirrors through the maintenance script. Avoid installing frameworks, models,
   or adapters into real projects or the actual home cache as verification.

## Tests

- Native help and documented forms agree for all 16 command families.
- Semantic review covers installed/no-model/invalid-model context selection;
  ranking-to-bounded-reading; discovery outside an adopter; explicit model download;
  update preview/apply/clear; install; migration routing; and destructive cleanup.
- Negative review catches automatic downloads during queries, treating scores as
  calibrated truth, invoking source edits through Cumaru, and granting new mutation
  authority merely because a discipline was loaded.
- Formatting, native tests, and `scripts/sync-domain-kernel.sh --check` pass.
  Deterministic text/mirror checks prove artifact contracts, not live LLM behavior.

## References

- [Canonical discipline](../../domains/__base/disciplines/cumaru-first.md)
- [Native CLI dispatch](../../rust/src/main.rs)
- [Context guide](../../docs/context.md)
- [Model guide](../../docs/model.md)
- [Model catalog](../../models/catalog.json)
- [Native CLI specification](../specs/rust.md)
- [Context/model specification](../specs/context.md)
- [Discipline loading contract](../specs/disciplines.md)
- [Mirror synchronization](../../scripts/sync-domain-kernel.sh)
