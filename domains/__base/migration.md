---
release: 2026-08-01
targets:
  framework-version: 7
---

Work through the steps in order. Each one is detection-first: check whether it
applies before doing anything. Skipping a step that does not apply is correct.

## 0. Tools you have

You are running inside a project that has the `cumaru` CLI on `PATH`. **Use it** —
it is the framework's own tooling and it validates what hand-editing cannot. Every
command below accepts `--help`, and `cumaru help` lists the full surface.

| Command | Use it for | Read-only |
|---|---|---|
| `cumaru tree [<dir>] [--deep] [--rows]` | list a directory's candidates and their summaries | yes |
| `cumaru tag <file>` / `tag get\|set <file> <tag>` | audit, read, or replace a `<!-- cumaru:NAME -->` block body | `tag`/`get` yes |
| `cumaru flow <src> <verb> [<dst>]` | guarded `move`/`copy`/`create`/`remove` inside `.cumaru/` | no |
| `cumaru doctor [--quiet]` | validate the whole tree | yes |
| `cumaru coverage [--gaps]` | spec↔code reference coverage | yes |

**Three guardrails that will block you if you do not expect them.** They are
deliberate, not bugs — work with them:

1. **`cumaru tag` is config-validated.** `cumaru tag get <file> absorptions` works
   only while your `config.yaml` still declares that tag. **This is why step 6 runs
   before step 8:** once the config edit lands, the tool refuses the tag and you
   lose your only structured reader for it. Audit first, edit the config after.
2. **`cumaru tag set` replaces a body; it cannot delete a block.** Removing the
   `<!-- cumaru:NAME --> … <!-- /cumaru:NAME -->` markers themselves is a plain
   file edit.
3. **`cumaru flow` refuses pillar roots, `index.md`, non-`.md` files, and dotted
   directory names.** So `cumaru flow migrations remove` is **rejected** —
   `.cumaru/migrations/` is a direct child of the root. Use `rm -rf` for that one.

Prefer `cumaru tree` over `find` and `cumaru tag` over hand-parsing markers: they
enforce the contracts this migration is trying to reach. Fall back to plain shell
only where a guardrail blocks you, as flagged above.

**Prefer your own file-editing tools over shell one-liners.** You can read and edit
files directly; a `sed` pipeline buys nothing and breaks in ways that are easy to
miss. If you do shell out, three traps are live on a default macOS box — the
platform this framework targets:

- **You cannot assume which `grep` is on `PATH`.** A Homebrew box very often has
  `ugrep` or GNU `ggrep` ahead of `/usr/bin/grep`, and they disagree on flags.
  Concretely: `-Z` means `--null` only in GNU grep. macOS `/usr/bin/grep` emits
  newlines for it, and in `ugrep` `-Z` is `--fuzzy` while `--null` is `-0`. So
  `grep -rlZ … | xargs -0` collapses the whole list into one filename and the
  command dies. Stick to flags every grep agrees on — `-r`, `-l`, `-n`, `-F` — and
  read the list with a `while IFS= read -r` loop.
- **In-place editing: use `perl -pi -e`.** `sed -i` needs a suffix argument on BSD
  (`sed -i ''`) that GNU rejects, so it silently ties the command to one platform.
  `/usr/bin/perl` ships with macOS and behaves identically everywhere without
  leaving sidecar files.
- **Verify after every bulk rewrite.** Re-run the step's `Detect` command; it must
  come back empty. A rewrite that matched nothing looks exactly like one that
  worked — this is how the `grep -Z` bug above shipped in the first place.

## 1. Preflight

**Applies when** — always, before any other step.
**Detect**
```bash
git status --porcelain                 # is the worktree clean?
git ls-files .cumaru | head -1         # is .cumaru/ tracked AT ALL?
```
**Do**
1. **Check that `.cumaru/` is tracked.** If `git ls-files .cumaru` prints nothing,
   the tree is untracked and **git is not a rollback for it** — a clean
   `git status` says nothing about `.cumaru/` in that case. STOP and ask the user
   to commit `.cumaru/` first. Do not start an untracked migration: a clean
   status alone does not provide recovery.
2. If the worktree is dirty in paths this migration touches, STOP and ask the user
   to commit or stash. There is no transactional rollback here; git history — when
   it covers `.cumaru/` — is the safety net.
3. Confirm `.cumaru/index.md` and at least one of `.cumaru/schema.yaml` or
   `.cumaru/config.yaml` exists. If no configuration file exists, STOP.
4. Record which configuration-name state applies: legacy only, current only,
   both, or neither. Do not mutate it during preflight.
**Blockers** — an untracked `.cumaru/`, a dirty worktree in the affected paths,
or a `.cumaru/` that is not an install.
**Verify** — you can state exactly how to undo everything this migration will do,
before doing any of it.

## 2. Normalize the configuration filename

**Applies when** — always. This is the first mutation after preflight.
**Detect**
```bash
test -f .cumaru/schema.yaml && echo legacy
test -f .cumaru/config.yaml && echo current
```
**Do**
1. Only `schema.yaml`: `mv .cumaru/schema.yaml .cumaru/config.yaml`.
2. Both files: `rm .cumaru/schema.yaml`; `config.yaml` is authoritative and is
   not merged with or compared to the legacy file.
3. Only `config.yaml`: do nothing.
4. Neither file: STOP; the migration cannot infer project configuration.
5. If `.cumaru/.state/` exists, remove it with `rm -rf .cumaru/.state`. Version 7
   has no baseline, release checksum, or three-way configuration history.
**Blockers** — a non-regular file or symlink at either configuration path.
**Verify** — `test -f .cumaru/config.yaml`, `test ! -e .cumaru/schema.yaml`, and
`test ! -e .cumaru/.state` all succeed.

## 3. Legacy `.llm/` naming

**Applies when** — a `.llm/` directory exists, or any Markdown still carries
`<!-- llm:` markers, or `.agents/` still holds `llm-*` skills or a `commands/llm/`
directory.
**Detect**
```bash
test -d .llm; grep -rl '<!-- llm:' .cumaru .llm 2>/dev/null
ls -d .agents/skills/llm-* .agents/commands/llm 2>/dev/null
```
**Do** — this step predates the tree being a valid Cumaru install, so `cumaru`
subcommands cannot help until it finishes. Plain shell is correct here.
1. If `.llm/` exists and `.cumaru/` does not: `mv .llm .cumaru`.
2. Rewrite the markers in every `.md` under `.cumaru/`. Edit them with your own
   tools, or portably in shell:
   ```bash
   grep -rl '<!-- llm:\|<!-- /llm:' .cumaru | while IFS= read -r f; do
     perl -pi -e 's/<!-- llm:/<!-- cumaru:/g; s|<!-- /llm:|<!-- /cumaru:|g' "$f"
   done
   ```
3. In `.agents/AGENTS.md`: `perl -pi -e 's|\.llm/|.cumaru/|g' .agents/AGENTS.md`.
4. `mv .agents/commands/llm .agents/commands/cumaru`. If `commands/cumaru/`
   already exists, `rm -rf .agents/commands/llm` instead.
5. For each `.agents/skills/llm-<name>/`: `mv` it to `.agents/skills/cumaru-<name>/`.
6. Now that the tree is named correctly, `cumaru doctor` becomes meaningful — run
   it and carry the result into the following steps.
**Blockers** — both `.llm/` and `.cumaru/` present with divergent content: STOP
and ask which is authoritative.
**Verify** — `grep -rn '<!-- llm:' .cumaru` returns nothing and no `llm-*`
artifact remains under `.agents/`.

## 4. Namespaced touched-file marker

**Applies when** — any file contains `cumaru:files:touched`.
**Detect** — `grep -rl 'cumaru:files:touched' .cumaru`
**Do**
1. Rewrite every occurrence, opening and closing markers alike:
   ```bash
   grep -rl 'cumaru:files:touched' .cumaru | while IFS= read -r f; do
     perl -pi -e 's/cumaru:files:touched/cumaru:touched/g' "$f"
   done
   ```
   A textual rewrite is right here: `cumaru tag` addresses a block by name and
   cannot rename one.
2. Remove `meta.tags."files:touched"` from `.cumaru/config.yaml` if declared:
   `yq -i 'del(.meta.tags."files:touched")' .cumaru/config.yaml`.
3. Confirm the renamed blocks still resolve: `cumaru tag all --rows | grep touched`.
**Verify** — `grep -rn 'files:touched' .cumaru` returns nothing.

## 5. Summary contract widened to 32–512

**Applies when** — always worth checking; nothing to do on a healthy tree.
**Detect** — `cumaru doctor` and look for summary diagnostics.
**Do** — a `summary:` must now contain **32 to 512** Unicode code points: the
ceiling moved from 256 to 512 and the floor is unchanged. This only widens the
contract, so every previously valid summary stays valid and there is nothing to
rewrite. If doctor reports missing or invalid summaries, they predate this
change: use the `cumaru-summarize` skill.
**Verify** — `cumaru doctor` reports no summary errors.

## 6. Retire the `absorptions` ledger

**Applies when** — the durable pillar's `index.md` still contains a
`<!-- cumaru:absorptions -->` block. The pillar is `specs/` in the SDLC domains,
`topology/` in `iac-basic`, and `coverage/` in `qa-basic`.
**Detect** — `cumaru tag <pillar>/index.md` and `grep -n 'cumaru:absorptions'`.

The ledger duplicated what the pillar already asserts, and drifted: on the
adopter that prompted this change it had grown to 94% of `specs/index.md`, a
file loaded shallowly every session. Its one non-derivable column — the
absorption SHA — was unusable in a third of rows, because squash and rebase
rewrite commits. It is replaced by nothing in-tree. `git log` indexes
ticket↔pillar in both directions and is a strict superset.

**Do — audit every row before removing the block. Never truncate.**

Rows are independent, so this is resumable and parallelizable across sessions:
work through them in any order, and stop whenever you like.

For each row:

1. **Classify each durable claim in the Description.**
   - a system contract → the area or concern that owns it
   - a measured-and-rejected alternative → beside the requirement it explains
   - a durable gap → the domain's tech-debt concern
   - an open task → the tracker, not the pillar
2. **Delete outright anything that is bookkeeping about the ledger itself** —
   retained-archive pointers, "no stable absorption SHA", "identify by content",
   "shipped in squash X, not this SHA". That is metadata for an index that is
    going away, and it is usually a large fraction of the text.
3. **Drop the row only when nothing survives that is not already in the pillar.**
4. Use the row's KEY against the area's `deltas:` list (still present at this
   point — step 6 removes it) to find where the row *should* have landed.

**Commands for this step.** Read the ledger with
`cumaru tag get <pillar>/index.md absorptions` — it works because your config
still declares the tag, and it is why this step precedes step 7. While working
through a long ledger you may shrink it in place with
`cumaru tag set <pillar>/index.md absorptions` (body on stdin), so a partial audit
is durable across sessions. To place a claim, edit the owning area directly; to
create a missing area, use `cumaru flow <pillar>/<area> create` plus
`cumaru flow <pillar>/<area>/index.md create` and then author the frontmatter.

Only once every row is accounted for, remove the
`<!-- cumaru:absorptions -->` … `<!-- /cumaru:absorptions -->` block from the
pillar's `index.md` — that is a plain file edit, since `cumaru tag set` replaces a
body but cannot delete the markers.

**Then let the framework rewrite the prose for you.** The pillar's `index.md` is
framework-owned, and the new source already carries the replacement wording (a
`## History` section with the two `git log` recipes). So instead of hand-editing
every sentence that pointed at the ledger:

```bash
cumaru update <pillar>/index.md --from <cumaru-checkout> --apply
```

**The order is load-bearing, and getting it wrong is the one way to lose ground
here.** `cumaru update` captures every local marker body and restores it; when the
source no longer has that marker it re-inserts the body **at the top of the
rebuilt file**. Run update *before* removing the block and your ledger comes back,
worse placed than it started. Remove the block first, then update, and there is
nothing left to re-inject.

If the file has local divergence you want to keep, skip the update and rewrite the
prose by hand instead.

**Blockers** — a row whose Description contains a durable claim you cannot place
with confidence. STOP and ask; do not delete it.
**Verify** — no `cumaru:absorptions` block remains, and `cumaru doctor` reports
zero errors. Until the block is gone, doctor reports it as one unknown-marker
**warning**, which is expected and not an error.

## 7. Remove `deltas:` and `consolidated-at:`

**Applies when** — any area or concern frontmatter under the durable pillar
carries `deltas:` or `consolidated-at:`.
**Detect** — `grep -rn 'deltas:\|consolidated-at:' .cumaru/<pillar>/`

**Order matters: this step runs AFTER step 6.** The row audit uses `deltas:` as
its clue for where each ledger row should have landed. Reversed, the audit loses
its only lead and becomes guesswork.

**Do**
1. Remove both keys from every area and concern frontmatter, changing nothing else:
   ```bash
   grep -rl 'deltas:\|consolidated-at:' .cumaru/<pillar> | while IFS= read -r f; do
     yq -i --front-matter=process 'del(.deltas) | del(.["consolidated-at"])' "$f"
   done
   ```
   Review the diff afterwards — `yq --front-matter=process` rewrites the whole
   frontmatter block, so confirm it preserved key order and quoting acceptably.
   Where it did not, prefer a targeted edit with your own tools on that file.

   Beware that `grep -rl 'deltas:'` also matches *prose* mentioning the key, not
   only frontmatter. Confirm each hit is really a frontmatter key before editing —
   `yq --front-matter=extract 'has("deltas")' <file>` answers that exactly.
2. Confirm nothing else moved: `cumaru doctor` must still report zero errors, and
   `cumaru tree <pillar> --rows` must list the same areas as before.
2. `deltas:` was demonstrably lossy — on the adopter that prompted this change,
   git recovered three plans a file's own list omitted. Nothing replaces it: the
   pillar body is the record and `git log` is the cross-reference.
3. `consolidated-at:` goes with it. The durable pillar states current truth; no
   exact-time description belongs in it. Consolidation now runs on request, with
   the signal being a body that reads like a changelog.
**Verify** — the grep above returns nothing.

> Scope: this removal covers the durable pillar only. `completed-at:` on archive
> entities and `synced-at:` on intake items are operational metadata on transient
> pillars and stay exactly as they are.

## 8. Reconcile configuration and enter version 7

**Applies when** — `.cumaru/config.yaml` still declares the `absorptions` tag or
the two frontmatter keys.
**Detect** — `grep -n 'absorptions\|deltas\|consolidated-at' .cumaru/config.yaml`
**Do**
1. Set `.cumaru/config.yaml` `version: 7` and `.cumaru/index.md`
   `framework-version: 7`. This explicit migration step opens the equal-version
   update gate; ordinary update is never allowed to cross it.
2. Run `cumaru update config` and inspect the additive plan. Source values fill
   only missing keys. Valid local values, custom entities, tags, and rules
   remain; model-incompatible properties, including `x-*`, are listed for removal.
3. A permitted property carrying an invalid local value is a blocker. STOP and
   ask rather than replacing it with a source default.
4. Give the `cumaru update config` report, including its schema and candidate
   diff, to the agent. The agent must reconcile `config.yaml` deliberately.
5. Run `cumaru update --apply` to refresh framework Markdown and agent artifacts.
**Blockers** — a config whose pillar `tags:` map holds adopter-defined tags
alongside `absorptions`: remove only `absorptions` and keep the map.
**Verify** — `yq -e '.version == 7' .cumaru/config.yaml` and
`yq --front-matter=extract -e '."framework-version" == 7' .cumaru/index.md`
succeed and `cumaru doctor` reports zero errors with no configuration-drift
warning.

## 9. Remove the installed `migrations/` directory

**Applies when** — `.cumaru/migrations/` exists.
**Detect** — `test -d .cumaru/migrations`
**Do** — migration instructions are no longer distributed into the adopter tree.
They live in the CLI checkout and are delivered by `cumaru migrate`. Remove
`.cumaru/migrations/` entirely, including its `index.md` and any `.tsv`:

```bash
rm -rf .cumaru/migrations
```

`cumaru flow migrations remove` is **refused** here — guardrail 3: any direct
child of `.cumaru/` counts as a pillar root. This is the one deletion in this
document that must bypass `cumaru flow`.
**Verify** — `test ! -e .cumaru/migrations`.

## 10. Verify the whole tree

**Applies when** — always, last.
**Do**
1. `cumaru doctor` — expect zero errors.
2. `cumaru tree . --deep` — expect no navigation or summary defects.
3. `cumaru coverage` if the project uses `reference` tables — unchanged by this
   migration, so any regression here means something else was touched.
4. Commit. From now on the absorption commit **message** is load-bearing: it
   must name every KEY it absorbs, because it is the grep key that replaced the
   ledger. Messages survive rebase and squash; SHAs do not.
5. Verify no persistent backup artifacts were created by Cumaru. Recovery for
   manual migration edits remains the adopter's explicit responsibility (for
   example, a commit before editing), not command-generated litter.
