---
human_revised: false
apps: [meta]
summary: Framework guidance for Vault Memory domain and its required workflow.
---

<!-- cumaru:components -->
| Link | Description |
|------|-------------|
_(replace with memory domains, vault folders, or important external collections)_
<!-- /cumaru:components -->

<!-- cumaru:root -->
_(empty - replace with adopter-specific context for this vault)_
<!-- /cumaru:root -->

# Vault Memory domain

This domain turns loose captured material, rough drafts, and durable memory
nodes into a typed graph. It is designed for personal or team vaults where raw
inputs are processed by an LLM and only distilled, useful knowledge survives as
permanent memory.

## Pillars

```
.cumaru/
├── index.md       <- kernel (identical across domains)
├── schema.yaml    <- canonical contract
├── domain.md      <- this file
├── inbox/         <- raw captured material; transient by default
├── drafts/        <- working notes and guided rough thinking
├── memories/      <- durable graph-shaped memory nodes
├── attachments/   <- retained source files that should outlive inbox cleanup
├── roles/         <- agent roles
└── templates/     <- entity templates
```

- **`inbox/`** holds raw captures: pasted text, URLs, PDFs, images, audio notes,
  or any other input. A capture is processed into a draft, a memory, an
  attachment, or rejected; processed captures are removed by default.
- **`drafts/`** holds rough thinking that may or may not become memory. Drafts
  are durable enough to revisit, but they are not agent memory yet.
- **`memories/`** holds canonical memory nodes. Each node has a concise
  statement, optional notes, typed frontmatter relationships, and a `relations`
  table for graph traversal.
- **`attachments/`** holds retained evidence files. Use it only when a source
  file needs to outlive the transient inbox.

## Flow

```
inbox/ -> drafts/ -> memories/
   |         |          ^
   |         +----------+
   +-> attachments/ when source files must be retained
```

The default lifecycle is capture, distill, link, then clean up. The durable
memory should be self-contained. Raw inbox material is not archival storage.

## Memory Graph

Graph edges live in frontmatter so they are machine-readable:

- `relates` - broad connection.
- `supports` - strengthens or evidences another node.
- `contradicts` - conflicts with another node.
- `supersedes` / `superseded-by` - replacement relationship.
- `part-of` - hierarchy or containment.
- `similar-to` - near duplicate or adjacent concept.
- `derived-from` - capture, draft, URL, or retained attachment used to create
  the memory.

The optional `<!-- cumaru:relations -->` table mirrors the most important graph
edges for humans and LLM traversal.

## Roles

- **Keeper** - maintains the vault memory graph. Reads and writes every pillar,
  distills captures and drafts, links memories, and prunes processed inbox
  entries with user confirmation.

### Shallow indexes per role

| Role | Shallow indexes loaded |
|---|---|
| Keeper | `inbox/index.md`, `drafts/index.md`, `memories/index.md`, `attachments/index.md` |

## Domain Context

This domain is not an Obsidian clone and does not try to index everything by
default. Tags, paths, frontmatter, and relation tables are the first retrieval
layer. Embeddings or web search may rank candidates after structural filtering,
but permanent memory remains explicit, typed, and reviewable.
