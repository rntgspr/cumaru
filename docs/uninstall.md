# `cumaru uninstall`

Reverse of [`cumaru install`](install.md). Reads the active adapter from schema,
removes its Cumaru-owned artifacts, then removes `.cumaru/`. Refuses
non-interactive execution unless `--yes` is passed.

## Usage

```
cumaru uninstall [--yes]
```

| Flag | Description |
|---|---|---|
| `-y`, `--yes` | Skip the confirmation prompt. Required for non-TTY runs (CI, scripts, agents). |

## What it does

1. **Pre-checks**:
   - If `.cumaru/` exists, it must look like an install (`index.md` + `schema.yaml` at its root). Also verifies the path resolves inside the filesystem (refuses `/`, `$HOME`, or non-absolute targets).
   - If `--yes` is not set and stdin is not a TTY, refuses with a hint to pass `--yes`.
2. **Discovery** — reads `agent` from schema and scans its native artifact paths. If the value is invalid, refuses to guess removal targets.
3. **Confirmation** (TTY without `--yes`):
   - Prints the target path + what will be removed.
   - Reads `y/N` from stdin; aborts on anything else.
4. **Removes framework commands** — deletes only the adapter's `commands/cumaru/` namespace.
5. **Removes framework skills** — deletes only `cumaru-*` skill directories; opt-ins and adopter skills remain.
6. **Strips durable instructions** — removes the marked hook from the native Markdown file, or Cumaru's exact entries from `opencode.json.instructions`. Other content remains.
7. **Prunes empty adapter directories**.
8. **Removes the install tree** — `rm -rf .cumaru/`.

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
