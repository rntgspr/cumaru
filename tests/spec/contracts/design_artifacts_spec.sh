Include tests/spec/contracts/spec_helper.sh

Describe 'design domain authoring contracts'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  # Resolve literal skill and template dependencies from the shipped recipes.
  check_design_references() {
    local domain="$CONTRACT_ROOT/domains/design-as-code" reference
    local references skill sources=("$domain/templates" "$domain/roles"
      "$domain/intake" "$domain/research" "$domain/assets" "$domain/plans"
      "$domain/specs" "$domain/concepts" "$domain/domain.md")
    for skill in "$domain"/skills/*/SKILL.md; do
      reference=${skill#"$domain"/}
      # Universal recipes discuss other domains; validate domain-owned recipes here.
      if [[ "$reference" != skills/cumaru-install/SKILL.md &&
        -f "$CONTRACT_ROOT/domains/__base/$reference" ]]; then
        continue
      fi
      sources+=("$skill")
    done

    references=$(grep -rhoE 'templates/[a-z-]+\.md|cumaru-[a-z-]+' \
      "${sources[@]}" | sort -u)

    while IFS= read -r reference; do
      case "$reference" in
        cumaru-*)
          if [[ -f "$domain/disciplines/$reference.md" ]]; then
            reference="disciplines/$reference.md"
          else
            reference="skills/$reference/SKILL.md"
          fi
          ;;
      esac
      test -f "$domain/$reference" || {
        printf 'missing design dependency: %s\n' "$reference"
        return 1
      }
    done <<< "$references"
  }

  # Compare entity template keys to the actual domain configuration contract.
  check_design_template_metadata() {
    local domain="${1:-$CONTRACT_ROOT/domains/design-as-code}" template node keys actual required key
    while IFS='|' read -r template node; do
      keys=$(yq -r "$node.frontmatter | to_entries[] | select(.value.optional != true) | .key + \"!\", ($node.frontmatter | to_entries[] | select(.value.optional == true) | .key)" "$domain/config.yaml") || return
      actual=$(yq --front-matter=extract -r 'keys | .[]' "$domain/templates/$template.md") || return
      required=$(printf '%s\n' "$keys" | sed -n 's/!$//p')

      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        printf '%s\n' "$actual" | grep -Fxq "$key" || {
          printf '%s: missing required key %s\n' "$template" "$key"
          return 1
        }
      done <<< "$required"

      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        case "$key" in human_revised|summary) continue ;; esac
        printf '%s\n' "$keys" | sed 's/!$//' | grep -Fxq "$key" || {
          printf '%s: undeclared key %s\n' "$template" "$key"
          return 1
        }
      done <<< "$actual"
    done <<'MAPPINGS'
intake-brief|.root.intake."*.md"
research|.root.research."*"
concept|.root.concepts."*"
plan|.root.plans."*"
task|.root.plans."*"."t*.md"
handoff|.root.plans."*"."handoff-t*.md"
delta-draft|.root.plans."*"."delta-draft.md"
spec|.root.specs."*"
spec|.root.specs."*"."*.md"
bootstrap|.root.specs."*"."*.md"
asset|.root.assets."*.md"
MAPPINGS
  }

  # Compare bootstrap working-note metadata to each configured concern destination.
  check_bootstrap_template_metadata() {
    local domain node keys actual required key
    while IFS='|' read -r domain node; do
      keys=$(yq -r "$node.frontmatter | to_entries[] | select(.value.optional != true) | .key + \"!\", ($node.frontmatter | to_entries[] | select(.value.optional == true) | .key)" \
        "$CONTRACT_ROOT/domains/$domain/config.yaml") || return
      actual=$(yq --front-matter=extract -r 'keys | .[]' \
        "$CONTRACT_ROOT/domains/$domain/templates/bootstrap.md") || return
      required=$(printf '%s\n' "$keys" | sed -n 's/!$//p')

      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        printf '%s\n' "$actual" | grep -Fxq "$key" || {
          printf '%s bootstrap: missing required key %s\n' "$domain" "$key"
          return 1
        }
      done <<< "$required"

      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        case "$key" in human_revised|summary) continue ;; esac
        printf '%s\n' "$keys" | sed 's/!$//' | grep -Fxq "$key" || {
          printf '%s bootstrap: undeclared key %s\n' "$domain" "$key"
          return 1
        }
      done <<< "$actual"
    done <<'MAPPINGS'
sdlc-full|.root.specs."*"."*.md"
sdlc-light|.root.specs."*"."*.md"
iac-basic|.root.topology."*"."*.md"
qa-basic|.root.coverage."*"."*.md"
MAPPINGS
  }

  # Prove a valid summary cannot mask missing metadata outside the design domain.
  reject_sdlc_bootstrap_without_required_metadata() {
    local fixture="$CONTRACT_TMP/domains"

    mkdir -p "$fixture"
    cp -R "$CONTRACT_ROOT/domains/sdlc-full" "$fixture/sdlc-full"
    yq -i --front-matter=process 'del(.targets)' \
      "$fixture/sdlc-full/templates/bootstrap.md" || return

    local CONTRACT_ROOT="$CONTRACT_TMP"
    check_bootstrap_template_metadata
  }

  # Validate the native strictness scale used by the discipline authoring recipe.
  check_generated_discipline_strictness() {
    local domain="$CONTRACT_TMP/sdlc-full"

    cp -R "$CONTRACT_ROOT/domains/sdlc-full" "$domain"
    cp "$domain/disciplines/code-comments.md" "$domain/disciplines/generated.md"
    yq -i --front-matter=process '.name = "generated" | .strictness = "7/10"' \
      "$domain/disciplines/generated.md" || return

    bash -c '. "$1/src/common.sh"; SCRIPT_DIR=$1; . "$1/src/agent_adapter.sh"; . "$1/src/schema.sh"; schema_validate_domain "$2" sdlc-full' \
      _ "$CONTRACT_ROOT" "$domain" >/dev/null || return

    yq -i --front-matter=process '.strictness = "7"' \
      "$domain/disciplines/generated.md" || return
    if bash -c '. "$1/src/common.sh"; SCRIPT_DIR=$1; . "$1/src/agent_adapter.sh"; . "$1/src/schema.sh"; schema_validate_domain "$2" sdlc-full' \
      _ "$CONTRACT_ROOT" "$domain" >"$CONTRACT_TMP/invalid.out" 2>&1; then
      return 1
    fi

    grep -Fq 'strictness must be 0/10 through 10/10; saw 7' \
      "$CONTRACT_TMP/invalid.out"
  }

  # Exercise the IaC working-note destination and topology-shaped delta contract.
  check_iac_topology_template_scenario() {
    local project="$CONTRACT_TMP/iac-project"

    mkdir -p "$project"
    (
      cd "$project" || exit 1
      /bin/bash "$CONTRACT_CLI" install --domain iac-basic >/dev/null || exit
      mkdir -p .cumaru/topology/network
      cp .cumaru/templates/topology.md .cumaru/topology/network/index.md
      cp .cumaru/templates/bootstrap.md .cumaru/topology/network/bootstrap.md
      yq -i --front-matter=process \
        '.name = "Network" | .summary = "Network topology and its external interface." | .depends-on = [] | .relates = [] | .targets = ["dev"]' \
        .cumaru/topology/network/index.md || exit
      yq -i --front-matter=process \
        '.name = "Network discovery" | .summary = "Working evidence for the network topology." | .depends-on = [] | .relates = [] | .targets = ["dev"]' \
        .cumaru/topology/network/bootstrap.md || exit
      /bin/bash "$CONTRACT_CLI" doctor --quiet >/dev/null || exit
    ) || return

    grep -Fq 'following `templates/topology.md`' \
      "$CONTRACT_ROOT/domains/iac-basic/templates/bootstrap.md" &&
      grep -Fq '## Interface' "$CONTRACT_ROOT/domains/iac-basic/templates/bootstrap.md" &&
      grep -Fq '## Dependencies (apply order)' "$CONTRACT_ROOT/domains/iac-basic/templates/bootstrap.md" &&
      grep -Fq 'document Interface / Dependencies / Decisions' \
        "$CONTRACT_ROOT/domains/iac-basic/skills/cumaru-topology/SKILL.md" &&
      grep -Fq '### Added topology facts' \
        "$CONTRACT_ROOT/domains/iac-basic/templates/delta-draft.md" &&
      ! grep -Eq '^#{2,} .*Requirements' \
        "$CONTRACT_ROOT/domains/iac-basic/templates/delta-draft.md"
  }

  # Prove a valid summary cannot mask missing required bootstrap metadata.
  reject_bootstrap_without_required_metadata() {
    local domain="$CONTRACT_TMP/design-as-code"

    cp -R "$CONTRACT_ROOT/domains/design-as-code" "$domain"
    yq -i --front-matter=process 'del(.name)' "$domain/templates/bootstrap.md" || return
    check_design_template_metadata "$domain"
  }

  # Exercise an authored bootstrap note at its configured concern destination.
  check_authored_bootstrap_navigation() {
    local project="$CONTRACT_TMP/project"

    mkdir -p "$project"
    (
      cd "$project" || exit 1
      /bin/bash "$CONTRACT_CLI" install --domain design-as-code >/dev/null || exit
      mkdir -p .cumaru/specs/checkout
      cp .cumaru/templates/spec.md .cumaru/specs/checkout/index.md
      cp .cumaru/templates/bootstrap.md .cumaru/specs/checkout/bootstrap.md
      yq -i --front-matter=process \
        '.name = "Checkout discovery" | .depends-on = [] | .targets = ["meta"]' \
        .cumaru/specs/checkout/bootstrap.md || exit
      /bin/bash "$CONTRACT_CLI" tree specs/checkout --deep >/dev/null || exit
      /bin/bash "$CONTRACT_CLI" doctor --quiet >/dev/null
    )
  }

  # Ensure handoff references separate repository files from knowledge artifacts.
  check_design_handoff_reference_boundaries() {
    local template="$CONTRACT_ROOT/domains/design-as-code/templates/handoff.md"

    grep -Fq 'relative to the project root' "$template" &&
      grep -Fq 'do not use `.cumaru/` paths or paths containing' "$template" &&
      grep -Fq 'Leave the table empty when the task changed only Cumaru knowledge' "$template" &&
      grep -Fq 'outside `touched`' "$template"
  }

  # Keep active-plan context complete but bounded across domain and role guidance.
  check_design_plan_context_contract() {
    local domain="$CONTRACT_ROOT/domains/design-as-code"

    grep -Fq 'The canonical acceptance source' "$domain/domain.md" &&
      grep -Fq 'explicitly linked or listed by the plan, task, or review dispatch' "$domain/domain.md" &&
      grep -Fq 'Asset-only maintenance may use `scope: []` and task `concerns: []`' "$domain/domain.md" &&
      grep -Fq 'Do not load sibling briefs, concepts, research, assets, plans, or' "$domain/domain.md" &&
      ! grep -Fq 'traversal starts from those nodes, nothing else' "$domain/domain.md" &&
      grep -Fq "domain.md\`'s **Plan-scoped entry**" "$domain/roles/lead.md" &&
      grep -Fq "domain.md\`'s **Plan-scoped entry**" "$domain/roles/designer.md" &&
      grep -Fq "domain.md\`'s **Plan-scoped entry**" "$domain/roles/reviewer.md" &&
      grep -Fq '[Brief](../../intake/<KEY>.md)' "$domain/templates/plan.md" &&
      grep -Fq '[Selected concept](../../concepts/<slug>/index.md)' "$domain/templates/plan.md" &&
      grep -Fq '[Research](../../research/<slug>/index.md)' "$domain/templates/plan.md" &&
      grep -Fq 'remove the maintenance-only Overview' "$domain/templates/plan.md" &&
      grep -Fq 'use `scope: []` and task `concerns: []`' "$domain/templates/plan.md" &&
      grep -Fq 'affected asset records' "$domain/templates/task.md" &&
      grep -Fq 'do not restate them as a competing acceptance contract' "$domain/templates/task.md" &&
      grep -Fq 'not switch an active role or expand its permissions' "$domain/domain.md" &&
      grep -Fq 'Execute only the task and allowed files dispatched by Design Lead' "$domain/roles/designer.md" &&
      grep -Fq 'do not implement fixes' "$domain/roles/reviewer.md"
  }

  # Keep tracker choice on adopter-owned briefs instead of canonical index metadata.
  check_design_tracker_ownership() {
    local domain="$CONTRACT_ROOT/domains/design-as-code"

    [ "$(yq --front-matter=extract -r '.tracker // "absent"' "$domain/intake/index.md")" = absent ] &&
      [ "$(yq -r '.root.intake.frontmatter // "absent"' "$domain/config.yaml")" = absent ] &&
      grep -Fq 'There is no project-wide tracker registry on this index' "$domain/intake/index.md" &&
      grep -Fq 'actual tracker in scalar `tracker:`' "$domain/skills/cumaru-intake/SKILL.md" &&
      grep -Fq 'tracker registry on `intake/index.md`' "$domain/skills/cumaru-install/SKILL.md" &&
      grep -Fq 'retire the tracker registry' "$domain/migration.md"
  }

  It 'ships every concrete skill and template dependency'
    When call check_design_references
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'aligns entity template metadata with config'
    When call check_design_template_metadata
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'rejects bootstrap metadata drift even when its summary remains valid'
    When call reject_bootstrap_without_required_metadata
    The status should be failure
    The output should include 'bootstrap: missing required key name'
    The stderr should equal ''
  End

  It 'accepts an authored bootstrap note at the concern destination'
    When call check_authored_bootstrap_navigation
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'aligns every remaining bootstrap template with its concern destination'
    When call check_bootstrap_template_metadata
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'rejects missing bootstrap targets even when summary remains valid'
    When call reject_sdlc_bootstrap_without_required_metadata
    The status should be failure
    The output should include 'sdlc-full bootstrap: missing required key targets'
    The stderr should equal ''
  End

  It 'accepts only the native discipline strictness scale'
    When call check_generated_discipline_strictness
    The status should be success
  End

  It 'keeps IaC bootstrap, deepening, and deltas topology-shaped'
    When call check_iac_topology_template_scenario
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'separates project-file references from delivered knowledge artifacts'
    When call check_design_handoff_reference_boundaries
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'loads only declared plan acceptance, evidence, assets, and spec context'
    When call check_design_plan_context_contract
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End

  It 'stores tracker provenance on briefs rather than the framework index'
    When call check_design_tracker_ownership
    The status should be success
    The output should equal ''
    The stderr should equal ''
  End
End
