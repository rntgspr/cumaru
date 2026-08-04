---
release: 2026-08-01
targets:
  framework-version: 7
---

## sdlc-light — domain notes

This domain never declared the `absorptions` tag, so base step 5 has nothing to
audit here. Base step 6 (`deltas:` / `consolidated-at:`) applies in full, and it
matters more here than anywhere else.

### `deltas:` was called canonical, and is not

**Applies when** — always, while migrating this domain.

Three shipped sentences asserted that `deltas:` was the record, in stronger
words than the other domains used:

- `specs/index.md` — "`deltas:` frontmatter is the **canonical reference**"
- `roles/lead.md` — "this domain keeps durable local trace through each spec's
  `deltas:` list"
- `cumaru-absorb/SKILL.md` — "the absorption commit (if git is used) and the
  spec's `deltas:` are the durable record"

**Do** — the framework-owned copies of those files are refreshed by
`cumaru update`. If the adopter has diverged locally, rewrite their wording to
the actual position: **the updated spec body is the record.**

There is no `archive/` pillar here and the plan directory is removed on close,
so with `deltas:` gone a tree without the `git` skill keeps no history layer at
all. That is consistent, not a gap: the pillar states what is true now, and that
claim stands on its own. If the user wants a history layer, install the skill
with `cumaru install --with git` and let the absorption commit message carry the
plan key.

**Verify** — `grep -rn 'deltas:' .cumaru/specs/` returns nothing.
