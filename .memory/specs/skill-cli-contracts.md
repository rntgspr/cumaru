---
name: skill-cli-contracts-specification
description: "Reviewed native CLI contracts for shipped skills, launchers, README, and command guides"
type: project
status: implemented
version: 9
---

# Skill and native CLI contracts

## Purpose

Keep shipped recipes consistent with the supported Rust CLI. The command
arguments and mechanical boundaries are canonical in [rust.md](rust.md);
skills own semantic workflows and do not imply additional command capabilities.

## Invariants

1. Domain/config freshness uses a commit-pinned HEAD of main. CLI release
   identity, skill frontmatter version, and integer config version are distinct.
   Missing remote information never supplies an inferred latest version.
2. Navigation emits TSV by default. Tree rows contain path and summary; map
   rows contain path, line, and literal H1-H6 heading. Relations and targets
   require reading selected frontmatter; structural inventories do not live in tags.
3. Project install writes after preflight and defaults to base. Domain-specific
   recipes select their own domain explicitly. Optional skills use update skills,
   and Claude/Codex receive skills directly rather than separate command files.
4. Update previews do not mutate; apply and clear enforce conditional Git
   recovery and preserve adopter bodies and siblings. Config reconciliation is
   read-only. Filesystem primitives do not promise multi-file atomicity.
5. Installed skill references to knowledge use project-root `.cumaru/` paths,
   not relative paths into the source package. Sibling skill links remain portable.
6. Doctor validates structural health offline. It does not prove acceptance,
   custom-link meaning, requirements language, or freshness against main.
7. Native command forms omit retired source/filter/typed-tag flags. Migration
   can inspect legacy bodies with config-free tag listing or direct host reads;
   an old declaration does not bypass native schema validation.

## Review coverage

The universal `cumaru-search` recipe owns read-only knowledge discovery when
the owning file is unknown. `cumaru-first` routes that need to the installed
skill; the [canonical recipe](../../domains/__base/skills/cumaru-search/SKILL.md)
defines tool selection and content verification without duplicating the policy
in the discipline. Every domain receives the skill and its Generic/OpenCode
launcher through universal synchronization. The inventory below is the earlier
review snapshot, before this addition.

The 2026-10-03 review accounts for 99 SKILL.md files: 91 domain files and eight
optional files. Six universal recipes are reviewed at base and verified across
eight domains (48 files); the other 43 domain recipes and eight optional recipes
are reviewed individually. All rows below are reviewed for native compatibility;
the outcome names corrections where necessary, not an agent execution result.

Names in the domain tables use the `cumaru-` prefix. Paths resolve through
`domains/<domain>/skills/<name>/SKILL.md`; optional paths use `skills/<name>/SKILL.md`.

| Canonical set | Recipes | Outcome |
|---|---|---|
| `__base` universal | doctor, flow, refs, role, summarize, update | Native health/freshness distinction, opaque references, complete role bootstrap, control-character summary rule, preview/apply/clear and independent versions; mirrors synchronized. |
| `__base` domain-owned | install | Base default, remote config-selected materialization, optional skills after adoption, all-adapter uninstall. |
| `sdlc-full` | install, intake, issue, explore, plan, specs, absorb | Explicit domain install; TSV candidate interpretation; removed marker-table navigation and unverified Bash timing claims; preserve evidence and Git recovery. |
| `sdlc-light` | install, explore, plan, specs, absorb | Explicit domain install and single Lead routing; filesystem navigation and bounded close-out discovery. |
| `iac-basic` | install, intake, explore, plan, topology, arch, absorb | Explicit domain install; read frontmatter for graph edges; replace index-table round trips with navigation; retain infrastructure promotion and recovery gates. |
| `qa-basic` | install, intake, explore, plan, coverage, absorb | Explicit domain install; filesystem navigation; GWT remains agent-reviewed, not a doctor language check; preserve acceptance provenance. |
| `design-as-code` | install, intake, concept, plan, specs, absorb | Native installation and adapter exposure; independent review and evidence remain prerequisites for durable edits and cleanup. |
| `focus` | install, directives, sources, thread, outcome, zoom | Native installation/bootstrap; installed contracts addressed through `.cumaru/`; source reads, archive discovery, and custom-link verification remain semantic workflow responsibilities. |
| `vault-memory` | install, capture, draft, distill, link | Native installation/update; durable provenance and confirmed cleanup retained, with no new Git requirement for vault distillation. |
| optional | git, terraform, pulumi, pytest, vitest, cypress, playwright, skill-to-discipline | Install-time opt-ins replaced by adapter-targeted update; discipline recipe naming updated. Tool-specific execution and external effects retain their own authorization. |

## Supporting resources and public documentation

All 82 source command launchers retain namesake skills and argument forwarding.
Generic/OpenCode install them; Claude/Codex use the skills directly. No bundled
scripts or reference directories exist inside the reviewed skill folders.
References to installed domain indexes, templates, roles, bootstrap and migration
instructions were reviewed alongside recipe callers.

README and the public command guides now describe native source resolution,
installation, adapters, TSV/heading output, opaque tags, update ownership, offline
doctor, removal, and binary distribution. Optional YAML editor examples in the
rolling migration require Mike Farah yq v4; the native CLI does not.

Reader-facing onboarding now starts with compiled CLI installation and usage in
README. Source checkout, architecture overview, compilation, development PATH
links, and verification are owned by [HOW_TO_DEV.md](../../HOW_TO_DEV.md);
the native guide links there rather than duplicating build recipes.

## Verification

- All 71 native unit tests passed with default parallel execution; formatting,
  locked release build, mirror synchronization, and diff checks passed.
- Disposable offline CLI smokes installed all eight domains and exercised all
  four adapters. Tree, map, version, bootstrap, migrate, update/config previews,
  adapter refresh, optional skill update, opaque tags, fs verbs, clear and
  uninstall passed. Preview snapshots preserved managed bytes and modes;
  adopter content and config survived the tested refresh/removal boundaries.
- Removed navigation filters, install opt-ins, `--from`, and typed tag rows
  returned usage status 2. No live adopter or global installer was invoked.
- YAML metadata for 99 skills and namesake/argument forwarding for 82 launchers
  passed independent structural checks. The generic skill-creator validator
  could not start because its Python environment lacks PyYAML; it is not
  reported as passing. Native checks and YAML parsing provide separate evidence.
- The retired Bash runner returned its documented missing-entry-point failure.
  ShellSpec is retained reference, not proof of native recipe behavior.
- GitHub release listing returned no releases at the time of this review.
  Subsequent publication and platform evidence are recorded in
  [release verification](rust.md#release-verification).

This review does not execute an LLM, tracker, browser suite, infrastructure tool,
or provider API. Compatibility review and deterministic checks do not prove a
live agent will follow a recipe. The existing intermittent native fixture failures
remain historical unresolved observations; one passing parallel run does not
establish that they are fixed.

## Follow-up boundaries

Homebrew packaging remains undelivered: separately decide artifact/checksum
ownership, macOS/Linux architectures, and package-manager versus CLI upgrades.
No formula, tap, bottle, release publication, or global install is included.
The missing migration skill, remaining domain bootstrap documents, and broader
test-scope audit remain separately tracked in the [issue catalog](../issues/index.md).

## References

- [Native CLI specification](rust.md)
- [Testing boundaries](testing.md)
- [README](../../README.md)
- [Public adapter matrix](../../docs/agent-adapters.md)
- [Kernel synchronization](../../scripts/sync-domain-kernel.sh)
- [GitHub issue 13](https://github.com/rntgspr/cumaru/issues/13)
