# .memory/issues — issue index

Issues follow [`_issue_template.md`](_issue_template.md).

This directory holds open issues only. Completed issues are removed once their
invariants are absorbed into `.memory/specs/`, which is the durable single
source of truth; Git history keeps the retired records. New issues continue
from 143.

## Open issues

| Issue | Priority | Description |
|---|---|---|
| [040](issue_040.md) | low | Implement the manifest, loader, and hooks using issue 120's context policy |
| [064](issue_064.md) | medium | Restore a universal migration skill with approval and post-migration checks |
| [065](issue_065.md) | medium | Audit deterministic test scope and skill contract coverage |
| [132](issue_132.md) | medium | Ship bootstrap.md for the remaining domains |
| [139](issue_139.md) | high | Reuse legacy Bash regression scenarios for the native Rust CLI |
| [140](issue_140.md) | medium | Review deprecated src files and prepare an evidence-backed deletion manifest |
| [142](issue_142.md) | medium | Verify Homebrew installation on every supported platform |

## Notes

- [040](issue_040.md) implements the context policy that
  [`../specs/disciplines.md`](../specs/disciplines.md) and
  [`../index.md`](../index.md) already define; it is not approved for delivery.
- [064](issue_064.md) is the known gap recorded in
  [`../specs/migration.md`](../specs/migration.md).
- [065](issue_065.md) is the known limit recorded in
  [`../specs/testing.md`](../specs/testing.md).
- [142](issue_142.md) is the known limit recorded in
  [`../specs/rust.md`](../specs/rust.md#homebrew-distribution).
- The completed native skill/README review is recorded in
  [`../specs/skill-cli-contracts.md`](../specs/skill-cli-contracts.md).
