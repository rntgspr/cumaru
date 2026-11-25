---
name: doctor-reference-cache-write-errors-are-fatal
description: Make doctor survive an unwritable or contended drift reference cache
status: open
priority: high
---

# Issue 165: Drift reference cache write errors fail doctor

Doctor now writes `.cumaru/.cache/config-<date>.yaml` and may append the cache
entry to the project `.gitignore`. Every filesystem error on that path is
propagated as a fatal doctor error. The temporary file name
`.config-<date>.yaml.tmp` carries no process id, so two concurrent doctors
(for example an agent run and the `update --apply` postcheck) write the same
temporary file and one of them fails on rename or on removing the older cache.

## Risk

- Doctor fails on a read-only checkout or CI mount where it used to pass.
- Concurrent runs fail intermittently with a not-found error.

## Required invariant

Failing to persist the drift reference never fails doctor; the reference
already in memory is still used for the comparison.

## Work

1. Treat cache directory, `.gitignore`, write, rename, and stale-file removal
   errors as a warning, and compare against the downloaded text.
2. Add the process id to the temporary file name, as `vectors::Cache::save`
   does, and ignore not-found when removing older files.
3. Keep the symlink refusal as a hard error.

## Tests

- With an unwritable `.cumaru/.cache`, doctor exits 0 with a warning and the
  drift comparison still runs.
- Two overlapping reference writes both succeed.

## References

- `src/commands/doctor.rs` `reference`
- `src/vectors.rs` `Cache::save`, `ignore`
