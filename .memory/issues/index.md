# .memory/issues — issue index

Issues follow [`_issue_template.md`](_issue_template.md).

This directory holds open issues only. Completed issues are removed once their
invariants are absorbed into `.memory/specs/`, which is the durable single
source of truth; Git history keeps the retired records. New issues continue
from 136.

## Open issues

| Issue | Priority | Description |
|---|---|---|
| [040](issue_040.md) | low | Implement the manifest, loader, and hooks using issue 120's context policy |
| [044](issue_044.md) | medium | Let pillar content live at project-root mounts |
| [064](issue_064.md) | medium | Restore a universal migration skill with approval and post-migration checks |
| [065](issue_065.md) | medium | Audit deterministic test scope and skill contract coverage |
| [132](issue_132.md) | medium | Ship bootstrap.md for the remaining domains |

## Notes

- [040](issue_040.md) implements the context policy that
  [`../specs/disciplines.md`](../specs/disciplines.md) and
  [`../index.md`](../index.md) already define; it is not approved for delivery.
- [064](issue_064.md) is the known gap recorded in
  [`../specs/migration.md`](../specs/migration.md).
- [065](issue_065.md) is the known limit recorded in
  [`../specs/testing.md`](../specs/testing.md).
