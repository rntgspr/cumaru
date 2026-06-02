---
name: rename-llm-to-cumaru
description: "COMPLETED: full rename from legacy naming to cumaru: CLI, install path, project tree, skills, commands, and marker blocks"
type: project
status: completed
---

## Scope

Full 3-level rename:

1. **CLI binary name + install path** (legacy binary → `cumaru`, legacy install dir → `~/.cumaru`)
2. **Skill/command prefix** (`llm-*` → `cumaru-*`, `commands/llm/` → `commands/cumaru/`)
3. **Marker blocks** (`<!-- llm:NAME -->` → `<!-- cumaru:NAME -->`)

Plus:
- `cumaru migrate` subcommand to migrate existing project trees
- Legacy symlink (`llm` → `cumaru`) for transition window
- Parser accepts both `cumaru:` and `llm:` prefixes

## Status

Completed (2026-07-03) on branch `rename-cumaru`. All three layers done, migrate subcommand included. Historical repository naming is handled manually by Renato.
