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
- Runtime parser accepts only `cumaru:` markers
- Legacy `.llm/`, marker, skill, and command names are accepted only as migration input and rewritten to Cumaru

## Status

Completed and incorporated into `main`. All three layers and the migration adapter are shipped. Historical repository naming is handled manually by Renato.
