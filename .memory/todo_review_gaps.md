# TODO: Review implementation gaps before next coding step

Open items unchanged by v4 (the v4 tag-shape overhaul is its own work stream):

1. Basecamp is still not wired in `cmd_intake.sh`.
2. Semantic cross-file dependency validation is still deferred.
3. `cumaru install` / `cumaru uninstall` target `.cumaru/` only; custom target support is gone by design.
4. `cmd_intake` still re-appends RAW blocks on re-sync; verify whether the current behavior is acceptable or should be refined.
5. `update schema --apply` remains intentionally destructive — product decision, not a routine update path.

v4-specific open items (tracked in session tasks #2..#7):
- Parser/CLI adaptation (drop column/kind branches; hardcode `[Link, Description]`).
- Starter content rewrite (every `<!-- cumaru:* -->` body to the new shape across all four domains).
- Skills & slash commands update (recipes must emit `[Link, Description]`).
- Docs sweep (tag.md, update.md, doctor.md, README).
- v3 → v4 migration procedure (fuse old columns into the Description prose).
- Smoke test against the test bench.

Use this note as the decision checkpoint before implementing any follow-up.
