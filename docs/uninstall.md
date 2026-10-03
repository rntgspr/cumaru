# `cumaru uninstall`

Reverse of [`cumaru install`](install.md). Discovers every supported adapter,
removes its Cumaru-owned files while preserving adopter content, then removes
the whole `.cumaru/` tree, including adopter knowledge. Refuses non-interactive
execution unless `--yes` is passed. It needs no network, Git, or config schema
and never changes the global CLI installation.

## Usage

```text
cumaru uninstall [-y|--yes]
```

| Flag | Description |
|---|---|
| `-y`, `--yes` | Skip the confirmation prompt. Required outside a TTY (CI, scripts, agents). |

## What it does

1. **Pre-checks** — when `.cumaru/` exists, it must be a real directory with
   regular `index.md` and `config.yaml` markers; root or parent symlinks and
   unsafe, special, or linked nested entries are refused. A malformed config is
   still removable. Every file is snapshotted before confirmation. An absent
   `.cumaru/` still permits cleanup of a partial adapter footprint.
2. **Discovery and preflight** — plans every adapter merge and owned namespace
   before any write, without reading agent state from config.
3. **Confirmation** — with an actual footprint and no `--yes`, a TTY is
   required. The removal scope is displayed and only `y` or `yes`
   (case-insensitive) proceeds; anything else exits `1` without writes. With no
   footprint it prints `Nothing to uninstall.` and succeeds.
4. **Removes framework commands and skills** — files under `cumaru-*` skill
   directories (including hidden resources) and the `commands/cumaru/`
   namespaces, in `.agents/` (Generic, Codex, OpenCode), `.claude/`, and
   `.opencode/`. Opt-ins and adopter skills or commands remain.
5. **Strips durable instructions** — removes the marked block from the native
   Markdown file, or Cumaru's exact entries from `opencode.json.instructions`.
   A Markdown file is deleted only when install created it and nothing else
   remains.
6. **Removes the session hook** — deletes only Cumaru's `SessionStart` entry
   from `.claude/settings.json` or `.codex/hooks.json`. Other keys, events, and
   entries are preserved; a changed JSON file is deleted only when empty.
7. **Removes the install tree** — rechecks the snapshot, then deletes the
   entire `.cumaru/` directory. Adapter directories and empty namespaces may
   remain.

There is no transaction, Git recovery gate, backup, or rollback. Detected
concurrent edits block removal. Repeating a successful uninstall is a no-op.

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
- [`cumaru update`](update.md) — for refreshing an existing install, not removing it.
