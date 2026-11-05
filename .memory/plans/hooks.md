---
summary: Move every Cumaru hook payload into deterministic native `cumaru hooks` subcommands and reinforce domain disciplines per prompt.
---

# Hooks plan

Tracks [issue #22](https://github.com/rntgspr/cumaru/issues/22). Canonical
contracts: [disciplines](../specs/disciplines.md) and
[agent adapters](../specs/agent-adapters.md).

## Rule

Every hook command is a native `cumaru hooks <name>` subcommand: offline,
deterministic, reading only installed local files, validating the complete set
before printing, emitting one diagnostic line on failure, and exiting 0. No
hook ships shell logic.

## Status

1. Done: actionable discipline `summary:` lines across all shipped domains.
2. Done: `cumaru hooks disciplines` per-prompt digest (32768-byte budget).
3. Done: Claude/Codex adapters install the `UserPromptSubmit` entry; their
   static block keeps a fallback pointer instead of discipline bodies.
4. Done: `cumaru hooks session` replaces the inline SessionStart shell
   (legacy commands stay recognized as owned); Codex entries set
   `additionalContextLimit: 0`.
5. Next: decide whether repository-local `.claude/` and `.codex/`
   `load-context.sh` move to a native command, given they serve `.memory/`,
   not `.cumaru/`.
6. Pending: live probe of Codex `UserPromptSubmit` delivery in a fresh session.
