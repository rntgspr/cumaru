# .memory/issues — issue index

Issues follow [`_issue_template.md`](_issue_template.md).

This directory holds open issues only. Completed issues are removed once their
invariants are absorbed into `.memory/specs/`, which is the durable single
source of truth; Git history keeps the retired records. New issues continue
from 161.

## Open issues

| Issue | Priority | Description |
|---|---|---|
| [040](issue_040.md) | low | Implement the manifest, loader, and hooks using issue 120's context policy |
| [064](issue_064.md) | medium | Restore a universal migration skill with approval and post-migration checks |
| [065](issue_065.md) | medium | Audit deterministic test scope and skill contract coverage |
| [132](issue_132.md) | medium | Ship bootstrap.md for the remaining domains |
| [139](issue_139.md) | high | Reuse legacy Bash regression scenarios for the native Rust CLI |
| [142](issue_142.md) | medium | Verify Homebrew installation on every supported platform |
| [143](issue_143.md) | low | Remove the unreachable legacy v8 tag resolution path |
| [144](issue_144.md) | medium | Port the wildcard selector conflict check from the retired jq validator to Rust |
| [145](issue_145.md) | medium | Realign specifications with the native Rust implementation |
| [146](issue_146.md) | low | Compact historical Bash narrative in current specifications |
| [147](issue_147.md) | medium | Realign navigation.md with the native implementation |
| [148](issue_148.md) | medium | Realign update.md with the native implementation |
| [149](issue_149.md) | medium | Realign tags.md with the native implementation |
| [150](issue_150.md) | medium | Realign configuration.md with the native implementation |
| [151](issue_151.md) | low | Realign absorb.md with the native implementation |
| [152](issue_152.md) | low | Realign agent-adapters.md with the native implementation |
| [153](issue_153.md) | low | Realign architecture.md with the native implementation |
| [154](issue_154.md) | low | Realign coverage.md with the native implementation |
| [155](issue_155.md) | low | Realign disciplines.md with the native implementation |
| [156](issue_156.md) | low | Realign doctor.md with the native implementation |
| [157](issue_157.md) | low | Realign domains.md with the native implementation |
| [158](issue_158.md) | low | Realign install-upgrade.md with the native implementation |
| [159](issue_159.md) | low | Realign migration.md with the native implementation |
| [160](issue_160.md) | low | Realign workflows.md with the native implementation |

## Notes

- [040](issue_040.md) implements the context policy that
  [`../specs/disciplines.md`](../specs/disciplines.md) and
  [`../index.md`](../index.md) already define; it is not approved for delivery.
- [064](issue_064.md) is the known gap recorded in
  [`../specs/migration.md`](../specs/migration.md).
- [065](issue_065.md) is the known limit recorded in
  [`../specs/testing.md`](../specs/testing.md).
- Issues 147–160 are children of [145](issue_145.md), one per drifting
  spec; close a child only after its spec matches the Rust owner. Issues
  145 → 146 remain sequenced: ownership realignment first, then
  compacting the historical Bash narration left in each spec body.
- [142](issue_142.md) is the known limit recorded in
  [`../specs/rust.md`](../specs/rust.md#homebrew-distribution).
- The completed native skill/README review is recorded in
  [`../specs/skill-cli-contracts.md`](../specs/skill-cli-contracts.md).
