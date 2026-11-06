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
7. Done: `cumaru map` section ends and `cumaru get`
   ([docs/get.md](../../docs/get.md)).
8. Done: `cumaru hooks pretool` read veto (Claude and Codex `PreToolUse`,
   matcher `Bash`) redirecting to `cumaru map` and `cumaru get`.
   Live probe on 2026-11-06 in fresh Claude and Codex sessions: deny reason
   delivered and followed through `map` then `get`.
9. Next: pretool canonical-file recall before edits (items 1-4 below).

## `cumaru map` section ends

1. Rows become `path:start,end<TAB>title`, the `cumaru get` selector shared
   with `get` headers through one formatter; `--markdown` emits Selector/Title.
2. `end` is the line before the next heading of the same or higher level
   (fewer or equal `#`), or the last line at EOF, minus trailing blank lines, so each row is a complete
   section: an H1 spans the file and an H2 includes its H3s.
3. Update [navigation](../specs/navigation.md) and every `map` consumer and
   test before changing the row shape.

## `cumaru get`

Read-only, atomic line selection relative to `.cumaru/`, with the same path
rules as `map` (hidden targets rejected). Syntax follows `git log -L` and
`sed` addresses.

1. Selectors, one or more per call, `path[:range]`:
   - `path`: whole file.
   - `path:N`: one line.
   - `path:N,M`: inclusive range; `M` may be `$` (EOF).
   - `path:N,` or `path:N,$`: line `N` to EOF.
   - `path:,M`: line 1 to `M`.
   - `path:N,+K` / `path:N,-K`: `N` and `K` lines below / above.
2. Rejected with no output: malformed, reversed, or out-of-bounds ranges
   exit 2; unsafe, non-Markdown, or unreadable paths exit 1, as in `map`.
3. Output: every selector, in argument order, prints a
   `==> path:start,end <==` header with the resolved range, then the selected
   lines verbatim; blocks are separated by a blank line. Overlaps and repeats
   print as requested.
4. Validate every selector before printing; enforce a total byte budget
   (32768 bytes, matching the prompt digest) so selectors cannot rebuild a
   bulk read.
5. Deferred: regex heading selectors (`path:/Status/`) resolved through the
   `map` section ends.

## `cumaru hooks pretool`

Goal: recall the canonical summary chain of the file an agent is about to
change, closing issue #22's "canonical-file forgetting" task without bulk loads.

1. Contract: read the native hook JSON from stdin, take
   `tool_input.file_path`, normalize it relative to the project root, and stop
   silently when it is absent, outside the project, or outside `.cumaru/`.
2. Payload: the target file's `summary:` (when it exists), then every ancestor
   `index.md` summary up to `.cumaru/index.md`, nearest first, each with its
   path. Reuse `frontmatter` and `validate_summary`; 4096-byte budget; atomic
   one-line diagnostic on failure; always exit 0 and never emit a permission
   decision.
3. Output: Claude JSON
   `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":...}}`
   because plain PreToolUse stdout does not reach the model. Verify this
   field against the current Claude Code hooks reference before coding.
4. Adapter: Claude gets one owned `PreToolUse` entry, matcher
   `Edit|MultiEdit|Write|NotebookEdit`, command `cumaru hooks pretool`, merged
   and cleared like the other owned entries in `src/adapter.rs`. Codex stays
   out until a live probe confirms its PreToolUse delivery for file edits.
5. Tests: unit tests in `src/commands/hooks.rs` (outside path silent, chain
   order, missing summary, budget, malformed stdin), adapter merge/clear tests,
   and a ShellSpec case per [testing](../specs/testing.md).
6. Read veto: a second owned `PreToolUse` entry, matcher `Bash`, denies
   (`permissionDecision: "deny"`) `cat`/`sed`/`head`/`tail` over files under
   `.cumaru/` with a reason pointing to `cumaru map` + `cumaru get`. Parse the
   command conservatively; anything ambiguous passes through.
7. Docs: update [agent adapters](../specs/agent-adapters.md) bootstrap and
   canonical-hooks sections and the public hooks docs under `docs/`.
