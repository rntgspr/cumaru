---
human_revised: false
version: 1
name: cumaru-role
description: Load one declared Cumaru role after validating its plain name and reloading the local bootstrap context.
summary: Load one declared Cumaru role after validating its plain name and reloading the local bootstrap context.
---

# `cumaru-role` - assume one declared role

Use the invocation arguments as the requested role name. This skill changes
agent context only; it never persists role state or modifies `.cumaru/`.

## Workflow

1. Require one plain role name. If it is absent, run `cumaru tree roles --rows`,
   list the available roles, and ask the user to choose. Never guess a default.
2. Reload local bootstrap context in order:
   - `.cumaru/index.md`
   - `.cumaru/domain.md`
   - `cumaru tree . --rows`
3. Require a regular `.cumaru/roles/<role>.md` file. If it does not exist, list
   `cumaru tree roles --rows` and ask again. Never derive a role from a path
   outside `.cumaru/roles/`.
4. Load exactly that role and apply its responsibilities, restrictions,
   ownership boundaries, and `Initial load` rules for the rest of the session.
5. Report the active role and the root candidates from step 2. Do not preload
   role-optional pillars or task entities.

## Hard rules

- Reload local bootstrap context on every invocation; the skill may run after a
  compacted or resumed session.
- A role never grants capabilities outside its own file.
- Never silently combine roles. Ask the user to invoke this skill again when
  work requires a different role.
- Do not persist an active-role setting or modify `.cumaru/`.
