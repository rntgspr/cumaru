# Native regression inventory

`bash tests/run.sh [--ci|--random]` uses ShellSpec 0.28.1 as a process harness,
not as a Bash implementation dependency. It selects `tests/native/` and five
reviewed source-independent artifact suites. Native unit tests stay beside Rust
implementations. An absolute `CUMARU_TEST_BINARY` selects the executable; the
default is `target/release/cumaru`. No native test executes `src/*.sh`.

Each process example has a fresh project and HOME. A closed cURL stub serves
main identity, a complete checkout inventory, and raw files at one fixed SHA;
unknown URLs fail instead of reaching the network. Model downloads, inference,
global installation, and real adopter mutations are outside this suite.
Git recovery/coverage cases initialize only their disposable project repositories.

## Legacy file disposition

Paths below are relative to `tests/spec/`. “Adapted” means the named subset is
exercised, not that every legacy example was ported. “Remaining” retains relevant
behavior that requires later native scenarios; issue 139 stays open.

| Legacy file | Disposition and current owner |
|---|---|
| `cli/fs_spec.sh` | Adapted in `native/fs_spec.sh`: all existing verb, containment, preservation, arity, symlink and retired-flow cases. Clap diagnostics replace Bash wording. |
| `cli/tree_spec.sh` | Adapted shallow TSV, file-parent/overlap, deep partial errors, length boundaries and containment in navigation. Retired domain/pillar filters and external yq requirements. Remaining YAML forms, Unicode/control paths and full symlink matrix; Rust tree/walker units cover related mechanics. |
| `cli/map_spec.sh` | Adapted exact-file literal headings, numeric ordering, partial unsafe/UTF-8 results. Retired rg dependency, H2-only format and domain/pillar filters. Remaining Markdown escaping/frontmatter/CRLF probes; Rust markdown units cover parsing. |
| `cli/coverage_spec.sh` | Adapted covered/uncovered/stale/invalid/template buckets, strict status, mode conflict and byte preservation. Remaining foreign/outside-host/filter combinations; Rust coverage/reference units cover these mechanics. |
| `cli/doctor_spec.sh` | Already covered in part by Rust doctor unit tests and update postchecks. Remaining full process health matrix, warnings, workflow failures and custom-domain defaults. Legacy setup sources `src/common.sh`; not selected. |
| `cli/version_spec.sh` | Retired snapshot/VERSION installer behavior. Native version/release units cover separate identities/tag grammar. Remaining native scratch-installer failure/publication and process upgrade/version cases; no old installer is executed. |
| `cli/support/helpers.sh` | Replaced by `native/helpers.sh`; legacy doctor helper directly sources `src/common.sh`. |
| `contracts/auxiliary_skills_spec.sh` | Reused unchanged: four source-independent artifact contracts. |
| `contracts/command_skill_launchers_spec.sh` | Reused unchanged: namesake/arguments, mirror and ordered role-bootstrap contracts. |
| `contracts/summarize_artifacts_spec.sh` | Reused five artifact cases; outdated CR/LF/tab wording adapted to current C0/DEL contract. |
| `contracts/terraform_skill_spec.sh` | Reused unchanged: three written inspection/authorization contracts. No Terraform execution. |
| `contracts/workflow_orchestrator_skill_spec.sh` | Reused unchanged: three written prerequisite/launcher contracts. No agent execution. |
| `contracts/bootstrap_spec.sh` | Remaining native process delivery/source-only and focus pillar checks; native bootstrap units already cover rendering/resolution. Retired `--from`. |
| `contracts/design_artifacts_spec.sh` | Remaining domain artifact/schema/scenario checks. Direct calls to Bash `schema_validate_domain` must be replaced; native install/doctor/config units provide partial mechanical coverage. |
| `contracts/documented_contracts_spec.sh` | Remaining written lifecycle/ownership/role contracts and catalog checks. Adapted unsupported CLI invocations and fs safeguards in native suites. Retired Bash help layout and source-text implementation assertions. |
| `contracts/domain_kernel_sync_spec.sh` | CI already runs `scripts/sync-domain-kernel.sh --check`. Remaining disposable apply/idempotence checks; old CLI-map checks need native invocation. |
| `contracts/focus_templates_spec.sh` | Remaining focus-specific template/source-skill cases; adapter process matrix currently uses sdlc-light, not focus. |
| `contracts/migrate_spec.sh` | Native migrate units already cover checkpoint order/resolution. Remaining delivery, repeatability and prose-policy processes. Retired `--from`, old source-module assertions and Bash help. |
| `contracts/public_catalogs_spec.sh` | Remaining native help/README/domain/skill inventory correspondence. Retired parsing of the deleted Bash dispatcher. |
| `contracts/workflow_scenarios_spec.sh` | Remaining cross-role written scenario contracts and doctor-failure retention. Native postchecks prove structural health only. |
| `contracts/spec_helper.sh` | Reused only by the five selected artifact suites; its deleted CLI path is never invoked. Remaining helpers belong to unported scenarios. |
| `integration/agent_adapters_spec.sh` | Adapted four stateless adapters, adopter-file uninstall preservation, codex hooks/instructions/skills refresh idempotence and offline clear. Remaining all-domain/per-adapter malformed-native-state and switch/cleanup matrices; Rust adapter/artifact/install/uninstall units cover mechanics. |
| `integration/schema_spec.sh` | Rust config/config-tree units already cover native schema loading. Remaining process reconciliation/invalid-state probes. Bash validator internals and jq/yq runtime requirements are retired native contracts; direct `src/` calls remain unselected. |
| `integration/tree_resolution_spec.sh` | Rust config-tree unit tests cover selectors, overrides/collisions and index exemption. Remaining process matrix; legacy direct `_tree`/config calls are unselected. |
| `integration/workflow_graph_spec.sh` | Rust doctor units cover cycles/dependencies/installed skills. Remaining native process graph matrix; Bash validator calls unselected. |
| `integration/support/integration_helpers.sh` | Unselected legacy CLI setup; no production dependency. |
| `update/content_spec.sh` | Adapted preview, framework prose replacement, opaque body and local-only preservation. Remaining full changed/no-op/source-error matrix. |
| `update/dry_run_spec.sh` | Adapted ordinary/config previews with project snapshots. Remaining every scoped adapter/optional-skill preview. |
| `update/transaction_spec.sh` | Adapted dirty/untracked Git refusal, warned non-Git apply, publication postcheck and preservation. Remaining clean baseline/absent HEAD/unsafe native-state and interruption matrices. |
| `update/tags_spec.sh` | Adapted opaque body/orphan preservation and malformed edit refusal. Rust tags/update units cover nested/duplicate parsing and merge. Remaining process replay of `fixtures/update-tags/`; direct `src/common.sh`, `src/cmd_update.sh`, `src/cmd_tag.sh` calls remain unselected. |
| `update/v9_ownership_spec.sh` | Native config-tree/update unit tests cover explicit per-entry ownership. Remaining wildcard/path-remap process combinations. |
| `update/version_gate_spec.sh` | Native update/version unit tests cover independent version gates. Remaining cross-config-version process refusal and preservation. |
| `update/intake_tracker_spec.sh` | Remaining domain tracker-provenance preservation cases; no live tracker is part of testing. |
| `update/design_tracker_spec.sh` | Remaining design tracker/local brief preservation cases; no live tracker is part of testing. |
| `update/support/update_helpers.sh` | Replaced for selected cases by the closed main-SHA stub; unported legacy `--from` helpers remain unselected. |
| `spec_helper.sh` | Adapted executable resolution through `CUMARU_TEST_BINARY`; no redirect/wrapper recreates the deleted Bash CLI. |

The source-independent legacy suites test artifact structure/written policies,
not whether an LLM follows them. Broad wording/duplication cleanup belongs to
issue 065. Unselected legacy suites that source the removed Bash modules no longer
run; tag 0.10.0 keeps those modules as porting reference.

## Evidence

On macOS ARM, ShellSpec 0.28.1 with Bash 3.2 executes 57 native process cases plus
18 reused artifact cases. Default TAP and randomized execution passed all 75
cases; the random run completed in 20.14 seconds. Missing-binary and legacy
runner-argument probes returned the documented statuses 1 and 2.
Each native spec file also passed independently: fs 25, lifecycle 14, navigation
16 and coverage two cases. `random-env.sh` redirects the upstream harness's
randomized example list into its own temporary directory, leaving no root artifact.
Four disposable binary wrappers injected wrong exit codes, stderr-to-stdout
routing, unsafe-path acceptance and copy source loss; each caused fs regressions
to fail with harness status 101. The production executable was not modified.
Canonical fixtures are copied only. CI installs a pinned, SHA-256-verified harness
and runs the same default/random selection alongside Cargo tests; remote execution
requires publication of these changes and is not established by local results.
