# Load all markdowns below:

- [advisor-mode](advisor_mode.md) — How this advisor mode works and what it does when loaded
- [cumaru framework / CLI](cumaru.md) — what the repo is, layout, cumaru CLI surface
- [v6 virtual tree](v6_virtual_tree.md) — CANONICAL current model: filesystem navigation, summaries, transactional migration, and version-gated updates
- [v4 model and universal tag shape](v4_model.md) — historical model superseded by v5 tag typing and v6 filesystem navigation
- [frameworks layout](frameworks_layout.md) — historical layout; v6 renamed `frameworks/` to `domains/`
- [universal index + loading rule](universal_index.md) — kernel history; v6 traversal now expands filesystem candidates through `cumaru tree`
- [iac-basic domain](iac_domain.md) — tool-agnostic IaC domain; topology/ + runbooks/ durable, apps=environments, no ghost role; shipped, folded into main, PR #11 auto-closed
- [sdlc-light domain](sdlc_light_domain.md) — simplified 3-pillar domain (plans/specs/exploring), single Lead role, direct plans→specs absorb; installed + smoke-tested on gitboiler (2026-07-02)
- [install command state](install_state.md) — current v6 install contract, required Bash/cURL/Git/jq/yq tooling, agent artifacts, migration boundary, and destructive upgrade behavior
- [schema-selected agent adapters](agents_dialect.md) — generic, Claude, Codex, and OpenCode native artifact matrix; no prompt-submit hooks
- [test process](test_process.md) — repeatable test cycle: uninstall-first → verify clean → install → test → report
- [superpowers → disciplines](superpowers_absorption.md) — don't enable the plugin; absorb select execution skills via the "discipline" artifact (loading-rule-loaded, domain-attached); skill-to-discipline tool
- [Bugfix: cross-domain handoff + metadata + rsync + Codex format](bugfix_llm_install_cross_domain_handoff.md) — bugs #1–10: wrong skill handoffs in iac-basic/qa-basic, sdlc-light cumaru-doctor ref, context-loader.sh env vars + Codex JSON, missing frontmatter in 9 skills, orphan template, rsync cleanup; plus sdlc-light admin→lead rename
- [Spec coverage feature](coverage_feature.md) — `reference` tag (project-root source-file rule), `cumaru coverage` CLI, universal cumaru-refs skill + /cumaru:refs; schema attrs specification_dir + coverage.source; OPEN: cumaru-install kernel drift (pre-existing)
- [Rename llm → cumaru (DONE)](rename-cli-and-framework.md) — renamed CLI, paths, skills, commands, markers from `llm` to `cumaru`
- [v5 tag body model](v5_tag_model.md) — tag blocks are adopter-owned; schema declares `default`, custom column arrays, `prose`, `mixed`, `other`; `domain.md` anchors at project root
- [SDLC archive → specs absorptions](sdlc_archive_absorptions.md) — archive is transient staging; durable `SHA | KEY | Description` ledger lives in `specs/index.md`
- [v5 update smoke on gitboiler](update_v5_gitboiler.md) — legacy `flavor:` fallback, source-schema tag typing, reference row correction, schema apply to v5
- [Cleanup: regen + cross_file_checks](regen_cleanup.md) — removed stale `cumaru regen` references and unused schema cross_file_checks metadata
- [User: Renato](user_renato.md) — role and context
- [Feedback: git read-only](feedback_git_readonly.md) — git is read-only by default
- [Feedback: commit messages](feedback_commit_messages.md) — one-line gitmoji commits under 120 chars
- [Feedback: install.sh is destructive](feedback_install_sh_destructive.md) — never run install.sh / cumaru upgrade without explicit ask; it rm -rf ~/.cumaru and breaks the workspace symlink
- [Feedback: update/reconcile design](feedback_update_design.md) — tag bodies + FM values never auto-overwritten; skills/commands replaced deterministically; v4 collapses kinds into one hardcoded shape
- [Feedback: compact text, reference templates](feedback_compact_text.md) — prefer compactness over duplication
- [Feedback: communication style](feedback_communication.md) — pt-BR chat, English artifacts, terse responses

@./feedback_communication.md
@./feedback_compact_text.md
@./feedback_git_readonly.md
@./feedback_commit_messages.md
@./feedback_install_sh_destructive.md
@./feedback_update_design.md
@./cumaru.md
@./v6_virtual_tree.md
@./frameworks_layout.md
@./iac_domain.md
@./install_state.md
@./agents_dialect.md
@./superpowers_absorption.md
@./test_process.md
@./universal_index.md
@./v4_model.md
@./user_renato.md
@./sdlc_light_domain.md
@./coverage_feature.md
@./rename-cli-and-framework.md
@./v5_tag_model.md
@./sdlc_archive_absorptions.md
@./update_v5_gitboiler.md
@./regen_cleanup.md
