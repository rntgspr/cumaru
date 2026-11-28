# durable-memory/issues — issue index

Issues follow [`_issue_template.md`](_issue_template.md).

This directory holds open issues only. Completed issues are removed once their
invariants are absorbed into `durable-memory/specs/`, which is the durable single
source of truth; Git history keeps the retired records. New issues continue
from 179.

## Open issues

| Issue | Priority | Description |
|---|---|---|
| [040](issue_040.md) | low | Implement the manifest, loader, and hooks using issue 120's context policy |
| [064](issue_064.md) | medium | Restore a universal migration skill with approval and post-migration checks |
| [065](issue_065.md) | medium | Audit deterministic test scope and skill contract coverage |
| [139](issue_139.md) | high | Reuse legacy Bash regression scenarios for the native Rust CLI |
| [142](issue_142.md) | medium | Verify Homebrew installation on every supported platform |
| [143](issue_143.md) | low | Remove the unreachable legacy v8 tag resolution path |
| [144](issue_144.md) | medium | Port the wildcard selector conflict check from the retired jq validator to Rust |
| [145](issue_145.md) | medium | Realign specifications with the native Rust implementation |
| [161](issue_161.md) | high | Keep released binaries able to read the main domain config after additive meta keys ship |
| [162](issue_162.md) | high | Keep doctor reporting when the downloaded drift reference fails this binary's schema |
| [165](issue_165.md) | high | Make doctor survive an unwritable or contended drift reference cache |
| [166](issue_166.md) | medium | Bound the network cost of a drift reference that cannot be fetched |
| [167](issue_167.md) | medium | Decide whether cumaru context keeps ranking when the installed config is invalid |
| [168](issue_168.md) | medium | Make files outside the meta.context lists visible instead of silently unranked |
| [169](issue_169.md) | medium | Honor cumaru context --reset when no encoder is enabled |
| [170](issue_170.md) | low | Resolve the base/__base domain alias through one helper and fix the drift message path |
| [172](issue_172.md) | low | Port the source-domain wildcard index check to Rust |
| [173](issue_173.md) | low | Decide whether update reports archive skill artifacts |
| [174](issue_174.md) | low | Validate source discipline metadata before update writes |
| [177](issue_177.md) | medium | Let doctor verify memory-graph integrity: alias collisions, open disputes, reciprocal edges |

## Notes

- [040](issue_040.md) implements the context policy that
  [`../specs/disciplines.md`](../specs/disciplines.md) and
  [`../index.md`](../index.md) already define; it is not approved for delivery.
- [064](issue_064.md) is the known gap recorded in
  [`../specs/migration.md`](../specs/migration.md).
- [065](issue_065.md) is the known limit recorded in
  [`../specs/testing.md`](../specs/testing.md).
- The per-spec children of [145](issue_145.md) (147–160) are closed; only its
  jq-validator removal remains, blocked by [144](issue_144.md). Behaviors that
  lost a native owner during realignment are [172](issue_172.md),
  [173](issue_173.md), and [174](issue_174.md). Historical Bash deltas live in
  each capability spec's `Differences from the retired Bash CLI` section,
  indexed from [`../specs/rust.md`](../specs/rust.md#port-status).
- [142](issue_142.md) is the known limit recorded in
  [`../specs/rust.md`](../specs/rust.md#homebrew-distribution).
- The completed native skill/README review is recorded in
  [`../specs/skill-cli-contracts.md`](../specs/skill-cli-contracts.md).
