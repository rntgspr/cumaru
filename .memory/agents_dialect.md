# Schema-selected agent adapters

## Decision

Cumaru keeps one active adapter in `.cumaru/schema.yaml`:

- missing or `agent: null` — generic `.agents/` behavior;
- `agent: claude` — Claude Code native files;
- `agent: codex` — Codex native instructions and repository skills;
- `agent: opencode` — OpenCode config, shared skills, and native commands.

The CLI keyword `none` maps to YAML null. `cumaru doctor` has no agent option:
it reads schema state and validates the matching integration.

The canonical artifact matrix and switching contract live in
[`docs/agent-adapters.md`](../docs/agent-adapters.md). Do not duplicate it here.

## Command contract

- `cumaru install [agent <name>]` installs `.cumaru/` plus one adapter.
- `cumaru update agent <name>` is a dry-run.
- `cumaru update agent <name> --apply` switches adapters and writes schema last.
- `cumaru update agent none --apply` restores generic behavior.
- `cumaru uninstall` removes only Cumaru-owned artifacts for the active adapter.

## No prompt-submit loader

Cumaru does not install prompt-submit hooks. Durable instructions select the
framework entry points, while skills remain lazily loaded by the agent.
