# `cumaru update`

Refresh an installed `.cumaru/` tree from the matching source domain. It never
crosses a major schema version: use `cumaru migrate` for that transition.

## Usage

```text
cumaru update [<path>] [--from <src>] [--apply]
cumaru update skills|commands [--from <src>] [--apply]
cumaru update config [--from <src>]
cumaru update agent [<none|claude|codex|opencode>] [--apply|--clear]
cumaru update skills|commands [<none|claude|codex|opencode>] [--apply|--clear]
```

The installed `config.yaml` selects `<source>/domains/<domain>/`; `base`
selects `domains/__base/`. There is no `--domain` flag because update refreshes
the domain already installed in the project.

## Ownership and replacement

Framework-owned Markdown files include starter indexes, templates, roles,
disciplines, and domain instructions. On `--apply`, a file present in the
source is rebuilt from its canonical source version. Its YAML frontmatter is
framework-owned and always comes from that source.

Before replacement, update captures every local `<!-- cumaru:NAME -->` body.
It then restores each body at the first corresponding source tag. If a local tag
has no source marker, update inserts it immediately after frontmatter (or at
the beginning when the file has none). Thus tags remain adopter-owned while all
content outside tags, including frontmatter, returns to the canonical source.

Source and local tags are fully parsed before output is built. Missing exact
closers and crossing tags stop the update without writing. Balanced nested tags
remain queryable and are preserved as part of their top-level body. Duplicate
top-level tags are folded into the first occurrence with one blank line between
their bodies; duplicate source slots emit only one result tag.

Matching uses the canonical tag name, not schema `host_file` or body type. Those
schema fields control interpretation and command validation, not whether update
preserves adopter data. Distinct names use collision-free identities, so names
such as `a:b` and `a__b` cannot overwrite each other during the merge.

When a tag exists only in the source, its canonical body is retained. This
includes empty-table headers, replacement prompts, template rows, and other
HTML-comment scaffolding; update does not erase a source scaffold merely because
the adopter has no prior body.

The merge is fail-closed per file. It is built in a temporary target, and a
parsing or merge error leaves the installed file unchanged. Dry-run and apply
use the same expected-content builder.

Content outside tags is always framework-owned and comes from the canonical
source. Adopter prose must live inside a declared tag body to survive update.

Local-only files and directories are adopter-owned and are never changed.
Source-only files are copied wholesale. Passing a local-only path as `<path>`
is rejected.

Dry-run changed-set detection, displayed diffs, and staged apply use the same
expected-content builder.

## Transaction

Every `--apply` runs against a project-local staging copy first. Full update
refreshes skills and commands before rebuilding Markdown and reconciling the
adapter. It does not reconcile `config.yaml`; that is exclusive to `cumaru update
config`. It runs `cumaru doctor` against the staged project, and only a valid
result is published.

Cumaru serializes applies with `.cumaru-update.lock`, snapshots the exact managed
surfaces, and restores them on a handled commit failure. The transaction covers
`.cumaru/`, adapter instructions and hooks, `cumaru-*` skills, and supported
commands while preserving adopter-owned siblings. Staging and the lock are
removed after success or successful rollback.

This is logical transactionality across several filesystem paths, not one
filesystem-wide atomic rename. An existing lock blocks another apply rather
than guessing whether its owner is stale.

## Configuration reconciliation

Every general update mode validates the complete installed config before source
resolution, adapter inspection, or writes. The source domain config is also
validated before planning. Malformed YAML, closed-object violations, invalid
agent state, selected cross-field errors, and config/root version disagreement
block the operation. General update reports an invalid installed config as a
warning and stops before source resolution, staging, or mutation. Runtime
validation is Cumaru's `jq` implementation of its operational metamodel subset,
not a generic JSON Schema engine.

`cumaru update config` is a read-only reconciliation report. It gives the agent
the global `schemas/config.schema.json` contract, selected domain defaults,
model incompatibilities, and a complete candidate diff. The agent decides which
adopter-owned choices to keep and edits `config.yaml` deliberately.

`config.yaml` is never rewritten by Cumaru, including with `--apply`; that form
returns a usage error after printing the report. No persistent backup is created.
The only snapshots Cumaru keeps are private transaction snapshots, removed after
success or successful rollback.

## Agent artifacts

General update never changes agent artifacts. Use `cumaru update skills <agent>
--apply`, `cumaru update commands <agent> --apply`, or `cumaru update agent
<agent> --apply` for explicit targets. Agent artifacts are never persisted in
config. `--apply` requires an explicit agent; `--clear` removes the requested
adapter immediately, or every adapter when no agent is given. See
[`agent-adapters.md`](agent-adapters.md).

## Version gate

The local config version and root `framework-version` must agree. Versions are
integer migration boundaries, so the complete valid integer is compared: a
higher source value can be inspected in dry-run mode but `--apply` is refused
and points to `cumaru migrate`; every lower source value is refused.

`cumaru update config` has no adapter-file side effects and is not a
major-version migration mechanism. `cumaru doctor` surfaces the same drift as a
warning until an agent reconciles it.

## Recommended flow

1. Run `cumaru update --from <source>` and inspect the diff.
2. Confirm `cumaru update --apply`.
3. Run `cumaru doctor`; review any nested-tag warning, then use `cumaru tree <directory>` to navigate any
   affected directory.

Apply already runs doctor against the staged project; step 3 is an optional
visible post-commit confirmation.

## Exit codes

- `0` — success.
- `1` — validation, runtime, or transaction failure.
- `2` — usage error.

## Related

- [`cumaru migrate`](migrate.md) — prints the current migration instructions.
- [`cumaru tree`](tree.md) — filesystem-backed navigation.
- [`cumaru doctor`](doctor.md) — validates the resulting tree.
