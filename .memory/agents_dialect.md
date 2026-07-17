# Canonical agent dialect: `.agents/`

## Decision

Cumaru uses `.agents/` as its only managed agent dialect. The canonical
instruction file is `.agents/AGENTS.md`.

The CLI does not manage `CLAUDE.md` or `.claude/`:

- `cumaru install` creates or extends `.agents/AGENTS.md` only;
- `cumaru doctor` validates the canonical `CUMARU-HOOK` block in
  `.agents/AGENTS.md` only;
- a missing instruction file, missing block, or block drift is warning-only;
- `cumaru update` reconciles artifacts under `.agents/` only;
- the `cumaru-update` skill may inspect existing `CLAUDE.md` or `.claude/`
  compatibility files and offer a separate alignment, but must explain the
  edits and obtain user confirmation before changing them.

## No prompt-submit context loader

The `context-loader.sh` feature was removed from every domain. Cumaru no longer:

- ships a `domains/*/hooks/context-loader.sh` file;
- installs framework hooks under `.agents/hooks/`;
- creates or edits `.agents/hooks.json`;
- injects `.cumaru/index.md` or `.cumaru/domain.md` on every prompt;
- validates prompt-hook wiring in `cumaru doctor`;
- exposes `cumaru update hooks`;
- removes adopter hooks during uninstall or migration.

`.agents/AGENTS.md` and its `@.cumaru/index.md` directive are the sole framework
bootstrap contract. Existing adopter-owned hooks are left untouched.

## Doctor contract

Version 6 doctor now runs seven checks:

1. Navigation and summaries.
2. Marker contracts.
3. Stale work-marker files.
4. Unrefined RAW blocks.
5. Retained file references.
6. External tools.
7. Agent instruction block.

## Verification

The removal was verified with shell syntax checks, `git diff --check`, and the
full test suite: six test scripts passing.
