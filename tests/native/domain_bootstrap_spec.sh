Include tests/native/helpers.sh

Describe 'shipped domain bootstrap documents'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  # Installs each shipped domain and reports any whose bootstrap lacks a domain body.
  domains_without_body() {
    for dir in "$REPO_ROOT"/domains/*/; do
      domain=$(basename "$dir")
      [ "$domain" = __base ] && continue
      rm -rf "$PROJECT/.cumaru"
      cli install --domain "$domain" >/dev/null 2>&1 || { printf 'install failed: %s\n' "$domain"; continue; }

      output=$(cli bootstrap 2>&1) || { printf 'bootstrap failed: %s\n' "$domain"; continue; }
      printf '%s\n' "$output" | grep -Fq "## $domain — bootstrap steps" || printf 'no body: %s\n' "$domain"
      printf '%s\n' "$output" | grep -Fq 'ships no bootstrap.md' && printf 'absence note: %s\n' "$domain"
    done
    return 0
  }

  It 'prints a domain body, never the absence note, for every domain'
    When call domains_without_body
    The output should equal ''
  End

  # Lists every pillar directory and template a domain bootstrap.md does not name.
  coverage_gaps() {
    for dir in "$REPO_ROOT"/domains/*/; do
      domain=$(basename "$dir")
      [ "$domain" = __base ] && continue
      doc="${dir}bootstrap.md"
      [ -f "$doc" ] || { printf '%s: missing bootstrap.md\n' "$domain"; continue; }

      for pillar in $(yq '.root | keys | .[]' "${dir}config.yaml"); do
        [ -d "$dir$pillar" ] || continue
        grep -Fq "\`$pillar/" "$doc" || printf '%s: pillar %s\n' "$domain" "$pillar"
      done

      for tpl in "$dir"templates/*.md; do
        name=$(basename "$tpl")
        [ "$name" = index.md ] && continue
        grep -Fq "templates/$name" "$doc" || printf '%s: template %s\n' "$domain" "$name"
      done
    done
  }

  It 'names every pillar directory and template in each domain bootstrap.md'
    When call coverage_gaps
    The output should equal ''
  End

  # Reports domain install skills that restate steps instead of pointing to cumaru bootstrap.
  install_skills_off_contract() {
    for skill in "$REPO_ROOT"/domains/*/skills/cumaru-install/SKILL.md; do
      case $skill in */__base/*) continue ;; esac
      grep -Fq 'Run `cumaru bootstrap`' "$skill" || printf 'no pointer: %s\n' "$skill"
      grep -Eq '^## (Post-install|Configure project context)' "$skill" && printf 'restated steps: %s\n' "$skill"
    done
    return 0
  }

  It 'points every domain install skill to cumaru bootstrap'
    When call install_skills_off_contract
    The output should equal ''
  End
End
