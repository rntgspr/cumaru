---
name: remove-legacy-v8-tag-resolution
description: Remove the unreachable v8 tag-declaration fallback now that config loading accepts only v9
status: open
priority: low
---

# Issue 143: Remove the legacy v8 tag resolution path

`cumaru tag` still branches on `config["version"]`: v9 configs resolve tag
contracts through `config_tree::tag_contracts`, and every other version falls
back to `config_tree::legacy_tags`, which reads v8 `root.tags` and pillar
declarations. Since the v8 schema was removed, `config::load` validates every
config against the single `config.schema.json`, whose `version` is `const: 9`.
Any non-v9 config fails before the branch, so the fallback is unreachable dead
code that documents a contract Cumaru no longer supports.

## Risk

- Readers infer that `tag` still supports v8 trees and keep the fallback in
  sync with future tag changes.
- A future loosening of the schema version constraint would silently revive
  v8 tag semantics instead of routing the tree to `cumaru migrate`.

## Required invariant

Tag declarations resolve only through the v9 config tree; no code path reads
v8 `root.tags` or pillar tag declarations.

## Work

1. Delete `config_tree::legacy_tags` and the version branch in
   `commands/tag.rs`, calling `config_tree::tag_contracts` unconditionally.
2. Remove any test or spec text that describes v8 tag resolution.

## Tests

- `cargo test --locked` passes with the existing v9 tag audit/get/set cases.
- A `version: 8` config makes `cumaru tag audit` fail at config validation
  without reading or writing the target Markdown file.

## References

- `src/config_tree.rs` `legacy_tags`
- `src/commands/tag.rs` tag operation dispatch
- `src/config.rs` `validate`
- `schemas/config.schema.json`
