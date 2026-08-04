# `cumaru upgrade`

Update the `cumaru` tool itself. Does **nothing beyond re-running the install script**: it resolves the highest plain `X.Y.Z` release tag with `git ls-remote`, downloads GitHub's tarball of that tag (or of `main` while no tag exists) into a temporary directory, and only after a successful download and unpack replaces `~/.cumaru`, writes the installed tag (or `main`) to `~/.cumaru/VERSION`, and re-links `~/.local/bin/cumaru`. GitHub's archive honors `.gitattributes` `export-ignore`, so maintainer-only paths never ship. No clone is made; Git is needed only for `ls-remote`.

```
cumaru upgrade
```

Equivalent to the install one-liner: `curl -fsSL https://raw.githubusercontent.com/rntgspr/cumaru/main/src/install.sh | bash`. Upgrade always runs the installer script from `main`, never the installed copy; that script then installs the latest release tag.

## Version and staleness check

```
cumaru version          # offline: installed release tag (or main) and contract version
cumaru upgrade --check  # network: compare with the latest X.Y.Z tag on GitHub; replaces nothing
```

Two versions coexist:

- **Contract** — the integer `config.version` (`9`), gated by `cumaru update` and crossed only through `cumaru migrate`.
- **Distribution** — a plain Git tag `X.Y.Z` (no `v` prefix) whose major equals the contract, e.g. `9.0.0`. The installer records it in `~/.cumaru/VERSION`. A Git checkout has no `VERSION` and reports `development build`.

`upgrade --check` runs `git ls-remote --tags --refs https://github.com/rntgspr/cumaru.git`, picks the highest `X.Y.Z`, and prints `installed`, `latest`, `status`, and the upgrade command. An equal (or higher) installed tag is `up to date`; a lower tag, or `main` once any tag exists, is `behind`. Both exit `0`. It prints `cannot check` on stderr and exits `1` when the remote is unreachable, publishes no release tag, or the installed CLI is a development build. `cumaru doctor` never checks staleness; it stays offline.

## Kernel integrity check

The install script verifies the downloaded snapshot before linking: every universal artifact — `index.md`, every file under `__base/skills/` (except `cumaru-install`, which is domain-owned), `__base/commands/`, and `__base/disciplines/` (except the domain-owned `index.md`) — must be **byte-identical** across all domains. On any divergence the install aborts with `✗ kernel drift` — the snapshot is a broken distribution, not something the adopter can fix locally.

This check belongs here, not in `cumaru doctor`: doctor audits the **adopter's** `.cumaru/` tree, which never contains `__base` to compare against. Kernel drift is a distribution problem, caught at the point where the snapshot lands on disk.

## Scope

| Concern | Command |
|---|---|
| The tool (`cumaru`, `src/*.sh`, `domains/`, `skills/`, `commands/` in `~/.cumaru`) | `cumaru upgrade` |
| An installed project tree (`.cumaru/`, its skills, slash commands) | [`cumaru update`](update.md) |

`upgrade` never touches any project's `.cumaru/`. After upgrading, run `cumaru update` per project to pull the new framework content in.

## Related

- [`cumaru update`](update.md) — steady-state update of an installed `.cumaru/` tree.
- [architecture](architecture.md) — why the kernel must be byte-identical across domains.
