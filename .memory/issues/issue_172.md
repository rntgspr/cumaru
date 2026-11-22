---
name: port-source-wildcard-index-check
description: Reject source domains whose tagged file wildcard also matches an entry index.md, porting the retired Bash check to Rust
status: open
priority: low
---

# Issue 172: Port the source-domain wildcard index check to Rust

The retired Bash `schema_validate_source_wildcards` (tag 0.10.0, `src/schema.sh`)
failed source-domain validation when a v9 `root` file selector containing `*`,
`?`, or `[` declared non-empty `tags` and also matched the literal name
`index.md`. Its diagnostic named the pillar, the wildcard, and the JSON Pointer.
The native CLI only exempts `index.md` from leaf wildcards during selector
resolution (`config_tree`); no Rust code rejects such a source declaration, so
`configuration.md` invariant 9's validation sentence has no native owner.

## Risk

- A shipped domain declares leaf tags through a wildcard such as `*.md`, and
  maintainers believe the index exemption is enforced at source-validation time
  when it is only applied silently during resolution.

## Required invariant

Remote source-domain validation for install and update fails, naming the pillar
and the wildcard selector, whenever a v9 file wildcard with non-empty `tags`
matches `index.md`; adopter configs and wildcards without tags are unaffected.

## Work

1. Add the check to the native source-domain validation path used by install
   and update, before any project write.
2. Update `configuration.md` invariant 9 to name its native owner.

## Tests

- A source config with `'*.md': {tags: [x]}` under a pillar fails with status 1,
  names the pillar and selector, and leaves the project unchanged.
- The same selector without `tags`, and a literal `index.md` selector with tags,
  remain valid.

## References

- `src/config_tree.rs`
- `src/commands/install.rs`, `src/commands/update.rs`
- `.memory/specs/configuration.md` invariant 9
- [`src/schema.sh`](https://github.com/rntgspr/cumaru/blob/0.10.0/src/schema.sh) — retired reference
