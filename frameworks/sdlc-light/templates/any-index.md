---
human_revised: true         # flip to false once a human has reviewed this file
generated: true             # true = machine-generated output; false = hand-authored
generated-at: <ISO datetime> # set at generation time; update on every regen
apps: [meta]                # component scope: `meta` means .cumaru/ itself; replace
                            # with your component keys from schema.yaml meta.apps.values
---

<!-- cumaru:<pillar-name> -->
<!-- This block is the pillar's shallow index — the ONLY thing that enters
     context by default for this pillar. Its name must match the key declared
     under root.entities in schema.yaml. v4: every body is a [Link, Description]
     table — hardcoded shape, do NOT add columns. Rows are added here (one per
     entry) as items are created in this pillar. The `<!-- cumaru:NAME --> /
     <!-- /cumaru:NAME -->` wrapper is required: the CLI and LLM use it to locate
     and update the table. -->
| Link | Description |
|------|-------------|

_No <entries> yet._
<!-- /cumaru:<pillar-name> -->

# <Pillar name>

A pillar for **<one-line essence — what this directory holds>**. <One sentence on how entries arrive here and who curates them.>

## Rules

<!-- Spell out the constraints that govern this pillar. Each bullet is a rule
     other LLMs/humans must respect when creating, reading, or moving entries. -->

- **<Rule>** — <reason / how to apply>.
- **<Rule>** — <reason / how to apply>.
- **Each entry is a directory** with `index.md` and any aux files, following the universal entity rules.

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
