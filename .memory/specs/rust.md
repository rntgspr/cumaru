---
name: rust-bootstrap-specification
description: "Rust CLI bootstrap, tree traversal, guarded fs operations, shared paths, and schema-validated configuration loading"
type: project
status: implemented
version: 9
---

# Rust bootstrap specification

## Purpose

Record the implemented Rust CLI under `rust/`. The repository's Bash CLI remains
the existing distribution; the Rust bootstrap currently implements `version`,
`tree`, and `fs`, with no claim of complete Bash parity.

## Public surface

```text
cargo run --manifest-path rust/Cargo.toml -- version
cargo run --manifest-path rust/Cargo.toml -- tree [<directory-or-md>...]
    [--deep] [--rows]
cargo run --manifest-path rust/Cargo.toml -- fs <src> move|copy <dst>
cargo run --manifest-path rust/Cargo.toml -- fs <path> create|remove
rust/build.sh
```

An invocation without a subcommand prints `Hello Cumaru!`. Package version
`0.9.1` is baked into the binary; it is separate from adopter config version 9.

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
   been removed, and neither `tree` nor `version` loads the configuration.
4. Shared `walk::Walk::run` receives target directories, the `deep` option,
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
   `emit` prints a Markdown table or TSV. Diagnostics are also deduplicated
   and go to stderr. Markdown file targets resolve to their parent directory.
7. `fs` ports the Bash primitive in [docs/fs.md](../../docs/fs.md) with the
   positional order `<src> <verb> [<dst>]`. It uses fs-specific private
   helpers, not navigation's target validation/resolution: hidden file names
   are allowed, the root may be reached through a symlinked `.cumaru/`, and
   parent symlinks are accepted when the canonical result stays strictly
   inside the root. Direct symlink targets, including broken links, are
   refused. Missing paths resolve through their nearest existing ancestor; an
   unresolvable ancestor, such as a broken parent link, is rejected.
8. All syntax, shape, containment, existence, protection, descendant, and copy
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
9. Intentional differences from Bash: ASCII `->` replaces the arrow and color
   markers are omitted; FIFOs, sockets, and devices are refused instead of being
   removed or copied; a directory copy containing any nested symlink or
   unsupported entry is refused; moving or copying a directory into its own
   descendant is refused; and every I/O error returns status 1 without a success
   line. `help` is not a positional alias; use `fs --help`. Unknown verbs and
   extra arguments are Clap usage errors.

## Failure contract

| Condition | Status | Mutation |
|---|---:|---|
| Clap usage error | `2` | none |
| Invalid config, target, index, summary, or safety boundary | `1` | none |
| Config parsing or embedded-schema runtime failure | `1` | none |
| Deep traversal defects | `1` after traversal; valid rows may be emitted | none |
| Clean traversal or version output | `0` | none |
| `fs` missing `<dst>` for move/copy, `<dst>` given to create/remove, empty path | `2` | none |
| `fs` guardrail, missing source, existing destination, or unsupported type | `1` | none |
| `fs` operation succeeds | `0` | exactly one create, move, copy, or remove |
| `fs` I/O failure during the operation | `1` | implicit parents or a partial copy may remain |

`fs` has no rollback. Parent directories created before a failed move or copy
remain, and a recursive copy stops at the first error, leaving a partial
destination. A failed recursive removal may leave some entries removed.
Validation and mutation are not atomic against concurrent filesystem changes.
Cross-filesystem moves are not emulated; `rename` failures are reported.

## Implementation map

| Artifact | Responsibility |
|---|---|
| `rust/src/main.rs` | CLI arguments and dispatch. |
| `rust/src/commands/version.rs` | Build-time package version output. |
| `rust/src/commands/tree.rs` | CLI coordination, tree-specific entry parsing, index/summary rules, diagnostics, and output. |
| `rust/src/commands/fs.rs` | Guarded create/move/copy/remove inside `.cumaru/`, private fs path resolution and shape checks, and their unit tests. |
| `rust/src/walk.rs` | Reusable contained traversal, file filters, path callbacks, deduplication, and filesystem diagnostics. |
| `rust/src/config.rs` | `CUMARU_DIR`, `CONFIG_FILE`, `load`, private `validate`, and private `yaml_to_json`. |
| `rust/src/paths.rs` | `normalize_target`, `is_symlink`, `has_symlink_component`, `canonical_inside`, and `file_name`. |
| `rust/src/text.rs` | Shared C0/DEL detection through `is_control` and `has_control`, plus diagnostic string escaping through `shell_quote`. |
| `rust/src/tsv.rs` | Reusable `write_row` writes caller-selected fields with tab separators and a final newline; callers supply fields without tabs or newlines. |
| `rust/src/markdown.rs` | Frontmatter extraction through `read_frontmatter`, stopping at the closing YAML fence, and table-cell formatting through `markdown_escape`. |
| `rust/Cargo.toml`, `rust/Cargo.lock` | Edition 2024 package, dependencies, and locked resolution. |

## Regression coverage

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

Rust `tree` does not expose `--domain` or `--pillars`; Bash commands other than `fs` are
not implemented. The config loader is retained for future consumers and
currently produces dead-code warnings because no CLI command calls it.
The loader applies the declarative JSON Schema, not the additional semantic
checks in the Bash validators, such as workflow dependency cycles or skill
availability. Native automated coverage currently targets schema validation;
filesystem loader failures do not yet have native tests. Walker unit tests
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

Fs verification on 2026-10-02: `cargo test --locked` passed 13 native tests,
including seven `fs` unit tests on disposable fixtures for create, implicit
parents, existing-path byte preservation, file/tree move and copy, protected
removals, arity/syntax/shape classification, the fs symlink policy (escaping
parent, direct and broken links, broken parent, in-root alias), descendant
transfers, nested-symlink copy refusal, and an I/O failure without success.
Rejections assert an unchanged fixture snapshot. `cargo build --locked` and
`cargo fmt --check` passed. Disposable CLI smokes over a copy of
`tests/fixtures/fs` exercised every verb, the ShellSpec failure messages and
statuses, missing `.cumaru/`, help, a FIFO refusal, and confirmed that nothing
was written outside the project. No Rust integration tests were added, and the
ShellSpec fs scenarios still target the Bash CLI.

Native CLI integration tests are deferred by maintainer decision; existing Bash
scenarios remain available for a later port. A heading projection is the next
design topic, with no Rust `map` command or `tree --heads` option implemented.

## Verification

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
