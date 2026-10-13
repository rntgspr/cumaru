---
human_revised: false
summary: Universal Cumaru entry point with loading rules and framework navigation guidance.
targets: [meta]
depends-on: [domain.md]
---

> **Framework kernel — do not edit.** This file is byte-identical across domains and adopters' `.cumaru/` trees. Project-specific configuration lives in [`domain.md`](domain.md), declared as `depends-on` below.

# `.cumaru/`

Entry point for any LLM or human using this repository. **Identical across every domain**, this kernel comes from `__base`. Domain-specific pillars, roles, work entry, and project discipline live in [`domain.md`](domain.md), declared as this index's `depends-on` and loaded by the rule below.

## Loading rule

The LLM loads only what is **declared** — never by filesystem proximity. The schema declares contracts and semantic links; the filesystem supplies candidates through `cumaru tree`. Loading is a **guided traversal**, not a bulk read: the structure proposes candidates and the LLM prunes them by relevance to the task. The structure proposes; the LLM disposes.

**Bootstrap and priority.** Every context receives this kernel, `domain.md`,
`disciplines/index.md`, and every installed discipline before the root candidate
projection.

The discipline index defines required consideration: `strictness:` controls how
aggressively each `applies-when:` is evaluated; `applies-when:` controls
application, never loading. Apply every matching discipline.

Evaluate `cumaru-first` first whenever repository work could use Cumaru
navigation, workflows, semantic tags, coverage, health checks, lifecycle,
update, migration, or guarded `.cumaru/` operations. It chooses an existing
surface and creates no second loading mechanism.

1. **A role is on duty.** The role declares which directory index(es) enter context to begin. An index explains purpose and rules; drilling into candidates is a separate, deliberate act.
2. **The task fixes a subject.** Every prune below is judged against this subject and the context accumulated so far.
3. **Expand the current directory.** Read its `index.md`, run `cumaru tree <directory>`, and combine the resulting shallow candidates with fields and tags declared by the selected domain (for example `depends-on`, `relates`, or a vault graph field). Each candidate carries a one-line `summary:` and resolves to either another indexed directory or a leaf file.
4. **Prune by relevance** to the subject and the accumulated context — the LLM's judgment. `depends-on` is the strongest signal; `relates` is "consider".
5. **Load the survivors.** Prefer Cumaru commands for further discovery or section inspection, following the installed `cumaru-search` skill (for example `cumaru context` for ranking and `cumaru map` for headings). Read the selected Markdown bodies directly; ranking and heading output do not replace their content.
6. **Recurse.** Every surviving directory repeats from step 3, judged against the now-larger accumulated context.
7. **Terminate at a leaf.** A branch stops at a selected Markdown file whose declared semantic links add nothing relevant.

This split is the framework's core: traversal is **deterministic in structure** (schema contracts, filesystem candidates, and declared semantic links) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). `cumaru tree` expands a directory; pruning and recursion stay with the LLM.

**Role merging.** Step 1 of the traversal assumes *a* role is on duty. When the task needs capabilities the current role does not cover, prompt before expanding — never silently fail, never assume permission to merge.

## The model — one recursive node

The whole `.cumaru/` tree is described under `config.yaml`'s `root:` key. **`root` is the top node** (the `.cumaru/` directory itself); its children are the **pillars** (declared per domain). Every node shares one shape:

```
{ path?, optional?, framework?, frontmatter?, tags?, <selector>: <node>, ... }
```

- **`path`** — the node's dir/file, relative to its parent (implicit = the key).
- **`optional`** — `true` makes a literal entry optional; glob selectors may match no entries.
- **`framework`** — only explicit `true` marks an entry as framework-owned; ownership never inherits.
- **`frontmatter`** — field contracts for a file or a directory's `index.md`: `{}` requires presence; `{optional: true}` makes a field optional.
- **`tags`** — required semantic marker names for that host. Their bodies are adopter-owned; they express relations or durable records, never directory inventories.
- **Child selectors** — literal or glob keys declared directly inside the node, each mapping to another node. There is no `entities` wrapper.

A node's `index.md` states the directory's purpose and rules. The filesystem is the structural source of truth; `cumaru tree <directory>` is the shallow index and reads each candidate's `summary:` without loading its body.

## Domain definition

The pillars, roles, entry points, and domain conventions for this domain are declared in [`domain.md`](domain.md), pulled in as this index's `depends-on`. To build a new domain: declare your pillars as direct child keys under `config.yaml`'s `root`, create each `<pillar>/index.md`, write your `domain.md`, and run `cumaru doctor`.

## Project context

Adopter-specific context the LLM should keep in mind: stack, conventions not yet in pillar specs, key links, current focus, hard constraints. Edit the `<!-- cumaru:components -->` table and the `<!-- cumaru:root -->` block at the top of [`domain.md`](domain.md) — their bodies are preserved across `cumaru update`.

## The `cumaru` CLI

The CLI reads and mutates this tree. `tree` performs the expansion step above;
`fs` is the only sanctioned way to change what exists inside `.cumaru/`.
This table covers every dispatcher entry and supported help topic. Use the safe
reference route for its full current contract.

| Entry | Purpose | Safe reference route |
|---|---|---|
| `cumaru install` | Install one domain from main HEAD and one explicit agent adapter into a project; add opt-in skills later with `cumaru update skills <agent> --with <skill>`. | `cumaru install --help` |
| `cumaru uninstall` | Remove project installation and shared adapter artifacts with explicit confirmation. | `cumaru uninstall --help` |
| `cumaru doctor` | Offline validation of installed config, tree, tags, references, tools, agent instructions, and config drift; the default command. | `cumaru doctor --help` |
| `cumaru tag` | List, audit, read, or replace schema-declared semantic marker bodies. | `cumaru tag --help` |
| `cumaru coverage` | Report durable-specification references and uncovered repository source. | `cumaru coverage --help` |
| `cumaru tree` | List filesystem candidates and summaries without loading their bodies. | `cumaru tree --help` |
| `cumaru map` | List literal H1-H6 headings with `#` markers and source lines in a directory or exact Markdown file. | `cumaru map --help` |
| `cumaru context` | Offline, read-only ranking of visible `.cumaru/` Markdown against an English query as path/score TSV; uses a cached encoder when present, otherwise a lightweight fallback. Scores are uncalibrated. | `cumaru context --help` |
| `cumaru model` | List the closed model catalog or explicitly download a supported encoder to `~/.cumaru/<name>/`; never automatic. | `cumaru model --help` |
| `cumaru update` | Preview or apply framework-owned content and adapter artifact updates. | `cumaru update --help` |
| `cumaru upgrade` | Replace the global `cumaru` binary with the latest release; never for discovery or project update. Only `cumaru upgrade --check` is read-only, comparing the CLI build version with the latest release tag. | `cumaru upgrade --help` |
| `cumaru fs` | Create, move, copy, or remove paths inside `.cumaru/` under guardrails. | `cumaru fs --help` |
| `cumaru migrate` | Print the required direct migration instructions without writes. | `cumaru migrate --help` |
| `cumaru bootstrap` | Print post-install bootstrap steps for the installed domain without writes. | `cumaru bootstrap --help` |
| `cumaru version` | Read-only CLI build version; inside a project, also installed domain/config integer and latest config, status, and drift at main HEAD. | `cumaru version --help` |
| `cumaru help` | Show the top-level command catalog. | `cumaru help` |
| `cumaru help domains` | List installable domains; a help topic, not a `domains` subcommand. | `cumaru help domains` |

Domain skills are separate from CLI subcommands. A workflow such as
`cumaru-intake`, when shipped by the installed domain, is invoked through the
active agent's skill surface; `cumaru intake` is not a command.

`tree`, `map`, and `fs` take paths relative to `.cumaru/`; absolute paths and
`..` segments are refused. `tag` also accepts absolute paths and `.cumaru/`-prefixed
paths when contained in the current tree. `tree`, `map`, and `tag` refuse symlinks;
`fs` resolves symlinked roots and parents but refuses direct symlink targets and
paths escaping the tree. Consult each command's help for its full path contract.

```bash
# Navigate: start shallow, prune by summary, recurse only into survivors.
cumaru tree .                           # root candidates — the entry of every context
cumaru tree <pillar>/                   # expand one pillar
cumaru tree <pillar>/<entity>/          # expand a selected entity
cumaru tree <pillar>/ --deep            # audit a branch: missing indexes, invalid summaries
cumaru tree . --rows                    # path<TAB>summary, for piping

# Mutate: never create, move, or delete inside .cumaru/ by hand.
cumaru fs <pillar>/<entity>           create   # an entity directory
cumaru fs <pillar>/<entity>/index.md  create   # its index — required by every directory
cumaru fs <pillar>/<entity>/note.md   move     <pillar>/<other>/note.md
cumaru fs <pillar>/<entity>           remove   # the whole entity
```

`--deep` is for auditing, never for loading. `fs` refuses to remove an `index.md` or a pillar root; remove the entity's directory instead. After creating any Markdown file, give it a valid `summary:` — until then it is invisible to navigation and `cumaru doctor` fails.

## Advisor mode

Be a truthful, efficient advisor: prioritize accuracy, useful disagreement, concise communication, and concrete progress.

1. Start with the most useful answer or action. Do not open with praise, agreement, apology, or filler.
2. Directly explain flaws, gaps, or risky assumptions in the user's idea, including the reason for the objection.
3. If the idea is sound, say so briefly and take the next useful step.
4. Separate evidence from inference. Label uncertainty; never present guesses as facts.
5. Before deep execution, pause on conflicts with known facts, project constraints, or relevant public standards. State the conflict objectively, cite its source or origin when available, and offer clear options (A/B/C when useful), including discussion.
6. Make claims fact-checkable. For standards, external practices, APIs, legal/security claims, or benchmark-like statements, name the supporting source, spec, documentation, project file, or observed evidence. Disclose when no source was checked.
7. When disagreeing, offer a better alternative and its main risk or downside.
8. Keep replies as short as the task permits. Avoid restating the request, over-explaining, or optional detail unless it changes the decision.
9. Prefer execution for requested changes, fixes, verification, or concrete outcomes, unless item 5 applies.
10. If challenged, revise your position on new evidence; otherwise retain the assessment without repeating it.
11. Never invent objections just to be contrarian. No sarcasm.

## Sub-agent workspace

Explicitly assume sub-agents share the root agent's working directory and
filesystem. Use another working directory only at the user's explicit request.

## Language

All content authored under `.cumaru/` is written in **English** — indexes, specs, notes, roles, templates, frontmatter strings. Mirrored external content may keep its source language for fields copied verbatim; locally authored notes use English. The user-facing chat language is set by the active agent instructions or the system prompt, independent of this rule.
