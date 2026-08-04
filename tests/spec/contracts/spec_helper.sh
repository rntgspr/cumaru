CONTRACT_ROOT=${SHELLSPEC_PROJECT_ROOT:-$(pwd)}
CONTRACT_CLI="$CONTRACT_ROOT/cumaru"

contract_tmp_setup() {
  CONTRACT_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cumaru-shellspec.XXXXXX")
}

contract_tmp_cleanup() {
  rm -rf "$CONTRACT_TMP"
}

make_migration_project() {
  name=$1
  domain=$2
  project="$CONTRACT_TMP/$name"
  mkdir -p "$project/.cumaru"
  printf 'version: 6\ndomain: %s\n' "$domain" >"$project/.cumaru/schema.yaml"
  printf '%s\n' '---' 'framework-version: 6' \
    'summary: Root index for a synthetic migration fixture used by the cumaru test suite.' \
    '---' '' '# Root' >"$project/.cumaru/index.md"
  printf '%s\n' "$project"
}

file_has() {
  grep -Fq "$2" "$1"
}

file_lacks() {
  ! grep -Eq "$2" "$1"
}

files_equal() {
  cmp -s "$1" "$2"
}

file_has_exact_line() {
  grep -Fqx -- "$2" "$1"
}

project_manifest() {
  root=$1
  (
    cd "$root" || exit 1
    find . -print | LC_ALL=C sort | while IFS= read -r path; do
      if [ -d "$path" ]; then
        printf 'd\t%s\n' "$path"
      elif [ -L "$path" ]; then
        printf 'l\t%s\t%s\n' "$path" "$(readlink "$path")"
      else
        printf 'f\t%s\t' "$path"
        shasum "$path"
      fi
    done
  )
}
