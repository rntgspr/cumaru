---
version: 1
description: Run `cumaru doctor`, synthesize the findings, and offer to remediate each error/warning before touching anything.
allowed-tools: Bash, Read, Edit, Write
---

Run `cumaru doctor`. Read its output:

- The orchestrator emits one line per check: `[✓]` pass, `[⚠]` warning, `[✗]` error. Some lines carry a `→` hint with the recommended next action.
- The `Summary: N error(s), M warning(s), K ok` line at the end gives the totals. Exit code is non-zero iff there is at least one error.

Then:

1. **Synthesize a one-paragraph summary for the user** — totals, then list errors first and warnings second, grouped by check (schema conformance / orphan rows & files / stale work-marker files / unrefined RAW blocks / file refs / external tools). Mention any `→` hints verbatim, since each is a known remediation path.
2. **Ask the user how to proceed**, offering:
   - `fix-all` — walk the findings top-down and propose a concrete fix for each (see remediation map below). Apply each fix only after the user confirms it.
   - `walk` — pick one finding at a time; for each, propose the fix and confirm before applying.
   - `skip` — do nothing; report and exit.
3. **Act on the answer**, applying fixes in order. After all fixes (or on `skip`), re-run `cumaru doctor` and report the new totals so the user sees the delta.

Do not apply any fix without explicit confirmation from the user. Errors block exit 0; warnings do not — surface that distinction when proposing what to fix first.

Remediation map (per finding):

- **Schema: missing frontmatter keys** → Read the file, add the missing keys with values inferred from siblings of the same kind (read `.cumaru/schema.yaml` to confirm the expected shape). Confirm values before writing.
- **Schema: `apps` value not in `schema.yaml`** → Read `.cumaru/schema.yaml` `meta.apps.values`, propose the closest valid value, ask before editing.
- **Schema: `framework-version` mismatch** → Read `.cumaru/schema.yaml` `version:`, bump `framework-version:` in `.cumaru/index.md` to match.
- **Schema: EARS warning** → Reword the offending bullet to `WHEN <trigger> THE SYSTEM SHALL <behavior>` form, preserving intent. Show the proposed rewrite before applying.
- **Schema: missing H1** → Add a `# <title>` line at the top derived from the filename or surrounding context.
- **Orphan row (`✗ X — orphan row`)** → A pillar-index row points at a missing path. Either (a) the row's path is stale and needs editing via `cumaru tag set <pillar>/index.md <pillar> <new body>`, (b) the entity was removed and the row leaked (drop the row), or (c) the entity should still exist (recreate it). Ask the user when intent is unclear.
- **Orphan file (`⚠ Y — orphan file`)** → Disk has an entity no row claims. Either (a) the entity is new and the table needs a row added (use `cumaru tag set`), or (b) it's stray/debris (confirm before deleting — never delete adopter data without consent).
- **Stale work-marker file (`*.delete-me.md`)** → A recipe step in a domain skill (e.g. `cumaru-archive`) forgot to clean up. Identify which recipe owns the file from its name/location, complete the recipe step, then `cumaru flow <path> remove`.
- **Unrefined RAW block** → Read the embedded instructions, refine the item with user confirmation, then delete the entire `BEGIN/END RAW` block.
- **File references not found** → For each `<file>: <path>` in the `→` detail, ask whether the path is wrong (edit the `[Link, Description]` row via `cumaru tag set`) or the file was lost (recreate or remove the row).
- **Missing external tools** → Print the install command(s) for the user's platform; do not install on their behalf.

If the schema-conformance check itself failed catastrophically (e.g. `schema not found`), stop and report — the rest of the run is not meaningful until that is resolved.
