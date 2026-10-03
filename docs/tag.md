# `cumaru tag`

Read, write, and audit `<!-- cumaru:NAME --> ... <!-- /cumaru:NAME -->` tags. **Config-validated**: `get` and `set` refuse a `<tag>` that the installed `config.yaml` does not declare for the target file. The mechanical primitive composed by recipe skills (`cumaru-absorb`, `cumaru-explore`, `cumaru-plan`, `cumaru-specs`, `cumaru-intake`) — no skill of its own; semantics fit in this doc plus `cumaru tag --help`.

## Usage

```text
cumaru tag                                  audit the root index.md
cumaru tag <file>                           audit the file's tags against the config
cumaru tag [<file>] get <tag>               print the body of <tag>
cumaru tag [<file>] set <tag> [<content>]   replace the body; content positional or stdin
cumaru tag get [<file>] <tag>               equivalent verb-first form
cumaru tag set [<file>] <tag> [<content>]   equivalent verb-first form
cumaru tag all [--body]                     list (or dump) every tag in every .cumaru/*.md
```

`<file>` must end in `.md` and is relative to `.cumaru/`. Absolute paths and
paths prefixed with `.cumaru/` are accepted only when they resolve inside the
current `.cumaru/` tree. When omitted, it defaults to the root `index.md`.
Hosts must be regular files; direct and parent symlinks are refused.

Tag name format: `[a-z][a-z0-9_-]*(:[a-z][a-z0-9_*-]*)*` — colon segments repeat, so deep node-tree names like `plans:plan:handoff:touched` are valid. The `cumaru:` prefix is implicit — pass `specs` or `cumaru:specs`, both resolve to the same.

Audit mode prints `Schema declares:` and `File contains:` lists, then reports
whether they are aligned. A mismatch exits `1`.

## Config validation

Audits and ordinary `get`/`set` load the validated configuration and resolve
the declared tree, including path overrides, literal and glob selectors, and
the union of overlapping wildcard tag sets. A tag must be declared for the
host. Exception: `reference` may be read or written without a declaration or
configuration. `tag all` modes also need no configuration.

## Tag bodies

Every tag body is opaque adopter content. `tag` never parses tables, classifies
links, resolves references, or enforces a body format; `cumaru update` preserves
bodies byte-for-byte. Reference resolution belongs to
[`cumaru coverage`](coverage.md) and [`cumaru doctor`](doctor.md).

Tag parsing uses balanced stack semantics. Whole-line markers accept
surrounding whitespace and optional `#` or `//` prefixes. Nested tags remain
independently addressable, while reading an outer tag includes the complete
nested tag and its delimiters. `cumaru doctor` warns about valid nesting
because it is unusual. Crossing tags, unclosed tags, and unmatched closers are
invalid; reads, writes, and update merges fail instead of interpreting the rest
of the file as tag data.

Reads expose duplicate top-level bodies in document order. Operations that
rewrite the file, including `tag set` and update, consolidate them at the first
occurrence. A missing block is inserted after closed leading frontmatter.

`set` accepts positional content, including an explicitly empty string, or
stdin. It stages the result beside the host, checks that the result is still a
balanced document and that the host was not concurrently changed, then renames
it into place. A failure preserves the original host. This is a single-file
operation, not a multi-file transaction.

Update preservation is name-based. Tag declarations tell the CLI where a tag is
expected, but do not permit update to discard an undeclared, moved, or opaque
local body. Source-only tags retain their canonical placeholder body until the
adopter edits them.

## Tree-wide listing

```bash
cumaru tag all          # every tag name, grouped by host file
cumaru tag all --body   # every tag body, with its host and name
```

There is no typed `--rows` mode. Malformed hosts or traversal defects exit `1`
while safe hosts still emit.

## Examples

```bash
# Audit the root index.md and one specific file.
cumaru tag
cumaru tag specs/index.md

# Get the components table body (hosted on domain.md).
cumaru tag get domain.md components

# Set a body via positional arg (multi-line works with $'...').
cumaru tag set intake/index.md intake "$body"
cumaru tag intake/index.md set intake "$body"

# Set a reference body via stdin (preferred for long content).
cat <<'EOF' | cumaru tag specs/auth/index.md set reference
| Link | Description |
|---|---|
| [session](src/auth/session.ts) | Session lifecycle source implementation. |
EOF
```

## Exit codes

- `0` — success.
- `1` — invalid config, undeclared or absent tag, malformed host, audit
  mismatch, or write failure.
- `2` — usage error or invalid tag name.

## Why a primitive (no skill)

Skills exist when there's multi-step orchestration that doesn't fit in `--help`. Tag operations are primitives: read a body, replace one host through a staged rename, or audit a file. Lifecycle skills use `cumaru tree` for structural navigation and use `cumaru tag set` only for declared semantic tags such as `reference`.

## Related

- [`cumaru fs`](fs.md) — the other CLI primitive (file ops). Recipe skills compose both.
- [`cumaru doctor`](doctor.md) — validates navigation, summaries, tag shapes, and retained file references.
- [`cumaru update`](update.md) — shares the balanced parser and preserves adopter-owned tag bodies during canonical rebuilds.
