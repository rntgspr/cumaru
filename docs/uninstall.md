# `llm uninstall`

Reverse of [`llm install`](install.md). Removes `.llm/`, strips the `CLAUDE.md` hook block, and (optionally) removes installed slash commands. Refuses non-interactive (no TTY) unless `--yes` is passed.

## Usage

```
llm uninstall [TARGET] [--yes]
```

| Argument / flag | Default | Description |
|---|---|---|
| `TARGET` | `./.llm` | Directory to remove. Must look like a dot-llm install (contains `index.md` + `schema.yaml`). |
| `--yes`, `-y` | (interactive prompt) | Skip the confirmation prompt. Required for non-TTY runs (CI, scripts, agents). |

## What it does

1. **Pre-checks**:
   - `TARGET` exists and looks like an install (`index.md` + `schema.yaml` at its root).
   - If `--yes` is not set and stdin is not a TTY, refuses with a hint to pass `--yes`.
2. **Confirmation** (TTY without `--yes`):
   - Prints the target path + what will be removed + the CLAUDE.md changes.
   - Reads `y/N` from stdin; aborts on anything else.
3. **Removes the install tree** — `rm -rf TARGET`.
4. **Strips the CLAUDE.md hook** — locates the `<!-- BEGIN DOT-LLM-HOOK --> ... <!-- END DOT-LLM-HOOK -->` block in the parent's `CLAUDE.md` and removes it (along with surrounding blank lines). If `CLAUDE.md` becomes empty after, removes it too.
5. **Removes installed slash commands** — every `*.md` under `<parent>/.claude/commands/llm/` that is **byte-identical** to the file shipped by the dot-llm checkout's `commands/llm/` (verified with `cmp -s`). Locally-edited commands are **kept** and reported with a `· keeping (modified, not install's)` warning — the adopter's customizations are never destroyed. Adopter-added commands at other paths are not touched. After removal, empty `.claude/commands/llm/` and `.claude/` dirs are pruned.
6. **Prints a summary** of what was removed and a hint to re-install via `llm install` if needed.

## When to use

- Resetting a bench between test cycles.
- Migrating to a different flavor (uninstall, then `llm install --framework <new>`).
- Removing the framework from a project that won't use it anymore.

**Don't use it to "refresh" the framework** — that's [`llm sync`](sync.md)'s job. Uninstall is destructive; sync is steady-state.

## Examples

```bash
llm uninstall                       # interactive (TTY required)
llm uninstall --yes                 # non-interactive (CI / agents)
llm uninstall /path/.llm            # custom target
llm uninstall /path/.llm -y         # custom target, non-interactive
```

## Related

- [`llm install`](install.md) — installs the inverse.
- [`llm sync`](sync.md) — for upgrading an existing install, not removing it.
