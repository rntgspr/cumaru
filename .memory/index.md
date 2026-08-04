# Memory index

Use this catalog to select current specifications on demand. Root files outside
`specs/` are metacontext, user context, working notes, templates, or historical
review.

## Repository startup policy

Before substantive repository work, load this complete mandatory set exactly
once and in this order:

1. `.memory/index.md`.
2. `.memory/advisor_mode.md`.
3. Every regular `.memory/disciplines/*.md` file in `LC_ALL=C` path order.

The complete set has a 32 KiB (32,768-byte) budget, measured as the sum of the
selected files' byte sizes. A context emitter must resolve and validate the
whole set first, then report the selected file count and total byte count. If a
mandatory file is missing or the total exceeds the budget, it must diagnose the
complete-set failure and emit none of the selected file bodies; truncation and
partial context are forbidden.

Specifications are current reference material selected on demand from the
catalog below. Review issues, todo records, working notes, templates, and Git
history are historical or task-scoped material and load only when relevant.
Public documentation under `docs/` also loads on demand for the surface being
worked on. Neither repository startup nor its 32 KiB budget changes installed
Cumaru bootstrap: `.cumaru/index.md`, `.cumaru/domain.md`, every installed
discipline with its index first, and the root candidate projection remain the
mandatory framework order.

## Specifications

- [Architecture](specs/architecture.md) — kernel, ownership, configuration, lifecycle, and system boundaries.
- [Navigation](specs/navigation.md) — filesystem projection, summaries, filters, and bounded traversal.
- [Domains](specs/domains.md) — domain package contract and shipped domain profiles.
- [Design as Code](specs/design-as-code.md) — six-pillar lifecycle, three roles, canonical briefs, and reviewed design evidence.
- [Absorb](specs/absorb.md) — transient close-out into the durable single source of truth.
- [Disciplines](specs/disciplines.md) — execution-discipline artifact, loading, attribution, and drift.
- [Update](specs/update.md) — steady-state previews, direct writes, scoped modes, explicit adapter targets, and Git recovery.
- [Configuration](specs/configuration.md) — global model, validation, and agent-led reconciliation.
- [Doctor](specs/doctor.md) — v9 installed-tree validation and migration routing.
- [Workflows](specs/workflows.md) — optional skill dependency graphs and cumaru-flow orchestration.
- [Tags](specs/tags.md) — marker grammar, body types, balanced parsing, and preservation.
- [Migration](specs/migration.md) — read-only rolling direct N-to-v9 instructions.
- [Agent adapters](specs/agent-adapters.md) — native artifacts, bootstrap order, hooks, and switching.
- [Install and upgrade](specs/install-upgrade.md) — project installation and destructive global upgrade.
- [Coverage](specs/coverage.md) — source-reference coverage modes, buckets, and strict gate.
- [Testing](specs/testing.md) — ShellSpec suite, CI, isolation, manual bench, and upgrade exception.

## Operational Disciplines

- [Communication](disciplines/communication.md)
- [Compact text](disciplines/compact_text.md)
- [Git read-only](disciplines/git_readonly.md)
- [Commit messages](disciplines/commit_messages.md)
- [Destructive installer](disciplines/install_sh_destructive.md)
- [Update design](disciplines/update_design.md)

## Other Memory

- [Advisor mode](advisor_mode.md) — collaboration behavior.
- [Spec template](_spec_template.md) — canonical specification structure.
- [Issues](issues/index.md) — open issues only; completed records are absorbed into `specs/` and removed.
