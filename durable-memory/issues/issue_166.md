---
name: doctor-reference-fetch-has-no-negative-cache
description: Bound the network cost of a drift reference that cannot be fetched
status: open
priority: medium
---

# Issue 166: Failed drift reference fetches repeat on every doctor run

The drift reference goes through `distribution::domain_source`, which resolves
the main commit, lists the recursive tree, and then reads one file: three
requests. A failed lookup is not remembered, so a custom domain or an offline
machine repeats those requests on every `cumaru doctor`, each with its connect
timeout, and the `update --apply` postcheck fetches `domain_source` a second
time. The requests are unauthenticated and count against the GitHub API quota.

## Risk

- An agent loop running doctor exhausts the unauthenticated quota, which then
  also breaks `cumaru update`.
- Offline doctor runs are slow on every invocation.

## Required invariant

Within one calendar day, a project performs at most one drift reference fetch
attempt per outcome, successful or not.

## Work

1. Record a failed attempt for the day under `.cumaru/.cache/` and skip the
   network while that record is current.
2. Read the single `config.yaml` without listing the whole tree when the
   existing download helper allows it.
3. Reuse the reference already resolved when doctor runs as the update
   postcheck.

## Tests

- Two consecutive offline doctor runs perform one fetch attempt in total.
- A custom domain performs one attempt per day and still passes doctor.

## References

- `src/commands/doctor.rs` `reference`, `fetch_main`
- `src/distribution.rs` `domain_source`, `download`
- `src/commands/update.rs` doctor postcheck
