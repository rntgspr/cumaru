---
name: align-user-and-agent-guides-with-cli-behavior
description: Correct misleading uninstall and search guidance and reconcile the remaining CLI documentation findings
status: open
priority: high
---

# Issue 171: Align user and agent guidance with observed CLI behavior

The November 18 review compared the public guides and shipped agent instructions
with the Linux CLI 0.15.1 and source at `7483145`. The command catalog broadly
matches. The highest-impact gaps affect what users delete and whether agents
can read what search returns.

## Risk

- Someone following the README can remove their own specs and notes. Uninstall
  removes the entire project `.cumaru/` tree after confirmation.
- An agent following the search recipe can find the right source file and then
  fail to read it, or load a whole file expecting a short passage.

## Required invariant

Following the published instructions tells the user what will be removed,
gives the agent a working way to read each kind of search result, and accurately
describes network access, cache writes and adapter changes.

## Work

1. State the full uninstall scope in the README command table. The dedicated
   uninstall guide already describes deletion of adopter knowledge.
   Done: the README row names deletion of adopter specs and notes.
2. Correct the universal search recipe and its mirrors. The lightweight backend
   can rank a whole file. A source result such as `./src/auth.rs:1,3` fails
   when passed to `get`. Document a working repository-relative read for source
   results, or support those selectors in `get` and test that contract.
   Done in part: `context` now trims blank edge lines with `get::trim`, so a
   Markdown result's range equals the header `get` prints for it.
3. Reconcile the upgrade guide with the doctor guide. On a cold cache, doctor
   can fetch the drift reference and write a cache entry and ignore rule.
   Clarify which context operations preserve knowledge files and which write
   vectors or ignore rules. Track the no-encoder reset defect in [169](issue_169.md).
4. Align the install, uninstall and adapter guides with Codex discipline delivery
   through the session hook and its fallback. Document removal of Cumaru-owned
   SessionStart, UserPromptSubmit and PreToolUse entries and preservation of
   unrelated hooks.
   Done: install, uninstall and adapter guides updated; a disposable uninstall
   kept a `Stop` hook and removed the three Cumaru entries.
5. Reconcile the inventory of 16 command families with the 18 entries in CLI
   help. Include `cumaru-search` and `cumaru-discipline` in the architecture
   guide's universal skill inventory.
   Done: the missing families were `get` and `hooks` (`help` was already
   listed); the Rust spec lists all 18 and the architecture guide both skills.

## Tests

- In a disposable project, check the README description against a confirmed
  uninstall of a tree containing an adopter-authored spec. Verify that an
  unrelated Stop hook survives and the three Cumaru hook entries are removed.
- Run the documented search-to-read sequence on a Markdown spec and a Rust
  source file. Both must return the requested lines. Check that the lightweight
  example describes the actual range it returns.
- Compare the doctor and context guides with cold and warm cache behavior.
  Verify the reset outcome against issue 169 with the encoder disabled.
- Compare the command and skill inventories with CLI help and the canonical
  domain. Run the existing universal skill mirror checks after editing the recipe.

## References

- `README.md`, `docs/uninstall.md`, `docs/install.md`, `docs/agent-adapters.md`
- `domains/__base/skills/cumaru-search/SKILL.md`, `docs/context.md`
- `src/commands/context.rs`, `src/commands/get.rs`, `src/commands/uninstall.rs`
- `docs/upgrade.md`, `docs/doctor.md`, `docs/architecture.md`, `.memory/specs/rust.md`
