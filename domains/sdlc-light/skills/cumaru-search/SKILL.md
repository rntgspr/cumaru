---
human_revised: false
version: 1
name: cumaru-search
description: Discover relevant knowledge in a project's .cumaru/ when the task needs it and the owning file is unknown. Route conceptual queries, structural navigation, and exact-term searches, then read selected evidence. Known file paths can be read directly; source-code search stays with normal repository tools.
summary: Discover relevant Cumaru knowledge through conceptual ranking, bounded tree navigation, or exact-term search, then verify selected file contents.
---

# Discover Cumaru knowledge

Use the current project's `.cumaru/` after its normal bootstrap. This workflow
is read-only and applies across domains; use the installed domain's pillars
and semantic links rather than assuming a `specs/` directory.

## Choose the discovery route

| Task signal | First action |
|---|---|
| Conceptual question or unclear location, without an exact search term | Run `cumaru context "<concise English query>"` before broad Markdown searches. Translate the intent when needed, keeping exact identifiers intact. |
| Known area, or a need to inspect the knowledge structure | Run `cumaru tree <area>` and select candidates by summary; recurse only into relevant directories. |
| Exact identifier or literal phrase | Run `rg -n -F -- "<term>" .cumaru` and inspect the matching hosts. |
| Known file | Read it directly; discovery is unnecessary. |

## Select and verify

1. Inspect the returned paths and signals. For `context`, start with the most
   promising ranked candidates. Scores are experimental and backend-specific;
   no score threshold proves relevance or absence of knowledge.
2. Read selected files to verify that their contents answer the task. Use
   `cumaru map <path>` when a large host needs a heading map first. Follow only
   relevant domain-declared links and keep any active plan's context boundaries.
3. If the contents do not answer the question, refine the query or switch to
   bounded tree or exact-term discovery. The lightweight fallback can miss
   paraphrases; a weak ranking is not proof that no relevant file exists.
4. Stop when the evidence answers the task or further candidates add no relevant
   information. Report the supporting paths and remaining gaps; do not load the
   entire tree or every ranked body.

Report command errors and partial results explicitly. A present invalid encoder
is an error, not permission to remove it or silently change the backend. Model
downloads require their own user authorization; search never installs models.
Use `cumaru help <command>` for CLI details. Source-code inspection and subsequent
edits remain with the task's normal tools and domain workflow.
