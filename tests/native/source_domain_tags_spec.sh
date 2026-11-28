Include tests/native/helpers.sh

Describe 'shipped domain required tags'
  BeforeEach 'native_setup'
  AfterEach 'native_cleanup'

  # Installs each shipped domain and fails when doctor reports a missing required tag.
  missing_required_tags() {
    for domain in __base ai-ccn design-as-code focus homebrew-management iac-basic qa-basic sdlc-full sdlc-light vault-memory; do
      rm -rf "$PROJECT/.cumaru"
      cli install --domain "$domain" >/dev/null 2>&1 || { printf 'install failed: %s\n' "$domain"; continue; }

      cli doctor 2>&1 | grep -F "missing required tag" | sed "s|^|$domain: |"
    done
  }

  It 'ships every tag its config requires on a fresh install'
    When call missing_required_tags
    The output should equal ''
  End
End
