#!/usr/bin/env bash
# Ledger↔monitor reconciliation for enterprise E2E matrix rounds.
# Parses SB_E2E_LEDGER_FILE workflow table; exit 0 only when rows 1–22 are Pass.
#
# Usage:
#   source scripts/lib/enterprise-e2e-ledger-reconcile.sh
#   enterprise_e2e_ledger_reconcile_ok   # exit 0/1
#   enterprise_e2e_ledger_reconcile_status  # prints: COMPLETE|LEDGER_MISMATCH|STALE|UNREADABLE
#
# Environment:
#   SB_E2E_LEDGER_FILE  Ledger path (default ROUND-1-LEDGER.md)
set -euo pipefail

_enterprise_e2e_ledger_reconcile_root() {
  if [[ -n "${SB_ROOT:-}" ]]; then
    printf '%s\n' "$SB_ROOT"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
  fi
}

enterprise_e2e_ledger_file_path() {
  local root
  root="$(_enterprise_e2e_ledger_reconcile_root)"
  printf '%s\n' "${SB_E2E_LEDGER_FILE:-${root}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
}

# Normalize Pass/Fail cell: strip markdown emphasis and whitespace.
enterprise_e2e_ledger_normalize_status() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | sed -E 's/\*//g; s/^[[:space:]]+//; s/[[:space:]]+$//')"
  printf '%s' "$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
}

enterprise_e2e_ledger_status_is_pass() {
  local norm
  norm="$(enterprise_e2e_ledger_normalize_status "$1")"
  [[ "$norm" == "pass" ]]
}

# Required matrix header columns (failure_class recommended; optional for legacy ledgers).
enterprise_e2e_ledger_required_columns() {
  printf '%s\n' \
    'Pass/Fail' \
    'graphify_query_ref' \
    'agentmemory_export_ref'
}

enterprise_e2e_ledger_header_ok() {
  local ledger="$1" header_line col
  header_line="$(awk '/^\| # \| WF slug \|/{print; exit}' "$ledger" 2>/dev/null || true)"
  [[ -n "$header_line" ]] || return 1
  while IFS= read -r col; do
    [[ -z "$col" ]] && continue
    if ! printf '%s' "$header_line" | grep -qF "$col"; then
      return 1
    fi
  done < <(enterprise_e2e_ledger_required_columns)
  return 0
}

# Emit one line per row: "<num> <status_norm>" for rows 1–22 in workflow matrix table.
enterprise_e2e_ledger_matrix_rows() {
  local ledger="$1"
  awk '
    /^\| # \| WF slug \|/ {
      n = split($0, h, "|")
      for (i = 2; i <= n; i++) {
        col = h[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", col)
        if (col == "Pass/Fail") pass_col = i
      }
      in_table = 1
      next
    }
    in_table && /^\|[-|[:space:]]+\|/ { next }
    in_table && /^\*\*Pass count:/ { in_table = 0 }
    in_table && /^\| [0-9]+ \|/ {
      n = split($0, c, "|")
      if (pass_col == 0 || n < pass_col) next
      row = c[2]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", row)
      status = c[pass_col]
      gsub(/\*/, "", status)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      print row, tolower(status)
    }
  ' "$ledger"
}

# Exit 0 when every Pass row has non-empty graphify_query_ref and agentmemory_export_ref.
enterprise_e2e_ledger_pass_rows_have_refs() {
  local ledger="$1"
  awk '
    /^\| # \| WF slug \|/ {
      n = split($0, h, "|")
      for (i = 2; i <= n; i++) {
        col = h[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", col)
        if (col == "Pass/Fail") pass_col = i
        if (col == "graphify_query_ref") g_col = i
        if (col == "agentmemory_export_ref") a_col = i
      }
      in_table = 1
      next
    }
    in_table && /^\|[-|[:space:]]+\|/ { next }
    in_table && /^\*\*Pass count:/ { in_table = 0 }
    in_table && /^\| [0-9]+ \|/ {
      n = split($0, c, "|")
      if (pass_col == 0 || g_col == 0 || a_col == 0) { missing = 1; next }
      status = c[pass_col]
      gsub(/\*/, "", status)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (tolower(status) != "pass") next
      gref = c[g_col]
      aref = c[a_col]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gref)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", aref)
      if (gref == "" || aref == "") { missing = 1 }
    }
    END { exit missing ? 1 : 0 }
  ' "$ledger"
}

# Prints: pass_count total_rows fail_rows (space-separated on one line).
enterprise_e2e_ledger_pass_summary() {
  local ledger="$1"
  local pass=0 total=0 row status fail_rows=""
  while read -r row status; do
    [[ -z "$row" ]] && continue
    total=$((total + 1))
    if [[ "$status" == "pass" ]]; then
      pass=$((pass + 1))
    else
      fail_rows="${fail_rows}${row},"
    fi
  done < <(enterprise_e2e_ledger_matrix_rows "$ledger")
  printf '%s %s %s\n' "$pass" "$total" "${fail_rows%,}"
}

enterprise_e2e_ledger_reconcile_status() {
  local ledger pass total fail_rows
  ledger="$(enterprise_e2e_ledger_file_path)"
  if [[ ! -f "$ledger" ]]; then
    printf '%s\n' "UNREADABLE"
    return 0
  fi
  if ! enterprise_e2e_ledger_header_ok "$ledger"; then
    printf '%s\n' "STALE"
    return 0
  fi
  read -r pass total fail_rows < <(enterprise_e2e_ledger_pass_summary "$ledger")
  if [[ "$total" -lt 22 ]]; then
    printf '%s\n' "STALE"
    return 0
  fi
  if [[ "$pass" -eq 22 ]] && enterprise_e2e_ledger_pass_rows_have_refs "$ledger"; then
    printf '%s\n' "COMPLETE"
  else
    printf '%s\n' "LEDGER_MISMATCH"
  fi
}

enterprise_e2e_ledger_reconcile_ok() {
  local status
  status="$(enterprise_e2e_ledger_reconcile_status)"
  [[ "$status" == "COMPLETE" ]]
}

# CLI entry when executed directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    -h|--help)
      cat <<'EOF'
Usage: enterprise-e2e-ledger-reconcile.sh [--status|--summary]

Exit 0 when ledger workflow matrix shows 22/22 Pass with required columns.
Exit 1 on LEDGER_MISMATCH or STALE; exit 2 when ledger missing/unreadable.
EOF
      exit 0
      ;;
    --status)
      enterprise_e2e_ledger_reconcile_status
      enterprise_e2e_ledger_reconcile_ok && exit 0
      status="$(enterprise_e2e_ledger_reconcile_status)"
      if [[ "$status" == "UNREADABLE" ]]; then
        exit 2
      fi
      exit 1
      ;;
    --summary)
      ledger="$(enterprise_e2e_ledger_file_path)"
      echo "ledger: $ledger"
      enterprise_e2e_ledger_reconcile_status
      enterprise_e2e_ledger_pass_summary "$ledger"
      exit 0
      ;;
    *)
      ledger="$(enterprise_e2e_ledger_file_path)"
      if enterprise_e2e_ledger_reconcile_ok; then
        echo "ledger reconcile: COMPLETE 22/22"
        exit 0
      fi
      status="$(enterprise_e2e_ledger_reconcile_status)"
      echo "ledger reconcile: $status" >&2
      read -r pass total _ < <(enterprise_e2e_ledger_pass_summary "$ledger")
      echo "ledger pass count: ${pass:-0}/${total:-0} (need 22/22)" >&2
      if [[ "$status" == "UNREADABLE" ]]; then
        exit 2
      fi
      exit 1
      ;;
  esac
fi
