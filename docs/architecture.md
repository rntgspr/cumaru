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

Use `cumaru map <path>` when a selected area needs a quick level-two heading
map before its full Markdown bodies are loaded.

This is iterative search with an explicit stopping condition: stop when newly surfaced candidates add no relevant concern. It does not authorize a bulk read of the pillar.

## Universal artifacts are identical across every domain

Four artifact sets are **byte-identical** in `__base` and in every domain:

1. **`index.md`** — the framework kernel: node model, loading rule, conduct, language. Carries no domain content.
2. **`skills/cumaru-doctor/`, `skills/cumaru-update/`, `skills/cumaru-refs/`, `skills/cumaru-summarize/`, `skills/cumaru-role/`, `skills/cumaru-resolve/`** — universal multi-step orchestration; same SKILL.md across all domains. (`skills/cumaru-install/` is deliberately **domain-owned**: its post-install recipe hands off to the domain's durable-pillar skill — `cumaru-specs` / `cumaru-topology` / `cumaru-coverage` — so each domain ships its own tuned copy and the drift-check skips it.)
3. **`commands/cumaru/doctor.md`, `commands/cumaru/update.md`, `commands/cumaru/resolve.md`, `commands/cumaru/refs.md`, `commands/cumaru/summarize.md`, `commands/cumaru/role.md`** — universal launchers with no domain-specific recipe content.
4. **Universal `disciplines/*.md` files** — eagerly delivered execution rules, excluding the domain-owned `disciplines/index.md`.

All four are authored once in `domains/__base/` and propagated verbatim into every `domains/<domain>/`. Domain-specific content (its pillars, roles, additional skills, additional slash commands, and discipline index) lives only in the domain.

Every slash command has a namesake `cumaru-<name>` skill in the same domain.
The command forwards `$ARGUMENTS` before requesting that skill and carries no
recipe of its own. Domain validation rejects a missing namesake skill before
adapter artifacts are written.

- The kernel `index.md` carries a blockquote header at the top stating that the file is framework-owned and must not be edited. The whole file (loading rule, conduct, language, etc.) is plain prose — outside any `<!-- cumaru:NAME -->` tag — so `cumaru update` carries it from source. Adopter-owned blocks (`components`, `root`) live in `domain.md`, where the tag-body preservation rule protects them.
- A drift-check enforces that every domain's universal artifacts match `__base`'s. It runs in the **install script** (`cumaru upgrade` re-runs it): a snapshot where any domain diverges is refused. It is deliberately NOT a `cumaru doctor` check — doctor audits the **adopter's** tree, which never contains `__base` to compare against. See "Reuse" below.

### Tag preservation boundary

Tags are the adopter-owned islands inside framework-owned Markdown. `cumaru
update` validates source and local tag structure with the same balanced parser
used by `cumaru tag`, rebuilds outside-tag content from source, and restores each
local top-level body by canonical name. Local-only tags survive as orphans;
source-only tags retain their canonical scaffold. Missing exact closers and
crossing tags fail closed before replacement.

Frontmatter and all prose outside tags are framework-owned and come from the
canonical source. Adopter prose survives only inside tag bodies; source-only tag
scaffolds retain their canonical placement and content.

Balanced nesting is supported with stack semantics: a nested tag remains
independently addressable and remains part of its outer body. Duplicate
top-level tags are folded deterministically at their first occurrence. Schema
host/type declarations affect interpretation, not preservation, so an unknown
or moved body is reported for adjudication rather than discarded.

## Domain specifics live in `domain.md`

Everything domain-specific — the pillars, the roles, the entry-point refinement, the domain context — lives in **`domain.md`**, declared as a `depends-on` of the root `index.md`. This dogfoods the loading rule: loading `index.md` surfaces `domain.md` as a candidate and pulls it in. Every domain (including `__base`) ships this file so the dependency never dangles.

Every domain `config.yaml` and adopter `.cumaru/config.yaml` follows the single
project-wide Draft 2020-12 model at `schemas/config.schema.json`. Cumaru's
`jq` runtime validator enforces its operational structural subset plus semantic
cross-field checks before install, doctor, and update. Known objects are closed;
recursive `root.entities` remains the structural extension point. Domain configs
provide initial values; adopter configs preserve every valid local value while
unknown properties are rejected or removed during reconciliation. No hidden
baseline state is installed.

Execution disciplines are the deliberate eager exception to relevance-pruned
traversal. Every installed `disciplines/*.md` file enters the initial context,
with `disciplines/index.md` first as the evaluation contract. `strictness:`
controls how aggressively the agent must consider a discipline; `applies-when:`
decides when its rules bind. Every discipline must declare a value from `0/10`
through `10/10`; a missing value is invalid and treated as `0/10`. Adapter
wiring derives this set from the installed domain, so domains may add
disciplines without changing the kernel. The universal `cumaru-first`
discipline is evaluated first: when a task has a relevant Cumaru surface, it
selects the matching command, skill, role, or domain workflow.

### Lifecycle flow

Every domain (except `__base`) includes a flow diagram under `## Flow` or `## Lifecycle` showing how work moves through its pillars. ASCII is the portable default; Mermaid is appropriate when the rendered Markdown surface supports it. The canonical pattern:

- **Transient pillars** (`intake/`, `exploring/`, `plans/`, `archive/`) feed into one another and are **removed after absorb** — only the durable pillar (`specs/`, `topology/`, `coverage/`) retains the absorbed knowledge.
- The diagram makes the cleanup explicit: "After absorb: archive/, plans/, exploring/, and intake/ entries related to the closed plan are removed (transient cleanup)."

## Why prose, not tags — and why not symlinks

- **Tags won't work:** tag bodies are adopter data, never overwritten on `cumaru update`. The shared kernel must propagate framework → adopter, so it is prose, not a tag.
- **Symlinks won't work:** fragile on Windows (admin/Developer-Mode, `git core.symlinks`, editor breakage), and the adopter never receives `__base` (install copies only the chosen domain), so a link would dangle.

## Reuse mechanism

Propagation is a **verbatim copy** of every universal file under `__base/{index.md, skills/, commands/, disciplines/}` into each domain, plus a **deterministic drift-check** (`cmp` per file in the install script) that aborts the install when any domain's universal artifact diverges from `__base`. The `cumaru-install` skill and `disciplines/index.md` are exempt (domain-owned). Maintainers edit `__base`, preview with `scripts/sync-domain-kernel.sh` (or explicit `--check`), then run `scripts/sync-domain-kernel.sh --apply`. (A build-time include was considered and set aside as more machinery for a marginal gain.)
