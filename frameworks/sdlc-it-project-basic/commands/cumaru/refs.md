---
version: 1
description: Run `cumaru coverage`, walk the gaps with the user, and wire uncovered source files into spec `reference` tables. Stale and invalid rows are adjudicated one spec file at a time; nothing is written without confirmation.
allowed-tools: Bash, Read, Edit, Write
---

**Scope: this command maintains `<!-- cumaru:reference -->` tables under the durable specification pillar (`meta.specification_dir` in `.cumaru/schema.yaml`, default `specs/`). It never writes spec prose and never touches git.**

1. **Run the report**. Execute `cumaru coverage` and read the buckets: covered, uncovered, stale, invalid, foreign. If the command errors (no git work tree, no spec pillar), surface the hint it prints and stop.

2. **Present the summary**. One paragraph: coverage percentage, how many uncovered files, how many stale/invalid rows. If everything is green, say so and exit.

3. **Ask the user how to proceed**:
   - `walk` — reconcile gap by gap, confirming each write.
   - `report` — stop after the summary; no writes.

4. **Group before writing**. Map each uncovered file to the spec file that should reference it (read the spec pillar's indexes to find the owning area). Three cases per file:
   - An existing spec file owns the area → queue a row for that file's `reference` block.
   - No spec covers the area → flag it; creating the spec entity belongs to the domain's spec skill (hand off, e.g. `cumaru-specs` / `cumaru-topology` / `cumaru-coverage`), then queue the row.
   - Not coverable source (asset, config, generated) → propose narrowing `meta.coverage.source` in `.cumaru/schema.yaml` instead of forcing a row.

   Present the full grouping (which rows land in which spec file) and confirm before any write.

5. **Write rows one spec file at a time**. **Read each source file before describing it** — the Description is one line of real prose, never invented. Fetch the current body, append, write the union back:

   ```bash
   cumaru tag <spec-file> get reference
   cat <<'EOF' | cumaru tag <spec-file> set reference
   <current rows>
   | [<name>](<project-root-relative path>) | <one-line prose> |
   EOF
   ```

6. **Adjudicate stale and invalid rows** (per spec file, with confirmation):
   - `stale` — renamed/moved → fix the path (search by basename; `git log --diff-filter=R --follow` is read-only and allowed); deleted → drop the row.
   - `invalid` — rewrite as a project-root-relative path to a real source file; expand directory targets into per-file rows or drop them.

7. **Closure**. Re-run `cumaru coverage` and `cumaru doctor`; report the new percentage and anything still open. If gaps remain by design (files awaiting a new spec area), list them explicitly as follow-ups.

Hard rules:

- Every reference row targets a repository **source file**, resolved from the project root — never a `.cumaru/` path, a directory, an absolute path, or a URL.
- Never write a Description for a file you did not read this session.
- Rows are adopter data: append and fix — never drop rows beyond what the user confirmed.
- Git stays read-only throughout.
