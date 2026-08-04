---
name: restore-universal-migration-skill
description: Ship a migration skill for every agent with inspection, approval, and post-migration checks
status: open
priority: high
---

# Issue 064: Restore the universal `cumaru-migrate` skill

The rolling migration document is available through `cumaru migrate`, but no
`cumaru-migrate` skill is installed for agents. The command only prints
instructions; it does not inspect an adopter, plan changes, request approval,
or apply them. Agents need one discoverable workflow for that work.

## Risk

- An agent may treat the printed procedure as a generic script and miss local
  structure, adopter-owned content, or a domain-specific conversion.
- A migration may appear complete while same-version update or doctor still
  reports a blocking problem.

## Required invariant

Every supported agent receives `cumaru-migrate`. The skill inspects the local
installation and data, prepares a project-specific migration plan, obtains
explicit user approval of that plan before mutation, applies the approved
changes, and verifies that `cumaru update` and `cumaru doctor` can run cleanly
against the target version.

## Work

1. Add `cumaru-migrate` to the universal `__base` skills and distribute it
   through the existing agent adapter install/update paths. Keep the rolling
   migration document and `cumaru migrate` as the canonical versioned procedure;
   the skill orchestrates it rather than copying its steps.
2. Require the skill to inspect the installed version, selected domain,
   configuration shape, directory layout, frontmatter, tags, adopter-owned
   content, and relevant agent artifacts. Identify ambiguous or destructive
   changes and stop for a user decision.
3. Produce a concrete plan and proposed diffs for the local adopter. Confirm
   the plan with the user before changing files. Apply only approved changes
   while preserving adopter data and the migration recovery contract.
4. After migration, run doctor and a same-version update preview against the
   target source. Resolve migration-caused findings and verify an update apply
   is safe before declaring completion. Do not claim success while either
   command reports a blocking issue; obtain separate approval if follow-up
   changes exceed the approved migration plan.
5. Update the relevant skill inventory and migration documentation with the
   entry point and its relationship to the read-only CLI command.

## Tests

- Every supported agent adapter receives the universal skill on install and
  skill update, without a domain-specific duplicate.
- A populated older adopter produces an inspection-based plan and remains
  unchanged until the user approves it; after application, doctor and update
  preview pass against the target version.
- Ambiguous ownership, missing approval, or failed post-migration checks
  prevent a success report and preserve user data.

## References

- [Rolling migration issue](issue_063.md)
- [Base migration procedure](../../domains/__base/migration.md)
- [Migration command](../../src/cmd_migrate.sh)
- [Universal skill source](../../domains/__base/skills)
- [Agent skill installer](../../src/cmd_install.sh)
- [Agent skill updater](../../src/cmd_update.sh)
