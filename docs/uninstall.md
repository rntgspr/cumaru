# `cumaru uninstall`

Reverse of [`cumaru install`](install.md). Removes `.cumaru/`, strips the installed agent hook block from `.agents/AGENTS.md`, removes the context hook from `.agents/hooks.json`, and removes `.agents/commands/cumaru/`, `.agents/skills/cumaru-*/`, and `.agents/hooks/`. Refuses non-interactive (no TTY) unless `--yes` is passed.

## Usage

```
cumaru uninstall [--yes]
```

| Flag | Description |
|---|---|
| `--yes`, `-y` | Skip the confirmation prompt. Required for non-TTY runs (CI, scripts, agents). |

## What it does

1. **Pre-checks**:
   - If `.cumaru/` exists, it must look like an install (`index.md` + `schema.yaml` at its root).
   - If `--yes` is not set and stdin is not a TTY, refuses with a hint to pass `--yes`.
2. **Confirmation** (TTY without `--yes`):
   - Prints the target path + what will be removed.
   - Reads `y/N` from stdin; aborts on anything else.
3. **Removes the install tree** — `rm -rf .cumaru/`.
4. **Removes framework commands** — the entire `.agents/commands/cumaru/` directory. The `cumaru` subdir is the framework namespace; every `.md` inside is framework-owned. Adopter-authored commands at other paths or namespaces are not touched.
5. **Removes framework skills** — every `.agents/skills/cumaru-*/` directory. The `cumaru-` prefix is the framework namespace marker. Opt-ins (any skill without the `cumaru-` prefix) and adopter-authored skills are not touched.
6. **Removes framework hooks** — the entire `.agents/hooks/` directory.
7. **Strips context hooks** — removes only the `UserPromptSubmit` command hook pointing at `context-loader` from `.agents/hooks.json`, using `jq`. Other hooks and settings remain untouched.
8. **Strips agent instruction hooks** — locates the `<!-- BEGIN CUMARU-HOOK -->` / `<!-- DOT-LLM-HOOK -->` block in `.agents/AGENTS.md` (also detects the legacy `DOT-LLM-HOOK` marker) and removes it (along with surrounding blank lines). If install created the file and only its boilerplate remains, removes it too.
9. **Prunes empty dirs** — removes `.agents/commands/`, `.agents/skills/`, and `.agents/` if they're empty after cleanup.

## When to use

- Resetting a bench between test cycles.
- Migrating to a different domain (uninstall, then `cumaru install --domain <new>`).
- Removing the framework from a project that won't use it anymore.

**Don't use it to "refresh" the framework** — that's [`cumaru update`](update.md)'s job. Uninstall is destructive; update is steady-state.

## Examples

```bash
cumaru uninstall                       # interactive (TTY required)
cumaru uninstall --yes                 # non-interactive (CI / agents)
```

## Related

- [`cumaru install`](install.md) — installs the inverse.
- [`cumaru update`](update.md) — for upgrading an existing install, not removing it.
