# Agent adapters

Cumaru does not persist an active agent in `.cumaru/config.yaml`. Agent
artifacts are addressed explicitly by each update command.

## Artifact matrix

| Config value | Instructions | Skills | Commands | Session hook |
|---|---|---|---|---|
| `null` | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` | none |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | `.claude/commands/cumaru/` | `.claude/settings.json` |
| `codex` | `AGENTS.md` | `.agents/skills/cumaru-*` | Native skills; no project command directory | `.codex/hooks.json` |
| `opencode` | `opencode.json.instructions` | `.agents/skills/cumaru-*` | `.opencode/commands/cumaru/` | none |

Adapters may coexist. `doctor` only reports whether one complete instruction
set exists; it does not validate skills, commands, or hooks.

## Context bootstrap

Every adapter enters the framework in the same order: the kernel `index.md`,
then `domain.md`, every installed execution discipline, then the root candidate
projection. Discipline `applies-when` fields control application, not loading.

1. **`.cumaru/index.md`, `.cumaru/domain.md`, and `.cumaru/disciplines/*.md`**
   load eagerly. Claude receives explicit `@` imports for each installed
   discipline; Generic and Codex receive their bodies inside the managed
   `CUMARU-HOOK`; OpenCode uses its native instructions glob. `domain.md` must be
   eager because it carries the pillars, roles, and the execution-discipline
   trigger table — a `depends-on` alone is a prunable signal, not a guarantee.
2. **The SessionStart projection** emits every installed discipline body, then
   `cumaru tree .` projects the root's current candidates and summaries. This
   guarantees the discipline content for adapters with a session hook instead
   of relying only on static import expansion.

Where the client has a session-start event, Cumaru registers the projection as
a hook so it runs exactly once per context, independent of model judgment:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact|fork",
        "hooks": [
          { "type": "command", "command": "for file in .cumaru/disciplines/*.md; do [ -f \"$file\" ] && cat \"$file\"; done; cumaru tree . 2>/dev/null || true" }
        ]
      }
    ]
  }
}
```

Claude and Codex share this shape. The matcher covers every point where a
context is created or re-created; the command is silenced and forced to succeed
because a failing hook must never disturb a session. Codex also accepts the
equivalent inline `[hooks]` table in `.codex/config.toml`; Cumaru writes
`hooks.json`.

Registration is a **merge**: an existing `settings.json` or `hooks.json` keeps
its own keys, its other hook events, and its own `SessionStart` entries.
Re-applying is idempotent. `uninstall` removes only the entry whose command is
Cumaru's, and deletes the file only when nothing else remains in it.

The generic and OpenCode adapters have no session-start event to bind to, so
they rely on the ordered instruction prose alone. OpenCode's plugin API exposes
`session.created` and a shell helper, but its only documented context-injection
point is `experimental.session.compacting`; a `session.start` hook is still an
open upstream proposal. Those two adapters gain the hook when it lands.

## Install and switch

```bash
cumaru install
cumaru install agent claude
cumaru install agent codex
cumaru install agent opencode

cumaru update agent opencode --apply  # install the complete OpenCode set
cumaru update skills claude --apply   # install Claude skills only
cumaru update agent claude --clear    # clear Claude-owned files immediately
cumaru update agent --clear           # clear every Cumaru adapter artifact
```

Every update is dry-run unless `--apply` is present. During a switch, Cumaru
removes only its marked instruction block, `cumaru-*` skills, namespaced
commands, and exact OpenCode instruction entries. It installs the new artifacts
before persisting the new config value.

## Why OpenCode needs an adapter

The generic layout exposed skills to OpenCode because it officially discovers
`.agents/skills/<name>/SKILL.md`. It did not expose Cumaru commands:
OpenCode discovers project command files under `.opencode/commands/`, not
`.agents/commands/`.

An `@.cumaru/index.md` line inside `.agents/AGENTS.md` was also not a portable
file-import mechanism. The OpenCode adapter therefore merges
`.cumaru/index.md`, `.cumaru/domain.md`, and `.cumaru/disciplines/*.md` into
`opencode.json.instructions`.

`instructions` must be an array containing exactly one occurrence of those
three entries in kernel → domain → disciplines relative order. Project-owned
entries may appear anywhere and retain their relative order. Adapter refresh
consolidates duplicate or reordered Cumaru entries into one canonical sequence;
doctor warns for missing, duplicate, reordered, malformed, or non-array state.

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
