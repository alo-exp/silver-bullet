#!/usr/bin/env bash
set -euo pipefail

ledger_header() {
  local ledger_file="$1"
  cat > "$ledger_file" <<'EOF'
# Silver Bullet Inline Coverage Ledger

EOF
}

init_coverage_ledger() {
  local ledger_file="$1"
  mkdir -p "$(dirname "$ledger_file")"
  ledger_header "$ledger_file"
}

ledger_append() {
  local ledger_file="$1"
  local surface="$2"
  local summary="$3"
  local issue="$4"
  local evidence="$5"

  printf '## %s\n- summary: %s\n- issue: %s\n- evidence: %s\n\n' \
    "$surface" "$summary" "$issue" "$evidence" >> "$ledger_file"
}

ledger_has_surface() {
  local ledger_file="$1"
  local surface="$2"
  grep -q "^## ${surface}$" "$ledger_file"
}

ledger_require_all() {
  local ledger_file="$1"
  shift
  local surface
  for surface in "$@"; do
    if ! ledger_has_surface "$ledger_file" "$surface"; then
      return 1
    fi
  done
}

