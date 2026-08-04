# Memory index

Load the current specifications first. Root files outside `specs/` are
metacontext, user context, working notes, templates, or historical review.

## Specifications

- [Architecture](specs/architecture.md) — kernel, ownership, configuration, lifecycle, and system boundaries.
- [Navigation](specs/navigation.md) — filesystem projection, summaries, filters, and bounded traversal.
- [Domains](specs/domains.md) — domain package contract and shipped domain profiles.
- [Absorb](specs/absorb.md) — transient close-out into the durable single source of truth.
- [Disciplines](specs/disciplines.md) — execution-discipline artifact, loading, attribution, and drift.
- [Update](specs/update.md) — steady-state previews, scoped modes, staging, publication, and rollback.
- [Configuration](specs/configuration.md) — global model, validation, and agent-led reconciliation.
- [Tags](specs/tags.md) — marker grammar, body types, balanced parsing, and preservation.
- [Migration](specs/migration.md) — read-only rolling direct N-to-v7 instructions.
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
- [Work notes](notepad.md) — informal review queue.
- [Spec template](_spec_template.md) — canonical specification structure.
- [Todo](todo/index.md) — issue index.

@./specs/*.md
@./disciplines/*.md
@./advisor_mode.md
