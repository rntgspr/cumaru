# `cumaru upgrade`

Update the `cumaru` tool itself. Does **nothing beyond re-running the install script**: wipes `~/.cumaru`, fresh shallow clone, strips `.git/`, re-links `~/.local/bin/cumaru`.

```
cumaru upgrade
```

Equivalent to the install one-liner: `curl -fsSL https://pixelpunk.works/dot-cumaru/install.sh | bash`.

## Kernel integrity check

The install script verifies the downloaded snapshot before linking: every universal artifact — `index.md`, every file under `__base/skills/` (except `cumaru-install`, which is domain-owned), `__base/hooks/`, and `__base/commands/` — must be **byte-identical** across all domains. On any divergence the install aborts with `✗ kernel drift` — the snapshot is a broken distribution, not something the adopter can fix locally.

This check belongs here, not in `cumaru doctor`: doctor audits the **adopter's** `.cumaru/` tree, which never contains `__base` to compare against. Kernel drift is a distribution problem, caught at the point where the snapshot lands on disk.

## Scope

| Concern | Command |
|---|---|
| The tool (`cumaru`, `src/*.sh`, `frameworks/`, `skills/`, `commands/` in `~/.cumaru`) | `cumaru upgrade` |
| An installed project tree (`.cumaru/`, its skills, hooks, slash commands) | [`cumaru update`](update.md) |

`upgrade` never touches any project's `.cumaru/`. After upgrading, run `cumaru update` per project to pull the new framework content in.

## Related

- [`cumaru update`](update.md) — steady-state update of an installed `.cumaru/` tree.
- [architecture](architecture.md) — why the kernel must be byte-identical across domains.
