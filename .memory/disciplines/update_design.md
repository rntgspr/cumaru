---
name: cumaru-update-and-doctor-design-principles
description: Preserve adopter data while v9 config, doctor, update, and migration enforce deterministic structure and explicit ownership
metadata:
  node_type: memory
  type: feedback
---

These principles apply when changing the current Cumaru v9 update, doctor,
migration, tag, and guarded filesystem contracts. The canonical details are in
[`../specs/configuration.md`](../specs/configuration.md),
[`../specs/update.md`](../specs/update.md), and
[`../specs/migration.md`](../specs/migration.md).

1. **Preserve adopter tag bodies and local-only paths.** `<!-- cumaru:NAME -->`
   bodies are adopter data, including unknown balanced tags. Framework Markdown
   frontmatter and outside-tag prose are canonical only at entries explicitly
   marked `framework: true` in the source v9 tree. Ownership does not inherit.
   Update must preserve tag bodies during canonical replacement and must not
   remove local-only files.
2. **Keep config reconciliation agent-led.** `cumaru update config` reports the
   complete candidate and incompatible properties without writing config or a
   persistent backup. Source defaults fill missing keys; valid local values
   remain. A permitted but invalid value is a blocker, not a reason to replace
   it mechanically.
3. **Use the v9 config as the deterministic structure contract.** Direct `root`
   selectors, `path`, `frontmatter`, `tags`, global `rules`, and explicit
   `framework` flags drive doctor and update. Tags are name arrays, not body
   format declarations. EARS/Gherkin language guidance stays in domain prose;
   doctor does not enforce it through config.
4. **Gate versions by config only.** `config.version` is the sole framework
   version source; Markdown has no `framework-version`. Ordinary update cannot
   apply across an integer version boundary. `cumaru migrate` prints one
   read-only, preservation-first procedure from any supported installed version
   directly to the current v9 contract. A validated v9 candidate precedes the
   final installed version write.
5. **Separate mechanical and semantic decisions.** Doctor checks configured
   structure, required frontmatter fields, markers, references, and workflow
   graph validity. The agent adjudicates ambiguous adopter content and migration
   choices; scripts must not invent values or silently discard provenance.
6. **Keep CLI roles distinct.** `cumaru fs` performs guarded create, copy, move,
   and remove inside `.cumaru/`. Named skill workflows live under optional
   `config.workflows` and are orchestrated by the `cumaru-flow` skill. Framework
   skills and supported commands are replaced deterministically for the selected
   adapter; unrelated adapter artifacts remain adopter-owned.
