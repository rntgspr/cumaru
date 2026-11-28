---
name: domains-specification
description: "Self-contained v9 domain sources, universal mirrors, installation, and explicit adapter targets"
type: project
status: implemented
version: 9
---

# Domains specification

## Purpose

Define how Cumaru packages one self-contained knowledge model per domain and
installs exactly one validated domain plus one agent adapter into a project.

The [native installer](rust.md#project-installation) records the detailed
main-HEAD resolution, selection, preflight, and publication. It uses `__base`
by default and materializes remote content from the domain config instead of
copying a complete domain.

The [native domain catalog](rust.md#native-help) discovers HEAD of GitHub
main instead of a local source snapshot, without requiring an adopter tree.

## Public surface

```text
cumaru help domains
cumaru install [agent <none|claude|codex|opencode>] [--domain <name>]
cumaru bootstrap
cumaru update skills <agent> --with <skill>...
domains/__base/
domains/{sdlc-full,sdlc-light,design-as-code,iac-basic,qa-basic,vault-memory,focus,homebrew-management,ai-ccn}/
```

## Invariants

1. A domain is self-contained; installation does not merge or inherit domain
   trees at runtime. `base` resolves to `domains/__base/`.
2. Each source `config.yaml` validates against the global v9 model and names
   its domain, integer version, global rules, direct `root` tree, metadata,
   and optional named skill workflows.
3. Kernel `index.md`, universal skills, universal commands, and universal
   disciplines are authored in `__base` and mirrored byte-identically, except
   declared domain-owned artifacts such as `cumaru-install` and indexes.
4. A domain author declares a pillar whose entries are directories with an
   entry selector, never with a wildcard child file key that also matches the
   entry's own `index.md`, because the resolver keeps every entry `index.md`
   under `rules.index_md` and `rules.pillar_index` alone. Rejecting such a
   wildcard with leaf `tags` at source validation has no native owner yet
   ([issue 172](../issues/issue_172.md)). A domain that expects the adopter to name real
   entries ships the pillar with no child key, as `focus` does for `outcomes`:
   the adopter then adds keys, which is additive and reports no drift, instead
   of replacing a shipped key. Replacing one is also accepted when the new keys
   are more specific stand-ins the shipped glob would have matched; see the
   [configuration specification](configuration.md) for that asymmetry.
5. Domain-specific pillars, roles, lifecycle, skills, and commands live only
   in that domain. `domain.md` carries domain semantics.
6. Install validates the selected source before project writes, materializes
   only the structure its config describes, never places source-only
   skills/commands/migration and bootstrap prose in `.cumaru/`, then installs
   native artifacts separately. Optional skills are outside install; they are
   added through `update skills <agent> --with <skill>`.
7. An omitted install adapter means generic; explicit targets are `claude`,
   `codex`, and `opencode`. Adapter choice is not persisted in config.
8. Every `commands/cumaru/<name>.md` requires a regular
   `skills/cumaru-<name>/SKILL.md` in the same source domain. Commands are thin
   argument-forwarding launchers; skills own every workflow recipe.
9. Shipped domain and auxiliary skills keep inspection separate from mutation.
   Drift or refresh inspection uses a non-mutating plan, and writing reconciled
   infrastructure state is a separate reviewed and authorized action. No domain
   ships release orchestration or Git conflict resolution, and no skill loads a
   project `.env`. Runner guidance keeps Cypress video and Playwright retries
   disabled by default and reports only artifacts actually produced.
10. `focus` declares signal intake in its `sources` pillar: one lowercase-slug
    file per data source under `.cumaru/sources/`, created from
    `templates/source.md`, describing read-only access. Doctor requires each
    source leaf's `summary` and `status`; the `root` tag keeps adopter intake
    policy.
11. `focus` ships `cumaru-sources` with a namesake `/cumaru:sources` command: it
    reads active sources strictly read-only, creates or updates threads through
    `cumaru-thread` under the active directives, and reports per source what
    was read, created, updated, unmatched, and unavailable.
12. A domain may ship a source-only, prose-only `bootstrap.md` at its root with
    the ordered post-install steps; `domains/__base/bootstrap.md` holds the
    universal rules. It is never copied into `.cumaru/`. The read-only
    `cumaru bootstrap` prints the base body then the installed domain body,
    frontmatter stripped, and fails with a diagnostic for a missing config or
    unknown domain. A domain's `cumaru-install` skill points to it instead of
    restating steps. `focus` ships one naming every pillar and template; other
    domains follow later.
13. The `focus` bootstrap runs sources first (proposed from the tools actually
    available, written only once confirmed, unreachable ones reported as
    unavailable), then directives (stated by the user or drafted from the
    confirmed sources as `proposed` and unranked), then outcome areas, then an
    optional adopter-owned presentation skill in the agent skill directory,
    named without the `cumaru-` prefix, that reads active threads and builds a
    derived asset without editing them. Framework `__base` rules allow a
    domain step to propose; nothing is written unconfirmed.
14. `focus` ships `templates/directive.md` carrying every field and section
    the directive contract requires; `directives/index.md` and
    `cumaru-directives` reference it instead of restating its sections.
15. Each `focus` outcome ledger item carries a kudos count. The
    [outcome contract](../../domains/focus/outcomes/index.md#kudos-per-item) owns
    initialization, evidence, deduplication, and preservation; the outcome
    template and skill expose it without changing value, work, or policy totals.
16. Each `focus` thread separates `Next action`, `Context`, `Waiting on`, and
    `Evidence` without repeating a fact, records material claims as evidence
    rows with occurrence and observation dates, author, excerpt, source, and
    confidence, and appends one `Coverage` row per source-reading run. The
    [thread contract](../../domains/focus/threads/index.md#evidence-per-claim)
    owns placeholder removal, deduplication, and provenance-preserving
    compaction; `cumaru-thread` and `cumaru-sources` apply it, and the focus
    `cumaru-doctor` skill adds a semantic review of what `cumaru doctor`
    cannot check structurally.
17. `homebrew-management` models one Homebrew tap. `formulae/<name>/` and
    `casks/<token>/` are durable entities created from `templates/formula.md`
    and `templates/cask.md`; each records what the Ruby does not say, never a
    version or checksum, and points at its `Formula/<name>.rb` or
    `Casks/<token>.rb` through `reference` rows. `meta.specification_dir` lists
    both pillars so `cumaru coverage` checks every package file. The shipped
    `release/bump.md` is a procedure document, not orchestration: the domain
    ships no bump skill or command, consistent with invariant 9. The
    `package-change` discipline gates every `.rb` change on downloaded-artifact
    checksums and tap-clone audit, install, and test.
18. `ai-ccn` models one Content Creator Network of AI characters and agents.
    `constitution.md` ships as starter governance text and is adopter-owned,
    so update never replaces it. `creator/<creator_slug>/` holds one profile
    from `templates/creator.md`; doctor requires its `slug` and `post-prefix`
    frontmatter, the latter a unique three-letter uppercase post prefix; `posts/` declares the entry selector `<PREFIX>-<four digits>` for
    plans from `templates/post.md`. Doctor does not reject an entry outside
    that selector, so the ID convention is prose-enforced. Creator media lives outside `.cumaru/` in
    `assets/<creator_slug>/`. `tasks/<task_slug>/` holds one entry from
    `templates/task.md` per unit of work; doctor requires its `status` and
    `mode` (`manual` or `automatic`) and accepts an optional `creator`. A
    task may produce a script, kept outside `.cumaru/` in
    `scripts/<task_slug>/`. The domain ships no domain-specific skill,
    command, or discipline, and nothing that publishes or schedules content.
19. Every tag a shipped domain's `config.yaml` requires on a file exists as a
    balanced marker in that source file, so doctor on a fresh install of any
    shipped domain reports no missing required tag. Inline-code mentions of a
    marker do not count.
20. `vault-memory` converges multi-source knowledge on one node per fact
    through the conventions in its `domain.md` Disambiguation section:
    search-before-write in `cumaru-distill`, `aliases` and `type: term`
    nodes, `status`, `authority` ranked by the adopter-owned `authority` tag,
    `valid-from` / `valid-until`, and span-level `derived-from` from bulk
    capture. Doctor checks field presence only; graph-integrity checks are
    tracked by [issue 177](../issues/issue_177.md).

## Inputs and ownership

| Input or surface | Owner | Contract |
|---|---|---|
| `domains/<domain>/config.yaml` | framework/domain author | Valid initial v9 configuration. |
| `domains/<domain>/domain.md` | framework/domain author | Pillars, lifecycle, roles, and domain context. |
| Universal mirrors | framework | Must match `__base` under `scripts/sync-domain-kernel.sh --check`. |
| Domain skills and commands | framework/domain author | Installed only when the selected domain ships them. |
| `update skills --with <skill>` | user | Opt-in top-level skill from main, validated before writes. |
| `.cumaru/config.yaml` after install | adopter | Effective domain configuration; it carries no adapter selection. |

## Execution

### Preflight

1. Parse domain and adapter arguments; `base` aliases `__base`, and unsafe
   names or unknown adapters fail before network access.
2. Refuse every replacement of an existing install, including files and broken
   symlinks, and route refresh or opt-in additions to `cumaru update`.
3. Resolve main HEAD, pin the domain inventory to one commit, and validate the
   remote config, version, domain agreement, selected files, and discipline
   metadata.
4. Download every selected file into memory and prepare adapter merges before
   the first write.

### Read-only forms

1. Domain discovery and help read source metadata without mutation.
2. Project install has no preview mode; complete validation and preflight are
   its pre-mutation boundary.

### Apply

1. Exclusively create `.cumaru/` and publish only the files the domain config
   selects.
2. Install domain `cumaru-*` skills and supported commands into the selected
   adapter paths, skipping existing skill directories and command files.
3. Merge ordered kernel, domain, and discipline instructions plus supported
   hooks.
4. Print domain/config review and doctor-oriented next steps without
   persisting adapter state or running doctor or bootstrap.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Usage, unsafe domain name, unknown adapter | `2` | none |
| Unknown domain, invalid source config, source or network failure | `1` | none |
| Existing install | `1` | none; use update or uninstall deliberately first |
| Filesystem failure after publication begins | `1` | install may be incomplete; config remains adapter-neutral |

## Transaction and recovery

Project installation is ordered but is not the update transaction. It writes
the requested native artifacts without adapter state and has no automatic
rollback. It never replaces an existing install; recovery and deliberate domain
removal remain user-owned. `cumaru upgrade` is machine-global, replaces the
installed binary and `~/.config/cumaru.json`, and is not run or
regression-tested without explicit authorization
([install and upgrade](install-upgrade.md)).

## Implementation map

| Artifact | Responsibility |
|---|---|
| [`src/commands/install.rs`](../../src/commands/install.rs) | Domain/adapter arguments, complete download and preflight planning, and initial project publication. |
| [`src/config_tree.rs`](../../src/config_tree.rs) | Remote initial-install file selection from the domain config. |
| [`src/distribution.rs`](../../src/distribution.rs) | Main-HEAD resolution and commit-pinned domain inventories and downloads. |
| [`src/commands/help.rs`](../../src/commands/help.rs) | Public domain discovery and `domain.md` title rendering. |
| [`src/commands/bootstrap.rs`](../../src/commands/bootstrap.rs) | Read-only delivery of `__base` plus domain `bootstrap.md`. |
| [`src/adapter.rs`](../../src/adapter.rs) | Adapter paths, instructions, hooks, and cleanup. |
| [`src/commands/uninstall.rs`](../../src/commands/uninstall.rs) | Removal of the project tree and owned adapter artifacts. |
| [`scripts/sync-domain-kernel.sh`](../../scripts/sync-domain-kernel.sh) | Universal mirror synchronization and `--check` integrity gate. |
| `domains/*/config.yaml` | Domain initial configuration. |
| `domains/*/domain.md` | Domain-specific model and lifecycle prose. |

## Principal methods

| Method | Contract |
|---|---|
| `install::validate_disciplines` | Require the discipline index and valid selected strictness metadata. |
| `config_tree::install_files` | Select the structure and files the remote domain config describes. |
| `distribution::domain_source` | Resolve one commit and the domain inventory for every read. |
| `adapter::markdown`, `adapter::hooks` | Materialize canonical bootstrap for one adapter. |

## Regression coverage

| Test | Covered behavior |
|---|---|
| `src/commands/install.rs` unit tests | Argument validation, source disciplines, and project preflight preservation. |
| `src/config_tree.rs`, `src/commands/help.rs`, `src/commands/bootstrap.rs` unit tests | Initial file selection, domain catalog, and bootstrap rendering. |
| [`tests/native/lifecycle_spec.sh`](../../tests/native/lifecycle_spec.sh) | Stateless adapters, existing-install refusal, truncated inventories, and missing remote assets. |
| [`tests/native/ai_ccn_domain_spec.sh`](../../tests/native/ai_ccn_domain_spec.sh), [`tests/native/homebrew_domain_spec.sh`](../../tests/native/homebrew_domain_spec.sh) | Domain-specific installed contracts. |
| [`tests/native/source_domain_tags_spec.sh`](../../tests/native/source_domain_tags_spec.sh) | Every shipped domain installs with all config-required tags present. |

Remaining legacy domain, schema, and bootstrap scenarios are tracked in the
[native regression inventory](../../tests/native/README.md).

## Verification

```bash
cargo test --locked
bash tests/run.sh
scripts/sync-domain-kernel.sh --check
```

## References

- [Design as Code domain contract](design-as-code.md) — six pillars, role boundaries, and evidence-driven delivery.

- [`../../src/commands/install.rs`](../../src/commands/install.rs)
- [`../../docs/install.md`](../../docs/install.md)
- [`../../docs/agent-adapters.md`](../../docs/agent-adapters.md)
- [`install-upgrade.md`](install-upgrade.md)
- [`disciplines.md`](disciplines.md)
