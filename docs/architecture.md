# Architecture — the kernel, the universal index, and domains

## The loading rule is the kernel

The whole framework revolves around one rule: **load only what is declared, by a guided traversal of the node tree.** At each step the *structure* proposes candidates (the entries a node lists as children + the nodes in its `depends-on`/`relates`) and the *LLM* prunes them by relevance to the task subject and the context accumulated so far; the traversal recurses into surviving indexes and terminates at a leaf (a file with no `depends-on` and no child index).

This is **deterministic in structure** (what each node declares, and where a branch ends, is fixed) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). Tooling can *expand* a node — list its declared candidates, their subjects, and whether each is an index or a leaf — but the pruning and the recursion stay with the LLM.

## Universal artifacts are identical across every domain

Four artifact sets are **byte-identical** in `__base` and in every domain:

1. **`index.md`** — the framework kernel: node model, loading rule, conduct, language. Carries no domain content.
2. **`skills/cumaru-doctor/`, `skills/cumaru-update/`, `skills/cumaru-refs/`** — universal multi-step orchestration; same SKILL.md across all domains. (`skills/cumaru-install/` is deliberately **domain-owned**: its post-install recipe hands off to the domain's durable-pillar skill — `cumaru-specs` / `cumaru-topology` / `cumaru-coverage` — so each domain ships its own tuned copy and the drift-check skips it.)
3. **`hooks/context-loader.sh`** — universal prompt-submit context loader; same script across all domains.
4. **`commands/cumaru/doctor.md`, `commands/cumaru/update.md`, `commands/cumaru/resolve.md`, `commands/cumaru/refs.md`** — pure mechanics, no domain-specific recipe content.

All four are authored once in `frameworks/__base/` and propagated verbatim into every `frameworks/<domain>/`. Domain-specific content (its pillars, roles, additional skills, additional slash commands) lives only in the domain.

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

Propagation is a **verbatim copy** of every file under `__base/{index.md, skills/, hooks/, commands/}` into each domain, plus a **deterministic drift-check** (`cmp` per file in the install script) that aborts the install when any domain's universal artifact diverges from `__base`. The maintainer edits `__base`, re-copies into the domains, and the check guards against shipping a drifted snapshot. (A build-time include was considered and set aside as more machinery for a marginal gain.)
