---
summary: Ordered bootstrap steps for the ai-ccn domain after install.
---

## ai-ccn — bootstrap steps

The install ships a starter `constitution.md` and empty `creator/` and
`posts/` pillars. Work through the steps in order. Where a step allows a
proposal, present it and write only what the user confirms. `disciplines/`
and `templates/` stay as shipped.

1. **Network.** Ask the network name, its shared channels, and local
   conventions. Write the answers in the `root` tag of `domain.md` with
   `cumaru tag`.
2. **Constitution.** Read `constitution.md` with the user. It is
   adopter-owned starter text: ask who sets direction, who coordinates shared
   operations, and what each creator decides alone, then rewrite the sections
   that differ.
3. **Creators.** Ask which creators the network has. For each one, ask the
   slug and a unique three-letter uppercase post prefix, then create
   `creator/<creator_slug>/index.md` from `templates/creator.md` with
   `cumaru fs`. Write both in the profile frontmatter as `slug` and
   `post-prefix`. Fill each characteristic from the user's answers; mark one
   that does not apply and give the reason.
4. **Assets.** Propose one `assets/<creator_slug>/` directory per confirmed
   creator at the repository root, outside `.cumaru/`, under the same slug.
5. **Components.** Add one row per creator to the `components` tag of
   `domain.md`, linking the profile.
6. **Posts.** The pillar stays empty. Create the first plan from
   `templates/post.md` only when the user asks for a post.
