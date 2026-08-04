---
name: canonical-domain-sync-script
description: Add a maintenance-only script that synchronizes universal __base artifacts into every shipped domain
status: completed
priority: medium
---

# Issue 034: Synchronize canonical domain artifacts

Universal kernel artifacts are authored under `domains/__base/` and copied
verbatim into every shipped domain. Today maintainers perform that propagation
manually, while `src/install.sh` only detects drift after a snapshot is cloned.

## Risk

- A canonical edit may leave one or more domains stale and produce a broken
  distribution snapshot.
- Duplicating the universal-artifact rules inconsistently can make maintenance
  sync disagree with the installer drift check.

## Required invariant

A standalone maintenance script deterministically copies the canonical
universal artifacts from `domains/__base/` into every other shipped domain,
while preserving domain-owned artifacts.

## Work

1. Create `scripts/sync-domain-kernel.sh`, independent from the Cumaru CLI and
   project install/update runtime.
2. Synchronize root `index.md`, universal skills, universal commands, and
   universal disciplines into every non-`__base` domain.
3. Exclude domain-owned `skills/cumaru-install/` and `disciplines/index.md`.
4. Add `--check` to report missing or divergent mirrors without mutation.
5. Keep the script's universal-artifact selection aligned with the integrity
   contract currently enforced by `src/install.sh`.

## Tests

- `scripts/sync-domain-kernel.sh --check` exits `0` when every mirror is
  byte-identical.
- Modifying or removing one mirror makes `--check` fail and identify its path.
- Running sync restores that mirror without changing domain-owned files.

## References

- `domains/__base/`
- `src/install.sh`
- `.memory/specs/domains.md`
- `.memory/specs/disciplines.md`
