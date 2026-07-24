# Agent adapters

Cumaru stores one active project integration in the top-level `agent` field of
`.cumaru/schema.yaml`.

```yaml
agent: null # or claude, codex, opencode
```

Missing or null state selects the backward-compatible generic adapter. The CLI
keyword `none` serializes to YAML null.

## Artifact matrix

| Schema value | Instructions | Skills | Commands |
|---|---|---|---|
| `null` | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | `.claude/commands/cumaru/` |
| `codex` | `AGENTS.md` | `.agents/skills/cumaru-*` | Native skills; no project command directory |
| `opencode` | `opencode.json.instructions` | `.agents/skills/cumaru-*` | `.opencode/commands/cumaru/` |

Only one adapter is active. `install`, `update`, `doctor`, and `uninstall` read
the same schema state.

## Install and switch

```bash
cumaru install
cumaru install agent claude
cumaru install agent codex
cumaru install agent opencode

cumaru update agent opencode          # dry-run
cumaru update agent opencode --apply  # switch
cumaru update agent none --apply      # restore generic state
```

Every update is dry-run unless `--apply` is present. During a switch, Cumaru
removes only its marked instruction block, `cumaru-*` skills, namespaced
commands, and exact OpenCode instruction entries. It installs the new artifacts
before persisting the new schema value.

## Why OpenCode needs an adapter

The generic layout exposed skills to OpenCode because it officially discovers
`.agents/skills/<name>/SKILL.md`. It did not expose Cumaru commands:
OpenCode discovers project command files under `.opencode/commands/`, not
`.agents/commands/`.

An `@.cumaru/index.md` line inside `.agents/AGENTS.md` was also not a portable
file-import mechanism. The OpenCode adapter therefore merges
`.cumaru/index.md` and `.cumaru/domain.md` into `opencode.json.instructions`.

Nested command files remain nested. For example,
`.opencode/commands/cumaru/doctor.md` is invoked as `/cumaru/doctor`.

## Upstream contracts

- [Codex custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- [Codex repository skills](https://developers.openai.com/codex/skills)
- [Claude Code skills and compatible commands](https://code.claude.com/docs/en/skills)
- [Claude Code project configuration](https://code.claude.com/docs/en/claude-directory)
- [OpenCode rules and custom instructions](https://opencode.ai/docs/rules/)
- [OpenCode commands](https://opencode.ai/docs/commands/)
- [OpenCode agent skills](https://opencode.ai/docs/skills/)
