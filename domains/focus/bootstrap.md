---
summary: Ordered bootstrap steps for the focus domain after install.
---

## focus — bootstrap steps

The install ships no source, directive, outcome area, or input policy. Work
through the steps in order. Where a step allows a proposal, present it as a
proposal and write only what the user confirms. `disciplines/` and
`templates/` stay as shipped.

1. **Sources.** Inspect the tools actually available in this session (plugins,
   MCP servers, authenticated CLIs) and propose the sources they can read, or
   take the user's list. For each confirmed source, ask the access method,
   filters, and window, then write one leaf under `sources/` from
   `templates/source.md`, `status: active` or `paused`, following the
   [source contract](sources/index.md). A proposed source that no tool can
   reach is reported as unavailable, never written as active. Never store
   credentials.
2. **Directives.** Ask the user for their directions, or ask whether to draft
   proposals from the confirmed sources. For each: purpose, included and
   excluded scope, and value scope (the benefit pursued and how a contribution
   is recognized). Drafts stay `proposed` and unranked until the user activates
   and orders them. Create each under `directives/` from
   `templates/directive.md` with `cumaru-directives`.
3. **Outcomes.** Ask which areas group results and which absorbs a result that
   fits no other. Add each as a named key under `outcomes` in `config.yaml`,
   shaped `<area>: {"*.md": {tags: [threads]}}`, add it to
   `meta.targets.values`, and create `outcomes/<area>/index.md` from
   `templates/any-index.md`. Never use a `"*"` wildcard: it matches the area's
   own `index.md`. Outcomes follow `templates/outcome.md`; threads, recorded
   under `threads/`, follow `templates/thread.md`.
4. **Presentation skill.** Offer to create a local, adopter-owned skill in the
   selected agent's skill directory (for example `.claude/skills/<name>/`) that
   reads every active thread's frontmatter and content and builds one derived
   asset, such as a website artifact. Ask its name, output, and where the asset
   is published; name it without the `cumaru-` prefix so `cumaru update` never
   replaces it. It reads `.cumaru/` only and never edits threads.
5. **Intake policy.** Ask which workflow runs `cumaru-sources` and the
   presentation skill, and when, and record it in the `root` tag of
   `.cumaru/domain.md`, in the user's own words.
6. **Boundaries.** Ask where own action ends and downstream monitoring begins,
   and which external actions may ever run on the user's behalf. Record both in
   the `root` tag; every external action is still presented for review first.
7. **Role name.** Keep the single Admin role or rename `roles/admin.md` and its
   index entry. Never add a second role.
8. **Components.** Fill the `components` tag when a local stack or contract
   document applies; otherwise leave it as shipped.
9. **First scan (optional).** Offer one `cumaru-sources` run over the active
   sources, then one presentation build.
10. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
