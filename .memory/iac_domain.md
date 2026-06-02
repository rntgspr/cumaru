---
name: cumaru-iac-domain
description: "The iac-basic domain build — branch, key design decisions, what's done (Phase 1 + 2a) and what's pending (2b skills)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 01739ed5-2d3f-41f2-967d-bce05510a424
---

Building `frameworks/iac-basic/` — a **tool-agnostic Infrastructure-as-Code domain**. Historical branch name used the old vocabulary (2 commits on top of main `a6c82fc ☀️ sunrise`; **NOT merged, NOT pushed**). See [[frameworks_layout]] and [[universal_index]].

**Shape.** Reuses the sdlc lifecycle pillars verbatim — `intake`, `plans`, `archive`, `exploring` (the transient finalize-and-delete layer) — and adds two durable pillars: `topology/` and `runbooks/`.

**Key decisions (Renato, 2026-06-03/04):**
- **Durable truth pillar is `topology/`, not `specs/`** — "spec" collides with "the .tf/manifest IS the spec" (a discipline this domain bakes in). `topology`'s `depends-on` is literally the apply-order DAG. Rename is domain-level only — `specs` is NOT hardcoded in core (only in comments/help/examples); doctor is schema-driven.
- **`runbooks/` is a DIRECTORY-entity pillar** (`runbooks/<slug>/index.md`, flat — no recursion, durable, not loaded by default). A flat `runbooks/<slug>.md` was the first attempt but its `*.md` glob collided with the pillar's own `runbooks/index.md` in doctor → use the directory form like every other entity.
- **Axis: the universal `apps:` field enumerates ENVIRONMENTS** (`dev/staging/prod/all/meta`; `all` = cross-env/shared, replaced sdlc's `platform`). Field name stays `apps` (NOT renamed to `environments`) so `index.md` is byte-identical to `__base` and the parser is untouched — `domain.md` frames the semantic. This supersedes the earlier "generalize the axis name" idea, which collided with the universal-index decision.
- **`index.md` = verbatim copy of `__base/index.md`** (drift-checkable). All domain specifics live in `domain.md` (depends-on of the root index).
- **Ghost role dropped** — infra work is deliberate (plan → apply → verify), not ad-hoc IDE pairing. Roles = `lead` (platform) + `dev` (operator).
- **MCP integrations explicitly dropped** from scope.

**Done — Phase 1 (commit 1, skeleton):** schema.yaml (domain iac-basic, apps=environments, 6 pillars incl. runbooks), index.md (verbatim __base), domain.md, 6 pillar indexes.
**Done — Phase 2a (commit 2, content):** templates — `plan` (blast radius / rollback / promotion path), `task` (plan/apply/verify), `topology` (stack spec: interface, depends-on=apply-order, decisions, cost & security), new `runbook` (when-to-run, preconditions, idempotent procedure, verify, rollback), plus adapted intake/delta/handoff/exploration/bootstrap/any-index; roles lead + dev.

**Done — Phase 2b (commit 3): `cumaru-arch` skill** (`frameworks/iac-basic/skills/cumaru-arch/`). Read-only recipe: renders the topology `depends-on`/`relates` graph as Mermaid (prerequisite→dependent = apply order; relates dashed) + ASCII apply-order layering, to chat on demand; annotates nodes with environments; scopes to a slice/env; overlays runbooks; flags cycles; never invents edges. Renders only declared connectivity (loading-rule traversal `expand` is a separate thing). Renato's idea, short name per his preference. Persisting a living `topology/architecture.md` is a deliberate follow-up (placement vs doctor's orphan check).

**Done — Phase 2b (commit 4): the 5 orchestration skills** under `frameworks/iac-basic/skills/` — `cumaru-intake` (change requests/incidents), `cumaru-plan` (changeset — blast radius/rollback/promotion, tasks=apply steps, handoff records the apply diff), `cumaru-topology` (≈ sdlc `cumaru-specs`; bootstrap/deepen/consolidate; depends-on=apply-order; topology carries NO EARS), `cumaru-archive` (close → absorb delta into topology/ → prune; notes runbook authoring as a follow-up), `cumaru-explore` (infra spikes). All 6 domain skills (+ `cumaru-arch`) install via the wholesale domain copy; doctor green.

**Done — commit 5: opt-in `terraform` + `pulumi` skills** at the TOP-LEVEL `skills/` (installed via `--with`, like `git`; NOT domain-shipped — reusable). Tool mechanics + the domain's safety discipline (never apply/up unread; the plan/preview diff IS the blast radius; envs = workspaces/stacks along the promotion path; outputs → topology Interface; depends-on = apply order). Discovered in `install --help`; verified install `--with terraform --with pulumi` + doctor green.

**Core fix (commit 6, `b2f46c9`):** `install --help` now reads each domain's one-line summary from its `domain.md` H1 (`_install_list_domains` in `cmd_install.sh`) instead of the now-universal `index.md` — every domain was showing the same generic line. Benefits all domains.

**DOMAIN COMPLETE — PUSHED + PR OPEN.** Historical branch name used the old vocabulary, **6 commits** on top of `a6c82fc`, pushed to origin; **PR #11** in the historical GitHub repo → base `main`; the historical title also used the old vocabulary. Skills: 6 domain-shipped (`cumaru-arch` + 5 orchestration) + 2 opt-in (`terraform`, `pulumi`). Every phase gated install→doctor (0/0/5).

**Polish (commit 7, `fbb1464`):** dropped the stale "topology — Requirements (EARS)" entry from the schema `ears.applies_to` (topology is described by structure, not behavioral EARS). Pushed — PR #11 now has 7 commits.

**SHIPPED.** Renato chose to fold the whole branch into his single-root-commit workflow: all 7 commits' content was squashed into `main`'s `☀️ sunrise` root commit; tree verified identical to the branch before pushing and **force-pushed** (`--force-with-lease`) → `main` is now root commit `768e6b1`. GitHub **auto-closed PR #11** (its changes are now in base). The previous sunrise `a6c82fc` is reflog-recoverable until GC.

The historical IaC branch (local `fbb1464` + remote) is now a **diverged-root, stale** branch (no common ancestor with the new `main`) — safe to delete once Renato is satisfied; left in place pending his call. The granular 7-commit history survives only on that branch (main carries only the squashed content).

**Verification method:** doctor runs on an INSTALLED tree, not `frameworks/` in place. Gate each phase from the scratch project root with `/path/to/cumaru install --domain iac-basic` then `/path/to/cumaru doctor` against the installed `.cumaru/` tree → green (0 err / 0 warn / 5 ok). Bash-internal tests must run under `bash` explicitly: the Bash tool's shell is **zsh**, where unquoted `$var` does NOT word-split (broke a sed batch once) and `shopt` is absent.
