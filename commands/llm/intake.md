---
description: Run `llm intake <KEY>` to mirror a Jira issue under `.llm/intake/`, then refine the generated file per the embedded JIRA-RAW instructions (Overview, EARS criteria, apps, bug sections) before deleting the block.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <JIRA-KEY>
---

Argument: `$ARGUMENTS` is the Jira key (e.g. `JET-1234`). If empty, ask the user for it before doing anything.

1. **Fetch and mirror.** Run `llm intake $ARGUMENTS`. Capture stdout — the last `✓ created <path>` or `✓ refreshed <path>` line gives the file you will refine. If the CLI fails (missing env vars, HTTP error, etc.), surface the message verbatim and stop.

2. **Decide whether refinement is needed.**
   - Read the resulting file. Locate the `<!-- BEGIN JIRA-RAW ... END JIRA-RAW -->` block.
   - If the block is **absent**, the file has already been refined in a previous pass. Report this to the user and exit — do not re-edit body content (the CLI does not re-inject the block on re-sync once it has been removed).
   - If the block is **present**, continue.

3. **Read the embedded instructions.** The block carries an `INSTRUCTION FOR LLM:` section tailored to the issuetype (Epic / Story / Ticket-or-bug). It enumerates exactly which sections to refine, plus the `JIRA SOURCE:` (Title, Type, Status, Description). Treat this list as the authoritative checklist for this run.

4. **Synthesize and confirm scope.** Print a one-paragraph summary: issuetype, status, the section list you will refine, and the proposed `apps:` value (see step 6). Ask the user `walk` (refine each section with confirmation) or `skip` (leave the file as-is and exit).

5. **Walk the refinement, section by section.** Apply the edits to the *body above* the JIRA-RAW block. Do not touch frontmatter `status:` or `synced-at:` — the CLI manages those.

   Per section, propose the new content, show a diff against the placeholder, and apply only after confirmation:

   - **`## Overview`** — 1–3 paragraphs in **English**, restating what is being asked and *why it matters*. Derive strictly from the `JIRA SOURCE` Description; if the source is in another language, translate. Do not invent context the source does not support; if the description is thin, say so and ask the user to fill the gap rather than padding.
   - **`## Acceptance Criteria (EARS)`** — bullets in the form `WHEN <trigger> THE SYSTEM SHALL <observable response>` (also `WHEN <trigger> AND <condition>` and `WHILE <state>`). Extract from explicit AC in the description when present; otherwise propose criteria derived from the Overview and ask the user to confirm/edit. **Every bullet must conform to the EARS pattern — `llm doctor` flags non-conforming bullets as a warning.**
   - **Bug-only sections** (`## Reproduction`, `## Expected`, `## Actual`) — only if `type: bug` in the frontmatter. Fill from the description; if the description does not separate these, ask the user. **If `type` is anything other than `bug`, delete these three sections entirely along with the surrounding `<!-- ===== Bug-only sections =====` / `<!-- ===== End bug-only sections =====` HTML comments** — the ticket template carries them as scaffolding that becomes noise when not applicable.
   - **Epic exception** — Epics get `## Overview` only (no AC, no bug sections), per the template.

6. **Set `apps:` in the frontmatter.** Read `.llm/schema.yaml` `apps.values` for the project's valid component keys. Propose the smallest set that covers the work described (single-component plans use one entry; multi-component lists each explicitly). Confirm with the user before editing; never write an `apps:` value that is not in `schema.yaml apps.values` (`llm doctor` will error on it).

   **If no value in `apps.values` matches the ticket** (e.g. the project still has only the reserved `platform`/`meta` and never declared its own components, or the work touches a component not yet listed), **leave `apps: []`** and tell the user: "the schema does not yet have a value that fits this ticket — populate `.llm/schema.yaml` under `apps.values` with the component(s) for this project, then re-run `/llm:intake $ARGUMENTS` (or edit `apps:` by hand)." Do not invent a value, do not fall back to `platform` unless the ticket genuinely is cross-component infrastructure, and do not stop the rest of the refinement over this — the block deletion and other sections proceed regardless.

7. **Drop the JIRA-RAW block.** Once every section in step 5 and the `apps:` field in step 6 are applied and confirmed, remove the entire `<!-- BEGIN JIRA-RAW ... END JIRA-RAW -->` block (including the blank line above it that the CLI inserted). This signals to future `llm intake $ARGUMENTS` re-syncs that the file is refined — only `status:` and `synced-at:` will be touched after this.

8. **Close out.** Print the final path and run `llm doctor` against the same `DOT_LLM_DIR`. If a new entry was created, doctor's shallow-index drift check will flag `intake/index.md` and emit `→ Run: llm regen index` — that regen is **delegated to the user / next `/llm:doctor` run**, not chained here, so the intake refinement stays focused on body content. Report: refinement complete, EARS warnings (none expected), `apps:` value applied (or the blocker noted in step 6), drift state if any, and doctor totals.

Hard rules:

- Never modify `status:` or `synced-at:` in frontmatter — the CLI owns those.
- Never write an `apps:` value not present in `.llm/schema.yaml` `apps.values`.
- Every bullet under `## Acceptance Criteria (EARS)` must match `WHEN .+ THE SYSTEM SHALL .+` (or `WHILE .+ SHALL .+`); incomplete bullets get reworded with the user, not left as-is.
- If the JIRA-RAW block is already gone, exit without editing the body — re-syncing a refined file is a no-op by design.
- Do not invent acceptance criteria the Jira source does not support; surface gaps and ask.
