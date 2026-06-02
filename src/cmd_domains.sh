# cmd_domains.sh — list available domains.
#
# Reuses _install_list_domains from cmd_install.sh.

cmd_domains() {
  cat <<'EOF'
Available domains:

EOF
  _install_list_domains | awk -F'\t' '{ printf "  %-26s %s\n", $1, $2 }'
  echo ""
  echo "Install one with: cumaru install --domain <name>"
}
