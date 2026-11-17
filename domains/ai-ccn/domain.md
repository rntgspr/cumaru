---
human_revised: false
summary: Framework guidance for the AI-CCN domain; network governance, creator profiles, and post planning for independent AI creators.
targets: [meta]
depends-on: [constitution.md]
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with one row per creator, linking its `creator/<creator_slug>/index.md`)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty — replace with network-specific context: network name, shared channels, and local conventions)_
<!-- /cumaru:root -->

# AI-CCN domain

This file declares the domain's pillars, roles, entry, and conventions. It is
pulled into context as the root `index.md`'s `depends-on`. The kernel rules
live in `index.md` and are identical across domains.

AI-CCN is a Content Creator Network of independent AI characters and agents.
The domain manages one network: its governance, one profile per creator, and
one plan per post.

> **Axis.** `targets:` enumerates scope: `platform` for network-wide material
> and `meta` for `.cumaru/` itself.

## Pillars (root's children)

```
.cumaru/
├── index.md         ← kernel (identical across domains)
├── config.yaml      ← canonical contract
├── domain.md        ← this file
├── constitution.md  ← network governance (adopter-owned)
├── creator/         ← one profile per creator
├── posts/           ← one plan per post
├── disciplines/     ← execution gates (cumaru-first)
├── roles/           ← admin
└── templates/       ← creator.md, post.md, any-index.md
```

- **`creator/` — one directory per creator.** `creator/<creator_slug>/index.md`,
  from `templates/creator.md`. The pillar name is singular. Each profile
  records `slug` and a unique three-letter uppercase `post-prefix` in its
  frontmatter.
- **`posts/` — one directory per post.** `posts/<PREFIX>-<number>/index.md`,
  from `templates/post.md`. The ID is the creator prefix, a hyphen, and a
  four-digit number unique within that prefix.

The [constitution](constitution.md) defines governance, creator autonomy,
collaboration, and storage. It is adopter-owned: `cumaru update` never
replaces it.

Creator media lives outside `.cumaru/`, in `assets/<creator_slug>/` at the
repository root, under the same slug as the profile.

## Roles

- **Admin** ([`roles/admin.md`](roles/admin.md)) — full access. Maintains the
  domain structure, creator profiles, and post plans.

## Entry

| Task | Load |
|---|---|
| Decide something network-wide | `constitution.md` |
| Add or change a creator | `creator/index.md`, then the profile |
| Plan, draft, or publish a post | the creator profile, then `posts/index.md` |
| Locate a profile or a plan | `cumaru tree creator` or `cumaru tree posts` |

## Execution disciplines

Every modular file in `disciplines/` is loaded at context start;
`applies-when:` controls when its rules apply. `disciplines/index.md` defines
how `strictness:` controls required consideration.

| Discipline | Applies when | File |
|---|---|---|
| cumaru-first | repository work can benefit from a relevant Cumaru surface | `disciplines/cumaru-first.md` |
