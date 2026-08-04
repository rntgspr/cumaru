---
name: mounted-pillars
description: Let a pillar's content live at a project-root-relative mount outside `.cumaru/`
status: open
priority: high
---

# Issue 044: Mounted pillars

Cumaru currently treats `.cumaru/` as framework home, containment boundary, and
content root for every pillar. Repositories whose published artifact is the
durable specification, such as a root-level `docs/` tree, cannot govern that
tree through Cumaru without moving it under `.cumaru/`.

Using `path: ../docs` is correctly rejected by schema validation, and patching
that guard out exposes a deeper false-green risk: `tree`, `coverage`, and
`doctor` still resolve pillar content by literal `.cumaru/<pillar>` paths, so an
escaping pillar can silently disappear from validation.

## Risk

- A project-root docs tree cannot be the durable pillar without relocating the
  published artifact into a hidden framework directory.
- Treating existing `path:` as location indirection would break its current node
  shape contract and still leave many literal `.cumaru/` call sites stale.
- If mount-aware traversal reaches lifecycle commands without ownership guards,
  uninstall or update could delete or overwrite adopter-owned published docs.
- Mounted specification files can become noisy coverable source unless coverage
  excludes every declared mount and rejects references into mounts.

## Required invariant

A direct root pillar may declare an optional project-root-relative `mount:`. CLI
interfaces continue to use logical Cumaru paths such as `specs/auth/index.md`,
while resolution maps them to the physical mount. The framework home remains
`.cumaru/`, mounted pillar content is adopter-owned, validation spans every
declared root, and destructive lifecycle operations never own or remove mounts.

## Work

1. Add the `mount:` schema contract for direct children of `root.entities` only;
   validate non-empty relative paths with no `..`, hidden segments, `.`,
   `.cumaru`, `.cumaru/` descendants, or overlapping mounts.
2. Centralize pillar resolution in shared helpers such as `cumaru_pillar_roots`,
   `cumaru_pillar_dir`, `cumaru_resolve`, and `cumaru_relativize`, initially
   preserving current behavior for unmounted trees.
3. Update tree, map, tag walking, doctor inventories, and shared tag traversal
   to iterate the framework home plus every mount while reporting logical paths.
4. Extend flow containment from one `.cumaru/` root to the validated set of
   roots, preserving symlink refusal and protecting mounted pillar roots from
   removal.
5. Make coverage exclude every mount from coverable source and classify
   references into mounted specification content as invalid.
6. Ensure install, update, and uninstall never seed, reconcile, overwrite, or
   remove mounted adopter content.
7. Update kernel, docs, migration guidance, and versioned config contracts for
   the new `mount:` key and propagate universal kernel edits byte-identically
   across shipped domains.

## Tests

- A mounted pillar under `docs/` appears in `cumaru tree`, `cumaru map`, tag
  walking, doctor inventories, and logical path output.
- Missing `index.md` files and invalid `summary:` frontmatter inside a mount are
  reported by doctor instead of producing a false green run.
- Invalid mounts, escaping mounts, hidden mounts, `.cumaru` mounts, symlinked
  mounts, and overlapping mounts fail validation before traversal or mutation.
- `cumaru coverage` does not report mounted specification files as uncovered
  source, and references into any mount are invalid.
- `cumaru flow` can operate inside allowed mounted pillar content but refuses to
  remove a mounted pillar root.
- `cumaru update --apply` and `cumaru uninstall --yes` preserve mounted content
  byte-for-byte.
- Existing unmounted projects keep byte-identical output and behavior.
- Version, migration, universal-kernel sync, and full regression tests pass.

## References

- GitHub issue: https://github.com/rntgspr/cumaru/issues/12
- `schemas/config.schema.json`
- `src/schema.sh`
- `src/common.sh`
- `src/cmd_tree.sh`
- `src/cmd_map.sh`
- `src/cmd_tag.sh`
- `src/cmd_doctor.sh`
- `src/cmd_doctor_checks.sh`
- `src/cmd_coverage.sh`
- `src/cmd_flow.sh`
- `src/cmd_update.sh`
- `src/cmd_uninstall.sh`
- `domains/__base/index.md`
- `.memory/specs/navigation.md`
- `.memory/specs/coverage.md`
- `.memory/specs/install-upgrade.md`
