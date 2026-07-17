---
name: cumaru-v5-tag-body-model
description: "v5 tag schema model — tag blocks are adopter-owned, but schema declares body type: default, custom columns, prose, mixed, other"
metadata:
  type: project
---

> Tag typing remains valid in V6, but structural inventories do not. Marker
> blocks now carry only semantic adopter data; filesystem candidates come from
> `cumaru tree`. See [[v6_virtual_tree]].

Decision from Renato (2026-07-10): v4's "every tag is `[Link, Description]`" was too strict. A tag is a named adopter-owned block; its body can be typed by schema.

**Schema shape.** Use scalar/array values under `tags:`:

```yaml
specs:
  tags:
    specs: default
    absorptions: [SHA, KEY, Description]
```

Allowed values:
- `default` = standard table with columns `Link`, `Description`.
- `[COL1, COL2, ...]` = custom deterministic table with those exact columns.
- `prose` = free prose, preserved by update, not path-resolved.
- `mixed` / `other` = adopter-owned opaque body; tooling preserves it but does not infer structure.

Meta tags can keep routing metadata:

```yaml
root: { host_file: domain.md, type: prose }
components: { host_file: domain.md, type: default }
```

`{}` is no longer authored in source schemas. The parser still reads old `{}` as `default` for migration/debugging compatibility.

**Tooling implications implemented.**
- `cumaru tag all --rows` emits only `default` `[Link, Description]` rows and resolves paths.
- `cumaru tag all --tables` emits deterministic table rows (`default` + custom arrays) as TSV.
- `cumaru tag all --prose` prints schema-declared prose blocks.
- `cumaru tag all --mixed` prints `mixed`/`other` bodies.
- `doctor` path-resolves only `default` rows; custom table tags are checked for declared headers; prose/mixed/other are preserved-only.
- `update` must preserve every tag body regardless of type; dry-run classifies prose/mixed/other as preserved, not malformed.

**Anchor rule fix.** `domain.md` and root `index.md` default rows resolve against the adopter project root, matching doctor's orphan-check intent. Other default rows resolve relative to their host file, except `reference`, which has its source-file rule.

**Why schema instead of hardcode.** Once `root` can be prose and `absorptions` can be `SHA | KEY | Description`, hardcoding tag names would reintroduce drift between doctor/tag/update. The schema now carries minimal body semantics without returning to v3's rich per-column metadata.
