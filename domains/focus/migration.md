---
release: 2026-08-01
targets:
---

Work through the steps in order. Each one is detection-first: check whether it
applies before doing anything. Skipping a step that does not apply is correct.
Supported starting layouts already use `.cumaru/`; a project without that tree
is unadopted and outside this migration contract.

An already-valid v9 tree needs no migration: detect that state during preflight,
skip every inapplicable conversion, and do not write its configuration.

## 0. Tools you have

You are running inside a project that has the `cumaru` CLI on `PATH`. **Use it** —
it is the framework's own tooling and it validates what hand-editing cannot. Every
command below accepts `--help`, and `cumaru help` lists the full surface.

| Command | Use it for | Read-only |
|---|---|---|
| `cumaru tree [<dir>] [--deep] [--rows]` | list a directory's candidates and their summaries | yes |
| `cumaru tag <file>` / `tag get\|set <file> <tag>` | audit, read, or replace a `<!-- cumaru:NAME -->` block body | `tag`/`get` yes |
| `cumaru fs <src> <verb> [<dst>]` | guarded `move`/`copy`/`create`/`remove` inside `.cumaru/` | no |
| `cumaru doctor [--quiet]` | validate the whole tree | yes |
| `cumaru coverage [--gaps]` | spec↔code reference coverage | yes |

**Three guardrails that will block you if you do not expect them.** They are
deliberate, not bugs — work with them:

1. **`cumaru tag` is config-validated.** `cumaru tag get <file> absorptions` works
   only while your `config.yaml` still declares that tag. **This is why the ledger
   audit runs before configuration reconciliation:** once the config edit lands,
   the tool refuses the tag and you lose your only structured reader for it.
   Audit first, edit the config after.
2. **`cumaru tag set` replaces a body; it cannot delete a block.** Removing the
   `<!-- cumaru:NAME --> … <!-- /cumaru:NAME -->` markers themselves is a plain
   file edit.
3. **`cumaru fs` refuses pillar roots, `index.md`, non-`.md` files, and dotted
   directory names.** So `cumaru fs migrations remove` is **rejected** —
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
**Detect** — first determine whether the project already uses Git:
```bash
git rev-parse --is-inside-work-tree
git status --porcelain
git ls-files .cumaru | head -1
```
**Do**
1. When the project is in a Git work tree, require `.cumaru/` to be tracked and
   the affected paths to be clean. A clean status alone is not recovery when
   `git ls-files .cumaru` prints nothing; STOP and ask for a committed baseline.
2. When Git is unavailable or the project is outside Git, warn that migration
   will continue without Git recovery. Do not initialize a repository.
3. Confirm `.cumaru/index.md` and at least one of `.cumaru/schema.yaml` or
   `.cumaru/config.yaml` exists. If no configuration file exists, STOP.
4. Record which configuration-name state applies: legacy only, current only,
   both, or neither. Do not mutate it during preflight.
**Blockers** — inside Git: an untracked `.cumaru/` or dirty affected paths. In
every project: a `.cumaru/` that is not an install.
**Verify** — Git projects have a committed recovery point; non-Git projects have
an explicit warning and no implied rollback.

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
5. If `.cumaru/.state/` exists, remove it with `rm -rf .cumaru/.state`. Version 8
   has no baseline, release checksum, or three-way configuration history.
**Blockers** — a non-regular file or symlink at either configuration path.
**Verify** — `test -f .cumaru/config.yaml`, `test ! -e .cumaru/schema.yaml`, and
`test ! -e .cumaru/.state` all succeed.

## 3. Discover preservation work

**Applies when** — always, before any canonical refresh.
**Detect** — read the domain preservation section inserted immediately below and
run all of its detection commands against the installed `.cumaru/` tree. Use
`yq -r` to record installed versions independently of retired fields:

```bash
yq -r '.version // "<missing>"' .cumaru/config.yaml
```

**Do**
1. Inventory every adopter value that the domain section says a later canonical
   refresh could remove or obscure.
2. Resolve and preserve those values before continuing. A detection result is
   not permission to guess: retain the original source until provenance is
   resolved.
3. Complete the domain section before base conversion resumes. The section is
   delivered here, not appended after refresh, so its ordering is executable.
**Blockers** — unresolved provenance, ambiguous ownership, or missing recovery.
STOP and ask. Do not continue to configuration conversion or refresh.
**Verify** — every discovered value has an explicit preserved destination, and
the source that proves it still exists.

<!-- cumaru:migration-domain-extension -->

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
**Detect** — run `cumaru tree . --deep` and inspect summary diagnostics. Unlike
doctor, tree navigation remains useful before the installed version converges.
**Do** — a `summary:` must now contain **32 to 512** Unicode code points: the
ceiling moved from 256 to 512 and the floor is unchanged. This only widens the
contract, so every previously valid summary stays valid and there is nothing to
rewrite. If tree reports missing or invalid summaries, they predate this
change: use the `cumaru-summarize` skill.
**Verify** — `cumaru tree . --deep` reports no summary errors.

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
   point — step 7 removes it) to find where the row *should* have landed.

**Commands for this step.** Read the ledger with
`cumaru tag get <pillar>/index.md absorptions` — it works because your config
still declares the tag, and it is why this step precedes step 9. While working
through a long ledger you may shrink it in place with
`cumaru tag set <pillar>/index.md absorptions` (body on stdin), so a partial audit
is durable across sessions. This ledger audit is preservation work, not cleanup.
To place a claim, edit the owning area directly; to
create a missing area, use `cumaru fs <pillar>/<area> create` plus
`cumaru fs <pillar>/<area>/index.md create` and then author the frontmatter.

Only once every row is accounted for, remove the
`<!-- cumaru:absorptions -->` … `<!-- /cumaru:absorptions -->` block from the
pillar's `index.md` — that is a plain file edit, since `cumaru tag set` replaces a
body but cannot delete the markers.

Do not refresh the pillar yet. The later general `cumaru update --apply` captures
every local marker body and restores it; when the source no longer has that
marker it re-inserts the body **at the top of the rebuilt file**. Refresh before
removing the block and the ledger comes back, worse placed than it started.
Remove the block first, preserve every claim, and wait for the authorized refresh
checkpoint.

**Blockers** — a row whose Description contains a durable claim you cannot place
with confidence. STOP and ask; do not delete it.
**Verify** — no `cumaru:absorptions` block remains. Do not use `cumaru doctor` as
an intermediate gate; the installed tree is not expected to satisfy v9 until
conversion, version convergence, and canonical refresh are complete.

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
2. Confirm nothing else moved: review `git diff -- .cumaru/<pillar>` and require
   `cumaru tree <pillar> --rows` to list the same areas as before. Full doctor
   validation waits until the tree has converged to v9.
3. `deltas:` was demonstrably lossy — on the adopter that prompted this change,
   git recovered three plans a file's own list omitted. Nothing replaces it: the
   pillar body is the record and `git log` is the cross-reference.
4. `consolidated-at:` goes with it. The durable pillar states current truth; no
   exact-time description belongs in it. Consolidation now runs on request, with
   the signal being a body that reads like a changelog.
**Verify** — the grep above returns nothing.

> Scope: this removal covers the durable pillar only. `completed-at:` on archive
> entities and `synced-at:` on intake items are operational metadata on transient
> pillars and stay exactly as they are.

## 8. Rename the applicability axis

**Applies when** — `config.yaml` has `meta.apps`, any managed frontmatter declaration names `apps`, or any Markdown artifact carries an `apps:` field.
**Detect**

```bash
yq -e '.meta | has("apps")' .cumaru/config.yaml
yq -e '.meta | has("targets")' .cumaru/config.yaml
grep -rn '^apps:' .cumaru
grep -n 'apps!\|apps,' .cumaru/config.yaml
```

**Do**
1. If both `meta.apps` and `meta.targets` exist, STOP. Their coexistence is ambiguous and must not be merged or guessed.
2. If only `meta.apps` exists, rename that key with `yq -i '.meta.targets = .meta.apps | del(.meta.apps)' .cumaru/config.yaml` without changing, sorting, deduplicating, or otherwise interpreting its `values` array.
3. Rename every `apps` entry in config-declared frontmatter arrays to `targets`, preserving array order and required-field suffixes.
4. Rename each Markdown frontmatter key from `apps:` to `targets:` without changing its array value or order. Do not keep an `apps` compatibility alias.

**Blockers** — mixed `apps` and `targets` keys in configuration or in one Markdown frontmatter block.
**Verify** — the detection commands find no `apps` field, the original array values compare equal to the renamed `targets` values, and `targets` appears at each former location.

## 9. Reconcile configuration and converge directly on version 9

**Applies when** — the installed version is lower than `9`, missing, malformed,
or any current-v9 configuration requirement is unmet. This step is independent
of whether `absorptions`, `deltas`, or `consolidated-at` exists.
**Detect**

```bash
yq -r '.version // "<missing>"' .cumaru/config.yaml
grep -n 'absorptions\|deltas\|consolidated-at' .cumaru/config.yaml
```

**Do**
1. If version metadata in the installed content disagrees, use tracked history
   and the installed content to establish the actual starting version. STOP if
   the evidence is ambiguous; do not write an intermediate version to open an
   update gate.
2. Run `cumaru update config --from <cumaru-checkout>` while the installed
   versions still describe the actual starting state. Inspect the complete
   candidate diff without writing it.
3. Give the report, including its schema and source-default paths, to the agent.
   The agent must reconcile `config.yaml` deliberately. Source values fill only
   missing keys. Valid local values, custom entities, tags, and rules remain;
   model-incompatible properties, including `x-*`, are listed for removal.
4. A permitted property carrying an invalid local value is a blocker. STOP and
   ask rather than replacing it with a source default. If a pillar `tags:` map
   holds adopter-defined tags alongside `absorptions`, remove only `absorptions`.
5. Preserve the complete current config, every `<!-- cumaru:... -->` body, and
   all local-only paths. Convert the structural declarations into the direct
   `root` tree: a literal selector is required, a glob may match zero paths, and
   a `path` override names its physical destination. Directory declarations
   describe their `index.md` frontmatter and tags. Mark only explicitly
   framework-owned entries with `framework: true`; ownership and `optional` do
   not inherit. Convert frontmatter declarations to field maps and tags to plain
   arrays. Do not carry EARS, Gherkin, tag formats, or retired compatibility
   fields into the v9 config. Retain `meta.targets.values` verbatim; named
   workflows are optional and must refer only to installed domain skills.
6. Write the reconciled v9 configuration to a temporary candidate, leaving
   `.cumaru/config.yaml` untouched. Set only the candidate's `version: 9` and
   validate that candidate against the v9 contract:
   ```bash
   candidate=/path/to/temporary-reconciled-v9-config.yaml
   yq -i '.version = 9' "$candidate"
   yq -o=json '.' "$candidate" | jq -r -f <cumaru-checkout>/schemas/schema-validate-v9.jq
   rm -f "$candidate"
   ```
   Resolve ambiguous paths or ownership deliberately; STOP and ask rather than
   guessing. The validator must emit nothing and exit successfully. This
   temporary validation selects the v9 contract before the installed config is
   changed.
7. Complete every base and domain conversion first. Apply the validated
   candidate's reconciled fields to `.cumaru/config.yaml` while retaining its
   starting version. Write the sole version field last: set
   `.cumaru/config.yaml` to `version: 9`. Do not add or reconcile a root
   `framework-version` field.
8. Run read-only `cumaru update --from <cumaru-checkout>` and inspect the
   preview. Apply only after the preserved config, tag bodies, and local-only
   paths are still present in the preview.
**Blockers** — unresolved config choices, a candidate that does not validate, an
   installed version greater than `9`, or a version write attempted before the
other conversion work is complete.
**Verify** — `.cumaru/config.yaml` returns `9`; the read-only update preview
succeeds; no mutating update has run.

## 10. Remove the installed `migrations/` directory

**Applies when** — `.cumaru/migrations/` exists.
**Detect** — `test -d .cumaru/migrations`
**Do** — migration instructions are no longer distributed into the adopter tree.
They live in the CLI checkout and are delivered by `cumaru migrate`. Remove
`.cumaru/migrations/` entirely, including its `index.md` and any `.tsv`:

```bash
rm -rf .cumaru/migrations
```

`cumaru fs migrations remove` is **refused** here — guardrail 3: any direct
child of `.cumaru/` counts as a pillar root. This is the one deletion in this
document that must bypass `cumaru fs`.
**Verify** — `test ! -e .cumaru/migrations`.

## 11. Establish the pre-refresh recovery checkpoint

**Applies when** — the conversion is complete and the read-only v9 preview from
step 9 succeeds.
**Detect** — determine whether the project already uses Git:

```bash
git status --porcelain --untracked-files=all
git diff -- .cumaru
```

Outside a Git work tree, the commands above may fail; that is a supported
project state, not a migration failure.

**Do**
1. Review every preservation and conversion change with the user.
2. When the project is in a Git work tree, STOP and confirm Git mutation is authorized.
   Create a commit that records the complete converted v9 tree. Do not commit implicitly.
   After the authorized commit exists, verify `git status
   --porcelain --untracked-files=all` is empty and both required Cumaru markers
   resolve from `git show HEAD:<path>`.
3. When Git is unavailable or the project is outside Git, disclose that the
   refresh will continue without a Git recovery point. Do not initialize a
   repository implicitly.
**Blockers** — inside Git: failed authorization or commit, pending changes, or
either required marker absent from `HEAD`. STOP before `cumaru update --apply`
only on an applicable Git blocker.
**Verify** — either the clean recovery commit contains all preserved provenance
plus the valid v9 config/root pair, or the non-Git recovery limitation is
explicitly accepted.

## 12. Refresh framework Markdown

**Applies when** — step 11 established either a clean Git recovery checkpoint or
the warned non-Git boundary.
**Detect** — run read-only `cumaru update --from <cumaru-checkout>` and review the
complete framework Markdown plan.
General update does not refresh agent artifacts; those remain an explicit,
separate operation.
**Do**
1. Run `cumaru update --from <cumaru-checkout> --apply`. This refreshes
   framework-owned `.cumaru/` files only; it does **not** refresh skills,
   commands, instructions, hooks, or any other agent artifact.
2. Run `cumaru doctor --quiet`. The apply command already invokes this gate, but
   the explicit result is part of migration evidence.
3. If agent artifacts must be refreshed, review the framework diff. Inside Git,
   STOP and ask the user to authorize a second commit, then require a clean
   worktree. Outside Git, retain the accepted no-recovery boundary. Run
   `cumaru update agent <agent> --apply` only afterward. This command uses the active CLI
   checkout; if it differs from `<cumaru-checkout>`, invoke that checkout's
   `cumaru` executable instead. If the active agent is ambiguous, ask.
**Blockers** — a dirty Git worktree, failed doctor, missing applicable recovery
authorization, or ambiguous adapter.
**Verify** — a second general update preview reports no framework Markdown
changes. When an adapter refresh applied, its second preview is also stable.

## 13. Verify the whole tree

**Applies when** — always, last.
**Do**
1. `cumaru doctor` — expect zero errors.
2. `cumaru tree . --deep` — expect no navigation or summary defects.
3. `cumaru coverage` if the project uses `reference` tables — unchanged by this
   migration, so any regression here means something else was touched.
4. Verify `cumaru update config --from <cumaru-checkout>` and the general update
   preview are stable. Re-running this completed procedure must make no change.
5. From now on an absorption commit **message** is load-bearing: it must name
   every KEY it absorbs, because it is the grep key that replaced the ledger.
   Messages survive rebase and squash; SHAs do not.
6. Verify no persistent backup artifacts were created by Cumaru. Recovery for
   manual migration edits remains the adopter's explicit responsibility (for
   example, the authorized commits above), not command-generated litter.
**Blockers** — any failed validation or non-idempotent second preview. STOP and
inspect the retained recovery commits rather than continuing cleanup.
**Verify** — all checks pass, every second preview is stable, and the final
worktree contains no unintended migration debris.
