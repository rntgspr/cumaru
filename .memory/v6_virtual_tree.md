---
name: cumaru-v6-virtual-tree
description: "Canonical v6 state: filesystem-backed navigation, summaries, transactional migration, and same-major updates"
type: project
status: implemented
---

Version 6 replaces persisted structural index tables with a read-only filesystem projection.

## Canonical model

- The filesystem is structural truth; marker blocks never inventory directory children.
- Every non-hidden directory has an `index.md` describing its purpose and rules.
- Every Markdown file has a stable `summary:` string of 32–256 Unicode code points.
- `cumaru tree [<directory-or-md>] [--deep] [--rows] [--pillars <names>] [--domain <name>]` lists candidates and summaries without loading Markdown bodies. Pillars restrict traversal; domain is an installed-contract guard.
- Shallow traversal is the normal loading path. `--deep` audits the complete tree and reports all navigation defects.
- Tree traversal rejects all symlinks, hidden paths, absolute paths, `..`, and candidates outside `.cumaru/`.
- Semantic tags remain adopter-owned. The schema declares `default`, custom-column arrays, `prose`, `mixed`, or `other`; retained tags include `reference`, `files`, `touched`, `absorptions`, `components`, `root`, and vault relations.
- Durable absorption ledgers use `SHA | KEY | Description` in `specs/index.md`, `topology/index.md`, or `coverage/index.md`; archive directories are transient staging only.

## Loading and doctor

- The context hook injects only `.cumaru/index.md` and `.cumaru/domain.md`.
- The LLM reads a directory index, runs `cumaru tree`, prunes by `summary:`, and loads only selected candidates.
- `cumaru doctor` accepts only v6 trees and runs seven checks: navigation indexes/summaries, retired or unknown marker contracts, stale work markers, RAW blocks, retained file references, external tools, and the schema-selected agent adapter. Pre-v6 trees are directed to `cumaru migrate v6`; the migration adapter does not invoke doctor.
- Structural orphan-table validation is gone; filesystem navigation replaces it.

## Migration and update

- `cumaru migrate v6 [--from <source>] [--apply]` is the only supported v5→v6 path.
- Migration is dry-run by default, uses `domains/<domain>/migrations/v5-to-v6.tsv`, derives summaries before removing structural tags, normalizes the former namespaced touched-file marker to `touched`, preserves unknown tags and local content, and swaps `.cumaru/` with framework-owned `.agents/` artifacts transactionally.
- `cumaru update --apply` is steady-state only: it refuses major-version crossings and downgrades.
- Framework-owned Markdown is rebuilt from the canonical source while marker bodies are captured and restored. Local-only files remain adopter-owned. `--keep-prose` is the explicit local-divergence escape hatch.
- Skills, durable instructions, and supported commands are framework-owned and refreshed deterministically in the schema-selected adapter paths.

## Repository layout and shipped surface

- Domain sources live under `domains/`, not `frameworks/`.
- Shipped domains: `base`, `sdlc-full` (default), `sdlc-light`, `iac-basic`, `qa-basic`, `vault-memory`.
- Universal skills: `cumaru-doctor`, `cumaru-update`, `cumaru-refs`, `cumaru-summarize`; `cumaru-install` remains domain-owned.
- New CLI surface includes `cumaru domains`, `cumaru tree`, and the v6 migration target.
- Regression coverage lives under `tests/` for tree, doctor, context, migration, summaries, intake layout, and update version gates.

## Completion record

- IaC and QA archive flows use durable `absorptions` ledgers on `topology/index.md` and `coverage/index.md`; archive entities are transient.
- All domain kernels and universal artifacts were checked byte-identical to `__base`.
- Focused validation covered Bash syntax, kernel drift, ledger schemas, tree filters, v6 doctor behavior, and whitespace checks. The doctor suite passed 33 assertions after the v6-only gate was introduced.
- SDLC templates use neutral `<app>`, `<app-a>`, and `<app-b>` placeholders instead of project-specific application names.
- The complete v6 package was committed on `main` as `5e791b4 💥 ship v6 filesystem-backed navigation`; the worktree was clean afterward and no push was performed.

Canonical references: [`README.md`](../README.md), [`docs/architecture.md`](../docs/architecture.md), [`docs/tree.md`](../docs/tree.md), [`docs/doctor.md`](../docs/doctor.md), [`docs/migrate.md`](../docs/migrate.md), and [`docs/update.md`](../docs/update.md).
