---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the vault-memory domain, set up a permanent memory vault, bootstrap inbox/drafts/memories/attachments, or convert a folder of loose notes into a typed memory graph.
summary: Use this skill whenever the user wants to adopt the vault-memory domain, set up a permanent memory vault, bootstrap inbox/drafts/memories/attachments, or convert a folder of loose notes into a typed memory graph.
---

# `cumaru install` - adopt vault-memory

`cumaru install --domain vault-memory` is the deterministic copy step. The
LLM work starts after installation: configure memory domains, then create the
first capture, draft, or memory node.

## Install

```bash
cumaru install --domain vault-memory
```

Install refuses an existing `.cumaru/`. Use `cumaru update` for refresh or
adapter-targeted opt-in skills.

## Bootstrap

Run `cumaru bootstrap` and follow the printed steps in order. It prints the
universal rules and the vault-memory steps from main HEAD, pinned to one commit; the
document is never installed into `.cumaru/`.

## Patterns

| User says | You do |
|---|---|
| "install vault-memory" | Run `cumaru install --domain vault-memory`, then `cumaru bootstrap` |
| "set up permanent memory" | Install this domain, then create the first `memories/` node |
| "use my notes as memory" | Install this domain, then decide what starts as `drafts/` versus `memories/` |
