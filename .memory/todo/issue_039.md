---
name: stateless-agent-artifact-management
description: Remove persisted agent selection and target agent artifacts explicitly in update commands
status: completed
priority: high
---

# Issue 039: Make agent artifact management stateless

The global configuration currently requires one persisted `agent` value and
uses it to choose instructions, hooks, skills, commands, doctor expectations,
and uninstall targets. This prevents deterministic management of a named
agent's artifacts when adapters coexist or when the config does not declare an
active agent.

## Risk

- Skills and slash commands cannot be installed or repaired for an explicit
  agent without first changing project configuration.
- Cleanup trusts one configured adapter and can leave Cumaru-owned artifacts
  behind in other native agent directories.
- Removing `agent` from the schema without redesigning doctor, install,
  update, and uninstall would make ownership detection ambiguous and unsafe.

## Required invariant

Agent artifact operations derive their target from the command line and never
require or persist an `agent` property in `.cumaru/config.yaml`. They reconcile
only Cumaru-owned files for the requested agent, preserve adopter-owned
siblings, and retain update's preview-by-default contract.

The proposed command behavior is:

```text
cumaru update skills claude
cumaru update skills claude --apply
```

Preview, then install or replace the complete Cumaru skill set in Claude's
native skill directory, regardless of which agent directories already exist.

```text
cumaru update commands claude
cumaru update commands claude --apply
```

Preview, then install or replace the complete Cumaru slash-command set in
Claude's native command directory, independently of current filesystem state.
Agents without slash-command support must fail clearly without mutation.

```text
cumaru update agent --clear
cumaru update agent --clear --apply
```

Preview, then remove every Cumaru-owned instruction, hook, skill, and command
artifact across all supported agent integrations.

```text
cumaru update agent claude --clear
cumaru update agent claude --clear --apply
```

Preview, then remove only Cumaru-owned Claude artifacts. All unrelated files
and every other agent integration remain unchanged.

## Work

1. Remove `agent` from the active config schema and every shipped domain
   config, preserving the prior schema as the next immutable `off-N` snapshot.
2. Replace config-selected artifact routing with explicit adapter arguments for
   `update skills` and `update commands`; validate supported targets before any
   staging or write.
3. Redesign `update agent` as scoped or all-agent cleanup through `--clear`,
   using the normal staged transaction, dry-run, doctor gate, and rollback.
4. Define install behavior without persisted selection: an install-time agent
   may choose which native artifacts are initially materialized, but it must
   not be written to project config.
5. Make doctor discover and validate present Cumaru-owned integrations instead
   of expecting one configured adapter. Absence of all integrations must be a
   valid state when the `.cumaru/` tree itself is healthy.
6. Make uninstall remove Cumaru-owned artifacts from every supported adapter
   without guessing from config, while preserving all adopter-owned content.
7. Remove `_agent_current` and `_agent_set` dependencies from update, install,
   doctor, and uninstall paths; retain explicit adapter path helpers.
8. Update CLI help, skills, architecture, adapter, install, update, uninstall,
   migration, and configuration contracts for the stateless model.

## Tests

- Configs without `agent` validate; configs containing the retired property are
  rejected or reconciled according to the versioned migration contract.
- `cumaru update skills claude --apply` installs only Claude-targeted Cumaru
  skills and does not require an `agent` config value.
- `cumaru update commands claude --apply` installs the canonical Claude command
  set even when its directory is absent, partial, or contains unrelated files.
- An unsupported command target such as Codex exits nonzero without mutation.
- All `--clear` forms are dry-run without `--apply` and leave every managed
  surface byte-identical.
- `cumaru update agent claude --clear --apply` removes only Claude-owned Cumaru
  artifacts and preserves adopter files plus other agents.
- `cumaru update agent --clear --apply` removes Cumaru-owned artifacts across
  generic, Claude, Codex, and OpenCode surfaces and preserves unrelated files.
- A forced publication failure restores every affected native surface and
  leaves no update lock or staging debris.

## References

- `schemas/config.schema.json`
- `domains/*/config.yaml`
- `src/agent_adapter.sh`
- `src/cmd_install.sh`
- `src/cmd_update.sh`
- `src/cmd_doctor.sh`
- `src/cmd_uninstall.sh`
- `tests/spec/integration/schema_spec.sh`
- `tests/spec/integration/agent_adapters_spec.sh`
- `tests/spec/update/transaction_spec.sh`
- `docs/agent-adapters.md`
- `docs/update.md`
