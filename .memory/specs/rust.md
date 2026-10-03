---
name: rust-bootstrap-specification
description: "Implemented native Rust CLI commands, shared contracts, binary distribution, verification, and Bash differences"
type: project
status: implemented
version: 9
---

# Rust CLI specification

## Purpose

Record the supported Rust CLI under `rust/`. The root Bash entry point has been
removed; deprecated `src/*.sh` CLI modules and ShellSpec scenarios remain as
reference for the later test port, without a supported Bash CLI invocation.
The Rust CLI implements 16 command families: `version`,
`tree`, `map`, `fs`, `tag`, `coverage`, `doctor`, `install`, `uninstall`, `bootstrap`, `migrate`, `update`, `upgrade`, `help`, `context`, and `model`, with no claim of complete Bash parity.
The [context and models contract](context.md) owns optional external encoder
packages, offline ranking, the lightweight fallback, and their verification limits.

## Public surface

```text
cargo run --manifest-path rust/Cargo.toml -- version
cargo run --manifest-path rust/Cargo.toml -- help [<command>|domains]
cargo run --manifest-path rust/Cargo.toml -- install
    [agent <none|claude|codex|opencode>] [--domain <name>]
cargo run --manifest-path rust/Cargo.toml -- uninstall [-y|--yes]
cargo run --manifest-path rust/Cargo.toml -- bootstrap
cargo run --manifest-path rust/Cargo.toml -- migrate
cargo run --manifest-path rust/Cargo.toml -- coverage [--refs|--gaps|--rows] [--strict]
cargo run --manifest-path rust/Cargo.toml -- doctor [--quiet]
cargo run --manifest-path rust/Cargo.toml -- update [<path>] [--apply]
cargo run --manifest-path rust/Cargo.toml -- update config
cargo run --manifest-path rust/Cargo.toml -- update skills <agent> [--with <skill>...] [--apply|--clear]
cargo run --manifest-path rust/Cargo.toml -- update commands <agent> [--apply|--clear]
cargo run --manifest-path rust/Cargo.toml -- update agent <agent> [--apply|--clear]
cargo run --manifest-path rust/Cargo.toml -- tree [<directory-or-md>...]
    [--deep] [--rows|--markdown]
cargo run --manifest-path rust/Cargo.toml -- map [<directory-or-md>] [--rows|--markdown]
cargo run --manifest-path rust/Cargo.toml -- fs <src> move|copy <dst>
cargo run --manifest-path rust/Cargo.toml -- fs <path> create|remove
cargo run --manifest-path rust/Cargo.toml -- tag [<file>]
cargo run --manifest-path rust/Cargo.toml -- tag [<file>] get|set <tag> [<content>]
cargo run --manifest-path rust/Cargo.toml -- tag get|set [<file>] <tag> [<content>]
cargo run --manifest-path rust/Cargo.toml -- tag all [--body]
cargo run --manifest-path rust/Cargo.toml -- upgrade [--check]
rust/build.sh
curl -fsSL https://raw.githubusercontent.com/rntgspr/cumaru/main/rust/install.sh | bash
/usr/local/bin/cumaru
~/.config/cumaru.json
```

An invocation without a subcommand runs `doctor`. Package version
`0.9.1` is baked into the binary; it is separate from adopter config version 9.
`version` reports both identities inside an adopter; see [Native version](#native-version).

## Port status

Command-name coverage is complete; full behavioral parity and production
distribution are separate boundaries. `flow` is a retired Bash diagnostic for
the rename to `fs`, not a remaining command implementation.

| Surface | Native contract |
|---|---|
| `tree`, `map` | TSV by default; optional Markdown output; no config/domain/pillar filter; map lists literal H1-H6 headings with markers. |
| `fs`, `tag` | Guarded filesystem operations and opaque balanced tag bodies; tag has no typed `all --rows` mode. |
| `coverage`, `doctor` | Offline reports; shared reference resolution; bare invocation runs doctor. |
| `install`, `update`, `bootstrap`, `migrate`, `help domains` | HEAD of main, commit-pinned reads, no local snapshot or `--from`. |
| `uninstall` | All stateless adapters; owned native cleanup; confirmed removal of the complete project tree. |
| `version`, `upgrade` | Build identity plus installed/latest domain config and drift report against main; binary-only global installation as `cumaru`. |
| `help` | Offline local CLI help; explicit domain discovery uses the network. |

The canonical native details live in this file. Capability specifications link
here when their Bash source contracts differ; those links do not rewrite the
retained Bash module contracts. Public command guides under `docs/` describe
the native contract.

## Invariants

1. Navigation is read-only; the framework root is fixed at `.cumaru/` relative
   to the current working directory, never redirected by environment variables.
2. Shared path helpers belong to `paths.rs`; configuration constants, loading,
   and schema validation belong to `config.rs`.
3. `config::load` requires a regular, non-symlink `config.yaml` containing
   exactly one YAML document and returns a validated `yaml_rust2::Yaml` value.
4. Schema validation is private and runs before the loader returns. Version 8
   selects `config.schema.off-9.json`; all other values select the active
   `config.schema.json`, whose version constraint rejects unsupported versions.
5. Both schemas are embedded with `include_str!`; changes require rebuilding.
   Validation uses `jsonschema` without its default features, plus `serde_json`,
   and requires no runtime `jq`, `yq`, or schema-file lookup.
6. YAML conversion rejects non-string mapping keys, non-finite numbers, and
   unsupported values. Schema failures aggregate diagnostics with JSON Pointer
   locations, using `/` for the document root.

## Execution

1. Clap parses and dispatches the selected command from `main.rs`.
2. `tree::run` invokes `execute`, which validates the target and framework root.
3. Targets are separate positional arguments, such as `tree templates plans
   --deep`. With none, the target is the framework root. Commas remain literal
   path characters. Every target is validated and resolved before traversal;
   repeated canonical target directories are visited once.
   Navigation is independent of domain/config declarations; `--pillars` has
   been removed. Navigation does not load the configuration; tag audit and
   declaration-gated operations use the validated configuration loader.
4. Shared `walk::Walk::run` receives target directories or exact files, the `deep` option,
   a file filter, and a parser callback. It emits safe directory/file paths,
   prunes hidden entries, rejects symlinks and canonical escapes, and collects
   filesystem diagnostics. It never reads file content or interprets Markdown.
   Files and directory expansion are deduplicated across overlapping targets;
   a directory may also be presented as an explicit target so the parser can
   apply target-specific rules.
5. `tree::TreeParser` supplies the Markdown filter and interprets directory
   indexes and file summaries. Directories without an index remain discoverable
   for deep-mode diagnostics. The parser chooses how much content to read;
   frontmatter extraction stops at its closing fence. Summary rules remain
   trimmed strings of 32-512 Unicode code points without C0 or DEL characters.
6. Results from all targets are combined, sorted, and deduplicated before
   `emit` prints TSV by default or a Markdown table with `--markdown`.
   `--rows` explicitly selects the default and conflicts with `--markdown`.
   Diagnostics are also deduplicated
   and go to stderr. Markdown file targets resolve to their parent directory.
7. `map` accepts one optional target, defaulting to the root. Directories are
   always searched recursively; Markdown files remain exact targets. It uses
   the shared path validation/resolution and walker, without requiring indexes,
   summaries, config, or a runtime `rg` process.
8. `markdown::read_headings` reads UTF-8 lines and matches literal H1-H6 ATX
   headings at column zero: one to six `#` characters followed by a space, tab,
   or end of line. It includes matches inside frontmatter and code fences and
   headings from `index.md`, preserving the complete line with its `#` markers
   and one-based line number. CRLF is accepted. Setext and indented headings
   are not interpreted by this literal reader.
   Output sorts by path then numeric line: default TSV
   `path<TAB>line<TAB>title`, or an escaped Path/Line/Title Markdown table with
   `--markdown`. `--rows` explicitly selects TSV and conflicts with `--markdown`.
   No matches is success. Read/traversal failures are
   reported on stderr, with safe results emitted before status 1.
9. `upgrade --check` runs `git ls-remote --tags --refs` against the public Cumaru
   repository, selects the highest plain `X.Y.Z` tag by numeric components,
   and compares it with the same build-time package version printed by `version`.
   It prints installed/latest/status/upgrade fields; both behind and up-to-date
   results succeed. Missing tags, unavailable Git/network, or invalid binary
   release versions fail with `cannot check` diagnostics. It never installs.
10. Bare `upgrade` selects the latest release once and executes the embedded
    `rust/install.sh` with that version as an argument and inherited streams.
    Direct curl installation uses the same script, which resolves the latest
    plain release through Git when no version argument is supplied. There is
    no `main` fallback, snapshot download, or call to Bash `src/install.sh`.
    Spawn or installer failures return status 1; Clap rejects extra arguments.
11. Binary assets are `cumaru-<target>` under
    `https://github.com/rntgspr/cumaru/releases/download/<version>/`.
    Supported targets are `aarch64-apple-darwin`, `x86_64-apple-darwin`,
    `aarch64-unknown-linux-musl`, and `x86_64-unknown-linux-musl`.
    The installer detects OS/architecture, downloads only the executable with
    cURL, verifies `--version` equals `cumaru <version>`, then publishes it to
    `/usr/local/bin/cumaru` with mode 755, using sudo only for destination writes
    when needed. Linux assets must be statically linked against musl.
    HTTP 404 reports that the selected version's binary file was not found,
    naming the asset and download URL. Other download failures retain cURL's
    diagnostic and do not claim the release file is missing.
12. After binary publication, the invoking user's `~/.config/cumaru.json` is
    replaced with `{"version":"X.Y.Z"}` using mode 600.
    The executable name is `cumaru`; the temporary `cuma` name is retired.
    Asset names and internal package
    identity remain `cumaru`. No other global fields are defined yet.
    This records that user's installation, not an authority
    over the machine-wide executable: `version` and `upgrade --check` continue
    to use build identity. No `~/.cumaru` runtime snapshot is created or removed.
13. `fs` ports the Bash primitive in [docs/fs.md](../../docs/fs.md) with the
    positional order `<src> <verb> [<dst>]`. It uses fs-specific private
    helpers, not navigation's `validate_target_syntax`/`resolve_target`: hidden
    file names are allowed, the root may be reached through a symlinked
    `.cumaru/`, and parent symlinks are accepted when the canonical result stays
    strictly inside the root. Direct symlink targets, including broken links,
    are refused. Missing paths resolve through their nearest existing ancestor;
    an unresolvable ancestor, such as a broken parent link, is rejected.
14. All syntax, shape, containment, existence, protection, descendant, and copy
    source checks run before mutation. Trailing slashes are stripped first.
    Files end in `.md`; directory segments, including implicit parents, contain
    no dots. Nested entries of a moved or copied tree are not shape-checked.
    Create of an existing path is a no-op success that keeps its bytes; file
    creation uses exclusive creation and never truncates. Move uses `rename`;
    copy is recursive. `remove` refuses `index.md` and direct-child directories.
    Success lines go to stdout as `<verb>: <src> -> <dst>`, `create: <path>
    (file)`, `create: <path>/ (dir)`, or `already exists (no-op): <path>`;
    diagnostics go to stderr with the `cumaru fs:` prefix. Paths are quoted
    through `text::shell_quote`.
15. Intentional differences from Bash: ASCII `->` replaces the arrow and color
    markers are omitted; FIFOs, sockets, and devices are refused instead of being
    removed or copied; a directory copy containing any nested symlink or
    unsupported entry is refused; moving or copying a directory into its own
    descendant is refused; and every I/O error returns status 1 without a success
    line. `help` is not a positional alias; use `fs --help`. Unknown verbs and
    extra arguments are Clap usage errors.

16. `tag` supports root/file audits, both positional get/set orders, and
    tree-wide list/body modes. Names use the canonical colon-segment grammar;
    a supplied `cumaru:` prefix is stripped. Whole-line markers accept whitespace
    and optional `#` or `//` prefixes. Balanced nested blocks are independently
    addressable; duplicate bodies extract in document order. Parsing completes
    before any results from a host are emitted. Crossing, unclosed, and unmatched
    closers fail. Invalid marker-shaped prose is not interpreted as a marker.
17. Audits and ordinary get/set load validated config. V9 resolves the complete
    declared tree with physical path overrides, required literals, optional
    literals, zero-or-more globs, literal precedence, index exclusion from leaf
    wildcards, and union of overlapping wildcard tag sets at equal ownership.
    Missing/unsafe entries and physical collisions fail before mutation.
    V8 uses root/pillar tag maps and literal/wildcard meta host declarations.
    The existing Bash exception permits `reference` get/set without declaration
    or configuration. All-tree modes also require no configuration.
18. Hosts are regular Markdown files inside a real `.cumaru/` directory;
    direct and parent symlinks are refused. Contained absolute paths and paths
    prefixed with `.cumaru/` are supported. Set accepts positional content,
    including an explicitly empty string, or stdin. Missing blocks insert after
    closed leading frontmatter. Duplicate top-level blocks consolidate at their
    first occurrence; nested markers and unrelated prose remain intact. New
    content must produce a balanced complete document before publication.
19. Set stages beside the host with exclusive creation, copies host permissions,
    syncs output, checks for detected concurrent edits, and renames the result.
    Failed parsing or staging preserves the original host. This is a single-file
    operation, not a multi-file transaction or a filesystem-race-proof lock.
20. Bodies are opaque text: tag does not parse tables, classify links, resolve
    references, or enforce a body format. The previous native `all --rows` mode
    and its link/status interpretation have been removed by maintainer decision.
    Get/set and all --body preserve body text regardless of its content format;
    balanced delimiters remain the structural safety boundary.
    Malformed hosts or traversal defects return 1 while safe hosts still emit.
    Audit mismatch returns 1; diagnostics go to stderr. Presentation omits Bash
    colors/bullets, and empty positional set content is honored rather than
    falling back to stdin.
21. `bootstrap` is read-only and takes no arguments. It reads the `domain`
    string from a regular, non-symlink `.cumaru/config.yaml` with exactly one
    YAML document, without schema validation, maps `base` to `__base`, and
    accepts only ASCII letters, digits, `-`, and `_` before any network access.
22. It resolves main HEAD and the domain inventory through
    `distribution::domain_source`, so both documents come
    from one commit revision. `domains/__base/bootstrap.md` is required; the
    domain's `bootstrap.md` is optional. Frontmatter is removed by
    `markdown::strip_frontmatter`, which reproduces the Bash awk filter: blank
    lines after the closing fence are kept, leading blanks are dropped only
    without frontmatter, and every line ends with LF.
23. Output is `# Bootstrap — <domain>`, a blank line, the base body, then for
    other domains a blank line and the domain body or the note
    ``> Domain `<domain>` ships no bootstrap.md; only the universal steps apply.``
    The whole document is assembled before printing, so failures emit no stdout.
    Intentional differences from Bash: there is no `--from`, local checkout, or
    Git URL source; legacy `schema.yaml`/`flavor` resolution is not ported;
    diagnostics go to stderr with the `cumaru bootstrap:` prefix instead of
    colored stdout; an unknown domain reports the source lookup failure; and
    CRLF fences are accepted. Network failures use shared source diagnostics.
24. `migrate` ports the strictly read-only [migration contract](migration.md)
    and takes no source argument. It reads `.cumaru/config.yaml` or, only when
    that entry is absent, legacy `.cumaru/schema.yaml`; the selected entry must
    be a regular non-symlink file. The `domain` string, else legacy `flavor`, is
    read from exactly one YAML document without schema validation, so old
    configurations still receive instructions. `base` maps to `__base`; names
    use the bootstrap grammar and are validated before network access.
25. It resolves main HEAD and the `__base` inventory through
    `domain_source`, then reads `domains/__base/migration.md` and, for other
    domains, an inventoried `domains/<domain>/migration.md` through
    `read_repository`, all pinned to one commit. A domain absent from the
    main inventory receives the base document only, matching the Bash checkout path.
26. Output is the Bash `# Migration — <domain>` heading and LLM execution
    preamble, then the base body before the whole-line
    `<!-- cumaru:migration-domain-extension -->` checkpoint, the optional domain
    body, and the base body after it. Base parts drop leading blanks like
    `_migrate_base_part`; the domain body uses `markdown::strip_frontmatter`.
    A missing checkpoint fails. `--apply` is a hidden flag that exits 2 with
    an explanation. Intentional differences from Bash: no `--from`, local
    checkout, or Git URL source; diagnostics go to stderr with the
    `cumaru migrate:` prefix; the domain is resolved before the source.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Clap usage error | `2` | none |
| Invalid config, target, index, summary, or safety boundary | `1` | none |
| Config parsing or embedded-schema runtime failure | `1` | none |
| Deep traversal defects | `1` after traversal; valid rows may be emitted | none |
| Clean traversal or version output, with or without an adopter | `0` | none |
| `version` present adopter with linked/non-directory root, missing/linked config, or malformed/multi-document/mistyped metadata | `1`, CLI version still on stdout | none |
| `version` remote lookup, domain mismatch, or config comparison failure | `1`, installed identity retained | none |
| Release check reports behind or up to date | `0` | none |
| Release listing or comparison failure | `1` | none |
| Bare upgrade succeeds | `0` | global binary and invoking user's version JSON replaced |
| Download, unsupported platform, or binary-version verification fails | `1` | existing binary and version JSON preserved |
| Binary/config publication fails | `1` | published binary may remain newer than the user JSON |
| `fs` missing `<dst>` for move/copy, `<dst>` given to create/remove, empty path | `2` | none |
| `fs` guardrail, missing source, existing destination, or unsupported type | `1` | none |
| `fs` operation succeeds | `0` | exactly one create, move, copy, or remove |
| `fs` I/O failure during the operation | `1` | implicit parents or a partial copy may remain |
| `tag` usage error or invalid name | `2` | none |
| `tag` invalid config, undeclared/absent tag, malformed host, or audit mismatch | `1` | none |
| `tag set` succeeds | `0` | one validated Markdown host replaced |
| `tag set` parsing, staging, or detected concurrent-edit failure | `1` | original host preserved |
| `install` invalid domain/adapter/options | `2` | none |
| `install` existing .cumaru, source/network/config/adapter/preflight failure | `1` | no project writes |
| `install` success | `0` | fresh .cumaru and selected native adapter artifacts |
| `install` filesystem failure after publication begins | `1` | partial install may remain; no automatic rollback |
| `bootstrap` extra argument | `2` | none |
| `bootstrap` missing/symlinked/invalid config, unknown domain, missing base document, network or UTF-8 failure | `1`, empty stdout | none |
| `bootstrap` success | `0` | none |
| `migrate` `--apply`, `--from`, or extra argument | `2`, empty stdout | none |
| `migrate` missing/symlinked/unparsable config, missing/unsafe domain, missing base document or checkpoint, network or UTF-8 failure | `1`, empty stdout | none |
| `migrate` success | `0` | none |
| `coverage` multiple modes or unknown argument | `2` | none |
| `coverage` missing tree/config/pillar, invalid config or glob, non-Git project | `1`, empty stdout | none |
| `coverage` malformed host or traversal defect | `1` after the report; defects on stderr | none |
| `coverage --strict` with uncovered/stale/invalid entries | `1` | none |
| `coverage` report, including foreign-only gaps | `0` | none |
| `doctor` invalid/unsafe config or tree, older version, invalid workflow, or blocking health check | `1` | none |
| `doctor` warnings only or healthy installation | `0` | none |
| `uninstall` malformed/unsafe tree or adapter state, non-TTY without --yes, or declined confirmation | `1` | none |
| `uninstall` success or already absent owned footprint | `0` | owned adapter entries and validated .cumaru tree removed, or no-op |
| `uninstall` detected pre-publication concurrent edits | `1` | none |
| `uninstall` I/O failure after publication begins | `1` | partial cleanup possible; no rollback |
| `help` unknown topic or extra argument | `2` | none |
| `help domains` source/inventory/download/metadata failure | `1`, empty stdout | none |
| `help` local command help or complete domain catalog | `0` | none |

## Transaction and recovery

Navigation and release checks are read-only. The Rust binary installer is
separate from the existing [Bash global installer](install-upgrade.md). It
downloads and verifies before publication, then stages a temporary executable
beside `/usr/local/bin/cumaru` and renames it over the previous path without
truncating a running executable. Temporary files are cleaned on exit.
The user JSON is staged before binary publication and renamed afterward;
binary and config writes are not one atomic transaction and have no automatic
rollback. A JSON publication failure may leave a newer installed binary.
No adopter tree or existing `~/.cumaru` snapshot is modified.

`fs` has no rollback. Parent directories created before a failed move or copy
remain, and a recursive copy stops at the first error, leaving a partial
destination. A failed recursive removal may leave some entries removed.
Validation and mutation are not atomic against concurrent filesystem changes.
Cross-filesystem moves are not emulated; `rename` failures are reported.

## Implementation map

| Artifact | Responsibility |
|---|---|
| `rust/src/main.rs` | CLI arguments and dispatch. |
| `rust/src/commands/version.rs` | Build identity, installed/latest domain config integers, main-HEAD reconciliation drift, and their unit tests. |
| `rust/src/commands/help.rs` | Local Clap help and read-only pinned-main domain discovery, title rendering, and their unit tests. |
| `rust/src/commands/upgrade.rs` | Upgrade arguments, coordination, release comparison, and result presentation. |
| `rust/src/release.rs` | Shared build-time `VERSION`, plain numeric release parsing/selection, and their unit tests. |
| `rust/src/distribution.rs` | Official repository access, binary release-tag resolution, main-HEAD domain inventories/downloads, and binary installer execution. |
| `rust/install.sh` | Platform asset download, binary verification, global executable publication, and per-user version JSON. |
| `rust/src/commands/tree.rs` | CLI coordination, tree-specific entry parsing, index/summary rules, diagnostics, and output. |
| `rust/src/commands/map.rs` | Exact-file or recursive heading projection, diagnostics, and TSV/Markdown output. |
| `rust/src/commands/fs.rs` | Guarded create/move/copy/remove inside `.cumaru/`, private fs path resolution and shape checks, and their unit tests. |
| `rust/src/commands/tag.rs` | Tag CLI parsing, audits, traversal, opaque body reads, and staged host publication. |
| `rust/src/commands/install.rs` | Main-HEAD domain coordination, complete download/preflight planning, and initial project publication. |
| `rust/src/commands/uninstall.rs` | Whole-footprint preflight, interactive/non-TTY confirmation, owned-file cleanup, and guarded final tree removal. |
| `rust/src/commands/update.rs` | Remote preview planning, scoped content/artifact refresh, exact clear, conditional Git recovery, direct publication, and native postchecks. |
| `rust/src/commands/bootstrap.rs` | Installed-domain resolution, pinned base/domain bootstrap reads, rendering, and their unit tests. |
| `rust/src/commands/migrate.rs` | Current/legacy installed-domain resolution, pinned base/domain migration reads, checkpoint rendering, `--apply` refusal, and their unit tests. |
| `rust/src/commands/coverage.rs` | Read-only Git source inventory, exclusions/globs, bucket classification/rendering, and their unit tests. |
| `rust/src/commands/doctor.rs` | Read-only v9 health inspection, cached Markdown checks, workflow validation, instruction discovery, embedded config drift, and their unit tests. |
| `rust/src/references.rs` | Shared table-cell extraction from innermost tags and project-source reference resolution for coverage and doctor. |
| `rust/src/adapter.rs` | Adapter paths, ordered instructions, and preservation-aware JSON hook/instruction merges. |
| `rust/src/artifacts.rs` | Shared update/uninstall file snapshots, owned namespace inventories and cleanup planning, exact native merges, and direct publication. |
| `rust/src/tags.rs` | Balanced marker parsing, body extraction, duplicate consolidation, and validated replacement. |
| `rust/src/config_tree.rs` | V9 selector resolution, effective host frontmatter/tag contracts, remote initial-install selection, logical-to-physical directory lookup, and legacy v8 tag declarations. |
| `rust/src/walk.rs` | Reusable contained traversal, file filters, path callbacks, deduplication, and filesystem diagnostics. |
| `rust/src/config.rs` | `CUMARU_DIR`, `CONFIG_FILE`, `load`, private `validate`, and private `yaml_to_json`. |
| `rust/src/paths.rs` | Normalization, shared `validate_target_syntax` and exact `resolve_target`, symlink checks, containment, and file names; tree alone converts resolved files to their parent. |
| `rust/src/text.rs` | Shared C0/DEL detection through `is_control` and `has_control`, plus diagnostic string escaping through `shell_quote`. |
| `rust/src/tsv.rs` | Reusable `write_row` writes caller-selected fields with tab separators and a final newline; callers supply fields without tabs or newlines. |
| `rust/src/markdown.rs` | Frontmatter extraction, Bash-compatible `strip_frontmatter`, literal heading reading through `read_headings`, and table-cell escaping. |
| `rust/Cargo.toml`, `rust/Cargo.lock` | Edition 2024 package, dependencies, and locked resolution. |

## Regression coverage

Current context/model verification on 2026-10-03: 81 native unit tests passed serially
and the ignored prepared-model smoke passed separately; see [context and models](context.md).
Earlier verification on 2026-10-03: 71 native unit tests passed serially; locked
release build, formatting, and diff checks passed. Unit tests live beside their
implementations under `#[cfg(test)]`. Disposable offline CLI smokes complement
them; no native integration suite has been added by maintainer decision.
Retained ShellSpec scenarios target the removed Bash entry point and cannot run
unchanged; their CI job has been removed. Live remote installation, release asset
publication, and a real-project bench remain unverified or undelivered.

The stage-specific verification records below describe earlier suite sizes and
warnings at the time of each change, rather than the current aggregate result.

Four native unit tests in `config.rs` cover the shipped v9 base configuration,
a valid v8 configuration, aggregate missing/type/unknown-property errors, and
invalid nested types with unsupported versions. They use Rust's built-in test
harness. The existing ShellSpec tree/version scenarios invoke the Bash CLI;
they are not automated Rust integration coverage.

Verification on 2026-10-01: `cargo test --locked` passed all four tests,
`cargo build --locked`, formatting, and `git diff --check` passed. A temporary
adopter CLI smoke accepted a valid config and rejected an invalid config with
all five schema diagnostics, status 1, and empty stdout before config loading
was removed from navigation.

After the multiple-target change, CLI smokes passed for shallow/deep navigation,
default root, overlapping directory/Markdown targets, options between targets,
literal comma/space paths, and rejection of missing targets, parent paths,
symlinks, and the removed `--pillars` option. The four schema unit tests still
pass; tree smokes run without an adopter config.

## Current boundaries

The [shipped recipe contract](skill-cli-contracts.md) records the completed
skills/README review against native arguments and ownership, including its
deterministic verification and semantic limits.

Rust `tree` and `map` do not expose `--domain` or `--pillars`. All active Bash
command names have native implementations, with the differences recorded here.
The tag command
now consumes the config loader, removing its previous dead-code warnings.
The loader applies the declarative JSON Schema, not the additional semantic
checks in the Bash validators, such as workflow dependency cycles or skill
availability. Doctor separately checks dependency graphs and installed skill
availability; other commands retain the declarative loader boundary. Walker unit tests
cover non-Markdown filters, directory delivery, overlapping targets, hidden
pruning, and symlink rejection. Tree-specific parsing still has smoke coverage.

The walker extraction passed six comparisons against the preceding binary,
matching stdout, stderr, and exit status for shallow/deep traversal, overlapping
targets, Markdown targets, invalid summaries, symlinks, and missing indexes.
Output selection remains implemented by `tree::emit`, which chooses paths and
summaries and delegates TSV row writing to `tsv::write_row`; an `output.rs`
design is deferred.
Diagnostic escaping is shared through `text::shell_quote`.
After extraction, `cargo test --locked` passed all six native tests and
`git diff --check` passed. The unused configuration-loader warnings remain.

Native CLI integration tests are deferred by maintainer decision; existing Bash
scenarios remain available for a later port. Heading projection remains a
separate `map` command; no `tree --heads` option is implemented.

Map implementation verification on 2026-10-01: all six existing native tests,
build, formatting, and diff checks passed. Disposable CLI smokes covered exact
files, recursive roots, index headings, TSV, numeric line order, CRLF, literal
fence/frontmatter matches, hidden pruning, empty results, unsafe targets,
symlink refusal, partial output on defects, help, and tree file-parent behavior.

Upgrade verification on 2026-10-01: eight native tests passed, including two new
pure unit tests for release grammar and numeric selection. Build and diff checks
passed. Offline disposable smokes stubbed Git and cURL to verify behind/equal/ahead,
missing tags, network failure, help/usage, pipeline failure propagation, and
installer dispatch to a temporary marker. The real global installer was not run;
no Rust CLI integration tests were added.

Binary installer verification used a scratch copy with both binary/config
destinations rewritten and Git/cURL/uname/sudo stubbed. All four platform
asset selections, latest-release resolution, binary/config publication,
config mode, and preservation after download/version failures passed.
Eight native tests, build, shell syntax, and diff checks passed.
No real global installation or sudo operation was performed. Release asset
publishing is not implemented in this repository yet, so production downloads
require those assets to be attached to releases before this installer is usable.

Fs verification on 2026-10-02: `cargo test --locked` passed 15 native tests,
including seven `fs` unit tests on disposable fixtures for create, implicit
parents, existing-path byte preservation, file/tree move and copy, protected
removals, arity/syntax/shape classification, the fs symlink policy (escaping
parent, direct and broken links, broken parent, in-root alias), descendant
transfers, nested-symlink copy refusal, and an I/O failure without success.
Rejections assert an unchanged fixture snapshot. `cargo build --locked`,
`cargo fmt --check`, and `git diff --check` passed; the existing config-loader
dead-code warnings remain. Disposable CLI smokes over a copy of
`tests/fixtures/fs` exercised every verb, the ShellSpec failure messages and
statuses, missing `.cumaru/`, help, a FIFO refusal, and confirmed that nothing
was written outside the project. No Rust integration tests were added, and the
ShellSpec fs scenarios still target the Bash CLI.

Tag verification on 2026-10-02: seven focused native tests cover parser grammar,
nested extraction/replacement, duplicate folding, malformed content rejection,
selector overrides/precedence/composition/index exemption, unsafe config paths,
collisions, command syntax, opaque body preservation, and publication
permissions/concurrent-edit preservation. The complete native suite passes 22
tests, including the concurrently added fs tests. Build, formatting, and diff
checks passed. Disposable CLI smokes exercise both positional orders, audit,
empty content, missing-block insertion, absolute hosts, all bodies,
reference exceptions, symlink rejection, unchanged bytes after malformed content,
and valid bodies alongside malformed-host diagnostics. No Rust integration suite
was added. The glob dependency supplies selector expansion rather than a custom
wildcard engine; runtime Bash, jq, and yq are not required by tag.

Bootstrap verification on 2026-10-02: three focused native tests in
`bootstrap.rs` cover rendering order, the absence note, the base-only form,
domain resolution (`base` alias, missing/non-string/unsafe/multi-document
values), and missing or symlinked config failing before network access with no
writes; `markdown::strip_frontmatter` has its own Bash-parity test. The complete
native suite passed 38 tests, including the concurrently added migrate tests
after its base part kept Bash `_migrate_base_part` spacing. `cargo build --locked`,
`cargo fmt --check`, and `git diff --check` passed. Offline smokes stubbed `git` and `curl`
and served the working tree: focus, sdlc-light, and base output matched the Bash
CLI byte for byte, every request used one commit revision, and unknown domain,
missing/unsafe config, unreachable Git, a missing base document, a failed domain
download, and an extra argument failed with empty stdout and unchanged project
files. No Rust integration tests were added and no real adopter was touched.

Migrate verification on 2026-10-02: six focused native tests in `migrate.rs`
cover checkpoint insertion and spacing, base-only forms, a missing or inline
checkpoint, `domain`/`flavor` resolution from old unvalidated configs, current
over legacy selection, and missing or symlinked config failing before network
access with no writes. The native suite passed 38 tests; `cargo build --locked`,
`cargo fmt --check`, and `git diff --check` passed. Offline smokes stubbed `git`
and `curl` and served the working tree: output for `__base`, `base`, and seven
domains matched `cumaru migrate` from the Bash CLI byte for byte; every raw read
used one commit; repeated runs were identical with an unchanged project manifest;
`--apply`, `--from`, help outside a project, no config (no network request),
unsafe domain, unreachable Git, missing base document, and missing checkpoint
returned the documented statuses with empty stdout. No migration was applied, no
Rust integration tests were added, and no real adopter was touched.

## Project installation

Native `install` implements initial project adoption from HEAD of
GitHub main. The Bash CLI retains its separate distribution contract.

1. Default to domain `__base`; preserve explicit adapter selection and the
   existing generic adapter default.
2. Refuse an existing `.cumaru/`; project refresh belongs to `update`.
3. Resolve and validate the selected domain from main HEAD. The
   machine-global installation contains only the CLI binary, not a domain or
   skill source snapshot.
4. Optional skills are outside initial installation. Their availability and
   selection belong to `update`; install does not validate or install opt-ins.
5. Read the selected domain's remote `config.yaml` and materialize only the
   structure and files it describes, including the adopter configuration itself.
   Use its selectors and path overrides rather than copying the whole domain.
   `framework: true` controls update ownership, not initial-install inclusion;
   configured adopter-owned pillars and templates must also be materialized.
6. Do not copy source-only content into `.cumaru/` and then delete it. Skills,
   migration/bootstrap prose, and adapter artifacts are distinct source surfaces.
7. Install the selected domain's skills into the adapter's skill directory,
   including its universal skills, which are already present in each domain.
8. Preserve adapter instruction and session-hook wiring, including adopter-owned
   content and unrelated hook entries. Adapter selection remains stateless.
9. Do not install separate Claude slash-command files; Claude uses the skills
   directly. Other supported adapters retain their existing command behavior.
10. Print the domain/config review and doctor-oriented next steps. Do not run
    doctor or bootstrap automatically.

### Remote source and preflight

1. Validate domain/adapter arguments and refuse any existing `.cumaru` entry,
   including files and broken symlinks, before network access. `base` aliases
   `__base`; unsafe names and unknown adapters fail without writes.
2. Resolve HEAD of main through GitHub's commits API on each invocation,
   fetch its recursive Git tree, and pin raw downloads to that commit SHA.
   Reject truncated inventories, unsafe/duplicate domain paths, symlinks, and
   unsupported Git entry modes. No checkout, snapshot, or tarball is downloaded.
3. Validate remote config through `config::parse`, requiring version 9 and
   selected-domain agreement (`base` for `__base`). Expand physical selectors
   against inventoried files and inferred directories; select directory indexes,
   matching files, root index, and config. Globs may match zero files; required
   literals and selected directory indexes must exist. Source-only selections
   under skills/commands or root bootstrap/migration are rejected.
4. Download the complete selected project/native content into memory and prepare
   adapter merges before writes. Require domain.md and discipline index for
   bootstrap and validate selected discipline frontmatter/strictness metadata.
   Preserve executable source modes for scripts and skills.
5. Copy domain cumaru-* skills as complete directories into the native surface,
   skipping existing skill directories as a whole. Generic/OpenCode command
   files install only when absent and require a namesake source skill.
   Claude/Codex receive no separate command files; `--with` is not supported.
6. Reject symlinked destinations and non-directory parents. Require unchanged
   original bytes for native merges and reject duplicate write destinations.
   Malformed adopter JSON or instruction blocks fail before project writes.

### Publication and recovery

After complete preflight, exclusively create `.cumaru/` and publish the selected
files and native artifacts. New files use exclusive creation. Existing native
instruction/JSON files stage beside the destination, preserve permissions, and
rename after an additional original-byte check. Unrelated prose, JSON keys,
instruction entries, hooks, commands, and skills remain adopter-owned.
Install has no multi-file transaction or automatic rollback: I/O failure may
leave a partial fresh installation and already-published native changes.
Concurrent-change checks detect observed changes but are not filesystem locks.
No Git mutation, global installation, backup, doctor, or bootstrap run occurs.
Next steps point to domain/config review and native doctor. Native
hooks and bootstrap prose use `cumaru`. Refresh and cleanup recognize previously
delivered `cuma` hooks as owned entries, replacing/removing them without duplication.

### Verification and limits

Verification on 2026-10-02: 28 native tests passed. Six new tests cover source
selection, arguments, discipline metadata, preflight preservation, instruction
merges, and hook preservation/idempotence. Offline disposable CLI smokes stubbed
Git/cURL and exercised four adapters and eight domains, preserved skills and
instructions/hooks, existing-install refusal, HTTP 404, malformed hook JSON,
truncated inventories, symlinked adapter destinations, and rejected opt-in
flags. Build, formatting, and diff checks passed. No Rust
integration tests were added; no real adopter or global installation was run.

Remote install source access needs cURL, without runtime jq/yq or a local domain source.
Public GitHub API rate limits/network failures are reported as download errors;
truncated inventories fail closed. Native config validation retains its
declarative-schema boundary; install does not check workflow cycles or skill
availability. Native doctor checks them separately after installation. Main HEAD must contain
compatible v9 source content. Live remote installation has not been verified;
smokes use the current checkout as stubbed release data.

## Native project update

The universal update skill verifies CLI identity and installed domain/config
identity separately through `cumaru version` before project preview. It never
uses a release tag or CLI `behind` status as config-version evidence; only the
validated source/local config integer gate routes to migration. Its native
commands omit `--from`, and global binary upgrade remains separately authorized.

Native update resolves HEAD of main on each invocation, pinned to one commit through
the shared distribution module. It does not use a local snapshot or `--from`.
Only installed v9 configurations and equal source/config versions are supported;
other versions fail before writes and route to migration. Configuration and
domain validation retain the native declarative-schema boundary.

1. General/scoped update refreshes existing Markdown only when the same logical
   entry explicitly declares `framework: true` in both source and local trees.
   Ownership never inherits. Literal path overrides map canonical content to
   the installed destination; wildcard matches require equal physical selectors
   and a matching source file. Literals override wildcard rules. Source path
   collisions and conflicting wildcard ownership fail. Unowned and local-only
   files, config, bootstrap/migration documents, and adapter files are untouched.
2. `tags::merge` restores local top-level bodies by name, folds duplicates in
   document order, retains nested content, inserts orphan bodies after canonical
   frontmatter, and retains source-only scaffolds. Both inputs and the candidate
   must have balanced tags. Frontmatter and outside-tag prose come from source.
3. Preview prints change classifications and complete current/expected Markdown
   pairs without mutation. Config mode prints removed JSON Pointers and the
   complete current/candidate documents; the JSON candidate is valid YAML.
   Reconciliation prunes only unknown model properties, fills missing source
   defaults, retains scalar/array choices and refined glob selectors, and blocks
   permitted invalid values. `update config --apply` is a usage error.
4. Skill/command/agent refresh requires an explicit adapter. Domain skills and
   supported command namespaces replace/prune only owned files. Repeatable
   `skills <agent> --with <name>` refreshes only selected top-level opt-ins from
   the pinned repository inventory. Claude/Codex use skills directly and reject
   separate commands refresh. Agent mode also merges instructions/hooks using
   installed discipline bodies, preserving unrelated native entries.
5. `--clear` immediately removes only the named owned surface; omitted adapter
   means all adapters. It requires valid local config but no remote lookup.
   Cumaru skills include hidden resources; adopter skills/opt-ins remain.
   Legacy Claude namespaced commands can be cleared. Native merges remove exact
   managed instruction/hook entries; native files and empty directories remain
   rather than broadening deletion. Clear and apply are mutually exclusive.
6. Complete download/merge planning and safe destination/original-byte preflight
   precede publication. Symlinked paths and nonregular targets fail. Inside Git,
   mutation requires empty porcelain status including untracked files, HEAD, and
   tracked config/index. Missing Git or a non-Git project warns and proceeds.
   No Git mutation, project staging, locks, backups, or automatic rollback occurs.
   Files are written/removed directly; I/O/postcheck failure may leave partial
   mutation. Detected concurrent edits block the affected write, without claiming
   race-free filesystem locking. Existing file permissions are preserved.
7. Every changed apply/clear runs native doctor in quiet mode after publication.
   Blocking checks return status 1 with already-published changes left for review
   and recovery. Reference, instruction, and drift warnings remain nonblocking.

Verification on 2026-10-02: 44 native tests passed, including six added tests for
opaque preservation/idempotence, explicit ownership and path mapping, schema
reconciliation, mode validation, clear ownership including hidden resources,
and detected concurrent edits. Locked build, formatting, and diff checks passed.
Offline disposable CLI smokes exercised preview non-mutation, scoped apply,
dirty/untracked Git rejection, warned non-Git application, malformed tags,
unchanged config, skill pruning and adopter preservation, selected opt-ins,
agent refresh idempotence, and clear without network. Install regression smokes
were rerun after shared destination/selector changes. No native integration tests,
real adopter updates, global installation, or live release validation were run.

## Native coverage

Native `coverage` ports the read-only [coverage contract](coverage.md) without
Bash, jq, yq, or network access. Git runs only `rev-parse --is-inside-work-tree`
and `-c core.quotepath=off ls-files -z` from the project directory.

1. Guards run in Bash order: `.cumaru/`, `config.yaml` presence, validated
   `config::load`, the specification pillar, then the Git work tree. Failures
   print one `cumaru coverage:` diagnostic on stderr with empty stdout.
2. `meta.specification_dir` defaults to `specs`. V9 configs resolve the logical
   name through `config_tree::directory_path`, honoring `path` overrides; an
   undeclared or wildcard name fails instead of Bash's silent `specs` fallback.
   Other versions use the declared value verbatim.
3. Tracked paths under `.cumaru/`, `.agents/`, `.claude/`, `.opencode/`, and root
   `AGENTS.md`, `CLAUDE.md`, `opencode.json`, and `opencode.jsonc` are excluded.
   `.codex/` remains coverable, preserving the documented Bash omission; it is
   pinned by a unit test and a smoke rather than changed silently. Optional
   `meta.coverage.source` globs use `glob::Pattern` with `*` crossing `/` and
   leading dots matched; runs of `*` collapse so `src/**` equals `src/*`.
4. Reference hosts are safe Markdown files found by the shared deep walker and
   sorted by byte order of their `.cumaru/`-relative path. Coverage interprets
   only table lines whose innermost balanced block is `reference`; `tags` stays
   opaque. Row parsing mirrors `fm_tag_table_rows`: header and separator lines
   are skipped, extra cells join the description with ` | `, the first Markdown
   link destination (without backticks) is the target, and tabs become spaces.
5. Targets follow `_fm_resolve_reference_target`: empty and `<...>` rows are
   skipped before host filtering; anchors, URI schemes, absolute paths,
   directories, `.cumaru/` targets, and physical escapes from the project are
   invalid with their raw target; missing files are stale with the fragment
   removed; accepted targets are project-relative after resolving the parent
   physically. Rows outside `<spec_dir>/` only increment the notice count.
6. Report, refs, gaps, and rows text matches Bash without ANSI colors, including
   bucket order and detail columns. `--strict` fails on uncovered, stale, or
   invalid entries; foreign entries stay informational. Modes are a Clap group.

Intentional differences: invalid configs fail through the native schema gate;
malformed tag hosts and walker defects (symlinks, hidden entries pruned) are
reported after the projection with status 1, where Bash's awk reader parsed
leniently and `find` included hidden or linked files; table separators may use
alignment colons; rows after a nested non-reference block remain in the
reference body; ordering is byte order rather than locale `sort`; patterns do
not support Bash backslash escapes or extglob. Reference parsing now lives in
`references.rs`, shared with doctor. Direct symlink and special-file reference
targets are invalid, and syntactic `.cumaru/` paths are invalid even when missing.

Verification on 2026-10-02: six focused native tests cover table-row parsing,
innermost-block attribution and malformed hosts, every target status with
normalization and symlink escape, exclusions with `.codex/` and glob crossing,
specification directory resolution, and exact bucket rendering. The native
suite passed 50 tests and the locked build passed; `rustfmt --check` passed for
`coverage.rs`, while crate-wide `cargo fmt --check` still reports pre-existing
formatting in concurrently edited `config_tree.rs` code outside this change.
`git diff --check` passed. Disposable smokes rebuilt the ShellSpec fixture and
matched the Bash CLI byte for byte (ANSI stripped) for default, `--refs`,
`--gaps`, `--rows`, `--strict`, and `--rows --strict`, plus unscoped rows with a
tracked `.codex/` file; they verified statuses, an unchanged project manifest,
multiple-mode usage errors, all four runtime guards, and defect reporting. No
Rust integration tests were added and no real adopter was touched.

## Native doctor

`doctor [--quiet]` and a bare invocation inspect the fixed `.cumaru/` tree
offline and without writes. The active contract is v9; an integer version below
9 routes to `cumaru migrate` before current-shape validation. Symlinked roots or
config files, malformed/schema-invalid config, unsafe or missing declared
entries, conflicting wildcard contracts, invalid workflow dependencies/cycles,
and missing installed workflow skills fail preflight.

1. Resolve host contracts through `config_tree::contracts`, retaining literal
   precedence, zero-or-more globs, path overrides, and wildcard index exemption.
   Entry frontmatter overrides global Markdown/index/pillar defaults; pillar
   rules follow logical depth even when an override changes physical depth.
   Undeclared Markdown receives only global Markdown rules.
2. Cache each visible regular Markdown body once through the shared walker.
   Require closed, single-mapping YAML frontmatter, required fields, declared
   target arrays/vocabulary, configured literal H1 headings, and required tags.
   Validate every summary through the shared Markdown helper and every discipline
   except its index through the shared strictness helper. Hidden entries are
   pruned; symlinks and unsafe traversal entries are blocking diagnostics.
3. Balanced tag failures are errors. Balanced unknown tags remain opaque;
   nesting, stale `*.delete-me.md`, and RAW markers are warnings. Only declared
   `files`, `touched`, and `reference` tags receive table interpretation. Reference
   rows share coverage's project-source rule; explicitly removed missing touched
   files are allowed. Retained-reference defects warn rather than fail.
4. Check Git/cURL availability without invoking them. Discover at least one
   complete generic, Claude, Codex, or OpenCode instruction set using native
   adapter planning and installed discipline bodies. Missing/drifted instructions
   warn. Skills, commands, and hooks are outside this instruction-health check;
   workflow skill availability is checked separately, without execution.
5. Compare config with the domain defaults embedded at build time, naming missing
   defaults by JSON Pointer and ignoring formatting/order/additive local entries.
   Custom domains retain their local tree, rules, metadata, and workflows. No
   remote freshness is claimed: main-HEAD reconciliation remains the explicit
   `update config` operation. New source defaults require rebuilding the binary.
6. Emit ASCII `[ok]`, `[warn]`, and `[error]` lines and a summary counting failed
   checks, not individual defects. Quiet mode suppresses passes only. Preflight
   failures use stderr; completed check reports use stdout. Errors return 1;
   warnings alone return 0. Neither doctor nor a bare invocation runs repairs.

Workflow availability intentionally uses installed supported-adapter skill files
rather than a local domain snapshot; it does not prove same-domain membership
against a remote package. Doctor and update postchecks use this same boundary.
Older Bash-only semantic checks are not silently added to `config::load`.

Verification on 2026-10-02: 56 native tests passed, including six doctor tests for
custom config/override/index exemption, required metadata, target vocabulary/H1,
summaries and strictness, malformed/unknown tags, retained references, workflow
dependencies/cycles/availability, older and symlinked configs, hidden pruning,
safe traversal, property-specific drift, quiet output, and byte preservation.
Locked build, formatting, and diff checks passed. Offline disposable smokes covered
four adapters, all eight domains, bare/explicit doctor equivalence, and update
postchecks. Seven domains passed; `vault-memory` correctly returned 1 because its
config requires `relations` in `domain.md`, which has no balanced relations block.
That existing source defect remains outside this port. Install/update regression
smokes passed. No native integration tests, real adopter edits, global installer,
or network health checks were run.

## Native project uninstall

`uninstall [-y|--yes]` reverses project adoption across every stateless adapter.
It has no network, Git, config-schema, or active-adapter dependency and never
changes the global CLI installation. A malformed installed config may be removed
when the root still has regular `index.md` and `config.yaml` markers.

1. Require a real `.cumaru/` directory when present; refuse files, root/parent
   symlinks, missing or linked markers, and unsafe/special/linked nested entries.
   Snapshot every regular file, including hidden content, before confirmation.
   Absent `.cumaru/` still permits cleanup of a partial adapter footprint.
2. Preflight every adapter merge and complete owned namespace before any write.
   Generic/Codex/OpenCode share `.agents/skills`; Claude uses `.claude/skills`.
   Remove files under `cumaru-*` skills and supported `commands/cumaru` namespaces,
   including legacy Claude commands and hidden skill resources. Opt-ins and
   adopter skills/commands outside those namespaces remain intact.
3. Strip balanced Cumaru instruction blocks and the delivered legacy
   `DOT-LLM-HOOK` blocks. Delete a native Markdown file only when a `created`
   marker proves install provenance and only empty content or the generated
   project header remains. Preserve unrelated prose and existing permissions.
4. Remove exact OpenCode instruction entries and exact owned SessionStart hook
   commands through shared adapter cleanup. Preserve unrelated native keys,
   instructions, events, and hook entries. Changed JSON files are removed only
   when empty after cleanup; unrelated empty files are not deletion targets.
5. With an actual footprint, require `--yes` outside a TTY. Otherwise display
   the removal scope and accept only `y` or `yes`, case-insensitively. Empty or
   negative responses fail without writes. An absent footprint succeeds with
   `Nothing to uninstall.` even without `--yes`.
6. Recheck the tree snapshot and every planned native file before mutation.
   Publish adapter cleanup first, recheck the tree, then remove the entire
   `.cumaru/` directory. Native directories and empty namespaces may remain.
   Repeating a successful uninstall is a no-op.

This operation has no multi-file transaction, filesystem lock, staging, backup,
Git recovery gate, or automatic rollback. Observed concurrent file edits/additions
block removal; these checks do not guarantee race-free execution. Adapter I/O
failure leaves `.cumaru/` intact but may leave partial adapter cleanup. A tree
removal I/O failure may leave a partially removed tree. Its complete contents,
including adopter knowledge, are intentionally removed after confirmation.

Intentional differences from Bash: refuse symlinks/special files anywhere in the
managed cleanup set, preflight all native JSON/blocks before mutation, retain
strict affirmative confirmation, report errors on stderr, and omit ANSI output.
No positional `help` alias is provided; use `uninstall --help`.

Verification on 2026-10-02: 61 native tests passed. Five uninstall tests cover
coexisting adapters, hidden owned resources, opt-in/adopter preservation, native
permissions, malformed config removal, partial installs, creation provenance,
empty JSON cleanup, repeated no-op, missing markers, malformed instructions/JSON,
root/nested/adapter symlinks, concurrent tree/native edits, and affirmative parsing.
Disposable offline CLI smokes covered four adapters, eight domains, non-TTY
refusal, confirmed cleanup, repeatability, and preserved native state. Real PTY
smokes confirmed both declined and accepted prompts on scratch installs. Locked
debug/release builds, formatting, and diff checks passed; update regression
smokes passed after shared artifact extraction. No Rust integration tests, real
adopter removals, global uninstall, or Git mutations were performed.

## Native version

`version` is read-only and consults main HEAD when an adopter is present. It always prints `version:  <cli>` first,
the build-time package version. When the fixed `.cumaru/` path is absent, that
is the whole output and the status is 0. When it is present, the root must be a
regular directory and `config.yaml` a regular, non-symlink file holding exactly
one YAML document with a non-empty `domain` string without control characters
and an integer `version`. The command then adds `domain:   <name>` and
`config:   <integer>`, printing the installed values verbatim. It resolves main HEAD once, then reads
`domains/<domain>/config.yaml` at that SHA (base aliases __base), independently
of CLI release tags. Output adds `source: main (<sha>)`, `latest config:`,
`config status:`, and `config drift:`. Lower installed integers are outdated,
higher ones ahead; equal versions may still have reconciliation drift. Drift
means different version contracts or a changed schema/default candidate, not
formatting or preserved valid local choices. Future remote integers are reported
without applying the current schema across version boundaries. Equal-version
comparison uses the shared read-only reconciliation, which rejects invalid values.
Remote/metadata failures return 1 with installed fields preserved and no invented
latest version. No adopter means no network; doctor remains offline.

The identity read does not validate the current schema, so an older installed contract
still reports its actual integer; nothing is migrated or inferred. CLI and
config versions are independent: neither is derived from the other, and no
Markdown domain-version field exists. A present but unsafe or malformed adopter
keeps the CLI line on stdout, writes a `cumaru version:` diagnostic to stderr,
invents no config version, and returns 1. `--version` remains Clap's package
identity `cumaru <cli>`, used by binary installer verification, and never
parses an adopter. Every shipped domain config starts at version 9, matching
`domains/__base/config.yaml`; a native test enforces that alignment and each
config's domain name.

Verification on 2026-10-02: 70 native tests passed, including six version tests
for absence, the shipped base identity, older metadata, malformed/mistyped
metadata, unsafe layouts with unchanged files, and shipped-config alignment.
Release CLI smokes in disposable directories reported the CLI-only form, focus
config 9, legacy config 7, and status 1 for mistyped version and missing config;
`--version` printed `cumaru 0.9.1` and the copied config stayed byte-identical.

Main-HEAD verification on 2026-10-03: all 71 native unit tests passed serially.
The added comparison test covers older/ahead/future integers, domain mismatch,
invalid metadata, missing defaults, unknown properties, formatting, and preserved
local choices. Disposable offline install/update/version smokes passed, including
four adapters and eight domains, with tag lookups rejected by the source stub.
They verified pinned main reads, drift/status output, remote failure preservation,
and offline `--version`. A read-only live version query in the maintainer's
sdlc-light adopter reported installed/latest config 9 and no drift against
main `cfc2664f189c3611a397c6507e8c9f17fc4676eb`. At the maintainer's request,
remote tag `0.0.0` was moved to that commit; runtime domain freshness does not
depend on that tag. Universal update mirrors passed synchronization. The retired
Bash runner returned its expected missing-entry-point diagnostic; no native
integration suite, real adopter edits, or global upgrade was performed.

## Native help

`help` prints local Clap help; `help <command>` prints that command's long help.
Both work outside an adopter without dependencies or network access. Unknown
topics return 2. `--help` remains Clap's ordinary help flag.

`help domains` (also `help domain`) discovers public immediate domain directories
with regular `config.yaml` files from main HEAD's recursive Git
inventory. Shared distribution resolution pins the inventory and every metadata
read to one commit; there is no local snapshot, embedded catalog, or release-tag lookup.
It needs cURL but no adopter configuration.

The catalog lists `__base` as `base` first, then other names in byte order, skipping
hidden and other `__` directories. Names use install's ASCII name grammar;
literal `base` conflicts with the reserved alias. Configs and available metadata
must be regular Git blobs. Each description uses the first literal `# ` heading
in `domain.md`, or `domain` when that file/title is absent. Titles over 70 Unicode
characters truncate to 67 plus `...`; invalid UTF-8 or terminal controls fail.
Base uses its fixed minimal-kernel description. All metadata downloads complete
before printing, so failures never emit a partial catalog. No files are written.

Verification on 2026-10-02: 64 native tests passed, including three help tests for
public discovery/order/fallback, invalid catalogs and download propagation, and
literal Unicode title handling. Locked debug/release builds, formatting, and diff
checks passed. Offline disposable CLI smokes served all eight checkout domains
through stubbed Git/cURL, checked the domain alias, local help outside a project,
usage errors, HTTP 404 and truncated-inventory failures with empty stdout, and an
unchanged project. No Rust integration tests or live release validation were run.
All active Bash command names now have native implementations; the differences
and remaining feature/distribution boundaries above still apply.

## Verification

`rust/build.sh` resolves its own manifest path, builds with `--release --locked`
from any working directory, and preserves incremental artifacts. The native
binary remains at `rust/target/release/cumaru`; the root Bash `./cumaru` entry
point has been removed. Routine CI runs on `ubuntu-24.04`: native formatting,
unit tests, locked release compilation, and a release-binary `--version`/`help`
smoke, with the existing main-push/pull-request triggers and concurrency
cancellation. Linux success does not establish macOS runtime compatibility or
produce Apple release assets; that validation remains separate and undelivered.
The former Bash regression job has been removed. The doctor no-warning unit test
expects `git` and `curl` on PATH, as GitHub's Ubuntu runner provides.
No old global binary, alias, PATH entry, or snapshot is removed by this transition.
The public [native guide](../../docs/rust.md) describes build and distribution.

Naming/deprecation verification on 2026-10-02: all 64 native tests passed,
including replacement and removal of delivered `cuma` hooks. Release compilation
passed both from the repository and from an unrelated working directory.
An isolated installer copy with binary/config destinations rewritten and cURL
stubbed published `cumaru`, no `cuma`, and the version-only JSON. Release help
and `--version` passed outside an adopter; shell syntax, formatting, and diff
checks passed. No real global install or legacy snapshot removal was performed.
The added native CI job has not yet run remotely.

Linux CI verification on 2026-10-02: in an `ubuntu-24.04` container (aarch64,
non-root user, stable rustup toolchain), formatting, all 70 native unit tests,
the locked release build, and the workflow's binary smoke passed; the smoke also
failed as intended against a mismatched package version. Every platform gate in
the suite is `cfg(unix)`, so symlink, permission, containment, and preservation
tests executed; none were disabled. Without `git` on PATH the doctor no-warning
test failed deterministically through its external-tools warning; with `git`
installed, ten consecutive runs passed. The workflow has not yet run remotely
on GitHub's x86_64 runner.

Pre-push macOS verification on 2026-10-02: formatting, diff checks, locked release
build, and all 70 native tests with `--test-threads=1` passed. A default parallel
run failed in uninstall's concurrent-edit fixture with an unclosed instruction
block; the focused test passed immediately afterward. This remains an unresolved
intermittent fixture failure, alongside the earlier doctor fixture failure;
serialized success is not evidence that parallel execution is reliable.

Local bench on 2026-10-02: the maintainer requested publication of the verified
binary to `~/.local/bin/cumaru`, replacing only the old Bash symlink and leaving
its checkout target intact. At the maintainer's follow-up request, the installed
copy was replaced by a symlink to `rust/target/release/cumaru`, so each successful
local release build is immediately available through PATH. This is a manual development installation, distinct
from the release installer's `/usr/local/bin` destination. A temporary copy of
the current checkout exercised sdlc-light/Codex installation, deep tree, map,
coverage, tag get/set, all fs verbs, update preview, dirty-Git apply refusal,
doctor, and uninstall using that installed binary. Release reads were stubbed
from the current checkout; no live remote release or upgrade was exercised.
Doctor reported zero errors/warnings. Non-managed project files remained byte
identical and the adopter skill/instruction text survived. The instruction merge
and clear leave an additional blank separator in an existing `AGENTS.md`; that
native file is content-preserved, not byte-identical after the lifecycle.

The maintainer subsequently authorized deletion of the root Bash entry point.
`./cumaru` was removed and the legacy ShellSpec CI job retired; `src/*.sh` and
old scenarios remain port reference. The legacy runner now diagnoses the absent
entry point explicitly. The local PATH symlink still resolves to the native
release binary. Diff checks passed and all 64 native tests passed on rerun.
The first full run had a transient missing-file failure inside the doctor test
fixture snapshot; the focused test and full rerun passed. Its cause remains
unresolved and is not attributed to the entry-point removal.

```bash
cargo test --manifest-path rust/Cargo.toml --locked
cargo build --manifest-path rust/Cargo.toml --locked
cargo fmt --manifest-path rust/Cargo.toml --check
git diff --check
```

## References

- [Configuration contract](configuration.md)
- [Navigation contract](navigation.md)
- [Testing contract](testing.md)
- [Rust config implementation](../../rust/src/config.rs)
- [Rust tree implementation](../../rust/src/commands/tree.rs)
- [Active schema](../../schemas/config.schema.json)
- [V8 migration schema](../../schemas/config.schema.off-9.json)
