---
name: cumaru-update-and-doctor-design-principles
description: Load-bearing principles for any update/migration/doctor work — script reports + LLM adjudicates; adopter content never auto-overwritten; skills/commands are framework-owned and replaced deterministically. v4 collapses the per-tag-kind logic into a single hardcoded shape.
metadata: 
  node_type: memory
  type: feedback
---

> Historical through V5. V6 keeps the tag-body preservation invariant but
> changes framework-owned Markdown updates: files are rebuilt from canonical
> source, tag bodies are restored, local-only files remain adopter-owned, and
> `--keep-prose` is the explicit divergence path. Frontmatter outside marker
> bodies is no longer universally adopter-owned. See [[v6_virtual_tree]].

These principles apply to any script-LLM split in the cumaru framework (update, doctor's orphan check, `cumaru flow` file ops, future migration tooling). Easy to violate; expensive to get wrong.

**1. Tag bodies are NEVER overwritten mechanically.** `<!-- cumaru:NAME -->` block contents are adopter data — preserve always. v4 makes every body a `[Link, Description]` table; the script REPORTS row drift (rows pointing at missing paths, rows whose link doesn't match the canonical `[name](path/index.md)` shape) and the LLM DECIDES how to reshape, keeping rows. The script never invents new rows or drops existing ones.

**Why:** adopter content lives in tag bodies by v4 design. Components, pillar entries, file lists — all of it is in tags. Overwriting them = silent data loss.

**2. Frontmatter values are NEVER overwritten mechanically.** Only **key drift** is reported (keys the source has that local lacks, and vice-versa). Values (`apps:`, `status:`, `key:`) are adopter data. When a required key is missing, the script reports it; the LLM reconstructs against the schema. **`--apply` of update keeps local frontmatter verbatim.**

**Why:** the schema declares the contract (which keys); the adopter owns the values. A required key being absent is a real issue but the value can't be invented by the script.

**3. Prose comes FROM SOURCE by default.** Framework rule updates land in prose. `--keep-prose` is the opt-out, with a per-file warning ("framework updates skipped; the tree may diverge from its spec").

**Why:** the user explicitly chose this direction: default = update prose from source; opt-out for the rare case where the adopter wants to keep their wording.

**4. File-presence triage runs before per-file logic.** Three cases the script classifies first: (a) source-only → new framework file, copy whole; (b) local-only → adopter-created (`specs/<area>/`, `plans/<PLAN-ID>/`) → **never touch**; (c) both → run the per-file algorithm. Adopter-owned paths passed as `<path>` arg are rejected with an explicit "no framework source exists for this path" message.

**5. Version gate is enforced by the command, not just docs.** `cumaru update` refuses on `source.version` ≠ `local.framework-version` and points to the matching migration (v2 → v3 → v4). **`cumaru doctor`'s orphan check** also refuses (warns + skips) when the schema has no `root.entities` (pre-v3 shape), pointing the same migration path.

**6. Skills and slash commands are framework-owned — replaced deterministically.** Unlike `.cumaru/` content, skills and slash commands carry no adopter data. `cumaru update --apply` replaces them wholesale from the source checkout. Deprecated items (locally present, absent from source) are LISTED but NOT deleted — removed manually by the user after review. This is symmetric: both skills and commands get the same treatment.

**7. LLM adjudicates; bash mechanical.** Anywhere there's ambiguity (row drift in a `[Link, Description]` block, missing required FM keys, deprecated skills/commands), the script REPORTS structured output and the LLM DECIDES with full context. The script never guesses.

**8. v4 simplification — one tag shape, hardcoded.** v3 had four "kinds" (array→table, string→prose, path-list, number) and per-tag column declarations; the script carried a branch per kind. v4 collapses all of it: every block is `[Link, Description]`, hardcoded. `cumaru tag`, `cumaru doctor`, `cumaru update` no longer branch on kind — they read tags, validate the table shape, and report row drift. Schema entries for tags only carry `host_file:` (when needed); everything else is implicit.

**9. Operational simplification beats configurability.** The fixed `.cumaru/` target is intentional. `CUMARU_DIR` lives in `src/common.sh` as a checkout-wide override, not a per-project setting. `cumaru doctor` owns the RAW marker warning, `cumaru update` has dedicated `skills|commands|schema` targets, and `cumaru flow` enforces canonical containment plus a no-dotted-directory contract across every verb.

**How to apply:** when adding a new verb that touches `.cumaru/` content, ask: what's deterministic (script does it) vs ambiguous (LLM adjudicates)? Default to non-destructive — preserve adopter content; surface discrepancies; let the LLM resolve. Skills/commands are the exception: they are deterministic replaces. Tag bodies are ALWAYS `[Link, Description]` — don't invent kinds.
