---
name: yq-adoption-plan
description: Replace awk+Ruby schema/frontmatter parsing with yq (mikefarah/yq v4+)
type: project
---

## Goal

Replace all YAML reading in cumaru — schema.yaml queries (8 awk state machines), recursive walks (3 Ruby spots), and frontmatter extraction (2 awk functions) — with a single tool: `yq` (mikefarah/yq v4+). JSON stays with `jq`.

## Tool

`yq` (mikefarah/yq v4+, Go static binary — no Go runtime needed).

Install: `brew install mikefarah/yq/yq` (macOS) or `snap install yq` (Linux).

Mandatory dependency — checked in `cumaru doctor` and `cumaru install`:

```bash
if ! command -v yq >/dev/null 2>&1; then
  red "✗ yq (mikefarah/yq) is required — brew install mikefarah/yq/yq"
fi
if ! yq --version 2>/dev/null | grep -qi mikefarah; then
  red "✗ yq found but wrong implementation — expected mikefarah/yq"
fi
```

## Scope

### Replaced — schema queries (8 awk state machines → `yq` path)

| Function | File | Current (awk) | `yq` equivalent |
|----------|------|---------------|-----------------|
| `_doctor_apps_values` | cmd_doctor.sh:123 | awk state machine | `.meta.apps.values[]` |
| `_doctor_pattern_rules` | cmd_doctor.sh:149 | awk state machine | `.rules \| to_entries[]` |
| `schema_version` scalar | cmd_doctor.sh:226 | `awk '/^version:/ {print \$2}'` | `.version` |
| `_tag_schema_root_keys` | cmd_tag.sh:207 | awk state machine | `.root.entities \| keys[]` |
| `_tag_schema_pillar_keys` | cmd_tag.sh:224 | awk state machine | `.root.entities.<pilar>.entities \| keys[]` |
| `_tag_schema_meta_table` | cmd_tag.sh:248 | awk (inline + block form) | `.meta.tags \| to_entries[]` |
| `_coverage_spec_dir` | cmd_coverage.sh:81 | awk state machine | `.meta.specification_dir` |
| `_coverage_source_globs` | cmd_coverage.sh:99 | awk (inline + block list) | `.meta.coverage.source[]` |

### Replaced — recursive walks (3 Ruby spots → `yq walk(f)`)

| Function | File | Current | Strategy |
|----------|------|---------|----------|
| `fm_schema_tag_specs` | common.sh:199 | Ruby `YAML.load_file` + recursion | `yq walk(if has("tags") …)` |
| `_doctor_schema_entities` | cmd_doctor.sh:491 | Ruby `YAML.load_file` + recursion | `yq walk(if has("frontmatter") …)` |
| `_doctor_schema_pillar_extras` | cmd_doctor.sh:516 | Ruby `dig` (flat) | `.root.entities \| to_entries[]` |

No `..` recursive descent — use `walk(f)` (safer, supported since yq v4).

### Replaced — frontmatter (2 awk functions → `yq --frontmatter=process`)

| Function | File | Current | `yq` equivalent |
|----------|------|---------|-----------------|
| `fm_scalar` | common.sh:36 | awk YAML block parse | `yq --frontmatter=process '.key' file.md` |
| `fm_list` | common.sh:50 | awk list parse | `yq --frontmatter=process '.key[]' file.md` |

### Kept as-is

- `fm_h1` (not YAML — plain H1 heading)
- `fm_block_list`, `fm_block_extract`, `fm_block_replace`, `fm_block_walk` (marker block mechanics, not YAML)
- `_schema_extract_contract` (filter/stripper for schema diff, not a query)
- All JSON handling (`jq` — hooks.json, API responses)

### Dependencies after migration

| Tool | Status | Used for |
|------|--------|----------|
| `jq` | **mandatory** (unchanged) | JSON: hooks.json, intake API responses |
| `yq` | **mandatory** (new) | YAML: schema.yaml, .md frontmatter |
| `ruby` | **removed** | — |
| `curl` | mandatory (unchanged) | HTTP intake |
| `git` | optional (unchanged) | read-only repo queries |

## Implementation phases

### Phase 1: simple queries (scalars + lists)
Replace the 8 awk queries one by one. Lowest risk — each is a 1:1 substitution.

### Phase 2: frontmatter
Replace `fm_scalar` and `fm_list` with `yq --frontmatter=process`.

### Phase 3: recursive walks
Replace the 3 Ruby spots with `yq walk(f)`. Requires the most care — validate output against each domain schema.

### Phase 4: cleanup
- Remove `command -v ruby` checks and fallbacks
- Remove Ruby from `cumaru doctor` external tools check
- Update docs: `docs/doctor.md`, `docs/install.md`, `docs/intake.md`
- Update README dependencies section
- Update all `cumaru-doctor` SKILL.md files (9 domains) and `cumaru-intake` SKILL.md files

## Validation

For each replacement, compare output between current vs. `yq` on all 6 schemas:

| Schema | Path |
|--------|------|
| base | `frameworks/__base/schema.yaml` |
| sdlc-it-project-basic | `frameworks/sdlc-it-project-basic/schema.yaml` |
| sdlc-light | `frameworks/sdlc-light/schema.yaml` |
| iac-basic | `frameworks/iac-basic/schema.yaml` |
| qa-basic | `frameworks/qa-basic/schema.yaml` |
| vault-memory | `frameworks/vault-memory/schema.yaml` |

Plus test `--frontmatter=process` against actual `.md` files in each framework domain.

## Progress — 2026-07-13

| Phase | Item | Status | Notes |
|-------|------|--------|-------|
| 1.1 | `_doctor_apps_values` | ✅ | `yq '.meta.apps.values[]'` |
| 1.2 | `_doctor_pattern_rules` | ✅ | `capture("\"(?<m>[^\"]*)\"").m // .` |
| 1.3 | `schema_version` (cmd_doctor.sh) | ✅ | `yq '.version'` |
| 1.4 | `_tag_schema_root_keys` | ✅ | `yq '.root.tags \| keys[]'` |
| 1.5 | `_tag_schema_pillar_keys` | ✅ | `yq ".root.entities.\"$p\".tags \| keys[]"` |
| 1.6 | `_tag_schema_meta_table` | ✅ | `yq '.meta.tags \| to_entries[] \| [.key, (.value.host_file // "")] \| @tsv'` |
| 1.7 | `_coverage_spec_dir` | ✅ | `yq '.meta.specification_dir // ""'` |
| 1.8 | `_coverage_source_globs` | ✅ | `yq '.meta.coverage.source[]'` |
| — | `_doctor_orphan_pillars` (bonus) | ✅ | `yq '.root.entities \| keys[]'` |
| 2 | `fm_scalar` | ✅ | `yq --front-matter=extract ".[\"$key\"] // \"\""` |
| 2 | `fm_list` | ✅ | `yq --front-matter=extract ".[\"$key\"][] // \"\""` |
| 2 | `fd_version` (cmd_doctor.sh inline) | ✅ | `yq --front-matter=extract '.["framework-version"] // ""'` |
| 3.1 | `fm_schema_tag_specs` | ✅ | `yq -o=json \| jq -r` (jq `def` + `..`) |
| 3.2 | `_doctor_schema_entities` | ✅ | `yq -o=json \| jq -r` (jq `def`) |
| 3.3 | `_doctor_schema_pillar_extras` | ✅ | `yq '.root.entities \| to_entries[] \| ... \| @tsv'` |
| 4 | Cleanup (ruby dep, tools check, docs) | ✅ | ruby refs removed; yq added to doctor tools check; `.memory/yq_adoption.md` updated |

**yq findings:**
- `yq --frontmatter=process` — works for `.md` frontmatter extraction
- `yq` does **not** support `def` (user-defined functions), `..` (recursive descent), or `try/catch`
- Recursive walks → `yq -o=json | jq -r` pipe (yq parses YAML, jq processes JSON)
- `yq` v4.53+ supports `capture`, `@tsv`, `//` (alternative op)

## Edge cases noted

1. **`_tag_schema_meta_table`** — deals with `{host_file: "*", type: default}` inline objects. `yq` treats them as a regular map — no awk hackery needed.
2. **`_doctor_schema_entities` `path:` resolution** — Ruby uses `edef["path"] || key` to determine segment name. `yq walk(f)` exposes node keys naturally, but the explicit `path:` field needs separate extraction.
3. **`fm_schema_tag_specs` `spec_for` edge case** — `value.keys - ["host_file"]` empty → type defaults to `"default"`. Needs an explicit check in the `yq` expression.
4. **Aggregated output from `walk(f)`** — if `walk` emits a stream of records, they concatenate correctly. If `walk` returns nothing (no matching nodes), output is empty — consistent with current "return 0" behavior.
