---
name: cumaru-universal-index-and-loading-rule
description: "Architectural decision (2026-06) — .cumaru/index.md is byte-identical across __base and ALL domains, sourced from __base; the Loading rule is the framework's kernel; domain-specifics live in domain.md declared as the index's depends-on"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d88e8ee-b4c0-424c-a232-9bc7450ca78e
---

> V6 keeps the byte-identical kernel but changes expansion: the filesystem
> supplies candidates through `cumaru tree`, while tags carry only semantic
> relations and durable records. See [[v6_virtual_tree]].

Decided **2026-06-03** with Renato. This is the load-bearing architecture of the whole repo.

**`.cumaru/index.md` is byte-identical across `__base` and EVERY domain**, sourced from `__base/index.md`. Domains do NOT carry their own index prose. Propagation = copy the whole file `__base/index.md` → each `frameworks/<domain>/index.md`, plus a deterministic **drift-check** (doctor / CI) that they always match. (Reuse mechanism leaning to verbatim-copy + check; build-time include was the alternative, set aside.)

**The Loading rule is the kernel — the entire project revolves around it.** In v6, loading is a guided traversal: read the current directory's `index.md`, use `cumaru tree` to project filesystem candidates, prune them by `summary:` and task relevance, then follow selected semantic `depends-on` and `relates` links. Structure is deterministic on disk; selection remains judgment-driven. `--pillars` can bound root navigation and `--domain` can guard the installed contract.

It lives in `__base/index.md` between `<!-- BEGIN/END __base:loading-rule -->` **plain HTML-comment sentinels** — deliberately NOT an `cumaru:` tag, because tag bodies are adopter-owned and never overwritten on update (see [[cumaru-update-and-doctor-design-principles]]); this must be **framework-owned prose** that `cumaru update` carries from source. Must stay **domain-neutral** — the framework is for ANY domain (research, design, ops, legal…), not only code.

**`depends-on` semantics changed:** from "hard MUST-load, pull the full closure" to **"strongest candidate signal, still prunable by relevance"**. `relates` = "consider". (Confirmed via Renato's described algorithm; encoded in the canonical text.)

**Domain-specifics live in `domain.md`** (named `domain.md`, chosen by Renato 2026-06-03; the file sits at the domain root, sibling of index.md — not in a `root/` subdir), declared as a `depends-on` of the root `index.md`. It carries: the domain's pillars, roles, entry-point refinement (e.g. sdlc's plan `scope:` entry), and domain context. The universal entry is *role → shallow indexes + task subject*; plan-`scope:` is an sdlc refinement that lives in its `domain.md`, not in the kernel.

**Why not a symlink:** Windows fragility (admin/Dev-Mode, git core.symlinks, editor breakage) AND the adopter never receives `__base` (install copies only the chosen domain) → a link would dangle.

**How to apply:** edit `__base/index.md` and propagate verbatim to every domain; never put domain-specifics in `index.md` (they go in `domain.md`); keep the loading rule domain-neutral and unchanged unless Renato approves. Add a drift-check so domain index.md ≠ __base fails. See [[cumaru-frameworks-layout]], [[v4_model]].
