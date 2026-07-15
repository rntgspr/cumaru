---
name: virtual-tree-v6
description: "Plan: replace materialized structural indexes with filesystem-backed tree navigation and universal summaries"
status: planned
---

# V6: Virtual Tree Navigation

## Goal

Replace persisted structural index tables with a read-only projection:

```text
directory purpose: index.md
directory contents: cumaru tree
candidate meaning: summary
semantic links: domain-declared frontmatter and relational tags
```

The filesystem is the source of structural truth. Marker blocks retain only
adopter-owned semantic data and no longer duplicate directory children.

## Decisions

- Every `.cumaru/**/*.md` has a one-line `summary:` of 32 to 256 characters.
- A summary is a stable selection signal, not a status/progress snapshot.
  Operational metadata remains in frontmatter and is read after selection.
- `index.md` explains the directory's purpose and rules; `cumaru tree` lists
  its current children and their summaries.
- Normal navigation is shallow. `--deep` is for discovery and auditing.
- A file target resolves to its parent directory.
- The context hook injects only root/domain context. The LLM navigates
  explicitly through `index.md`, `cumaru tree`, and selected files.
- Semantic links are domain-declared. `depends-on` and `relates` are common,
  but domains may declare additional relations such as the vault graph fields.
- Tag bodies remain adopter-owned. Migration removes only versioned,
  framework-known structural inventories and preserves unknown/custom tags.
- The universal `cumaru-summarize` skill fills missing or invalid summaries
  across the installed tree without overwriting valid summaries by default.
- Major-version changes run only through an explicit, transactional migration.
  Steady-state `cumaru update --apply` cannot cross or downgrade a major.
- Migration supports only versions/domains with an explicit adapter and test
  fixture. Unknown layouts abort without writing.

## Regression Gates

Implementation cannot start until these behaviors are represented in the
tasks and fixtures below:

1. No tag body, custom schema contract, local file, or structural Description
   is discarded without a deterministic destination or an explicit blocker.
2. IaC and QA archive rows that survive directory cleanup are durable ledgers,
   not structural inventory. Migrate them to `absorptions` on `topology/` and
   `coverage/` before removing their archive tags.
3. Preserve `vault-memory`'s `relations` tag and every domain-declared graph
   field (`supports`, `contradicts`, `supersedes`, `part-of`, and peers).
4. Never install v6 schema/content with v5 skills, commands, or hooks, or the
   inverse. Content and agent artifacts cross the version boundary together.
5. Root `index.md`, `domain.md`, every non-hidden directory index, summaries,
   schema, retained tags, and hook wiring must validate before version 6 lands.
6. Tree traversal must not read through any symlink or emit candidates outside
   `.cumaru/`.
7. A failed migration restores both `.cumaru/` and framework-owned `.agents/`
   artifacts exactly; a second successful run is a no-op.

## T1: V6 Contracts

1. Bump every framework schema to `version: 6`.
2. Add `summary!` to `rules.markdown.frontmatter`.
3. Define `summary` as a non-empty YAML string, trimmed, with no CR, LF, or
   tab, between 32 and 256 Unicode code points.
4. Remove only tags whose sole source of truth is the direct child inventory
   of their host directory. Do not use a global tag-name allowlist.
5. Publish a versioned migration manifest per domain containing each removable
   `(host path, tag name)` pair. Unknown/custom tags are preserved and reported.
6. Retain semantic tags including `reference`, `files`, `files:touched`,
   `absorptions`, `components`, `root`, `relations`, and adopter-defined tags.
7. Define retained tag resolution explicitly. `reference` keeps its repository
   source-file contract; custom/prose/mixed tags remain opaque; undeclared tags
   are audited but never path-resolved as default tables.
8. Remove `generated-at!` from stable directory indexes, or redefine a concrete
   event that owns it. Do not retain a timestamp with no update semantics.
9. Rewrite the `__base` loading rule: schema defines contracts, filesystem
   defines candidates, and `cumaru tree` performs expansion.
10. State that semantic traversal follows fields and tags declared by the
    selected domain rather than a universal `depends-on`/`relates` allowlist.
11. Propagate all kernel changes verbatim to each domain and keep the existing
    distribution drift check green.

## T2: `cumaru tree`

1. Add `src/cmd_tree.sh`, source it from `cumaru`, and document its help.
2. Support `cumaru tree [<directory-or-md>] [--deep] [--rows]`.
3. Omitted target means the `.cumaru/` root. User paths are root-relative;
   reject absolute paths, `..`, and non-Markdown file targets.
4. In shallow mode, require `<target>/index.md`; list direct non-hidden
   Markdown children except that index, plus direct non-hidden directories
   represented by `<child>/index.md`. Deep mode may inspect a target without an
   index and reports that defect after completing the walk.
5. Emit directory paths with a trailing slash and file paths as `.md`, always
   relative to `.cumaru/`. Never emit `index.md` separately from its directory.
6. Normalize a Markdown-file target to its parent directory.
7. For `--deep`, recursively inspect every non-hidden Markdown descendant,
   including an invalid tree with missing indexes or summaries. Emit all valid
   candidates, report every invalid entry, and return non-zero after the walk.
8. Hidden means any path segment whose basename starts with `.`.
9. Emit deterministic Markdown `Path | Summary` by default and stable TSV
   `path<TAB>summary` through `--rows`, sorted with `LC_ALL=C`.
10. Escape Markdown pipes/backslashes. Reject control characters in candidate
    paths so TSV remains unambiguous; summary validation already rejects tabs
    and line breaks.
11. Read only frontmatter through mikefarah/yq; never load Markdown bodies.
    Missing or incompatible yq is a hard runtime error.
12. Reject every symlink target or discovered descendant, including broken and
    in-tree links. Canonicalize each candidate before reading frontmatter.
13. Keep diagnostics on stderr so `--rows` stdout remains pipeable.
14. Add `docs/tree.md`, CLI dispatch/help coverage, and `tree --help` outside a
    project.

## T3: Doctor Navigation Checks

1. Remove the table-based orphan check.
2. Require root `index.md`, `domain.md`, `schema.yaml`, every schema-declared
   pillar/path, and the pillar's own `index.md`.
3. Require `index.md` in every non-hidden directory under `.cumaru/`, not only
   pillar descendants. This includes templates, roles, disciplines, and local
   support directories. Attachment grouping directories follow the same rule.
4. Validate the full summary contract for every `.cumaru/**/*.md` as a hard
   error, including type, whitespace, controls, and length boundaries.
5. Keep file-reference validation only for declared retained tags. Unknown tags
   are reported by tag audit but are not inferred as default/path tables.
6. Fix reference validation ordering: containment and tag-specific validity
   precede existence, and a final symlink cannot escape the project root.
7. Define and test project-root semantics for `files`/`files:touched`, their
   canonical name, and intentionally removed files before carrying them to v6.
8. Detect source-known structural marker blocks left after migration.
9. Verify the installed context hook script, `.agents/hooks.json` wiring, and
   canonical instruction block, not only the instruction prose.
10. Keep `cumaru tree --deep` usable to inspect all failures before doctor is
    green.

## T4: Context Loading

1. Remove the universal context loader's `cumaru tag all --rows` discovery.
2. Inject only root `index.md` and `domain.md`; do not inject `schema.yaml` or
   selected tag targets at prompt submission.
3. Preserve valid JSON output for every supported agent target. Define a
   UTF-8-safe truncation policy and explicit diagnostics for missing root,
   domain, jq, or project context.
4. Refuse symlinked root/domain files that escape `.cumaru/`.
5. Document the traversal discipline: read a directory's `index.md`, run
   `cumaru tree <directory>`, prune by summary, then read one selected file.
6. Propagate the hook verbatim to every domain and retain drift verification.

## T5: Framework Content

1. Remove structural inventory marker blocks and schema declarations.
2. Remove instructions to re-emit structural index rows.
3. Replace manual child inventories that only duplicate directory structure
   with `cumaru tree` guidance; retain narrative and semantic links.
4. Add valid summaries to all framework-owned Markdown, including indexes,
   `domain.md`, templates, roles, and disciplines.
5. Add `index.md` to every non-hidden framework directory, including Base
   templates and each disciplines directory.
6. Keep framework source summaries canonical for fresh installs and migration
   fallback, but never overwrite a valid local summary mechanically.
7. Rewrite every skill and slash command that creates, moves, or removes an
   entity: mutate the filesystem, set a valid entity summary, and stop
   re-emitting structural rows.
8. Update `cumaru intake` to create a valid summary and preserve it on re-sync
   unless the workflow explicitly curates it.
9. Preserve semantic inventories: plan/task DAGs, tracker hierarchy, declared
   file roles, discipline triggers, attachment files, components, references,
   graph relations, and absorption ledgers.
10. Add `absorptions: [SHA, KEY, Description]` to `topology/index.md` and
    `coverage/index.md`; update IaC/QA archive recipes and resolve their current
    durable-row versus transient-archive documentation conflict.
11. Update `cumaru-arch` and every recursive durable-pillar recipe to navigate
    with shallow traversal or explicit `cumaru tree --deep`, rather than a
    flattened root table.
12. Preserve Vault relation fields/tags and define how non-Markdown attachments
    are described by their containing indexed directory.

## T6: `cumaru-summarize`

1. Add the universal LLM skill.
2. Mirror it verbatim into every domain so install/update and drift checks treat
   it as a universal artifact.
3. Traverse every Markdown path reported invalid by doctor, including local
   root-level support directories, not only schema-declared pillars.
4. Curate leaf summaries before directory-index summaries.
5. Fill missing/invalid summaries. Preserve valid summaries by default and ask
   before replacing one whose meaning is stale or misleading.
6. Modify only `summary`; never alter bodies, paths, status, or semantic links.
7. Enforce the summary contract and run doctor when complete.

## T7: Update Version Gate

1. Read both local schema version and root `framework-version`; refuse when
   they disagree.
2. Allow steady-state apply only when source and local major versions match.
3. On source greater than local, allow an informational dry-run but refuse
   `--apply` and point to `cumaru migrate v6`.
4. Refuse source lower than local as a downgrade.
5. Keep `cumaru update schema --apply` explicitly destructive, but never use it
   as the v6 migration mechanism.
6. Add each supported pre-v6 to v6 procedure to `cumaru-update` and update
   documentation.

## T8: Pre-V6 Migration

1. Extend `cumaru migrate` with `cumaru migrate v6 [--from <src>] [--apply]`.
   Dispatch this target before the current `.cumaru exists` rename short-cut.
2. Default to a complete dry-run: detected version/domain, removable manifests,
   summary sources, schema changes, ledgers, missing indexes, agent artifacts,
   and blockers.
3. Detect version and domain explicitly. Compose the legacy `.llm` rename only
   when unambiguous. Unsupported versions, layouts, or custom domains without a
   v6 source/adapter abort before writes.
4. Merge schema contracts rather than replacing the schema. Preserve all local
   `root.entities`, tags and their types/hosts, rules, unknown `meta` regions,
   domain identity, and adopter values, including but not limited to
   `meta.apps.values`, `meta.specification_dir`, and `meta.coverage`.
5. Build each summary before removing its structural row, in priority order:
   existing valid summary; stable semantic prose from the old row Description;
   matching v6 framework summary; otherwise mark for LLM summarization and
   block completion. Treat descriptions dominated by status, progress, apps,
   or dependency snapshots as review candidates, not automatic summaries.
6. Report stale, duplicate, ambiguous, short, and conflicting structural rows.
   Do not remove a block until every non-template row is accounted for.
7. Migrate IaC/QA durable archive rows to their new absorption ledgers before
   deleting the structural archive blocks. Preserve Vault relations unchanged.
8. Inventory every directory lacking `index.md`. Create one only when a
   versioned adapter provides a deterministic mapping; otherwise block.
9. Remove only manifest-listed structural marker blocks. Preserve every other
   tag body, local-only file, and local prose byte-for-byte during migration.
10. Stage the transformed `.cumaru/` tree and framework-owned `.agents/`
    artifacts outside their live paths. Preflight tools, containment, free
    paths, and collisions before any swap.
11. Install matching v6 skills, commands, context hook, hook wiring, and
    instruction block while preserving adopter-owned agent artifacts.
12. Validate schema, summaries, indexes, tags, coverage/reference behavior,
    agent wiring, and doctor against the staged result.
13. Write schema version and `framework-version: 6` last, then swap staged paths
    under a rollback journal. Restore both project and agent paths on any
    failure and remove staging.
14. A rerun is a no-op only when all v6 postconditions pass, not merely when the
    version field equals 6.
15. Update migration docs and the universal update/migrate recipes.

## T9: Verification

1. Add a single non-interactive shell test entry point and fixtures; run it on
   macOS/Bash 3.2-compatible userland and Linux/GNU userland.
2. Test tree dispatch, default/absolute/relative/file targets, shallow/deep
   output, hidden policy, missing indexes, invalid summaries, sorting,
   Markdown/TSV escaping, stdout/stderr separation, and exit codes.
3. Test direct, intermediate, descendant, broken, cyclic, in-tree, and escaping
   symlinks. No candidate may be read before containment succeeds.
4. Test summary types and boundaries: null/bool/number, whitespace, controls,
   folded/literal YAML, 31/32/256/257 code points, and multibyte Unicode.
5. Validate all framework schemas, summaries, indexes, retained tags, universal
   mirrors, and framework Markdown before install.
6. Smoke-test every domain in a real bench: install, shallow/deep navigation,
   nested branches, domain semantic links, doctor, coverage, and minimal hook.
7. Add domain regression fixtures for IaC/QA durable archive rows, Vault
   relations/attachments, SDLC absorptions, custom tags/types/rules/pillars,
   local-only files, and root-level support directories.
8. Test every supported pre-v6 version/domain adapter, legacy rename composition,
   unknown layouts, schema extensions, summary conflicts, partial failures,
   rollback, byte-idempotent reruns, update-before/after, and downgrade refusal.
9. Fault-inject each migration phase and verify both `.cumaru/` and `.agents/`
   restore exactly.
10. Update README, architecture, tree, doctor, tag, flow, coverage, intake,
    install, update, migrate, upgrade, CLI help, every affected skill/command,
    and the manual smoke-test process.
