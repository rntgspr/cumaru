---
version: 1
description: Run `cumaru intake <KEY>` to mirror a tracker issue under `.cumaru/intake/<KEY>/`, then refine the generated file per the embedded RAW instructions (Overview, EARS / RFC 2119 criteria, apps=test levels, bug sections) before deleting the block.
allowed-tools: Bash, Read, Edit, Write
argument-hint: <TRACKER-KEY>
summary: Run `cumaru intake <KEY>` to mirror a tracker issue under `.cumaru/intake/<KEY>/`, then refine the generated file per the embedded RAW instructions (Overview, EARS / RFC 2119 criteria, apps=test levels, bug sections) before deleting the block.
---

Argument: `$ARGUMENTS` is the tracker key (e.g. `AAA-1234`). If empty, ask the user for it before doing anything.

1. **Fetch and mirror.** Run `cumaru intake $ARGUMENTS`. Capture stdout — the last `✓ created <path>` or `✓ refreshed <path>` line gives the file you will refine. If the CLI fails (missing env vars, HTTP error, etc.), surface the message verbatim and stop.

2. **Decide whether refinement is needed.**
   - Read the resulting file. Locate the `<!-- BEGIN RAW (tracker: <name>) ... END RAW -->` block.
   - If the block is **absent**, the file has already been refined in a previous pass. Report this to the user and exit — do not re-edit body content.
   - If the block is **present**, continue.

3. **Read the embedded instructions.** The block carries an `INSTRUCTION FOR LLM:` section tailored to the issuetype (Epic / Story / Ticket-or-bug). Treat its list as the authoritative checklist.

4. **Synthesize and confirm scope.** Print a one-paragraph summary: issuetype, status, the section list you will refine, and the proposed `apps:` value (see step 6 — for qa, apps enumerates target test levels). Ask `walk` (refine each section with confirmation) or `skip`.

5. **Walk the refinement, section by section.** Apply edits to the *body above* the RAW block. Don't touch frontmatter `status:` or `synced-at:`.

   - **`## Overview`** — 1–3 paragraphs in **English**, restating what is being asked and *why it matters*. Derive strictly from the source; translate if needed. Don't pad.
   - **`## Acceptance Criteria (EARS / RFC 2119)`** — bullets in EARS form (`WHEN <trigger> THE SYSTEM SHALL <observable response>`) or RFC 2119 form (`The system MUST <behavior>`). For qa, the response is an observable test outcome (the case asserts X, the suite covers level Y, the flake rate falls below Z). **Every bullet must conform to the requirements-language pattern (EARS or RFC 2119) — `cumaru doctor` flags non-conforming bullets as a warning.**
   - **Bug-only sections** (`## Reproduction`, `## Expected`, `## Actual`) — only if `type: bug`. For test-bench bugs, fill from the failure mode. **If `type` is not `bug`, delete these three sections and the surrounding bug-only HTML comments.**
   - **Epic exception** — Epics get `## Overview` only.

6. **Set `apps:` in the frontmatter (test levels).** Read `.cumaru/schema.yaml` `meta.apps.values` for the project's declared test levels (typically `unit`, `integration`, `e2e`, `contract`, plus `all` for cross-level and `meta` reserved). Propose the smallest set that covers the work; favor the pyramid (justify any e2e that a lower level could catch). Confirm before editing; never write an `apps:` value not in `meta.apps.values`.

   **If no value matches**, **leave `apps: []`** and tell the user: "the schema does not yet have a test-level value that fits this ticket — populate `.cumaru/schema.yaml` under `meta.apps.values`, then re-run `/cumaru:intake $ARGUMENTS` (or edit `apps:` by hand)."

7. **Drop the RAW block.** Remove the entire `<!-- BEGIN RAW … END RAW -->` block (plus the blank line above it).

8. **Set the summary and verify navigation.** Ensure the new `intake/<KEY>/index.md` has a valid, stable `summary:`. Do not add an intake table row: run `cumaru tree intake` to verify that the filesystem projection discovers it.

9. **Close out.** Print the final path and run `cumaru doctor`. Report refinement status, requirements-language warnings, the `apps:` value applied (or the blocker noted in step 6), and doctor totals.

Hard rules:

- Never modify `status:` or `synced-at:` — the CLI owns those.
- Never write an `apps:` value not in `meta.apps.values`.
- Every requirements bullet must match EARS or RFC 2119; reword incomplete bullets with the user, don't leave them.
- If the RAW block is gone, exit without editing — re-syncing a refined file is a no-op by design.
- For qa work, `apps:` = test levels (where coverage lands), NOT components.
