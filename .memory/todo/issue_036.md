---
name: universal-cumaru-usage-discipline
description: Add a high-priority universal discipline that makes Cumaru the default framework for related repository work
status: completed
priority: high
---

# Issue 036: Prefer Cumaru for framework-related work

The kernel explains Cumaru's loading rule and CLI, but it does not explicitly
prioritize a discipline for recognizing when repository work should use Cumaru.
Agents may therefore bypass available navigation, lifecycle, validation, and
guarded mutation workflows even when a task clearly falls within the
framework's scope.

The current `domains/__base/disciplines/index.md` also says disciplines are
loaded selectively, which conflicts with the v7 contract: every installed
discipline is eager context and `applies-when` controls application only.

## Risk

- Agents may edit or inspect `.cumaru/` directly instead of using its declared
  navigation and guarded mutation surfaces.
- A vague "always use Cumaru" instruction could force the framework onto tasks
  outside its scope or replace more appropriate repository tools.
- Introducing a special loading path could create a second bootstrap mechanism
  that diverges across agent adapters.

## Required invariant

A universal strictness `10/10` discipline is always delivered through the
existing eager discipline bootstrap and is applied broadly whenever a task can
need any project knowledge base, including Cumaru's knowledge navigation, domain workflows, semantic tags,
coverage, health checks, update/migration contracts, or guarded `.cumaru/`
operations. It does not require Cumaru for unrelated work where the framework
has no relevant surface.

## Work

1. Add a universal discipline under `domains/__base/disciplines/` with a broad,
   concrete `applies-when` and `strictness: 10/10`.
2. Define a decision gate that checks for relevant Cumaru surfaces before
   repository work and prefers the matching CLI command, skill, role, or domain
   workflow when one exists.
3. Cover at least navigation and context discovery, `.cumaru/` file operations,
   tag editing, source-reference coverage, doctor validation, lifecycle close,
   update, and migration.
4. State explicit boundaries: do not invoke commands gratuitously, do not use
   Cumaru as a substitute for source-code tools, and preserve command safety and
   user-confirmation requirements.
5. Update the kernel `index.md` to identify this discipline as the priority
   application rule without adding a second loading mechanism or changing the
   established kernel -> domain -> disciplines -> root projection order.
6. Correct `disciplines/index.md` so it describes eager delivery and
   applicability-based use rather than selective loading.
7. Mirror the discipline, kernel, and universal discipline-index changes
   byte-identically into every shipped domain.
8. Update architecture and adapter documentation if needed to describe the
   priority semantics without contradicting eager loading.
9. Extend the gate so repository work needing any project knowledge base first
   determines whether Cumaru is the relevant knowledge source.

## Tests

- The new discipline is present and byte-identical in every shipped domain.
- Its frontmatter declares `strictness: 10/10` and a broad, actionable
  `applies-when` criterion.
- Every adapter's existing bootstrap still delivers all disciplines in the
  canonical order; no new hook or instruction path is introduced.
- Kernel drift checks and `bash tests/run.sh` pass.

## References

- `domains/__base/index.md`
- `domains/__base/disciplines/index.md`
- `domains/__base/disciplines/code-comments.md`
- `.memory/specs/disciplines.md`
- `.memory/specs/agent-adapters.md`
- `docs/architecture.md`
- `docs/agent-adapters.md`
