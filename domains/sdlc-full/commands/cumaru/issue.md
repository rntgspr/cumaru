---
version: 1
description: Capture, refine, promote, or drop a locally authored issue in `.cumaru/issues/`. Drives the `cumaru-issue` skill.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <slug-or-action>
summary: Capture, refine, promote, or drop a local issue in `.cumaru/issues/`.
---

Argument: `$ARGUMENTS` may be a kebab-case issue slug, an existing issue slug, or empty. If empty, ask whether the user wants to create, refine, promote, or drop a local issue.

1. **Load the installed `cumaru-issue` skill.** It carries the local issue capture, refinement, promotion, and drop recipes.
2. **Dispatch by intent.** A new slug bootstraps `issues/<slug>/index.md` from `templates/issue.md`. For an existing issue, ask whether to refine it, promote it to a slug-based plan, or drop it. Do not use this command for a tracker-backed item; hand off to `/cumaru:intake <KEY>` instead.
3. **Run the recipe.** Confirm the slug, issue type, priority, applications, and promotion or deletion decision. Use `cumaru flow` for file operations. Set `summary:` before `cumaru tree issues --rows`.
4. **Close out.** Run `cumaru doctor` and report the resulting issue or plan path.

Hard rules:

- Local issues are not tracker mirrors and receive no tracker key.
- Do not write `scope:`, a task DAG, or implementation detail into an issue; promote it to `/cumaru:plan` when that structure is needed.
- Only completed plans flow through `archive/`.
