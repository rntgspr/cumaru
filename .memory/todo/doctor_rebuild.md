---
name: cumaru-doctor-rebuild
description: "Superseded: materialized index tables are replaced by virtual tree navigation in virtual_tree_v6.md"
status: superseded
---

> Superseded by [Virtual Tree V6](virtual_tree_v6.md). The filesystem and
> frontmatter summaries are now the structural source of truth; no table
> reconstruction command will be introduced.

## Historical Proposal

`cumaru doctor rebuild [<area>]`

- No arg = rebuild ALL table-type tags across the entire domain
- `<area>` = pillar name (e.g. `plans`, `specs`) — rebuild only that pillar's index tag

## Scope

- ONLY `default` and `[COL1, COL2, ...]` (table) tag types — never `prose`/`mixed`/`other`
- Operates per `host_file:` routing (reads schema `tags:` to know which tags live where)
- For pillar `index.md` files, the tag name matches the pillar name (e.g. `plans/index.md` → `<!-- cumaru:plans -->`)

## Source-of-truth for each row

### Directory-based entities (e.g. `plans/AAA-123/`)
- The directory `plans/AAA-123/` exists → must have a row
- The directory does not exist → row is stale (removed)
- Description comes from the entity's `index.md`:
  1. Frontmatter `description:` (if present)
  2. Fallback: first `# ` H1 found in the file
  3. If neither exists, the script adds the row with an empty description and reports a warning

### File-based entities (e.g. `specs/auth/authentication-flow.md`)
- The file exists on disk → must have a row
- The file is missing → row is stale (removed)
- Description comes from the file itself:
  1. Frontmatter `description:` (if present)
  2. Fallback: first `# ` H1
  3. Empty + warning if neither

### Root anchor rule
- `domain.md` `<!-- cumaru:root -->` and `<!-- cumaru:components -->` resolve against project root (same as `reference`)
- Pillar index rows resolve relative to the pillar directory (current behavior)

## Algorithm

```
for each table tag in the domain (ordered by schema):
  1. resolve host_file (e.g. specs/index.md)
  2. read the current <!-- cumaru:TAG --> block
  3. determine entity type from schema context:
     - child nodes of the pillar → directory-based OR file-based
     - meta tags → special rules (root, components, templates, etc)
  4. list actual entities on disk under the pillar
  5. diff: current rows vs actual entities
     - missing entity (has row, no dir/file) → DELETE row
     - orphan entity (has dir/file, no row) → ADD row (fetch description)
     - existing entity (has both) → UPDATE description if changed
  6. merge: keep unchanged rows, add new, drop stale
  7. write the new block in place
  8. report summary: +N / -N / ~N / unchanged
```

## Edge cases

- **Empty pillar directory**: regenerate block content with just the header + empty table body
- **Missing host_file**: error: "cannot rebuild — host_file not found"
- **Non-table tag**: silently skipped
- **Symlinks inside pillar**: resolved canonically, not followed out of `.cumaru/`
- **Description from foreign file**: if source file has no description and no H1, warn but keep an empty cell
- **`cumaru doctor rebuild` (no area)**: processes every table tag in the domain, one by one

## Dependencies

- New source file: `src/cmd_doctor_rebuild.sh` (sourced by `cmd_doctor.sh`)
- No new schema keys or template changes
- Parser reuse: `_parse_marker`, `_block_contents` etc from `common.sh`
- `_fm_get_description` utility (reads `description:` from frontmatter or H1)

## Future (not in scope)

- Cross-file validation (link targets, referenced paths)
- `prose`/`mixed` diffing
- Interaction with `cumaru update` (schema changes)
