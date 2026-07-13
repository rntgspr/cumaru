---
name: code review — negative points
description: Critical code quality issues found in the cumaru codebase (2026-07-10)
type: feedback
---

## 1. Bash quality — low baseline

| Issue | Location | Detail |
|-------|----------|--------|
| `set -uo pipefail` no `-e` | `cumaru:28` | Errors are silent — if `_resolve_self` fails, execution continues with empty `SCRIPT_DIR` |
| Leaking inner functions | `cmd_doctor.sh:414` | 7 functions (`fm`, `has_key`, etc.) defined inside `_doctor_check_schema` become global. The `unset -f` at the end is fragile — early return leaves them leaked |
| Mutable shared globals | `cumaru:91-93`, `cmd_doctor.sh:88-90` | `errors`, `warnings`, `QUIET` are global across all modules. Accidental subshells or `trap` overwrite silently |
| Zero automated tests | whole repo | `test_process.md` describes manual cycle only. No `make test`, `bats`, or shellcheck in CI |

## 2. Embedded Awk/Ruby — fragile and duplicated

- **4 different YAML parsers in Awk** (`common.sh`, `cmd_doctor.sh`, `cmd_tag.sh`, `cmd_update.sh`) — each has its own state machine and indentation assumptions. A schema.yaml indentation change silently breaks them.
- **Hidden Ruby dependency**: `_doctor_schema_entities` and `fm_schema_tag_specs` need `ruby -ryaml` on PATH. If Ruby is absent, functions silently return 0 without warning.
- **Duplicated `marker_line()`** in at least 5 places (common.sh:106,149, cmd_update.sh:864, etc.) — copy-pasted literal, not factored.

## 3. Subshell state loss

```bash
# cmd_doctor.sh:433 — counters reset but run in a subshell
out=$(QUIET=1 errors=0 warnings=0 _doctor_check_schema 2>&1)
```
The function runs in a subshell — `errors` and `warnings` bumps are invisible to the caller. Warning count is extracted via a hacky sentinel line (`WARNCOUNT:`) at line 420.

```bash
# common.sh:182 — find | while creates subshell
find ... -print0 | while IFS= read ...; do ... done
```
Variables modified inside the `while` vanish after the pipe.

## 4. Security and robustness

- **`rm -rf` with trivial confirmation**: `cmd_install.sh:57` — only `read -p "[y/N]"`. If stdin is piped (`echo y | cumaru install`), overwrites without question. No `--yes` flag.
- **`exec bash "$SRC/install.sh"`** (`cumaru:148`): runs `rm -rf ~/.cumaru` unconditionally. The problem was already documented in `feedback_install_sh_destructive.md` but the code is unchanged.
- **`mktemp` without `XXXXX` template** in some places (common.sh:129) — macOS accepts it, Linux may fail.
- **Paths with spaces**: `cmd_doctor.sh:196` — `"$CUMARU_DIR"/$glob` deliberately unquotes the glob, but if `$CUMARU_DIR` has spaces it breaks. The comment acknowledges the issue but doesn't fix it.

## 5. Performance

- **All 13 modules (~5.5K lines) sourced on every invocation**: even `cumaru --quiet` loads `cmd_install.sh`, `cmd_update.sh`, `cmd_intake.sh`, etc. Should use lazy loading.
- **Multiple full tree walks**: `cumaru doctor` runs `find "$CUMARU_DIR"` at least 4 times (schema check, orphans, stale markers, RAW blocks, pattern rules).

## 6. Maintainability

- **Monolithic modules**: `cmd_doctor.sh` (842 lines), `cmd_update.sh` (902), `cmd_tag.sh` (650). Many 100+ line functions.
- **YAML logic in inline Awk**: `_tag_schema_meta_table` (cmd_tag.sh:248) is 40 lines of Awk with a 6-state machine. A schema indentation change breaks it silently.
- **Verbose comments vs fragile code**: extensive comments explaining intent, but no tests to verify it actually works.

## 7. Specific bug candidates

| File | Line | Issue |
|------|------|-------|
| `common.sh` | `fm_block_replace:122-173` | If `content_file` is empty (empty stdin), `getline` returns 0 and the block silently vanishes |
| `cmd_doctor.sh` | `_doctor_apps_values:123-136` | Awk state machine breaks on non-standard indentation in `meta.apps.values` |
| `cmd_update.sh` | `_update_build_expected:69-100` | `_tag_insert_empty` called with `2>/dev/null || true` — errors swallowed |
| `cmd_flow.sh` | `_flow_resolve_inside:68-107` | `while [[ ! -e "$probe" && ! -L "$probe" ]]` — double-slash in path could cause infinite loop |
| `cmd_tag.sh` | `_tag_do_set:432-456` | If `fm_block_replace` fails (missing marker), temp file leaks |
