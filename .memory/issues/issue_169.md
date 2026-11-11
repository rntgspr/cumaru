---
name: context-reset-ignored-without-encoder
description: Honor cumaru context --reset when no encoder is enabled
status: open
priority: medium
---

# Issue 169: `--reset` is ignored when no encoder is enabled

In `execute`, the early return for a warm run without an enabled encoder
happens before the reset block. `cumaru context --reset`, with or without
`--scope`, then prints `no enabled encoder; nothing to cache`, exits 0, and
leaves the cache directory on disk. An adopter who released the model cannot
drop the stale vectors through the documented flag.

## Risk

- The command reports success while the requested deletion did not happen.

## Required invariant

`cumaru context --reset` removes the selected cache directory whether or not
an encoder is enabled.

## Work

1. Run the reset before the no-encoder early return.
2. Keep the "nothing to cache" notice after the reset.

## Tests

- Without an encoder, `--reset --scope source` removes only
  `.cumaru/.cache/context/source/` and exits 0.
- Without an encoder, `--reset` removes `.cumaru/.cache/context/`.

## References

- `src/commands/context.rs` `execute`
- `src/vectors.rs` `Cache::reset`
- `tests/native/`
