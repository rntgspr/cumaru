Include tests/spec/cli/support/helpers.sh

Describe 'installer release resolution, cumaru version, and upgrade --check'
  # Builds a scratch framework repository that stands in for GitHub: `ls-remote`
  # is redirected to it through `insteadOf`, and a PATH-stubbed curl serves
  # tarballs built from it. The installer copy writes only under a scratch HOME.
  version_setup() {
    VERSION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-version-spec.XXXXXX")
    export HOME="$VERSION_TMP/home"
    export GIT_CONFIG_NOSYSTEM=1
    SOURCE_REPO="$VERSION_TMP/source"
    TARBALLS="$VERSION_TMP/tarballs"
    STUB_BIN="$VERSION_TMP/bin"
    DEST="$HOME/.cumaru"
    LINK_DIR="$HOME/.local/bin"
    INSTALLER="$VERSION_TMP/install.sh"

    mkdir -p "$HOME" "$SOURCE_REPO" "$TARBALLS" "$STUB_BIN"
    cp -R "$REPO_ROOT/cumaru" "$REPO_ROOT/src" "$REPO_ROOT/schemas" \
      "$REPO_ROOT/domains" "$REPO_ROOT/skills" "$REPO_ROOT/README.md" "$SOURCE_REPO/"
    git -C "$SOURCE_REPO" init -q -b main
    git -C "$SOURCE_REPO" add -A
    source_git commit -qm sunrise

    sed -e "s#^DEST=.*#DEST=\"$DEST\"#" -e "s#^BIN=.*#BIN=\"$LINK_DIR\"#" \
      "$REPO_ROOT/src/install.sh" > "$INSTALLER"

    # curl stub: serve <tag|main>.tar.gz from $TARBALLS, 404 otherwise.
    cat > "$STUB_BIN/curl" <<EOF
#!/bin/sh
out= url=
while [ \$# -gt 0 ]; do
  case \$1 in
    -o) out=\$2; shift ;;
    -*) ;;
    *) url=\$1 ;;
  esac
  shift
done
file="$TARBALLS/\${url##*/}"
[ -f "\$file" ] || { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
cp "\$file" "\$out"
EOF
    chmod +x "$STUB_BIN/curl"

    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0="url.$SOURCE_REPO.insteadOf"
    export GIT_CONFIG_VALUE_0="https://github.com/rntgspr/cumaru.git"
  }

  version_cleanup() { rm -rf "$VERSION_TMP"; }

  # Runs git in the scratch source repository with a fixed identity.
  source_git() {
    git -C "$SOURCE_REPO" -c user.name=spec -c user.email=spec@example.invalid \
      -c commit.gpgsign=false -c tag.gpgsign=false "$@"
  }

  # Tags the scratch source and publishes its GitHub-style tarball.
  publish_tag() {
    source_git tag "$1"
    git -C "$SOURCE_REPO" archive --format=tar.gz --prefix="cumaru-$1/" HEAD > "$TARBALLS/$1.tar.gz"
  }

  # Publishes the GitHub-style tarball of main.
  publish_main() {
    git -C "$SOURCE_REPO" archive --format=tar.gz --prefix=cumaru-main/ HEAD > "$TARBALLS/main.tar.gz"
  }

  # Runs the rewritten installer copy with the stubbed curl first on PATH.
  run_installer() { PATH="$STUB_BIN:$PATH" /bin/bash "$INSTALLER"; }

  # Lists every path and checksum under the scratch HOME.
  home_state() { (cd "$HOME" && find . -print | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort); }

  # Runs the installed snapshot CLI.
  snapshot_cli() { /bin/bash "$DEST/cumaru" "$@"; }

  BeforeEach 'version_setup'
  AfterEach 'version_cleanup'

  Describe 'installer'
    It 'installs the highest strict X.Y.Z tag and records it in VERSION'
      publish_tag 8.9.9
      publish_tag 9.0.2
      publish_tag 9.0.10
      source_git tag v10.0.0
      When call run_installer
      The status should be success
      The output should include 'Installing cumaru 9.0.10'
      The contents of file "$DEST/VERSION" should equal '9.0.10'
      The path "$LINK_DIR/cumaru" should be symlink
    End

    It 'falls back to main while no release tag exists'
      publish_main
      When call run_installer
      The status should be success
      The output should include 'Installing cumaru main'
      The contents of file "$DEST/VERSION" should equal 'main'
    End

    It 'leaves an existing installation untouched when the download fails'
      source_git tag 9.0.0
      mkdir -p "$DEST"
      printf 'old\n' > "$DEST/marker"
      before=$(home_state)
      When call run_installer
      The status should be failure
      The output should include 'Installing cumaru 9.0.0'
      The error should include 'download failed'
      The value "$(home_state)" should equal "$before"
    End
  End

  Describe 'cumaru version'
    It 'prints the installed release and contract versions'
      publish_tag 9.0.0
      run_installer >/dev/null
      When call snapshot_cli version
      The status should be success
      The output should equal 'version:  9.0.0
contract: 9'
      The error should be blank
    End

    It 'reports a development build from a Git checkout'
      When call /bin/bash "$REPO_ROOT/cumaru" version
      The status should be success
      The output should include 'version:  development build'
      The error should be blank
    End
  End

  Describe 'cumaru upgrade --check'
    It 'reports behind when a newer tag exists and leaves HOME untouched'
      publish_tag 9.0.0
      run_installer >/dev/null
      source_git tag 9.1.0
      before=$(home_state)
      When call snapshot_cli upgrade --check
      The status should be success
      The output should include 'latest:    9.1.0'
      The output should include 'status:    behind'
      The output should include 'upgrade:   cumaru upgrade'
      The value "$(home_state)" should equal "$before"
    End

    It 'reports a main install as behind once a tag exists'
      publish_main
      run_installer >/dev/null
      source_git tag 9.0.0
      When call snapshot_cli upgrade --check
      The status should be success
      The output should include 'installed: main'
      The output should include 'status:    behind'
    End

    It 'reports up to date when the installed tag is the latest'
      publish_tag 9.0.0
      run_installer >/dev/null
      before=$(home_state)
      When call snapshot_cli upgrade --check
      The status should be success
      The output should include 'status:    up to date'
      The value "$(home_state)" should equal "$before"
    End

    It 'reports cannot check with a nonzero status when the remote is unreachable'
      publish_tag 9.0.0
      run_installer >/dev/null
      export GIT_CONFIG_KEY_0="url.$VERSION_TMP/missing.insteadOf"
      before=$(home_state)
      When call snapshot_cli upgrade --check
      The status should equal 1
      The output should not include 'status:'
      The error should include 'cannot check: unable to reach'
      The value "$(home_state)" should equal "$before"
    End

    It 'rejects extra arguments without running the installer'
      When call /bin/bash "$REPO_ROOT/cumaru" upgrade --check now
      The status should equal 2
      The error should include 'Usage: cumaru upgrade --check'
    End
  End
End
