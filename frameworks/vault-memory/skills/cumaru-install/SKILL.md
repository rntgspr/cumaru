---
human_revised: false
version: 1
name: cumaru-install
description: Use this skill whenever the user wants to adopt the vault-memory domain, set up a permanent memory vault, bootstrap inbox/drafts/memories/attachments, or convert a folder of loose notes into a typed memory graph.
---

# `cumaru install` - adopt vault-memory

`cumaru install --domain vault-memory` is the deterministic copy step. The
LLM work starts after installation: configure memory domains, then create the
first capture, draft, or memory node.

## Install

```bash
cumaru install --domain vault-memory
```

## Post-install

1. Read `.cumaru/domain.md`.
2. Replace the `components` table with the vault's major domains or external
   collections.
3. Update `.cumaru/schema.yaml > meta.apps.values` when the user wants a custom
   domain axis.
4. Run `cumaru doctor`.
5. Hand off to:
   - `cumaru-capture` for raw material.
   - `cumaru-draft` for rough notes.
   - `cumaru-distill` for permanent memory.
   - `cumaru-link` for graph relationships.

## Patterns

| User says | You do |
|---|---|
| "install vault-memory" | Run `cumaru install --domain vault-memory`, then configure domains |
| "set up permanent memory" | Install this domain, then create the first `memories/` node |
| "use my notes as memory" | Install this domain, then decide what starts as `drafts/` versus `memories/` |
