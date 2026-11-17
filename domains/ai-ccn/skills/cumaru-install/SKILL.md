---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the ai-ccn domain for a Content Creator Network of AI characters and agents, set up its constitution and creator profiles, or bootstrap post planning.
summary: Install the ai-ccn domain and bootstrap the network constitution and one profile per creator.
---

# `cumaru install` — adopt ai-ccn

`cumaru install --domain ai-ccn` is the deterministic copy step. The LLM work
starts after installation: describe the network, then create one profile per
creator.

## Install

```bash
cumaru install --domain ai-ccn
cumaru install --domain ai-ccn agent claude
```

The copy brings the starter `constitution.md`, the empty `creator/` and
`posts/` pillars with their contracts, the `creator.md` and `post.md`
templates, and the Admin role.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the ai-ccn steps from main HEAD, pinned to one commit; the
document is never installed into `.cumaru/`.

## What this skill does NOT do

- Invent a creator, a persona, or a post. Every profile comes from the user's
  answers.
- Publish or schedule content on any channel.
- Store media inside `.cumaru/`. Assets live in `assets/<creator_slug>/`.
