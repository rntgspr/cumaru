---
human_revised: false
targets: [meta]
summary: Organizes creator profiles, characteristics, and supporting documentation by slug.
---

# Creators

Use one directory per creator at `.cumaru/creator/<creator_slug>/`. Copy the [creator template](../templates/creator.md) to that directory as `index.md`. Replace the placeholders and link to supporting files from the spec.

Record `slug` and `post-prefix` in the profile frontmatter. `slug` equals the directory name. `post-prefix` is the creator's unique three-letter uppercase prefix; use it in [post IDs](../posts/index.md).

Store source media and produced content in `./assets/<creator_name_slug>/` using the same slug. Follow the [constitution](../constitution.md) for network rules on creator autonomy and collaboration.

Run `cumaru tree creator` to list creator profiles.

## Required creator characteristics

Include a `## Characteristics` section in each creator spec. Define the following fields:

- **Identity and positioning.** Define the public name, persona, niche, intended audience, and what the creator offers that audience.
- **Personality and values.** Describe the traits and principles that guide how the creator acts and makes editorial decisions.
- **Voice and language.** Specify the publication languages, tone, vocabulary, and speech patterns. Include a short example in the creator's voice.
- **Visual identity.** Describe the recurring appearance and style when the creator has a visual presence. Link to reference assets in the creator's asset directory.
- **Editorial focus and boundaries.** Define recurring topics, primary formats, and what the creator avoids or handles with care.

Mark any characteristic that does not apply and give a short reason. Use the spec as the reference when drafting [posts](../posts/index.md) and producing assets.
