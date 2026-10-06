---
name: port-wildcard-selector-conflict-check
description: Reject sibling wildcard selectors that declare conflicting attributes, porting the retired jq rule to Rust
status: open
priority: medium
---

# Issue 144: Port the wildcard selector conflict check to Rust

The retired Bash validator `schemas/schema-validate-v9.jq` enforced
`wildcard_conflicts`: within one `root` node, two sibling glob selectors (keys
containing `*`, `?`, or `[`) must not both declare `path`, `optional`,
`framework`, or `tags` with different values. The native CLI validates configs
through the embedded JSON Schema (`config::validate`) and the semantic checks in
`config_tree`, but no Rust code performs this cross-selector comparison. JSON
Schema cannot express it, so a v9 config with conflicting sibling wildcards is
currently accepted.

The jq file is no longer executed by any command, test runner, or CI job; it
remains only as the written reference for this rule and is blocked from removal
until the rule is ported (removal is tracked in issue 145).

## Risk

- A file matched by two sibling wildcards receives ambiguous ownership,
  optionality, or tag contracts; install, update, doctor, and tag resolve it by
  selector order instead of rejecting the config.
- Deleting the jq validator before porting loses the only written definition of
  the rule.

## Required invariant

Config validation fails, naming the node path and the conflicting attribute,
whenever two sibling glob selectors declare the same attribute among `path`,
`optional`, `framework`, and `tags` with unequal values; validation remains
unchanged when at most one of them declares it or the values are equal.

## Work

1. Add the pairwise sibling-wildcard comparison to the Rust config validation
   path that already walks `root` child selectors, reporting every conflict
   rather than stopping at the first one.
2. Record the rule in `.memory/specs/configuration.md` as a native invariant.
3. Issue 145 removes the jq validators and their stale references after this
   port lands.

## Tests

- Two sibling selectors `*.md: {framework: true}` and `[a-z]*.md: {framework: false}`
  fail validation with an error naming the node and `framework`.
- Sibling wildcards with equal values, a wildcard beside a literal selector,
  and wildcards in different nodes all validate successfully.
- All shipped `domains/*/config.yaml` files still validate.

## References

- `schemas/schema-validate-v9.jq` `wildcard_conflicts`, `validate_node`
- `src/config.rs` `validate`
- `src/config_tree.rs` `wildcard`, `declarations`
- `.memory/specs/configuration.md`
