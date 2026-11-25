---
name: share-base-domain-alias
description: Resolve the base/__base domain alias through one helper and fix the drift message path
status: open
priority: low
---

# Issue 170: The `base`/`__base` alias is implemented four times

The mapping between the `base` domain name and the `__base` source directory
exists in `src/commands/update.rs`, `src/commands/version.rs`, and twice more
in `src/commands/doctor.rs` (`fetch_main`, `same_domain`). The drift message
does not apply it: for the base domain it names
`domains/base/config.yaml on GitHub main`, a path that does not exist.

## Risk

- The copies drift apart and one command resolves the base domain differently.
- The drift message sends the adopter to a nonexistent file.

## Required invariant

Every command resolves the base domain's source directory through one shared
function, and messages name the real source path.

## Work

1. Add one helper next to the other domain/path helpers and use it at the
   four sites.
2. Use it when formatting the drift reference message.

## Tests

- Doctor on a base-domain tree names `domains/__base/config.yaml`.
- Existing base-domain update and version tests keep passing.

## References

- `src/commands/doctor.rs` `fetch_main`, `same_domain`, `drift`
- `src/commands/update.rs`
- `src/commands/version.rs`
