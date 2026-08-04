---
name: summarize-skill-review
description: Review cumaru-summarize skill — triggers are loose; may miss actual framework usage context
status: open
priority: medium
---

# Issue 032: Review cumaru-summarize skill

The current `cumaru-summarize` skill (in `domains/__base/skills/cumaru-summarize/SKILL.md`) has two problems:

1. **Triggers too loose** — the `description` frontmatter lists a long, open-ended set of phrases that match casual conversation rather than explicit invocations.
2. **May miss framework usage context** — the recipe focuses on mechanical summary curation but doesn't clearly connect to *how the framework actually uses summaries* (navigation via `cumaru tree`, loading rule pruning, doctor's summary validation, agent context bootstrap).

## Risk

- Skill activates on vague prompts, polluting context.
- Curation may produce technically valid summaries that don't serve the framework's actual selection signals (distinguishing candidates for `cumaru tree`, feeding the loading rule, satisfying doctor's 32–512 contract).

## Required invariant

- Triggers are precise, explicit phrases only.
- Recipe references the framework mechanics that consume summaries: `cumaru tree` output, loading-rule pruning by `summary:`, doctor checks 3–4, and the SessionStart hook delivery order.

## Work

1. Tighten `description` triggers to a short list of explicit invocations.
2. Add a "Framework context" section to the skill body explaining where summaries are consumed and what makes a summary useful there.
3. Ensure the curation guidance (concrete nouns, distinguish neighbors, no volatile metadata) maps to those consumption points.
4. Verify the skill still passes `cumaru doctor` and the universal drift check.

## Tests

- `grep -q 'description:' domains/__base/skills/cumaru-summarize/SKILL.md` shows a concise trigger list.
- Skill body contains explicit references to `cumaru tree`, loading rule, doctor checks 3–4, and SessionStart hook.
- `bash tests/run.sh` passes (kernel drift stays green).

## References

- `domains/__base/skills/cumaru-summarize/SKILL.md`
- `.memory/specs/navigation.md` (summary contract, tree navigation)
- `.memory/specs/agent-adapters.md` (SessionStart delivery)
- `.memory/specs/disciplines.md` (universal skill drift check)
