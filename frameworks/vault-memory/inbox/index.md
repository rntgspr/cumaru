---
human_revised: false
generated: true
generated-at: 2026-07-05T00:00:00Z
apps: [meta]
---

<!-- cumaru:inbox -->
| Link | Description |
|------|-------------|

_No captures yet. Each row links to `inbox/<capture-id>/index.md` with a one-line description of the raw input._
<!-- /cumaru:inbox -->

# Inbox

Raw captured material waiting for processing. A capture can be a URL, PDF,
image, audio file, pasted text, or any other source.

## Rules

- **One directory per capture.** Use `inbox/<capture-id>/index.md`.
- **Inbox is transient.** After processing, the capture is removed unless the
  user asks to keep it.
- **Do not treat raw input as memory.** Distill useful content into `drafts/`,
  `memories/`, or `attachments/`.
- **Keep source pointers explicit.** Use `source` and `attachments`
  frontmatter when relevant.

## When to use

- Capturing a webpage, PDF, file, image, audio note, or pasted text before
  deciding what it means.
- Holding temporary material for `cumaru-distill`.

## When NOT to use

- Rough thinking you want to keep working on -> `drafts/`.
- Permanent memory -> `memories/`.
- Retained source files -> `attachments/`.
