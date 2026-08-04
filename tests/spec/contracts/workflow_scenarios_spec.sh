Include tests/spec/contracts/spec_helper.sh

Describe 'corrected workflow cross-step scenarios'
  BeforeEach 'contract_tmp_setup'
  AfterEach 'contract_tmp_cleanup'

  # Model a bounded Dev handoff followed by Lead-owned DAG reconciliation.
  assigned_task_scenario() {
    domain=$1
    project="$CONTRACT_TMP/$domain-assigned"
    plan="$project/.cumaru/plans/AAA-1234"
    intake="$project/.cumaru/intake/AAA-1234"

    mkdir -p "$plan" "$intake" "$project/unrelated"
    printf '%s\n' '# Acceptance' '' '- The system MUST preserve the request.' >"$intake/index.md"
    printf '%s\n' '# Plan' '' '## Plan / DAG' '' '| T1 | pending |' >"$plan/index.md"
    printf '%s\n' 'status: pending' '# T1' >"$plan/t1.md"
    printf '%s\n' 'unrelated sentinel' >"$project/unrelated/note.md"

    plan_before=$(cksum "$plan/index.md")
    acceptance_before=$(cksum "$intake/index.md")
    unrelated_before=$(cksum "$project/unrelated/note.md")

    sed -i.bak 's/status: pending/status: done/' "$plan/t1.md" && rm "$plan/t1.md.bak"
    printf '%s\n' '# Handoff' '' 'Acceptance evidence: passed.' >"$plan/handoff-t1.md"
    plan_after_dev=$(cksum "$plan/index.md")

    sed -i.bak 's/| T1 | pending |/| T1 | done |/' "$plan/index.md" && rm "$plan/index.md.bak"

    [ "$plan_before" = "$plan_after_dev" ] &&
      grep -Fq 'status: done' "$plan/t1.md" &&
      grep -Fq 'Acceptance evidence: passed.' "$plan/handoff-t1.md" &&
      grep -Fq '| T1 | done |' "$plan/index.md" &&
      [ "$acceptance_before" = "$(cksum "$intake/index.md")" ] &&
      [ "$unrelated_before" = "$(cksum "$project/unrelated/note.md")" ]
  }

  # Apply a durable edit, fail doctor, and prove the transient plan remains.
  failed_post_edit_validation_scenario() {
    project="$CONTRACT_TMP/post-edit-validation"
    mkdir -p "$project"
    (cd "$project" && bash "$CONTRACT_CLI" install --domain sdlc-light) >/dev/null || return

    plan="$project/.cumaru/plans/maintenance-auth"
    spec="$project/.cumaru/specs/auth"
    mkdir -p "$plan" "$spec"
    cat >"$plan/index.md" <<'EOF'
---
human_revised: false
scope: [auth]
status: done
summary: Completed authentication maintenance plan awaiting guarded absorption.
targets: [platform]
aux: []
---
# Authentication maintenance

## Acceptance Criteria (EARS / RFC 2119)

- The system MUST preserve authenticated sessions.
EOF
    cat >"$spec/index.md" <<'EOF'
---
human_revised: false
name: Authentication
summary: Authentication requirements after a pending durable workflow edit.
depends-on: []
relates: []
targets: [platform]
---
# Authentication

<!-- cumaru:reference -->
| Link | Description |
|---|---|
| [session](src/session.ts) | Pending durable reference. |
EOF
    cp -R "$plan" "$CONTRACT_TMP/plan-before"

    (cd "$project" && bash "$CONTRACT_CLI" doctor) >"$CONTRACT_TMP/doctor.out" 2>&1
    status=$?

    [ "$status" -eq 1 ] &&
      grep -Fq 'Configured v9 tree contracts are invalid' "$CONTRACT_TMP/doctor.out" &&
      diff -r "$CONTRACT_TMP/plan-before" "$plan" >/dev/null &&
      grep -Fq 'Pending durable reference.' "$spec/index.md"
  }

  Context 'with a dispatched delivery-domain task'
    Parameters
      sdlc-full
      iac-basic
      qa-basic
    End

    It 'carries an assigned task through Dev evidence and Lead DAG reconciliation in $1'
      When call assigned_task_scenario "$1"
      The status should be success
      The stdout should equal ''
      The stderr should equal ''
    End
  End

  It 'preserves transient work when validation fails after a durable edit'
    When call failed_post_edit_validation_scenario
    The status should be success
    The stdout should equal ''
    The stderr should equal ''
  End
End
