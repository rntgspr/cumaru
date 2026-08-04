# `cumaru update`

Refresh an installed `.cumaru/` tree from the matching source domain. It never
crosses a major schema version: use `cumaru migrate` for that transition.

## Usage

```text
cumaru update [<path>] [--from <src>] [--apply]
cumaru update skills <agent> [--with <skill>...] [--from <src>] [--apply|--clear]
cumaru update commands <agent> [--from <src>] [--apply|--clear]
cumaru update config [--from <src>]
cumaru update agent [<none|claude|codex|opencode>] [--apply|--clear]
cumaru update skills|commands [<none|claude|codex|opencode>] [--apply|--clear]
```

Install and refresh forms are previews unless `--apply` is present. `--clear`
is the explicit exception: it removes the selected Cumaru artifacts immediately
after the Git recovery check and does not require `--apply`. With an agent it
is scoped to that adapter; without an agent it clears that artifact surface
across every supported adapter.

The installed `config.yaml` selects `<source>/domains/<domain>/`; `base`
selects `domains/__base/`. There is no `--domain` flag because update refreshes
the domain already installed in the project.

## Ownership and replacement

For v9 installs, only entries explicitly marked `framework: true` in the
configured tree are update targets. Ownership is per entry: it never inherits
from a marked directory, and omitted or `false` entries remain adopter-owned.
Cumaru verifies the matching canonical source entry before rebuilding a target.
An entry `path` changes the installed destination; if the former canonical path
still exists, update reports it for review and never moves or deletes it.

V8 installs retain the legacy starter traversal until migration. For an owned
target, YAML frontmatter and content outside marker bodies come from its
canonical source.

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

Matching uses the canonical tag name. Tag bodies are opaque adopter content, so
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
In v9, undeclared or unowned source files are not copied. Passing an
adopter-owned path as `<path>` is rejected.

Dry-run changed-set detection, displayed diffs, and apply use the same
expected-content builder.

## Deprecated archive artifacts

Within v8, update reports `.cumaru/archive/`, `root.entities.archive`, and
installed `cumaru-archive` skills or launchers as deprecated. Cumaru no longer
uses these surfaces. General dry-run and apply leave them untouched so an agent
can inspect and reconcile any remaining adopter evidence deliberately.

Explicit `update skills|commands|agent <agent> --apply` may replace the retired
framework-owned skill or launcher under its normal artifact rules. It does not
delete adopter-owned `.cumaru/archive/` content or rewrite config.

## Transaction

Every mutating `--apply` or `--clear` first checks whether the project belongs
to a Git work tree. When it does, `git status --porcelain
--untracked-files=all` must be empty, the repository must have a commit, and
`.cumaru/config.yaml` plus `.cumaru/index.md` must be tracked. Staged, unstaged,
or untracked changes block mutation so Git history remains the recovery point.

Outside Git — when the executable is unavailable or the project is not a work
tree — Cumaru prints a warning and continues without a Git recovery point. It
never initializes a repository implicitly. A Git URL passed through `--from`
still requires the Git executable to fetch that source.

Full update rebuilds Markdown directly in the live project after the Git
preflight. It does not reconcile `config.yaml`; that is exclusive to `cumaru
update config`. It runs `cumaru doctor` after mutation; if validation fails,
inspect the work tree and restore from Git history.

Cumaru creates no project-local lock, staging directory, private backup, or
recovery directory. The mutation covers `.cumaru/`, adapter instructions and
hooks, `cumaru-*` skills, and supported commands while preserving adopter-owned
siblings.

Writes across several filesystem paths are not atomic. If any write or the
post-mutation doctor fails, inspect the Git diff and restore from Git history.

## Configuration reconciliation

Every general update mode validates the complete installed config before source
resolution, adapter inspection, or writes. The source domain config is also
validated before planning. Malformed YAML, closed-object violations, invalid
agent state, selected cross-field errors, and config/root version disagreement
block the operation. General update reports an invalid installed config as a
warning and stops before source resolution or mutation. Runtime
validation is Cumaru's `jq` implementation of its operational metamodel subset,
not a generic JSON Schema engine.

`cumaru update config` is a read-only reconciliation report. It gives the agent
the global `schemas/config.schema.json` contract, selected domain defaults,
model incompatibilities, and a complete candidate diff. The agent decides which
adopter-owned choices to keep and edits `config.yaml` deliberately.

`config.yaml` is never rewritten by Cumaru, including with `--apply`; that form
returns a usage error after printing the report. No persistent backup is created.
No private recovery snapshots are created.

## Agent artifacts

General update never changes agent artifacts. Use `cumaru update skills <agent>
--apply`, `cumaru update commands <agent> --apply`, or `cumaru update agent
<agent> --apply` for explicit targets. Agent artifacts are never persisted in
config. `--apply` requires an explicit agent; `--clear` removes the requested
adapter immediately, or every adapter when no agent is given. Clear is not a
preview and does not require `--apply`. It uses the conditional Git recovery
check described above. See [`agent-adapters.md`](agent-adapters.md).

Add or refresh selected opt-ins without reinstalling the domain:

```bash
cumaru update skills codex --with git
cumaru update skills codex --with git --apply
```

`--with` is repeatable, previews without `--apply`, validates every requested
top-level skill before mutation, and changes only those opt-in directories.

## Version gate

The local and source config versions are the sole version gate. Versions are
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

Apply already runs doctor after mutation; step 3 is an optional
visible post-commit confirmation.

## Exit codes

- `0` — success.
- `1` — validation, runtime, write, or post-check failure.
- `2` — usage error.

## Related

- [`cumaru migrate`](migrate.md) — prints the current migration instructions.
- [`cumaru tree`](tree.md) — filesystem-backed navigation.
- [`cumaru doctor`](doctor.md) — validates the resulting tree.
