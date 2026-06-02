---
name: bugfix-cumaru-install-cross-domain-handoff
description: "BUG #1 and #2 — iac-basic and qa-basic cumaru-install skills incorrectly referenced cumaru-specs (SDLC skill) instead of their domain-specific equivalents. Fixed 2026-07-03."
type: bugfix
---

## Bug #1 — iac-basic cumaru-install handoff to cumaru-specs (doesn't exist)

**File:** `frameworks/iac-basic/skills/cumaru-install/SKILL.md`

**Problem:** Step 2 of the post-install recipe instructed the LLM to hand off to `cumaru-specs` and seed `specs/`, but `iac-basic` has no `cumaru-specs` skill — its spec-equivalent pillar is `topology/`, managed by `cumaru-topology`.

**Changes made:**
- Description trigger phrases: `specs/` → `topology/`, `cumaru-specs` → `cumaru-topology`
- Title: "bootstrap specs" → "bootstrap topology"
- Step 2 intro: seed `specs/` → seed `topology/`, plans → changesets
- Step 2 skill name: `cumaru-specs` → `cumaru-topology`
- Bootstrap areas: `auth`, `payments` (functional areas) → `networking`, `compute`, `database` (infra stacks)
- Deepen recipe: EARS requirements → interface/dependencies/decisions; split into concerns/subareas per provider/account/region
- Consolidate: spec → topology
- Reserved word in step 1: `platform` → `all` (matches iac-basic schema)
- Patterns table references updated

## Bug #4 — context-loader.sh CLAUDE_PROJECT_DIR + codex default — provider-agnostic

**File:** `frameworks/*/hooks/context-loader.sh` (5 byte-identical copies, source in `__base/hooks/context-loader.sh`)

**Problem:** Two provider-specific references in the hook script:
1. `CLAUDE_PROJECT_DIR` env var — Claude-specific name in an agnostic framework
2. `DOT_LLM_HOOK_TARGET` default was `codex` — mismatched the project convention (install defaults to `claude`)

**Changes made (source + propagated):**
- Line 172: `${CLAUDE_PROJECT_DIR:-$PWD}` → `${DOT_LLM_PROJECT_DIR:-$PWD}` (follows `DOT_LLM_*` env var convention)
- Line 173: `codex` → `claude` (matches `cumaru install --agent` default)

**Propagation:** Edited `__base/hooks/context-loader.sh` (source), then copied to all 4 domains:
`sdlc-it-project-basic`, `iac-basic`, `qa-basic`, `sdlc-light`

## Bug #3 — sdlc-light cumaru-doctor references cumaru-archive (doesn't exist)

**File:** `frameworks/sdlc-light/skills/cumaru-doctor/SKILL.md`

**Problem:** Two references to `cumaru-archive` (an SDLC skill not shipped in sdlc-light). This domain uses `cumaru-absorb` for plan-close absorption.

**Changes made:**
- Line 58: `cumaru-archive` → `cumaru-absorb`, "archive recipe" → "absorb recipe"
- Line 74: `cumaru-archive for sdlc` → `cumaru-absorb for sdlc-light`

## Bug #2 — qa-basic cumaru-install handoff to cumaru-specs (doesn't exist)

**File:** `frameworks/qa-basic/skills/cumaru-install/SKILL.md`

**Problem:** Same pattern — Step 2 instructed handoff to `cumaru-specs` and seeding `specs/`, but `qa-basic` uses `coverage/` managed by `cumaru-coverage`.

**Changes made:**
- Description trigger phrases: `specs/` → `coverage/`, `cumaru-specs` → `cumaru-coverage`
- Title: "bootstrap specs" → "bootstrap coverage"
- Step 2 intro: seed `specs/` → seed `coverage/`, plans → campaigns
- Step 2 skill name: `cumaru-specs` → `cumaru-coverage`
- Deepen recipe: EARS requirements → scenarios (GWT); split into cases/subareas per flow/feature
- Consolidate: spec → coverage map
- Reserved word in step 1: `platform` → `all` (matches qa-basic schema)
- Patterns table references updated

## Bug #5 — context-loader.sh emits bare text for non-claude targets (breaks Codex)

**File:** `frameworks/*/hooks/context-loader.sh` (5 byte-identical copies, source in `__base/hooks/context-loader.sh`)

**Problem:** `emit_context()` had an `if/else` branch: JSON for claude, bare `printf` text for everything else (codex). Codex accepts the **same JSON shape** as Claude (`{ hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext } }`). Bare text works in degraded mode but lacks suppressOutput, decision block, etc.

**Changes made (source + propagated to all 4 domains):**
- Removed the `if [[ "$target" == "claude" ]]` conditional
- `emit_context()` now always emits the JSON shape — works for both Claude and Codex
- `target` parameter kept for signature compatibility (now unused)

## Bug #6 — skill-to-discipline SKILL.md missing human_revised/version

**File:** `skills/skill-to-discipline/SKILL.md`

**Problem:** Frontmatter had only `name:` and `description:` — missing `human_revised: false` and `version: 1` required by all skills.

**Changes made:**
- Added `human_revised: false` and `version: 1` to frontmatter

## Bug #7 — cumaru-release SKILL.md missing human_revised/version

**File:** `frameworks/sdlc-it-project-basic/skills/cumaru-release/SKILL.md`

**Problem:** Same as #6 — frontmatter had only `name:` and `description:`.

**Changes made:**
- Added `human_revised: false` and `version: 1` to frontmatter

## Bug #8 — 5 skills across sdlc-light and sdlc-it-project-basic missing version: 1

**Files:** `frameworks/sdlc-light/skills/{cumaru-absorb,cumaru-explore,cumaru-plan,cumaru-specs}/SKILL.md`, `frameworks/sdlc-it-project-basic/skills/{cumaru-explore,cumaru-specs,cumaru-plan,cumaru-archive}/SKILL.md`

**Problem:** All had `human_revised: false` but no `version: 1`.

**Changes made:**
- Added `version: 1` to all 8 SKILL.md files

## Bug #9 — sdlc-light orphan template release-report.md

**File:** `frameworks/sdlc-light/templates/release-report.md`

**Problem:** Template existed in sdlc-light but no `cumaru-release` skill lives there (it's sdlc-it-project-basic-only). Orphan file.

**Changes made:**
- Deleted `frameworks/sdlc-light/templates/release-report.md`

## Bug #10 — rsync referenced in doctor but never used

**Files:** `src/cmd_doctor.sh` + all 5 copies of `frameworks/*/skills/cumaru-doctor/SKILL.md`

**Problem:** Check [6] (external tools) included `rsync`, but nothing in the codebase ever invokes it.

**Changes made:**
- `src/cmd_doctor.sh`: removed `rsync` from check description (lines 18, 53), loop (line 744), and pass message (line 748)
- All 5 `cumaru-doctor/SKILL.md`: removed `rsync` from the "External tools available" description

## sdlc-light: admin → lead role rename

**Files:** multiple under `frameworks/sdlc-light/`

**Problem:** Role was named `admin` but user prefers `lead` — same scope (unrestricted read/write across `.cumaru/` and the repository).

**Changes made:**
- Renamed `roles/admin.md` → `roles/lead.md`
- Title/content updated from "Admin" to "Lead"
- `roles/index.md`: link + description updated
- `domain.md`: tree comment, role description, and indexes table updated (3 occurrences)
- 4 command files (`explore.md`, `absorb.md`, `specs.md`, `plan.md`): `roles/admin.md` → `roles/lead.md`
