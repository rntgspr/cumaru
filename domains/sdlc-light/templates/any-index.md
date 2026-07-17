---
human_revised: true # flip to false once a human has reviewed this file
apps: [meta] # component scope: `meta` means .cumaru/ itself; replace
# with your component keys from schema.yaml meta.apps.values

summary: Framework guidance for <Pillar name> and its required workflow.
---

# <Pillar name>

A pillar for **<one-line essence — what this directory holds>**. <One sentence on how entries arrive here and who curates them.>

## Rules

<!-- Spell out the constraints that govern this pillar. Each bullet is a rule
     other LLMs/humans must respect when creating, reading, or moving entries. -->

- **<Rule>** — <reason / how to apply>.
- **<Rule>** — <reason / how to apply>.
- **Each entry is a directory** with `index.md` and any aux files, following the universal entity rules.

Use `cumaru tree <pillar-name>` to navigate current entries. Structural rows do
not belong in this file; use marker blocks only for declared semantic data.

## When to use

<!-- For ideation/active pillars. Rename to "## When to consult" when the
     pillar is read-only/historical (e.g. archive/). -->

- <Concrete scenario where this pillar is the right home>.
- <Another scenario>.

## When NOT to use

<!-- Rename to "## When NOT to consult" alongside the section above when
     read-only. -->

- <Off-target case → name the correct destination (e.g. "→ `plans/`")>.
- <Another off-target case>.
