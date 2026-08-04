---
name: codex-role-skill
description: Add a universal role-loading skill so Codex can assume Cumaru roles without slash commands
status: completed
priority: high
---

# Issue 038: Add a universal role-loading skill

Cumaru ships the universal `/cumaru:role <role>` command for Claude and
OpenCode, but Codex has no project slash-command surface. The same workflow is
therefore unavailable through the native artifact Codex does support: a
repository skill.

## Risk

- Codex users may assume roles manually, skip role validation or bootstrap
  order, and silently merge permissions from multiple roles.
- Maintaining a separate recipe from the command can make role behavior drift
  between agents.

## Required invariant

A universal `cumaru-role` skill exposes the same role-selection contract as the
canonical command: reload local bootstrap context, validate a plain role name
against `.cumaru/roles/<role>.md`, load exactly that role, and never persist or
silently combine roles.

## Work

1. Add `domains/__base/skills/cumaru-role/SKILL.md` with precise invocation
   triggers and the workflow currently declared by
   `commands/cumaru/role.md`.
2. Keep one canonical behavioral source or add a contract check that prevents
   the skill and command from drifting.
3. Mirror the universal skill byte-identically into every shipped domain using
   the canonical domain-kernel sync flow.
4. Ensure install and `cumaru update skills <agent> --apply` place the skill in
   every supported agent's native skill directory, including Codex.
5. Update install, adapter, and role documentation to explain that Claude and
   OpenCode may use the slash command while Codex invokes the skill.

## Tests

- Every shipped domain contains a byte-identical `cumaru-role/SKILL.md`, and
  the universal kernel drift check passes.
- A Codex install or explicit Codex skill update creates
  `.agents/skills/cumaru-role/SKILL.md` without creating a command directory.
- Missing and invalid role arguments list `cumaru tree roles --rows` candidates
  and never guess or persist a role.
- The skill and slash command enforce the same bootstrap order, role path
  validation, permission boundary, and no-write contract.

## References

- `domains/__base/commands/cumaru/role.md`
- `domains/__base/skills/`
- `src/cmd_install.sh`
- `src/agent_adapter.sh`
- `tests/spec/integration/agent_adapters_spec.sh`
- `tests/spec/contracts/documented_contracts_spec.sh`
