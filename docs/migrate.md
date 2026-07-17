# `cumaru migrate`

Migrate a project tree from legacy naming or a supported earlier framework major.
The v6 migration is transactional: it stages `.cumaru/` and framework-owned
`.agents/` artifacts, validates the result, then swaps both together.

## Usage

```
cumaru migrate [--apply]
cumaru migrate v6 [--from <source>] [--apply]
```

| Flag | Description |
|---|---|
| `--apply` | Perform the migration. Without this flag, only a dry-run plan is shown. |
| `--from <source>` | V6 only: source checkout containing `domains/<domain>/` and its migration manifest. |

## V6

`cumaru migrate v6` is the only supported way to cross into framework version
6. It requires an explicit adapter for the installed domain, preserves unknown
tags and adopter content, removes only manifest-listed structural inventories,
installs matching agent artifacts, and recovers an interrupted swap from its
rollback journal. A dry-run is the default; `--apply` is refused when summaries
or domain layout need LLM adjudication.

Recommended sequence:

```bash
cumaru migrate v6 --from /path/to/cumaru
cumaru migrate v6 --from /path/to/cumaru --apply
cumaru doctor
```

The adapter is selected from `domains/<domain>/migrations/v5-to-v6.tsv`.
Migration derives summaries before removing manifest-listed structural tags,
normalizes the touched-file marker to `touched`, preserves unknown tags and
local-only content, and swaps `.cumaru/` together with framework-owned
`.agents/` artifacts only after validation succeeds.

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
