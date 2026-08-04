Include tests/spec/contracts/spec_helper.sh

Describe 'Terraform refresh safety contract'
  SKILL="$CONTRACT_ROOT/skills/terraform/SKILL.md"
  DEV_ROLE="$CONTRACT_ROOT/domains/iac-basic/roles/dev.md"

  It 'uses refresh-only planning for drift inspection without state reconciliation'
    The contents of file "$SKILL" should include 'terraform plan -refresh-only'
    The value "$(file_has_compact_text "$SKILL" 'This proposes state and root-output changes without committing them.'; printf '%s' $?)" should equal 0
    The value "$(file_has_compact_text "$SKILL" 'A request to inspect drift stops here; it does not authorize state reconciliation.'; printf '%s' $?)" should equal 0
  End

  It 'separates reviewed and authorized state reconciliation from inspection'
    The contents of file "$SKILL" should include 'terraform apply -refresh-only'
    The value "$(file_has_compact_text "$SKILL" 'reconcile them only with explicit authorization'; printf '%s' $?)" should equal 0
    The value "$(file_has_compact_text "$DEV_ROLE" 'state reconciliation requires separate explicit user authorization.'; printf '%s' $?)" should equal 0
  End

  It 'identifies refresh as mutating automatic approval instead of an inspection fallback'
    The value "$(file_has_compact_text "$SKILL" '`terraform apply -refresh-only -auto-approve`: it writes state without an approval prompt.'; printf '%s' $?)" should equal 0
    The value "$(file_has_compact_text "$SKILL" 'Terraform added `-refresh-only` in v0.15.4.'; printf '%s' $?)" should equal 0
    The value "$(file_has_compact_text "$SKILL" 'never fall back to the mutating `refresh` command without a separate, explicit authorization.'; printf '%s' $?)" should equal 0
    The contents of file "$SKILL" should not include '`terraform refresh` (or `plan -refresh-only`)'
  End
End
