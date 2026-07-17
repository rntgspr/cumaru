# `cumaru update`

Refresh an installed `.cumaru/` tree from the matching source domain. It never
crosses a major schema version: use `cumaru migrate v6` for that transition.

## Usage

```text
cumaru update [<path>] [--from <src>] [--keep-prose] [--apply]
cumaru update skills|commands|schema [--from <src>] [--apply]
```

The installed `schema.yaml` selects `<source>/domains/<domain>/`; `base`
selects `domains/__base/`. There is no `--domain` flag because update refreshes
the domain already installed in the project.

## Ownership and replacement

Framework-owned Markdown files include starter indexes, templates, roles,
disciplines, and domain instructions. On `--apply`, a file present in the
source is rebuilt from its canonical source version.

Before replacement, update captures every local `<!-- cumaru:NAME -->` body.
It then restores each body at the corresponding source marker. If a local tag
has no source marker, update inserts it immediately after frontmatter (or at
the beginning when the file has none). Thus tags remain adopter-owned while all
outside-marker content, including frontmatter, returns to the canonical source.

`--keep-prose` retains local outside-marker prose for an explicitly selected
scope. It is an opt-out for a deliberately diverging local document.

Local-only files and directories are adopter-owned and are never changed.
Source-only files are copied wholesale. Passing a local-only path as `<path>`
is rejected.

## Agent artifacts

Skills and slash commands are framework-owned and replaced
deterministically from `domains/<domain>/`:

- `skills/cumaru-*/` → `.agents/skills/`;
- `commands/cumaru/*.md` → `.agents/commands/cumaru/`.

Opt-in skills are untouched. Deprecated framework skills are pruned; deprecated
commands are reported for review. The agent instruction hook is
reconciled only in `.agents/AGENTS.md` before content changes. The CLI never
reads or writes `CLAUDE.md` or `.claude/`; when those compatibility files
exist, the installed `cumaru-update` skill offers a separate, user-confirmed
content alignment.

## Version gate

The local schema version and root `framework-version` must agree. A source with
a higher major version can be inspected in dry-run mode but `--apply` is
refused and points to `cumaru migrate v<major>`. Downgrades are refused.

`cumaru update schema --apply` replaces the schema and is intentionally
destructive. It is not a major-version migration mechanism.

## Recommended flow

1. Run `cumaru update --from <source>` and inspect the diff.
2. Confirm `cumaru update --apply`.
3. Run `cumaru doctor` and use `cumaru tree <directory>` to navigate any
   affected directory.

## Related

- [`cumaru migrate`](migrate.md) — transactional major-version migration.
- [`cumaru tree`](tree.md) — filesystem-backed navigation.
- [`cumaru doctor`](doctor.md) — validates the resulting tree.
