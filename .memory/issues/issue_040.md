---
name: codex-session-context-loader
description: Load declared repository Markdown context into Codex through a deterministic SessionStart hook
status: open
priority: high
---

# Issue 040: Add a Codex SessionStart context loader

Codex does not expose OpenCode's `opencode.json.instructions` array. Its native
`AGENTS.md` discovery has a default combined size limit, while this repository's
requested startup set is already much larger and `@` glob lines are not a
documented Codex import mechanism. Codex `SessionStart` hooks can instead add
plain stdout as developer context.

The original proposed repository context declaration was:

```text
.memory/*.md
.memory/todo/*.md
docs/*.md
```

Those patterns are historical input, not the final selection policy. Another
historical startup proposal also included `.memory/specs/*.md` and
`.memory/disciplines/*.md`; issue 120 supersedes both proposals.

This issue is the sole owner of manifest, loader, hook implementation, and their
mechanical tests. It depends on the selection, ordering, history, and budget
policy delivered by [issue 120](issue_120.md). Issue 120 separately owns
the universal role reload correction; no second loader is implemented there.

## Risk

- Codex may begin substantive work without the memory and documentation that
  the repository declares mandatory.
- Copying the full content into `AGENTS.md` can exceed Codex's default project
  instruction limit and silently omit later guidance.
- A relative hook command may fail when Codex starts from a repository
  subdirectory.
- Eagerly injecting the complete set on every startup or compaction can consume
  substantial context and repeat duplicate files.
- Replacing `.codex/hooks.json` wholesale can destroy adopter-owned hooks.

## Required invariant

For Codex sessions, one trusted project `SessionStart` hook invokes a
deterministic, read-only loader resolved from the Git root. The loader emits
each declared regular Markdown file exactly once, in canonical order, with a
visible path delimiter. Successful stdout becomes developer context on
`startup`, `resume`, `clear`, and `compact`; missing optional paths do not break
the session, while malformed declarations and configured size-limit violations
produce explicit diagnostics rather than silent partial context.

## Work

1. Encode the accepted policy in `.memory/index.md` from issue 120 in one
   agent-neutral canonical manifest;
   do not duplicate the glob list independently in `AGENTS.md`, the loader, and
   adapter code.
2. Add a Bash 3.2-compatible read-only context emitter that resolves the Git
   root, expands only permitted project-relative Markdown patterns, rejects
   absolute paths, `..`, symlinks, and canonical escapes, and sorts with
   `LC_ALL=C`.
3. Emit `.memory/index.md` first, then the mandatory set in the canonical
   `.memory/index.md` order, sorting disciplines with `LC_ALL=C` and
   deduplicating paths.
   Keep historical details on demand as specified by that policy.
4. Register the emitter as a separate Cumaru-owned `SessionStart` entry in
   `.codex/hooks.json`, preserving unrelated hooks and using a Git-root-based
   command so launches from subdirectories behave identically.
5. Keep `AGENTS.md` compact: it declares startup policy and points to the
   canonical manifest but does not materialize the complete context body.
6. Enforce and document issue 120's context budget. Report selected file and
   byte counts, and either inject the accepted complete set or fail clearly;
   never truncate a file or silently omit the tail of the manifest.
7. Ensure refresh and clear operations remove only Cumaru's exact context hook
   and script while preserving adopter-owned `.codex` state.
8. Update adapter and architecture documentation with the Codex mechanism and
   its difference from OpenCode native instructions.

## Tests

- A startup fixture emits every declared Markdown file exactly once with
  `.memory/index.md` first, policy-defined group ordering, and deterministic
  C-locale ordering within groups; on-demand history is not injected eagerly.
- Starting from the repository root and a nested directory produces identical
  context output.
- Missing optional directories or unmatched optional globs do not fail the
  hook; unsafe, escaping, non-Markdown, and symlink targets are rejected without
  reading them.
- The generated `.codex/hooks.json` contains exactly one Cumaru context-loader
  entry and preserves unrelated hook events and `SessionStart` entries.
- `startup`, `resume`, `clear`, and `compact` match; unsupported sources do not
  execute the loader.
- Refresh is idempotent, and scoped/all-agent clear removes only Cumaru-owned
  Codex artifacts.
- An over-budget fixture reports the file and byte totals and injects no partial
  context.
- The complete adapter and contract test suites pass without weakening the
  existing discipline and root-tree SessionStart projection.

## References

- `AGENTS.md`
- `.memory/index.md`
- `.memory/issues/issue_120.md`
- `src/agent_adapter.sh`
- `tests/spec/integration/agent_adapters_spec.sh`
- `docs/agent-adapters.md`
- [OpenAI Docs: Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [OpenAI Docs: AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
