# Agent adapters

Cumaru does not persist an active agent in `.cumaru/config.yaml`. Agent
artifacts are addressed explicitly by each update command.

## Artifact matrix

| Adapter | Instructions | Skills | Commands | Session hook |
|---|---|---|---|---|
| `none` | `.agents/AGENTS.md` | `.agents/skills/cumaru-*` | `.agents/commands/cumaru/` | none |
| `claude` | `CLAUDE.md` | `.claude/skills/cumaru-*` | Native skills; no project command directory | `.claude/settings.json` |
| `codex` | `AGENTS.md` | `.agents/skills/cumaru-*` | Native skills; no project command directory | `.codex/hooks.json` |
| `opencode` | `opencode.json.instructions` | `.agents/skills/cumaru-*` | `.opencode/commands/cumaru/` | none |

Adapters may coexist. `doctor` only reports whether one complete instruction
set exists; it does not validate skills, commands, or hooks.

Every shipped slash command is a thin launcher for a required namesake skill:
`commands/cumaru/<name>.md` forwards `$ARGUMENTS` to
`skills/cumaru-<name>/SKILL.md`. The skill is the only workflow source. Source
domain validation rejects commands without that skill before install or update.
Generic and OpenCode receive the same launcher content in their command
directories; Claude and Codex invoke the skills directly.

## Context bootstrap

Every adapter enters the framework in the same order: the kernel `index.md`,
then `domain.md`, `disciplines/index.md`, every other installed execution
discipline, then the root candidate projection. Every discipline is loaded;
`strictness` controls required consideration and `applies-when` controls
application. Missing strictness is invalid and treated as `0/10`.

Invoking the universal `cumaru-role` skill repeats that same ordered bootstrap
before loading the requested role: kernel, domain, discipline index, remaining
regular disciplines in C-locale path order, then `cumaru tree . --rows`. Role
reload changes context only and never writes active-role state.

1. **`.cumaru/index.md`, `.cumaru/domain.md`, and `.cumaru/disciplines/*.md`**
   load eagerly, with the discipline index before discipline bodies where the
   adapter exposes deterministic file order. Claude and Codex, which have hooks, keep only a
   fallback pointer to the disciplines in the managed `CUMARU-HOOK`; Generic
   receives their bodies inside it; OpenCode uses its native instructions glob. `domain.md` must be
   eager because it carries the pillars, roles, and the execution-discipline
   trigger table — a `depends-on` alone is a prunable signal, not a guarantee.
2. **The SessionStart projection** emits the discipline index, every remaining
   discipline body, then `cumaru tree .` projects the root's current candidates and summaries. This
   guarantees the discipline content for adapters with a session hook instead
   of relying only on static import expansion.
3. **The per-prompt digest** runs `cumaru hooks prompt` before every
   prompt: one line with the kernel `summary:` from `.cumaru/index.md`, then one line per installed discipline with its strictness, actionable
   `summary`, and path, so the rules stay in view as the conversation grows.
   It reads only local files, prints nothing outside an installation, and on
   invalid metadata or budget overflow prints a single diagnostic line.
4. **The read redirect** runs `cumaru hooks pretool` before every shell tool
   call. When a `cat`, `head`, `tail`, or non-in-place `sed` targets a
   `.cumaru/` Markdown path, it denies the call with a reason that points to
   [`cumaru map`](map.md) and [`cumaru get`](get.md); every other command,
   malformed input, and non-shell tool passes silently.

Where the client has a session-start event, Cumaru registers the projection as
a hook so it runs exactly once per context, independent of model judgment:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact|fork",
        "hooks": [
          { "type": "command", "command": "cumaru hooks session" }
        ]
      }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "cumaru hooks prompt" }] }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "cumaru hooks pretool" }]
      }
    ]
  }
}
```

Claude and Codex share this shape; Codex context entries also set
`"additionalContextLimit": 0` so full discipline bodies are not spilled. Both
commands are native, offline, validate the complete set before printing, emit a
single diagnostic line on failure, and always exit 0. The matcher covers every point where a
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
cumaru update skills codex --with git --apply # add one Codex opt-in
cumaru update agent claude --clear    # immediately clear Claude-owned files
cumaru update agent --clear           # immediately clear every adapter set
```

Project install writes after preflight and has no preview. Update refresh forms preview unless `--apply` is present. `--clear` is
the exception: it mutates immediately after the Git recovery check and does not
require `--apply`. In a Git work tree, pending changes block the operation;
outside Git, Cumaru warns and continues without a recovery point. With an agent
it removes only that adapter's marked
instruction block, `cumaru-*` skills, namespaced commands, and exact OpenCode
instruction entries. Without an agent it performs the same owned-artifact
cleanup across every supported adapter. Adopter-owned files and adapter
directories remain.

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
