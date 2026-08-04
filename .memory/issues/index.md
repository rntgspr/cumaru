# .memory/issues — issue index

Issues follow [`_issue_template.md`](_issue_template.md).

This directory holds open issues only. Completed issues are removed once their
invariants are absorbed into `.memory/specs/`, which is the durable single
source of truth; Git history keeps the retired records. New issues continue
from 126.

## Open issues

| Issue | Priority | Description |
|---|---|---|
| [035](issue_035.md) | low | Add a configurable post-upgrade snapshot pruner |
| [040](issue_040.md) | low | Implement the manifest, loader, and hooks using issue 120's context policy |
| [044](issue_044.md) | medium | Let pillar content live at project-root mounts |
| [045](issue_045.md) | medium | Explore grounded intelligent search before defining its public contract |
| [064](issue_064.md) | medium | Restore a universal migration skill with approval and post-migration checks |
| [065](issue_065.md) | medium | Audit deterministic test scope and skill contract coverage |

## Notes

- [040](issue_040.md) implements the context policy that
  [`../specs/disciplines.md`](../specs/disciplines.md) and
  [`../index.md`](../index.md) already define; it is not approved for delivery.
- [064](issue_064.md) is the known gap recorded in
  [`../specs/migration.md`](../specs/migration.md).
- [065](issue_065.md) is the known limit recorded in
  [`../specs/testing.md`](../specs/testing.md).
- [045](issue_045.md) references a `docs/quickstart.md` that does not exist;
  resolve the target before defining the public contract.
