---
name: replace-update-backups-with-clean-git-preflight
description: Remove update recovery backup directories and require a clean Git work tree before mutation
status: completed
priority: high
---

# Issue 043: Replace update backups with a clean Git preflight

`cumaru update --apply` still creates temporary recovery copies of managed
surfaces before publication. The intended safety boundary should be the
adopter's Git history instead: before any mutating update step, Cumaru should
prove it is running inside a Git work tree and refuse to proceed when there are
uncommitted changes to commit.

## Risk

- Backup or recovery directories can leave adopter-visible debris after failed
  or interrupted runs.
- A private filesystem snapshot can hide the stronger operational requirement:
  the project must already have a user-controlled recovery point before Cumaru
  mutates managed surfaces.
- Updating over a dirty work tree can mix framework changes with unrelated user
  edits and make rollback or review ambiguous.

## Required invariant

No Cumaru update or other successful mutation creates a backup or recovery
directory. Before mutation, Cumaru verifies that the project is inside a Git
work tree and that there are no tracked, staged, unstaged, or untracked changes
that would need to be committed; if the work tree is dirty, it prints a clear
warning and exits without mutation.

## Work

1. Remove update's recovery-snapshot directory creation, restore path, cleanup
   path, and any equivalent backup directory behavior in other mutating flows.
2. Add a shared preflight for mutating commands that require recovery: verify a
   Git work tree with `git rev-parse --is-inside-work-tree` and inspect pending
   changes with porcelain status before staging or writes.
3. If pending changes exist, print an explicit warning that the user must commit
   or otherwise clean the work tree before running the update, then exit without
   creating locks, staging, backups, or partial output.
4. If the work tree is clean, continue with the existing update process: build
   staging, validate with doctor, publish the managed surfaces, and continue to
   the next update step.
5. Update the update, install/upgrade, migration, and architecture contracts so
   they describe Git cleanliness as the recovery boundary instead of private
   backup directories.

## Tests

- `cumaru update --apply` in a non-Git directory exits nonzero before mutation
  and reports that a Git work tree is required.
- `cumaru update --apply` with staged, unstaged, or untracked files exits
  nonzero before mutation, reports that the work tree must be committed or
  cleaned, and creates no lock, staging, backup, or recovery directory.
- `cumaru update --apply` in a clean Git work tree still stages, validates,
  publishes, and completes the normal update flow.
- A forced publication failure leaves no backup or recovery directory; recovery
  guidance points to Git history rather than private Cumaru snapshots.
- Contract tests confirm docs and help no longer promise update-created backup
  directories or snapshot-based restoration.

## References

- `src/cmd_update.sh`
- `src/common.sh`
- `docs/update.md`
- `.memory/specs/update.md`
- `.memory/specs/testing.md`
- `tests/spec/update/transaction_spec.sh`
- `tests/spec/update/dry_run_spec.sh`
