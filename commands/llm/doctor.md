---
description: Run `llm doctor`, synthesize the findings, and offer to remediate each error/warning before touching anything.
allowed-tools: Bash, Read, Edit, Write
---

Run `llm doctor`. Read its output:

- The orchestrator emits one line per check: `[✓]` pass, `[⚠]` warning, `[✗]` error. Some lines carry a `→` hint with the recommended next action.
- The `Summary: N error(s), M warning(s), K ok` line at the end gives the totals. Exit code is non-zero iff there is at least one error.

Then:

1. **Synthesize a one-paragraph summary for the user** — totals, then list errors first and warnings second, grouped by check (schema / drift / handoffs / archive work / delta-drafts / file refs / external tools). Mention any `→` hints verbatim, since each is a known remediation path.
2. **Ask the user how to proceed**, offering:
   - `fix-all` — walk the findings top-down and propose a concrete fix for each (see remediation map below). Apply each fix only after the user confirms it.
   - `walk` — pick one finding at a time; for each, propose the fix and confirm before applying.
   - `skip` — do nothing; report and exit.
3. **Act on the answer**, applying fixes in order. After all fixes (or on `skip`), re-run `llm doctor` and report the new totals so the user sees the delta.

Do not apply any fix without explicit confirmation from the user. Errors block exit 0; warnings do not — surface that distinction when proposing what to fix first.

Remediation map (per finding):

- **Schema: missing frontmatter keys** → Read the file, add the missing keys with values inferred from siblings of the same kind (plan/task/spec/archive/exploring index). Confirm values before writing.
- **Schema: `apps` value not in `schema.yaml`** → Read `.llm/schema.yaml` `apps.values`, propose the closest valid value, ask before editing.
- **Schema: `framework-version` mismatch** → Read `.llm/schema.yaml` `version:`, bump `framework-version:` in `.llm/index.md` to match.
- **Schema: EARS warning** → Reword the offending bullet to `WHEN <trigger> THE SYSTEM SHALL <behavior>` form, preserving intent. Show the proposed rewrite before applying.
- **Schema: missing H1** → Add a `# <title>` line at the top derived from the filename or surrounding context.
- **Shallow indexes drifted** → Run `llm regen index` (it is the documented fix in the `→` hint).
- **Tasks done without handoff** → For each task, read `.llm/templates/handoff.md` and draft a `handoff-t<N>.md` next to the task. Treat this as authoring, not mechanical: ask for the missing details before writing.
- **Lingering archive work files** → Suggest `llm archive finalize <PLAN-ID>`. Do not run automatically; archive finalize has side effects.
- **Orphan delta-draft.md (archive entry already exists)** → Inspect both files. If the draft duplicates archived content, propose deletion. If it carries deltas not yet absorbed, flag it for manual review — do not delete.
- **File references not found** → For each `<file>: <path>` in the `→` detail, ask whether the path is wrong (edit the `<!-- llm:files:* -->` block) or the file was lost (recreate or remove the reference).
- **Missing external tools** → Print the install command(s) for the user's platform; do not install on their behalf.

If the schema-conformance check itself failed catastrophically (e.g. `schema not found`), stop and report — the rest of the run is not meaningful until that is resolved.
