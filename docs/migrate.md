# `cumaru migrate`

Migrate a project tree from the legacy `llm` naming to `cumaru`. Idempotent —
safe to run on an already-migrated project (detects `.cumaru/` first and skips).

## Usage

```
cumaru migrate [--apply]
```

| Flag | Description |
|---|---|
| `--apply` | Perform the migration. Without this flag, only a dry-run plan is shown. |

## What it does

1. **Renames `.llm/` → `.cumaru/`** — only if `.llm/` exists and `.cumaru/` does not.
2. **Rewrites `<!-- llm: -->` → `<!-- cumaru: -->` and `<!-- /llm: -->` → `<!-- /cumaru: -->`** in every `.md` file under the tree.
3. **Updates `.agents/AGENTS.md`** — replaces `@.llm/` references with `@.cumaru/`.
4. **Renames `.agents/commands/llm/` → `.agents/commands/cumaru/`** (or removes redundant `llm/` if `cumaru/` already exists).
5. **Renames `.agents/skills/llm-*/` → `.agents/skills/cumaru-*/`**.
6. **Removes itself** — the `cumaru-migrate` skill is a one-shot tool; after
   running, run `cumaru update` which prunes it from `.agents/skills/`.

## When to use

After upgrading to `cumaru` CLI (`cumaru upgrade`), run this once in every
existing project that was created with the legacy `llm` tool. After migration,
run `cumaru update` to clean up the migration skill.

## Examples

```bash
cumaru migrate                  # dry-run: show plan without changing anything
cumaru migrate --apply          # apply the migration
cumaru update                   # prunes the migration skill if it landed
```

## Related

- [`cumaru install`](install.md) — install cumaru in a new project.
- [`cumaru doctor`](doctor.md) — run after migration to verify the tree.

