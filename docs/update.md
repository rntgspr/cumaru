# `cumaru update`

Refresh an installed `.cumaru/` tree from the matching source domain. It never
crosses a major schema version: use `cumaru migrate v6` for that transition.

## Usage

```text
cumaru update [<path>] [--from <src>] [--keep-prose] [--apply]
cumaru update skills|commands|schema [--from <src>] [--apply]
cumaru update agent <none|claude|codex|opencode> [--from <src>] [--apply]
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

Normal update reads `agent` from schema and refreshes that adapter's native
instructions, skills, and supported commands. Opt-in skills are untouched.
Deprecated framework skills are pruned; deprecated commands are reported.

`cumaru update agent <name>` previews a switch. `--apply` removes only the old
Cumaru-owned footprint, installs the target artifacts, and writes schema last.
`none` restores `agent: null` and the generic `.agents/` layout. See
[`agent-adapters.md`](agent-adapters.md) for the exact matrix.

## Version gate

The local schema version and root `framework-version` must agree. A source with
a higher major version can be inspected in dry-run mode but `--apply` is
refused and points to `cumaru migrate v<major>`. Downgrades are refused.

`cumaru update schema --apply` replaces the framework schema and is
intentionally destructive to other local schema customizations, but preserves
the active `agent` state. It is not a major-version migration mechanism.

## Recommended flow

1. Run `cumaru update --from <source>` and inspect the diff.
2. Confirm `cumaru update --apply`.
3. Run `cumaru doctor` and use `cumaru tree <directory>` to navigate any
   affected directory.

## Related

- [`cumaru migrate`](migrate.md) — transactional major-version migration.
- [`cumaru tree`](tree.md) — filesystem-backed navigation.
- [`cumaru doctor`](doctor.md) — validates the resulting tree.
