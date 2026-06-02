# Load all markdowns below:

- [advisor-mode](advisor_mode.md) — How this advisor mode works and what it does when loaded
- [cumaru framework / CLI](cumaru.md) — what the repo is, layout, cumaru CLI surface
- [v4 model and universal tag shape](v4_model.md) — recursive node tree, tracker-agnostic intake, `[Link, Description]` hardcoded for every tag block
- [frameworks layout](frameworks_layout.md) — multi-domain (frameworks/__base + frameworks/<name>/); universal vs domain-specific skills; install order with skip-if-exists
- [universal index + loading rule](universal_index.md) — index.md byte-identical across all domains from __base; loading rule is the kernel; domain-specifics → domain.md as a depends-on
- [iac-basic domain](iac_domain.md) — tool-agnostic IaC domain; topology/ + runbooks/ durable, apps=environments, no ghost role; shipped, folded into main, PR #11 auto-closed
- [sdlc-light domain](sdlc_light_domain.md) — simplified 3-pillar domain (plans/specs/exploring), single admin role, direct plans→specs absorb; installed + smoke-tested on gitboiler (2026-07-02)
- [install command state](install_state.md) — current state of `cumaru install`; `cumaru upgrade` (re-runs install script) + kernel drift check in install.sh (2026-06-09)
- [test process](test_process.md) — repeatable test cycle: uninstall-first → verify clean → install → test → report
- [superpowers → disciplines](superpowers_absorption.md) — don't enable the plugin; absorb select execution skills via the "discipline" artifact (loading-rule-loaded, domain-attached); skill-to-discipline tool
- [Bugfix: cross-domain handoff + metadata + rsync + Codex format](bugfix_llm_install_cross_domain_handoff.md) — bugs #1–10: wrong skill handoffs in iac-basic/qa-basic, sdlc-light cumaru-doctor ref, context-loader.sh env vars + Codex JSON, missing frontmatter in 9 skills, orphan template, rsync cleanup; plus sdlc-light admin→lead rename
- [Spec coverage feature](coverage_feature.md) — `reference` tag (project-root source-file rule), `cumaru coverage` CLI, universal cumaru-refs skill + /cumaru:refs; schema attrs specification_dir + coverage.source; OPEN: cumaru-install kernel drift (pre-existing)
- [Rename llm → cumaru (DONE)](rename-cli-and-framework.md) — renamed CLI, paths, skills, commands, markers from `llm` to `cumaru`
- [TODO: implementation gaps review](todo_review_gaps.md) — open items + v4 work stream
- [User: Renato](user_renato.md) — role and context
- [Feedback: git read-only](feedback_git_readonly.md) — git is read-only by default
- [Feedback: install.sh is destructive](feedback_install_sh_destructive.md) — never run install.sh / cumaru upgrade without explicit ask; it rm -rf ~/.cumaru and breaks the workspace symlink
- [Feedback: update/reconcile design](feedback_update_design.md) — tag bodies + FM values never auto-overwritten; skills/commands replaced deterministically; v4 collapses kinds into one hardcoded shape
- [Feedback: compact text, reference templates](feedback_compact_text.md) — prefer compactness over duplication
- [Feedback: communication style](feedback_communication.md) — pt-BR chat, English artifacts, terse responses

@./feedback_communication.md
@./feedback_compact_text.md
@./feedback_git_readonly.md
@./feedback_install_sh_destructive.md
@./feedback_update_design.md
@./cumaru.md
@./frameworks_layout.md
@./iac_domain.md
@./install_state.md
@./superpowers_absorption.md
@./test_process.md
@./universal_index.md
@./v4_model.md
@./user_renato.md
@./sdlc_light_domain.md
@./coverage_feature.md
@./rename-cli-and-framework.md
