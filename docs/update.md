# `cumaru update`

Refresh an installed `.cumaru/` tree from the matching source domain at HEAD of
`main`. It never crosses a config version boundary: use `cumaru migrate` for
that transition.

## Usage

```text
cumaru update [<path>] [--apply]
cumaru update config
cumaru update skills <agent> [--with <skill>...] [--apply|--clear]
cumaru update commands <agent> [--apply|--clear]
cumaru update agent <agent> [--apply|--clear]
cumaru update skills|commands|agent --clear
```

`<agent>` is `none`, `claude`, `codex`, or `opencode`. Install and refresh
forms are previews unless `--apply` is present. `--clear` is the explicit
exception: it removes the selected Cumaru artifacts immediately after the Git
recovery check and does not require `--apply`. With an agent it is scoped to
that adapter; without one it clears that artifact surface across every
supported adapter. `--apply` and `--clear` are mutually exclusive.

## Source

Every invocation resolves HEAD of `main` and pins all reads to that commit;
the preview prints it as `source: main (<sha>)`. There is no `--from`, local
checkout, or snapshot source, and no `--domain` flag: the installed
`config.yaml` selects `domains/<domain>/` (`base` selects `domains/__base/`).
A failed lookup is an error; no version is inferred. Binary release tags play
no part in project update.

## Version gate

Only installed version 9 configurations are supported, and the source and local
config integers must be equal. A different source version fails before any
write with `main config version differs; use cumaru migrate`. The CLI build
version (for example `0.9.1`) is unrelated to this gate. Use `cumaru version` to
see installed, latest, status, and drift fields before updating.

## Ownership and replacement

Only entries explicitly marked `framework: true` in both the source and the
installed configured tree are update targets. Ownership is per entry: it never
inherits from a marked directory, and omitted or `false` entries remain
adopter-owned. Literal path overrides map canonical content to the installed
destination; wildcard matches require equal physical selectors and a matching
source file. If a former canonical path still exists, update reports it for
review and never moves or deletes it.

Before replacement, update captures every local `<!-- cumaru:NAME -->` body.
It then restores each body at the first corresponding source tag. If a local tag
has no source marker, update inserts it immediately after frontmatter. Thus
tags remain adopter-owned while all content outside tags, including
frontmatter, returns to the canonical source.

Source, local, and candidate documents must all have balanced tags. Missing
closers and crossing tags stop the update without writing. Balanced nested tags
are preserved as part of their top-level body. Duplicate top-level tags are
folded into the first occurrence. When a tag exists only in the source, its
canonical scaffold body is retained.

Adopter prose must live inside a tag body to survive update. Local-only files,
unowned entries, `config.yaml`, bootstrap/migration documents, and adapter
files are untouched by content update. Passing a `<path>` that selects no
framework-owned entry is an error. A remaining `.cumaru/archive/` is reported
for review and left unchanged.

Preview, displayed diffs, and apply use the same expected-content builder.

## Configuration reconciliation

`cumaru update config` is a read-only reconciliation report. It prints removed
JSON Pointers for properties the global model does not allow, the current
`config.yaml`, and a complete candidate (JSON, which is valid YAML). The
candidate fills missing source defaults and retains valid local scalar, array,
and glob choices; a permitted but invalid value is a blocker. The agent decides
which adopter-owned choices to keep and edits `config.yaml` deliberately.

`config.yaml` is never rewritten by Cumaru; `update config --apply` is a usage
error. No persistent backup is created.

## Agent artifacts

General update never changes agent artifacts. Refresh requires an explicit
adapter:

- `skills <agent>` replaces and prunes only Cumaru-owned `cumaru-*` skills.
- `commands <agent>` applies to Generic (`none`) and OpenCode; Claude and Codex
  invoke skills directly and reject it.
- `agent <agent>` refreshes skills, supported commands, instructions, and hooks,
  preserving unrelated native entries.

Add or refresh selected opt-ins without reinstalling the domain:

```bash
cumaru update skills codex --with git
cumaru update skills codex --with git --apply
```

`--with` is repeatable, works only in skills mode, validates every requested
top-level skill against the pinned source before mutation, and changes only
those opt-in directories. `--clear` needs a valid local config but no network;
it removes exact owned entries and leaves adopter skills and opt-ins in place.
See [`agent-adapters.md`](agent-adapters.md).

## Transaction

Complete download, merge planning, and destination checks precede any write.
Every mutating `--apply` or `--clear` then checks whether the project belongs to
a Git work tree. When it does, `git status --porcelain --untracked-files=all`
must be empty, the repository must have a commit, and `.cumaru/config.yaml` plus
`.cumaru/index.md` must be tracked, so Git history remains the recovery point.
Outside Git, Cumaru prints a warning and continues without a recovery point; it
never initializes a repository.

Files are written and removed directly. Cumaru creates no lock, staging
directory, backup, or rollback; detected concurrent edits block the affected
write. Every changed apply or clear runs `cumaru doctor` in quiet mode
afterwards. A blocking check returns `1` with the published changes left for
review; restore from Git history if needed.

## Recommended flow

1. Run `cumaru version` and report the CLI and config identities separately.
2. Run `cumaru update` and inspect the diff.
3. Confirm `cumaru update --apply`.
4. Optionally run `cumaru doctor`, then `cumaru tree <directory>` to navigate
   any affected directory.

## Exit codes

- `0` — success.
- `1` — validation, network, version gate, runtime, write, or post-check failure.
- `2` — usage error.

## Related

- [`cumaru migrate`](migrate.md) — prints the current migration instructions.
- [`cumaru tree`](tree.md) — filesystem-backed navigation.
- [`cumaru doctor`](doctor.md) — validates the resulting tree.
