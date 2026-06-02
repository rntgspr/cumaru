# Architecture — the kernel, the universal index, and flavors

## The loading rule is the kernel

The whole framework revolves around one rule: **load only what is declared, by a guided traversal of the node tree.** At each step the *structure* proposes candidates (the entries a node lists as children + the nodes in its `depends-on`/`relates`) and the *LLM* prunes them by relevance to the task subject and the context accumulated so far; the traversal recurses into surviving indexes and terminates at a leaf (a file with no `depends-on` and no child index).

This is **deterministic in structure** (what each node declares, and where a branch ends, is fixed) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). Tooling can *expand* a node — list its declared candidates, their subjects, and whether each is an index or a leaf — but the pruning and the recursion stay with the LLM.

## `index.md` is identical across every flavor

`.llm/index.md` is **byte-identical** in `__base` and in every flavor. It is the kernel, authored once in `frameworks/__base/index.md` and propagated verbatim to each `frameworks/<flavor>/index.md`. It carries no domain content — only the node model, the loading rule, conduct, and language.

- The loading-rule prose lives between `<!-- BEGIN/END __base:loading-rule -->` **plain HTML-comment sentinels** — deliberately **not** an `llm:` tag. Tag bodies are adopter-owned and never overwritten on update; this must be framework-owned prose that `llm update` carries from source.
- A drift-check (doctor / CI) should enforce that every flavor's `index.md` matches `__base`'s — see "Reuse" below.

## Flavor-specifics live in `domain.md`

Everything domain-specific — the pillars, the roles, the entry-point refinement, the domain context — lives in **`domain.md`**, declared as a `depends-on` of the root `index.md`. This dogfoods the loading rule: loading `index.md` surfaces `domain.md` as a candidate and pulls it in. Every flavor (including `__base`) ships this file so the dependency never dangles.

## Why prose, not tags — and why not symlinks

- **Tags won't work:** tag bodies are adopter data, never overwritten on `llm update`. The shared kernel must propagate framework → adopter, so it is prose, not a tag.
- **Symlinks won't work:** fragile on Windows (admin/Developer-Mode, `git core.symlinks`, editor breakage), and the adopter never receives `__base` (install copies only the chosen flavor), so a link would dangle.

## Reuse mechanism

Propagation is a **verbatim copy** of `__base/index.md` into each flavor plus a **deterministic drift-check** (doctor / CI) that fails when a flavor's `index.md` diverges from `__base`. The maintainer edits `__base`, re-copies, and the check guards against drift. (A build-time include was considered and set aside as more machinery for a marginal gain.)
