---
version: 1
description: Run `cumaru intake <KEY>` to mirror a tracker issue under `.cumaru/intake/<KEY>/`, then refine the generated file per the embedded RAW instructions (Overview, EARS / RFC 2119 criteria, apps=environments, bug sections) before deleting the block.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <TRACKER-KEY>
summary: Run `cumaru intake <KEY>` to mirror a tracker issue under `.cumaru/intake/<KEY>/`, then refine the generated file per the embedded RAW instructions (Overview, EARS / RFC 2119 criteria, apps=environments, bug sections) before deleting the block.
---

Argument: `$ARGUMENTS` is the tracker key (e.g. `AAA-1234`). If empty, ask the user for it before doing anything.

1. **Fetch and mirror.** Run `cumaru intake $ARGUMENTS`. Capture stdout — the last `✓ created <path>` or `✓ refreshed <path>` line gives the file you will refine. If the CLI fails (missing env vars, HTTP error, etc.), surface the message verbatim and stop.

2. **Decide whether refinement is needed.**
   - Read the resulting file. Locate the `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block.
   - If the block is **absent**, the file has already been refined in a previous pass. Report this to the user and exit — do not re-edit body content (the CLI does not re-inject the block on re-sync once it has been removed).
   - If the block is **present**, continue.

3. **Read the embedded instructions.** The block carries an `INSTRUCTION FOR LLM:` section tailored to the issuetype (Epic / Story / Ticket-or-bug). It enumerates exactly which sections to refine, plus the source data (Title, Type, Status, Description). Treat this list as the authoritative checklist for this run.

4. **Synthesize and confirm scope.** Print a one-paragraph summary: issuetype, status, the section list you will refine, and the proposed `apps:` value (see step 6 — for iac, apps enumerates target environments). Ask the user `walk` (refine each section with confirmation) or `skip` (leave the file as-is and exit).

5. **Walk the refinement, section by section.** Apply the edits to the *body above* the RAW block. Do not touch frontmatter `status:` or `synced-at:` — the CLI manages those.

   Per section, propose the new content, show a diff against the placeholder, and apply only after confirmation:

   - **`## Overview`** — 1–3 paragraphs in **English**, restating what is being asked and *why it matters*. Derive strictly from the source Description; if the source is in another language, translate. Do not invent context the source does not support; if the description is thin, say so and ask the user to fill the gap rather than padding.
   - **`## Acceptance Criteria (EARS / RFC 2119)`** — bullets in EARS form (`WHEN <trigger> THE SYSTEM SHALL <observable response>`) or RFC 2119 form (`The system MUST <behavior>`). For infra: criteria often reference observable states (the stack exists in `<env>`, the apply diff is empty, outputs match), not user-facing behavior. Extract from explicit AC when present; otherwise propose criteria derived from the Overview and ask the user to confirm/edit. **Every bullet must conform to the requirements-language pattern (EARS or RFC 2119) — `cumaru doctor` flags non-conforming bullets as a warning.**
   - **Bug-only sections** (`## Reproduction`, `## Expected`, `## Actual`) — only if `type: bug`. For infra bugs, Reproduction is often "apply the current HCL/manifest in <env>" and Expected/Actual describes what the apply produces vs. what it should. **If `type` is anything other than `bug`, delete these three sections entirely along with the surrounding `<!-- ===== Bug-only sections =====` / `<!-- ===== End bug-only sections =====` HTML comments.**
   - **Epic exception** — Epics get `## Overview` only.

6. **Set `apps:` in the frontmatter (environments).** Read `.cumaru/schema.yaml` `meta.apps.values` for the project's declared environments (typically `dev`, `staging`, `prod`, plus `all` for cross-env and `meta` reserved). Propose the smallest set that covers the work: a single-env change uses one entry; a promotion path lists each environment explicitly; cross-env work (shared modules, IAM, baselines) uses `all`. Confirm with the user before editing; never write an `apps:` value that is not in `meta.apps.values` (`cumaru doctor` will error on it).

   **If no value in `meta.apps.values` matches the ticket**, **leave `apps: []`** and tell the user: "the schema does not yet have an environment value that fits this ticket — populate `.cumaru/schema.yaml` under `meta.apps.values` with the environment(s) for this project, then re-run `/cumaru:intake $ARGUMENTS` (or edit `apps:` by hand)." Do not invent values; do not stop the rest of the refinement over this — the block deletion and other sections proceed regardless.

7. **Drop the RAW block.** Once every section in step 5 and the `apps:` field in step 6 are applied and confirmed, remove the entire `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block (including the blank line above it that the CLI inserted).

8. **Set the summary and verify navigation.** Ensure the new `intake/<KEY>/index.md` has a valid, stable `summary:`. Do not add an intake table row: run `cumaru tree intake` to verify that the filesystem projection discovers it.

9. **Close out.** Print the final path and run `cumaru doctor`. Report: refinement complete, requirements-language warnings (none expected), `apps:` value applied (or the blocker noted in step 6), and doctor totals.

Hard rules:

- Never modify `status:` or `synced-at:` in frontmatter — the CLI owns those.
- Never write an `apps:` value not present in `.cumaru/schema.yaml` `meta.apps.values`.
- Every bullet under `## Acceptance Criteria (EARS / RFC 2119)` must match EARS or RFC 2119; incomplete bullets get reworded with the user, not left as-is.
- If the RAW block is already gone, exit without editing the body — re-syncing a refined file is a no-op by design.
- Do not invent acceptance criteria the tracker source does not support; surface gaps and ask.
- For infra work, `apps:` = environments (where the change applies / has applied), NOT components.
