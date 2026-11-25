---
name: context-fails-on-invalid-config
description: Decide whether cumaru context keeps ranking when the installed config is invalid
status: open
priority: medium
---

# Issue 167: `cumaru context` hard-fails on an invalid config

`resolve` in `src/commands/context.rs` falls back to config-free ranking only
when `config.yaml` is missing, symlinked, or unreadable. A config that exists
but fails parsing or schema validation is propagated as an error. A project
with a pre-v9 config, or a v9 config with one typo, used to rank every visible
`.cumaru/` Markdown file and now gets a schema error; the `cumaru update` warm
reports the cache as not warmed for the same reason.

## Risk

- Search stops working exactly when the tree is being repaired or migrated.
- The command's documentation still promises config-free operation.

## Required invariant

`cumaru context` either ranks with a stated fallback or fails with one stated
rule; the documentation and the behavior agree for an invalid config.

## Work

1. Decide: fall back to config-free ranking with a stderr warning, or keep
   the failure and document it.
2. Apply the decision in `resolve` and align the command help, the function
   doc comment, `docs/context.md`, and `specs/context.md`.

## Tests

- A `version: 8` config yields the decided status and, on fallback, the same
  rows as a tree without a config.
- An invalid `meta.context` entry (absolute path or `..`) stays a
  configuration error.

## References

- `src/commands/context.rs` `resolve`, `entry`
- `src/config.rs` `parse`
- `docs/context.md`
