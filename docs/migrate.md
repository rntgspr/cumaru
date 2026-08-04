# `cumaru migrate`

Print the migration instructions that apply to this project. **Read-only** — the
command changes nothing and has no `--apply`. The instructions it prints are
executed by the LLM, which also dispatches every deterministic step.

## Usage

```
cumaru migrate [--from <source>]
```

| Flag | Description |
|---|---|
| `--from <source>` | Cumaru checkout providing `domains/<installed-domain>/`. Defaults to the active CLI checkout. |

## The model

Cumaru ships **one rolling migration document** per release:

```text
domains/__base/migration.md      the universal content
domains/<domain>/migration.md    optional; extends base with domain nuance
```

`cumaru migrate` resolves the installed domain from `.cumaru/config.yaml` or,
only for legacy input, `.cumaru/schema.yaml`. It reads the base document plus the
domain's extension when one exists, strips frontmatter, and prints the bodies.

Three properties follow from this shape:

- **Never installed.** The document is resolved from the CLI checkout at runtime
  and is deliberately excluded from `cumaru install` and `cumaru update`. An
  adopter tree never contains a copy that could go stale.
- **Not cumulative.** There is exactly one current migration, replaced wholesale
  on every upgrade. It is not an archive of past migrations, so a project that
  skips several releases receives only the latest instructions.
- **Detection-first and idempotent.** Every step states how to detect whether it
  applies, so re-running the whole document on an already-migrated tree is a
  no-op. That replaces the version guard the old mechanical adapter carried.
- **Direct N→7 convergence.** The current rolling document handles every
  supported earlier layout directly. It does not require chained historical
  migrations. Configuration normalization is deterministic: rename legacy-only,
  delete the legacy file when both names exist, keep current-only, and block when
  neither exists.

## Why the LLM executes it

Migration transforms durable adopter content: which claims survive from a
   retired marker block, which pillar area owns each one, which config keys must be
preserved. Those are adjudications, not substitutions. This follows the
framework's standing split — the script reports, the LLM decides — and applies
even to the deterministic steps, which the LLM dispatches itself.

The consequence is stated plainly rather than hidden: **there is no transactional
rollback.** Git history is the safety net only when `.cumaru/` is tracked. The
printed instructions require a clean affected worktree plus tracked `.cumaru/`.

## Step shape

Each step in a migration document uses the same unit:

```markdown
## <n>. <what>

**Applies when** — <observable condition>
**Detect** — <exact command or check>
**Do** — <numbered actions, each naming its command>
**Blockers** — <what must stop and ask instead>
**Verify** — <how to confirm this step landed>
```

`Blockers` is load-bearing. Where the previous mechanical adapter aborted with an
error, the prose says *stop and ask* — never guess at adopter content.

## Frontmatter

Frontmatter is CLI-facing metadata and is stripped before the body reaches the
model:

```yaml
---
release: 2026-08-01
targets:
  framework-version: 7
---
```

## Examples

```bash
cumaru migrate                       # print the instructions for this project
cumaru migrate --from /path/to/cumaru # resolve from an explicit checkout
cumaru migrate --help                # works outside a project
```

## Exit codes

- `0` — instructions printed.
- `1` — no installed current or legacy configuration, or no base migration document in the source.
- `2` — usage error, including `--apply`.

## Related

- [`cumaru update`](update.md) — clean-Git refresh at the same integer version.
- [`cumaru doctor`](doctor.md) — run after applying a migration to verify the tree.
