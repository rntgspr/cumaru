#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-migrate-v6.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

for domain in __base sdlc-full sdlc-light iac-basic qa-basic vault-memory; do
  manifest="$ROOT/domains/$domain/migrations/v5-to-v6.tsv"
  [[ -f "$manifest" ]] || fail "missing v5-to-v6 adapter for $domain"
  awk -F'\t' '
    /^#/ || NF == 0 { next }
    NF != 5 || $1 != "remove" || $2 == "" || $3 == "" || $4 !~ /^\./ { exit 1 }
    { pair=$2 "#" $3; if (seen[pair]++) exit 1 }
  ' "$manifest" || fail "invalid or duplicate manifest rows for $domain"
done
grep -q $'archive/index.md\tarchive\t.root.entities.archive.tags.archive\ttopology/index.md:absorptions' "$ROOT/domains/iac-basic/migrations/v5-to-v6.tsv" || fail "IaC absorption mapping is missing"
grep -q $'archive/index.md\tarchive\t.root.entities.archive.tags.archive\tcoverage/index.md:absorptions' "$ROOT/domains/qa-basic/migrations/v5-to-v6.tsv" || fail "QA absorption mapping is missing"
! grep -q $'\trelations\t' "$ROOT/domains/vault-memory/migrations/v5-to-v6.tsv" || fail "Vault relations must not be structural"
pass "all known v5 domains have explicit structural adapters"

make_source() {
  local dir="$1"
  mkdir -p "$dir/src" "$dir/domains/__base/migrations" \
    "$dir/domains/__base/roles" "$dir/domains/__base/skills/cumaru-update" \
    "$dir/domains/__base/commands/cumaru"
  cat > "$dir/cumaru" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "doctor" ]]; then
  [[ "$(yq '.version' .cumaru/schema.yaml)" == "6" ]] || exit 1
  [[ "$(yq --front-matter=extract '.["framework-version"]' .cumaru/index.md)" == "6" ]] || exit 1
  exit 0
fi
exit 2
EOF
  cat > "$dir/src/common.sh" <<'EOF'
_cumaru_hook_block() {
  cat <<'BLOCK'
<!-- BEGIN CUMARU-HOOK -->
## `.cumaru/` framework

Read `.cumaru/index.md` and `.cumaru/domain.md`, then navigate with `cumaru tree`.
<!-- END CUMARU-HOOK -->
BLOCK
}
EOF
  cat > "$dir/domains/__base/schema.yaml" <<'EOF'
version: 6
domain: base
rules:
  markdown:
    required_heading: h1
    frontmatter: [human_revised!, summary!]
  index_md:
    frontmatter: [generated!, apps!]
  pillar_index:
    frontmatter: [generated!, apps!]
root:
  frontmatter: [framework-version!]
  tags: {}
  entities: {}
meta:
  apps:
    values: [meta]
  tags:
    root: {host_file: domain.md, type: prose}
    touched: {host_file: "*", type: default}
  migrations:
    v6:
      removable_structural_tags:
        - [roles/index.md, roles]
EOF
  cat > "$dir/domains/__base/index.md" <<'EOF'
---
human_revised: false
summary: Universal framework entry point and navigation contract for this project.
generated: false
framework-version: 6
apps: [meta]
---

# `.cumaru/`
EOF
  cat > "$dir/domains/__base/domain.md" <<'EOF'
---
human_revised: false
summary: Minimal base domain context for projects with custom local extensions.
generated: false
apps: [meta]
---

# Base domain
EOF
  cat > "$dir/domains/__base/roles/index.md" <<'EOF'
---
human_revised: false
summary: Available agent roles and their responsibilities within this project.
generated: false
apps: [meta]
---

# Roles
EOF
  cat > "$dir/domains/__base/roles/admin.md" <<'EOF'
---
human_revised: false
summary: Framework administrator role with full project maintenance authority.
generated: false
apps: [meta]
---

# Admin
EOF
  cat > "$dir/domains/__base/skills/cumaru-update/SKILL.md" <<'EOF'
---
name: cumaru-update
description: Update framework-owned project artifacts safely.
---
# Update
EOF
  cat > "$dir/domains/__base/commands/cumaru/update.md" <<'EOF'
---
description: Update framework artifacts.
---
Run `cumaru update`.
EOF
  cp "$ROOT/domains/__base/migrations/v5-to-v6.tsv" "$dir/domains/__base/migrations/v5-to-v6.tsv"
}

make_project() {
  local dir="$1"
  mkdir -p "$dir/.cumaru/roles" "$dir/.cumaru/local-support" \
    "$dir/.agents/skills/custom-tool" "$dir/.agents/skills/cumaru-old" "$dir/.agents/hooks"
  cat > "$dir/.cumaru/schema.yaml" <<'EOF'
version: 5
domain: base
rules:
  markdown:
    required_heading: h1
    frontmatter: [human_revised!]
  pillar_index:
    frontmatter: [generated!, generated-at!, apps!]
  adopter-rule:
    severity: warning
    custom: keep-me
root:
  frontmatter: [framework-version!]
  tags: {}
  entities:
    local_support:
      path: local-support
      frontmatter: [supports, contradicts, supersedes, part-of]
      tags:
        local-links: prose
meta:
  apps:
    values: [custom-app, meta]
  tags:
    roles: {host_file: roles/index.md, type: default}
    root: {host_file: domain.md, type: prose}
    "files:touched": {host_file: "*", type: default}
    custom-tag: {host_file: "*", type: mixed}
    relations: {host_file: "*", type: default}
  adopter-region:
    nested: keep-me
EOF
  cat > "$dir/.cumaru/index.md" <<'EOF'
---
human_revised: true
generated: false
framework-version: 5
apps: [meta]
---

# Local kernel prose

Keep this local kernel prose exactly.
EOF
  cat > "$dir/.cumaru/domain.md" <<'EOF'
---
human_revised: true
generated: false
apps: [meta]
---

<!-- cumaru:root -->
Adopter-owned orientation that must remain unchanged.
<!-- /cumaru:root -->

# Local base domain

Keep this adopter domain prose exactly.
EOF
  cat > "$dir/.cumaru/roles/index.md" <<'EOF'
---
human_revised: true
generated: false
generated-at: 2026-01-01T00:00:00Z
apps: [meta]
---

<!-- cumaru:roles -->
| Link | Description |
|------|-------------|
| [admin](admin.md) | Administrator role that owns framework and project maintenance decisions. |
<!-- /cumaru:roles -->

# Local roles

Keep the local roles prose exactly.
EOF
  cat > "$dir/.cumaru/roles/admin.md" <<'EOF'
---
human_revised: true
generated: false
apps: [meta]
---

# Local admin

Local role prose remains authoritative.
EOF
  cat > "$dir/.cumaru/local-support/index.md" <<'EOF'
---
human_revised: true
summary: Adopter-owned support notes and opaque custom marker content remain here.
generated: false
apps: [custom-app]
---

<!-- cumaru:custom-tag -->
opaque body | with punctuation and no structural meaning
<!-- /cumaru:custom-tag -->

<!-- cumaru:relations -->
| Link | Description |
|------|-------------|
| [related](../domain.md) | Durable Vault-style relation body that must remain byte-stable. |
<!-- /cumaru:relations -->

<!-- cumaru:local-links -->
Local opaque links contract retained without structural interpretation.
<!-- /cumaru:local-links -->

<!-- cumaru:files:touched -->
| Link | Description |
|------|-------------|
| [changed](changed.txt) | Legacy touched-file marker retained across migration. |
<!-- /cumaru:files:touched -->

# Local support
EOF
  cat > "$dir/.agents/AGENTS.md" <<'EOF'
# Existing adopter instructions

Keep this line.

<!-- BEGIN CUMARU-HOOK -->
old framework instructions
<!-- END CUMARU-HOOK -->
EOF
  printf 'custom skill\n' > "$dir/.agents/skills/custom-tool/SKILL.md"
  printf 'old framework skill\n' > "$dir/.agents/skills/cumaru-old/SKILL.md"
  printf '#!/usr/bin/env bash\nprintf old\n' > "$dir/.agents/hooks/context-loader.sh"
  cat > "$dir/.agents/hooks.json" <<'EOF'
{"adopter":{"keep":true},"hooks":{"UserPromptSubmit":[]}}
EOF
}

run_migrate() {
  local project="$1" source="$2" output="$3"; shift 3
  (cd "$project" && env "$@" bash "$ROOT/cumaru" migrate v6 --from "$source" --apply) > "$output" 2>&1
}

SOURCE="$TMP/source"; make_source "$SOURCE"
PROJECT="$TMP/project"; make_project "$PROJECT"
cp -R "$PROJECT" "$TMP/project-before-dry"
(cd "$PROJECT" && bash "$ROOT/cumaru" migrate v6 --from "$SOURCE") > "$TMP/dry.out" 2>&1 || { sed 's/^/  /' "$TMP/dry.out" >&2; fail "complete dry-run was blocked"; }
diff -ru "$TMP/project-before-dry" "$PROJECT" >/dev/null || fail "dry-run changed live project paths"
grep -q 'summary:description' "$TMP/dry.out" || fail "dry-run did not inventory Description summary source"
grep -q 'structural blocks removed: 1' "$TMP/dry.out" || fail "dry-run did not inventory structural manifest"
pass "dry-run inventories without writes"

run_migrate "$PROJECT" "$SOURCE" "$TMP/apply.out" || { sed 's/^/  /' "$TMP/apply.out" >&2; fail "v6 apply failed"; }
[[ "$(yq '.version' "$PROJECT/.cumaru/schema.yaml")" == "6" ]] || fail "schema version was not committed"
[[ "$(yq --front-matter=extract '.["framework-version"]' "$PROJECT/.cumaru/index.md")" == "6" ]] || fail "framework-version was not committed"
grep -q 'Administrator role that owns framework' "$PROJECT/.cumaru/roles/admin.md" || fail "Description summary was not backfilled"
! grep -q '<!-- cumaru:roles -->' "$PROJECT/.cumaru/roles/index.md" || fail "manifest structural block survived"
grep -q 'Adopter-owned orientation' "$PROJECT/.cumaru/domain.md" || fail "retained root tag body changed"
grep -q 'Keep this adopter domain prose exactly' "$PROJECT/.cumaru/domain.md" || fail "local prose changed"
grep -q 'opaque body | with punctuation' "$PROJECT/.cumaru/local-support/index.md" || fail "custom tag body changed"
grep -q 'Durable Vault-style relation body' "$PROJECT/.cumaru/local-support/index.md" || fail "Vault relations body changed"
grep -q '<!-- cumaru:touched -->' "$PROJECT/.cumaru/local-support/index.md" || fail "touched marker was not simplified"
! grep -q 'cumaru:files:touched' "$PROJECT/.cumaru/local-support/index.md" || fail "legacy touched marker survived"
[[ "$(yq '.meta.tags.touched.type' "$PROJECT/.cumaru/schema.yaml")" == "default" ]] || fail "touched tag contract was not installed"
[[ "$(yq '.meta.tags."files:touched"' "$PROJECT/.cumaru/schema.yaml")" == "null" ]] || fail "legacy touched tag contract survived"
[[ "$(yq '.meta.adopter-region.nested' "$PROJECT/.cumaru/schema.yaml")" == "keep-me" ]] || fail "unknown meta region was lost"
[[ "$(yq '.rules.adopter-rule.custom' "$PROJECT/.cumaru/schema.yaml")" == "keep-me" ]] || fail "custom rule was lost"
[[ "$(yq '.root.entities.local_support.tags.local-links' "$PROJECT/.cumaru/schema.yaml")" == "prose" ]] || fail "custom root entity/tag was lost"
[[ "$(yq '.root.entities.local_support.frontmatter | contains(["supports", "contradicts", "supersedes", "part-of"])' "$PROJECT/.cumaru/schema.yaml")" == "true" ]] || fail "Vault graph fields were lost"
[[ "$(yq '.meta.tags.custom-tag.type' "$PROJECT/.cumaru/schema.yaml")" == "mixed" ]] || fail "custom tag contract was lost"
[[ -f "$PROJECT/.agents/skills/custom-tool/SKILL.md" ]] || fail "adopter skill was lost"
[[ -f "$PROJECT/.agents/skills/cumaru-update/SKILL.md" && ! -e "$PROJECT/.agents/skills/cumaru-old" ]] || fail "framework skills did not replace as a set"
grep -q 'printf old' "$PROJECT/.agents/hooks/context-loader.sh" || fail "adopter-owned hook was changed"
jq -e '.adopter.keep == true' "$PROJECT/.agents/hooks.json" >/dev/null || fail "adopter hook config was lost"
grep -q 'Keep this line' "$PROJECT/.agents/AGENTS.md" || fail "adopter instruction prose was lost"
pass "apply preserves adopter data and replaces framework artifacts"

cp -R "$PROJECT" "$TMP/project-before-noop"
(cd "$PROJECT" && bash "$ROOT/cumaru" migrate v6 --from "$SOURCE") > "$TMP/noop.out" 2>&1 || fail "validated v6 rerun failed"
grep -q 'already complete' "$TMP/noop.out" || fail "rerun was not reported as a validated no-op"
diff -ru "$TMP/project-before-noop" "$PROJECT" >/dev/null || fail "validated no-op changed bytes"
pass "idempotence requires and passes v6 postconditions"

make_ledger_source() {
  local dir="$1"
  make_source "$dir"
  cp -R "$dir/domains/__base" "$dir/domains/iac-basic"
  yq -i '
    .domain = "iac-basic" |
    .root.entities.archive = {"tags": {}} |
    .root.entities.topology = {"tags": {"absorptions": ["SHA", "KEY", "Description"]}} |
    .meta.migrations.v6.removable_structural_tags = [["archive/index.md", "archive"]]
  ' "$dir/domains/iac-basic/schema.yaml"
  cat > "$dir/domains/iac-basic/migrations/v5-to-v6.tsv" <<'EOF'
# action	host	tag	schema-path	ledger
remove	archive/index.md	archive	.root.entities.archive.tags.archive	topology/index.md:absorptions
EOF
  mkdir -p "$dir/domains/iac-basic/archive" "$dir/domains/iac-basic/topology"
  cat > "$dir/domains/iac-basic/archive/index.md" <<'EOF'
---
human_revised: false
summary: Transient archive staging for infrastructure changes awaiting absorption.
generated: true
apps: [meta]
---
# Archive
EOF
  cat > "$dir/domains/iac-basic/topology/index.md" <<'EOF'
---
human_revised: false
summary: Durable infrastructure topology and its historical absorption ledger.
generated: true
apps: [meta]
---

<!-- cumaru:absorptions -->
| SHA | KEY | Description |
|-----|-----|-------------|
<!-- /cumaru:absorptions -->

# Topology
EOF
}

make_ledger_project() {
  local dir="$1"
  make_project "$dir"
  rm -rf "$dir/.cumaru/roles"
  yq -i '
    .domain = "iac-basic" |
    del(.meta.tags.roles) |
    .root.entities.archive = {"tags": {"archive": "default"}} |
    .root.entities.topology = {"tags": {}}
  ' "$dir/.cumaru/schema.yaml"
  mkdir -p "$dir/.cumaru/archive" "$dir/.cumaru/topology"
  cat > "$dir/.cumaru/archive/index.md" <<'EOF'
---
human_revised: true
generated: true
generated-at: 2026-01-01T00:00:00Z
apps: [meta]
---

<!-- cumaru:archive -->
| Link | Description |
|------|-------------|
| [INFRA-42](INFRA-42/index.md) | Absorbed-in: abcdef1234567890; durable network boundary changes. |
<!-- /cumaru:archive -->

# Archive
EOF
  cat > "$dir/.cumaru/topology/index.md" <<'EOF'
---
human_revised: true
generated: true
generated-at: 2026-01-01T00:00:00Z
apps: [meta]
---
# Topology
EOF
}

LEDGER_SOURCE="$TMP/ledger-source"; make_ledger_source "$LEDGER_SOURCE"
LEDGER_PROJECT="$TMP/ledger-project"; make_ledger_project "$LEDGER_PROJECT"
run_migrate "$LEDGER_PROJECT" "$LEDGER_SOURCE" "$TMP/ledger.out" || { sed 's/^/  /' "$TMP/ledger.out" >&2; fail "IaC ledger migration failed"; }
grep -q '| abcdef1234567890 | INFRA-42 |' "$LEDGER_PROJECT/.cumaru/topology/index.md" || fail "IaC archive row was not moved to absorptions"
! grep -q '<!-- cumaru:archive -->' "$LEDGER_PROJECT/.cumaru/archive/index.md" || fail "IaC archive structural block survived"
pass "IaC durable archive rows migrate to topology absorptions"

ROLLBACK="$TMP/rollback"; make_project "$ROLLBACK"; cp -R "$ROLLBACK" "$TMP/rollback-before"
if run_migrate "$ROLLBACK" "$SOURCE" "$TMP/rollback.out" CUMARU_MIGRATE_FAIL_AT=agents-installed; then fail "fault-injected migration succeeded"; fi
diff -ru "$TMP/rollback-before" "$ROLLBACK" >/dev/null || fail "rollback did not restore .cumaru and .agents exactly"
pass "fault-injected swap rolls back both live paths"

CRASHED="$TMP/crashed"; make_project "$CRASHED"; cp -R "$CRASHED" "$TMP/crashed-before"
CRASH_STAGE="$CRASHED/.cumaru-migrate.interrupted"; mkdir -p "$CRASH_STAGE/project"
mv "$CRASHED/.cumaru" "$CRASH_STAGE/backup-tree"; mv "$CRASHED/.agents" "$CRASH_STAGE/backup-agents"
CRASHED_REAL=$(cd "$CRASHED" && pwd -P)
cat > "$CRASH_STAGE/rollback.journal" <<EOF
transaction=started
input=$CRASHED_REAL/.cumaru
tree=backed-up
agents=backed-up
EOF
(cd "$CRASHED" && bash "$ROOT/cumaru" migrate v6 --from "$SOURCE") > "$TMP/crash-recovery.out" 2>&1 || { sed 's/^/  /' "$TMP/crash-recovery.out" >&2; fail "interrupted journal recovery failed"; }
grep -q 'interrupted migration rolled back' "$TMP/crash-recovery.out" || fail "interrupted transaction recovery was not reported"
diff -ru "$TMP/crashed-before" "$CRASHED" >/dev/null || fail "journal recovery did not restore both original trees"
pass "persistent journal recovers an untrappable interrupted transaction"

LEGACY="$TMP/legacy"; make_project "$LEGACY"; mv "$LEGACY/.cumaru" "$LEGACY/.llm"
run_migrate "$LEGACY" "$SOURCE" "$TMP/legacy.out" || { sed 's/^/  /' "$TMP/legacy.out" >&2; fail "legacy rename composition failed"; }
[[ -d "$LEGACY/.cumaru" && ! -e "$LEGACY/.llm" ]] || fail "legacy input did not atomically become .cumaru"
[[ "$(yq '.version' "$LEGACY/.cumaru/schema.yaml")" == "6" ]] || fail "legacy composition did not finish v6 migration"
pass "unambiguous .llm input composes rename with v6 migration"

BLOCKED="$TMP/blocked"; make_project "$BLOCKED"
cat > "$BLOCKED/.cumaru/local-support/unsummarized.md" <<'EOF'
---
human_revised: true
generated: false
apps: [custom-app]
---
# Ambiguous local note
EOF
cp -R "$BLOCKED" "$TMP/blocked-before"
if (cd "$BLOCKED" && bash "$ROOT/cumaru" migrate v6 --from "$SOURCE" --apply) > "$TMP/blocked.out" 2>&1; then fail "unsummarized local file did not block apply"; fi
grep -q 'needs LLM summarization' "$TMP/blocked.out" || fail "summary blocker was not diagnosed"
diff -ru "$TMP/blocked-before" "$BLOCKED" >/dev/null || fail "blocked apply changed live paths"
pass "ambiguous local summaries block before writes"

UNKNOWN="$TMP/unknown"; make_project "$UNKNOWN"; yq -i '.domain = "custom-domain"' "$UNKNOWN/.cumaru/schema.yaml"; cp -R "$UNKNOWN" "$TMP/unknown-before"
if (cd "$UNKNOWN" && bash "$ROOT/cumaru" migrate v6 --from "$SOURCE" --apply) > "$TMP/unknown.out" 2>&1; then fail "unsupported custom domain was accepted"; fi
grep -q 'unsupported custom/unknown domain' "$TMP/unknown.out" || fail "unsupported domain was not diagnosed"
diff -ru "$TMP/unknown-before" "$UNKNOWN" >/dev/null || fail "unsupported domain wrote before abort"
pass "unsupported custom domains abort before writes"

REAL_SOURCE_PROJECT="$TMP/real-source-project"; make_project "$REAL_SOURCE_PROJECT"
run_migrate "$REAL_SOURCE_PROJECT" "$ROOT" "$TMP/real-source.out" || { sed 's/^/  /' "$TMP/real-source.out" >&2; fail "migration against repository v6 source failed"; }
(cd "$REAL_SOURCE_PROJECT" && bash "$ROOT/cumaru" doctor --quiet) > "$TMP/real-source-doctor.out" 2>&1 || { sed 's/^/  /' "$TMP/real-source-doctor.out" >&2; fail "real v6 doctor rejected migrated fixture"; }
pass "repository v6 source and doctor accept the migrated fixture"
