---
summary: Prose-and-config plan to keep multi-document company knowledge in vault-memory free of duplicates, synonym drift, and unresolved conflicts.
---

# Vault-memory disambiguation

## Goal

Ingesting several documents from one organization must converge on one node
per fact. Today the domain records duplicates and conflicts
(`similar-to`, `contradicts`) but neither prevents nor resolves them.

## Scope

- In scope: `domains/vault-memory/` skills, templates, role, and `config.yaml`.
- Out of scope: Rust. Native doctor checks are listed under
  [Deferred native checks](#deferred-native-checks) as future issues.
- Every edit lands in `domains/vault-memory/`; universal `__base` artifacts are
  untouched, so `scripts/sync-domain-kernel.sh --check` must stay clean.

## Verified constraints

- Doctor checks frontmatter presence only; `optional: true` lifts it. There is
  no value or enum validation ([doctor](../specs/doctor.md),
  [configuration](../specs/configuration.md) rule 4). Allowed values for
  `status` and `authority` therefore live in prose and `meta`, not in the
  schema.
- Adding optional frontmatter keys is additive inside `version: 9`. Adopters
  receive it through `cumaru update config` candidate reconciliation, not
  `cumaru migrate` ([update design](../disciplines/update_design.md)).
- `cumaru-capture` already moves retained sources to `attachments/`
  (`domains/vault-memory/skills/cumaru-capture/SKILL.md:37`).
- `cumaru-link` asks for reciprocal edges but nothing verifies them
  (`domains/vault-memory/skills/cumaru-link/SKILL.md:29`).

## Phases

Phases 1 to 3 remove ambiguity; 4 to 6 add authority, time, and bulk intake.

1. **Search before write** (`cumaru-distill`). Add a step before the current
   step 2: run `cumaru context "<subject>"` and `cumaru tree memories`, then
   decide `same subject -> update`, `neighbor -> similar-to`, or `new`, and
   record the decision in `## Notes`.
2. **Term identity.** Add `aliases: {optional: true}` to `memories/*`, a
   `type: term` documented in `domain.md`, and `templates/term.md` (definition,
   explicit non-synonyms, canonical node). `cumaru-distill` resolves every term
   through aliases before creating a node.
3. **Conflict status.** Add `status: {optional: true}` with prose values
   `canonical | disputed | superseded`. `cumaru-link`: a `contradicts` edge
   sets both sides `disputed`; resolution marks one `canonical` and the other
   `superseded` with `superseded-by`. `keeper.md` graph hygiene lists open
   `disputed` nodes.
4. **Source authority.** Declare the ordered authority ranking (for example
   `policy > handbook > wiki > notes`) as prose in `domain.md`, inside a new
   `<!-- cumaru:authority -->` tag body so each vault sets its own order and
   update preserves it. Register it in `config.yaml` as
   `domain.md: {framework: true, tags: [components, root, authority]}`;
   `tags` is a free name array (`$defs/tagName` in
   `schemas/config.schema.json`), so no schema change. Add
   `authority: {optional: true}` on memories and drafts. `cumaru-distill`
   resolves conflicts by rank and asks the user only on equal rank. `meta` is
   closed (`additionalProperties: false` in `schemas/config.schema.json`), so
   the ranking stays out of config to avoid a schema change.
5. **Validity in time.** Add `valid-from` / `valid-until` optional fields.
   Outdated rules become `superseded` with `valid-until`, never deleted.
6. **Bulk ingest with span provenance.** A `cumaru-capture` bulk mode (prefer
   over a new `cumaru-ingest` skill to avoid a new workflow surface) keeps the
   source document under `attachments/`, walks it section by section with
   `cumaru map`, and writes `derived-from` as
   `attachments/<doc>/index.md:<start>,<end>`.

## Status

Phases 1 to 6 are implemented in `domains/vault-memory/` (prose, templates,
`config.yaml`). Remaining: the deferred native checks below, and the adopter
note that installed vaults must add `<!-- cumaru:authority -->` to `domain.md`
after `cumaru update config`. The pre-existing missing `relations` tag was fixed
(spec `domains.md` Invariant 19).

## Deferred native checks

Tracked by [issue 177](../issues/issue_177.md):

- Alias collision: two nodes claim the same alias.
- Open conflicts: `disputed` without resolution; `superseded` without
  `superseded-by`.
- Edge reciprocity for `contradicts`, `similar-to`, `supersedes` /
  `superseded-by`.

## Verification

- `cumaru doctor` on a scratch install of the vault-memory domain.
- `scripts/sync-domain-kernel.sh --check` reports no drift.
- Manual run: three overlapping documents yield one node per fact, one `term`
  per concept, and no `disputed` node left without an owner decision.
- Update `durable-memory/specs/domains.md` vault-memory profile when done.
