---
human_revised: false
version: 1
name: cumaru-capture
description: "Use this skill whenever the user wants to capture raw material into inbox: a URL, webpage, PDF, image, audio file, pasted text, or any temporary source that may later become draft or memory."
summary: Framework guidance for `cumaru-capture` - create inbox captures and its required workflow.
---

# `cumaru-capture` - create inbox captures

Load `.cumaru/roles/keeper.md` and `inbox/index.md` before using invocation
arguments to create or refine a capture.

Captures are raw inputs. They are temporary by default and should be distilled,
retained as attachments, or deleted.

## Recipe: create a capture

1. Decide a short kebab-case `<capture-id>`, usually date-prefixed.
2. Create `inbox/<capture-id>/index.md` from `templates/capture.md`.
3. Set frontmatter:
   - `type: <free string>` such as `url`, `webpage`, `pdf`, `image`, `audio`,
     `text`, or `mixed`
   - `captured-at`
   - `last_update`
   - `summary`
   - `source`
   - `attachments` when local files exist
   - `topics`
4. Put pasted text or extracted notes in the body.
5. Set the capture `summary:`, then run `cumaru tree inbox --rows` and `cumaru doctor`.
6. Run `cumaru doctor`.

## Recipe: bulk capture a document

Use for whole documents (handbooks, policies, wikis) that will yield many
memories.

1. Store the source document under `attachments/<slug>/` from
   `templates/attachment.md`, with `retained-for` naming the bulk ingest; it
   must outlive inbox cleanup.
2. Run `cumaru map attachments/<slug>` to list its sections and line ranges.
3. Create one capture per section that holds durable content, with
   `attachments` pointing at `attachments/<slug>/index.md:<start>,<end>`.
4. Distill section by section with `cumaru-distill`, so each memory's
   `derived-from` points at its exact span and each section runs the
   search-before-write step.
5. Run `cumaru doctor`.

## What this skill does NOT do

- Distill permanent memory - use `cumaru-distill`.
- Preserve source files after processing - move them under `attachments/` first.

## Patterns

| User says | You do |
|---|---|
| "capture this URL" | Create an inbox capture with `type: url` |
| "save this PDF for processing" | Create an inbox capture and list the file in `attachments` |
| "ingest the company handbook" | Bulk capture recipe |
