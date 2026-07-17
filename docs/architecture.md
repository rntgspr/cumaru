# Architecture — the kernel, the universal index, and domains

## The loading rule is the kernel

The whole framework revolves around one rule: **load only what is declared, by a guided filesystem traversal.** Read a directory's `index.md`, use `cumaru tree <directory>` to list its shallow candidates and summaries, then follow only domain-declared semantic links such as `depends-on` or `relates`. The LLM prunes by relevance and recurses only into selected candidates.

This is **deterministic in structure** (schema contracts, filesystem candidates, and semantic links) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). `cumaru tree` expands a directory; pruning and recursion stay with the LLM.

### Cross-reference discovery

An empty `depends-on:` or `relates:` field means no semantic edge was declared; it does not prove that a concern has no consumers. For changes to shared behavior, use the filesystem as a bounded discovery surface:

1. Expand the relevant durable pillar with `cumaru tree <pillar>/`.
2. Select the next candidate from its `summary:` and the task subject, then expand only that directory. Use `--deep` when shallow results indicate nested concerns.
3. Continue while newly surfaced summaries, names, or domain-declared semantic links suggest another relevant concern.
4. Load only selected files and inspect their `reference` tags for affected source files and consumers.
5. Report relevant consumers, durable updates outside the active scope, and uncovered gaps.

This is iterative search with an explicit stopping condition: stop when newly surfaced candidates add no relevant concern. It does not authorize a bulk read of the pillar.

## Universal artifacts are identical across every domain

Three artifact sets are **byte-identical** in `__base` and in every domain:

1. **`index.md`** — the framework kernel: node model, loading rule, conduct, language. Carries no domain content.
2. **`skills/cumaru-doctor/`, `skills/cumaru-update/`, `skills/cumaru-refs/`, `skills/cumaru-summarize/`** — universal multi-step orchestration; same SKILL.md across all domains. (`skills/cumaru-install/` is deliberately **domain-owned**: its post-install recipe hands off to the domain's durable-pillar skill — `cumaru-specs` / `cumaru-topology` / `cumaru-coverage` — so each domain ships its own tuned copy and the drift-check skips it.)
3. **`commands/cumaru/doctor.md`, `commands/cumaru/update.md`, `commands/cumaru/resolve.md`, `commands/cumaru/refs.md`, `commands/cumaru/summarize.md`** — universal launchers with no domain-specific recipe content.

All three are authored once in `domains/__base/` and propagated verbatim into every `domains/<domain>/`. Domain-specific content (its pillars, roles, additional skills, additional slash commands) lives only in the domain.

- The kernel `index.md` carries a blockquote header at the top stating that the file is framework-owned and must not be edited. The whole file (loading rule, conduct, language, etc.) is plain prose — outside any `<!-- cumaru:NAME -->` tag — so `cumaru update` carries it from source. Adopter-owned blocks (`components`, `root`) live in `domain.md`, where the tag-body preservation rule protects them.
- A drift-check enforces that every domain's universal artifacts match `__base`'s. It runs in the **install script** (`cumaru upgrade` re-runs it): a snapshot where any domain diverges is refused. It is deliberately NOT a `cumaru doctor` check — doctor audits the **adopter's** tree, which never contains `__base` to compare against. See "Reuse" below.

## Domain specifics live in `domain.md`

Everything domain-specific — the pillars, the roles, the entry-point refinement, the domain context — lives in **`domain.md`**, declared as a `depends-on` of the root `index.md`. This dogfoods the loading rule: loading `index.md` surfaces `domain.md` as a candidate and pulls it in. Every domain (including `__base`) ships this file so the dependency never dangles.

### Lifecycle flow

Every domain (except `__base`) includes an ASCII flow diagram under `## Flow` or `## Lifecycle` showing how work moves through its pillars. The canonical pattern:

- **Transient pillars** (`intake/`, `exploring/`, `plans/`, `archive/`) feed into one another and are **removed after absorb** — only the durable pillar (`specs/`, `topology/`, `coverage/`) retains the absorbed knowledge.
- The diagram makes the cleanup explicit: "After absorb: archive/, plans/, exploring/, and intake/ entries related to the closed plan are removed (transient cleanup)."

## Why prose, not tags — and why not symlinks

- **Tags won't work:** tag bodies are adopter data, never overwritten on `cumaru update`. The shared kernel must propagate framework → adopter, so it is prose, not a tag.
- **Symlinks won't work:** fragile on Windows (admin/Developer-Mode, `git core.symlinks`, editor breakage), and the adopter never receives `__base` (install copies only the chosen domain), so a link would dangle.

## Reuse mechanism

Propagation is a **verbatim copy** of every universal file under `__base/{index.md, skills/, commands/}` into each domain, plus a **deterministic drift-check** (`cmp` per file in the install script) that aborts the install when any domain's universal artifact diverges from `__base`. The `cumaru-install` skill is exempt from the drift-check (domain-owned). The maintainer edits `__base`, re-copies into the domains, and the check guards against shipping a drifted snapshot. (A build-time include was considered and set aside as more machinery for a marginal gain.)
