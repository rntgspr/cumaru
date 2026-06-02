---
name: cumaru-spec-coverage
description: "The spec↔code coverage feature (2026-07-03) — `reference` tag (canon rule: always a repository source file, project-root-resolved), `cumaru coverage` CLI, universal cumaru-refs skill + /cumaru:refs command, schema attrs specification_dir + coverage.source"
metadata:
  node_type: memory
  type: project
---

Shipped 2026-07-03. Renato's design decisions, via option picks:

**The `reference` tag (canon rule).** A flat tag declared per domain in `meta.tags` as `reference: { host_file: "*" }` (precedent: `files`/`files:touched`) — NOT the instance-named `specs:<name>:reference` form (schema validation is exact-match; the host file already identifies the spec; instance names break on `cumaru flow move`). Body is the universal `[Link, Description]` table with one extra hardcoded rule: **every row targets a repository SOURCE FILE, resolved from the PROJECT ROOT** (parent of `.cumaru/`) — never a `.cumaru/` path, a directory, an absolute path, a URL, or an anchor. Breaking rows get the new `--rows` status `invalid`. Resolution lives in `common.sh` (`_fm_resolve_reference_target`, dispatched by `fm_tag_resolve_target` via a 4th `tag` arg).

**`cumaru coverage` (new CLI primitive, `src/cmd_coverage.sh`).** Read-only report: source list = `git ls-files` (requires a git work tree; `.cumaru/` + `.agents/` always excluded) diffed against reference rows hosted under the spec pillar. Buckets: covered / uncovered / stale (target missing) / invalid (rule-breaking) / foreign (target exists but out of source scope — informational). Modes: default report, `--refs` (rows grouped by spec file), `--gaps` (pipeable list), `--rows` (TSV `bucket\tpath\tspec_host\tdetail`), `--strict` (exit 1 on any gap — CI gate). Template/empty rows are skipped BEFORE the spec-dir filter (else the starter template's placeholder counts as an "outside" row — bit us in the smoke test).

**Schema attrs (meta, adopter-owned).** `specification_dir:` names the durable pillar (`specs` sdlc×2, `topology` iac-basic, `coverage` qa-basic; `__base` ships it commented; default `specs`). `coverage.source:` = **array of globs** (Renato: "mais de um glob, um array de globs") narrowing coverable source; fnmatch-style where `*` crosses `/` (bash `[[ == ]]`, so `src/**` ≡ `src/*`); empty = every tracked file. Parser handles block and inline list forms.

**Universal pair named `cumaru-refs` / `/cumaru:refs`** — Renato picked this over renaming qa-basic's pillar skill: `cumaru-coverage` + `/cumaru:coverage` ALREADY exist in qa-basic (its coverage/ pillar manager), and universal artifacts mirror byte-identically into every domain, so the universal pair needed a collision-free name. CLI stays `cumaru coverage`. Division: the command measures, the skill maintains references (adjudication recipe: uncovered → row in owning spec / new spec entity via domain skill / narrow coverage.source; stale → fix path or drop; invalid → rewrite; never invent Descriptions — read the file first).

**Doctor integration.** Check 5 now also collects `invalid` (message: "must be a repository source file, project-root-relative"). Spec templates (`spec.md` ×2, `topology.md`, `coverage.md`) gained a `## Reference` section with an empty block + `<placeholder>` row (status `template` → no noise). The old deferred cross-file check "Files listed in '## Files' of specs exist on disk" is effectively implemented by this feature.

**Verification (scratch benches, 2026-07-03):** sdlc-light install → doctor 0/0/6 → spec area + rows via `cumaru tag set` → all 5 modes + strict rc=1 → stale/invalid/foreign exercised → doctor warns with per-row detail; iac-basic → `specification_dir: topology` + inline glob honored, doctor 0/0/6; guards (no git tree, no spec dir) error with hints; kernel `cmp` loop green for all NEW mirrors.

**RESOLVED (same day, Renato's call): `cumaru-install` demoted from the universal set.** The bugfixes #1/#2 (2026-07-03) had made iac-basic/qa-basic copies domain-specific on purpose (post-install hands off to the domain's durable-pillar skill), which would make the install.sh kernel drift-check ABORT a distribution. Fix: `install.sh` skips `skills/cumaru-install/*` in the drift loop (domain-owned exception, commented in the script); docs (architecture, install, update, README) now list the universal skill set as `cumaru-doctor`/`cumaru-update`/`cumaru-refs` and describe `cumaru-install` as "shipped by every domain, domain-owned, drift-exempt". See [[bugfix_llm_install_cross_domain_handoff]].

See [[v4_model]], [[frameworks_layout]], [[universal_index]].
