#!/usr/bin/env bash
# Install-version row pass registry — one live+outcome PASS per matrix row per SB install.
# See docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md § Install-version row pass registry.
set -euo pipefail

enterprise_e2e_row_pass_registry_path() {
  local sb_root="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
  printf '%s\n' "${SB_E2E_ROW_PASS_REGISTRY:-${sb_root}/.planning/enterprise-e2e/.row-pass-registry.json}"
}

# Fingerprint: <host>:<package.json version> — stable across harness-only commits.
# Override for tests: SB_E2E_INSTALL_FP=claude:0.49.1
enterprise_e2e_install_fingerprint() {
  if [[ -n "${SB_E2E_INSTALL_FP:-}" ]]; then
    printf '%s\n' "$SB_E2E_INSTALL_FP"
    return 0
  fi
  local host sb_root pkg_ver
  if declare -f enterprise_e2e_matrix_host >/dev/null 2>&1; then
    host="$(enterprise_e2e_matrix_host)"
  else
    host="${SB_E2E_LIVE_RUNTIME:-${SILVER_BULLET_RUNTIME:-claude}}"
  fi
  sb_root="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
  if command -v jq >/dev/null 2>&1 && [[ -f "${sb_root}/package.json" ]]; then
    pkg_ver="$(jq -r .version "${sb_root}/package.json" 2>/dev/null || echo unknown)"
  else
    pkg_ver="unknown"
  fi
  printf '%s:%s\n' "$host" "$pkg_ver"
}

enterprise_e2e_row_pass_registry_init() {
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [[ ! -f "$path" ]]; then
    jq -n '{version: 1, by_install: {}}' >"$path"
  fi
}

enterprise_e2e_row_pass_registry_has_pass() {
  local row_num="$1"
  local path fp
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || return 1
  fp="$(enterprise_e2e_install_fingerprint)"
  jq -e --arg fp "$fp" --arg row "$row_num" \
    '.by_install[$fp].rows[$row].outcome_pass == true' "$path" >/dev/null 2>&1
}

enterprise_e2e_row_pass_registry_record() {
  local row_num="$1"
  local log_ref="${2:-}"
  local outcome_pass="${3:-true}"
  local path fp now tmp
  path="$(enterprise_e2e_row_pass_registry_path)"
  enterprise_e2e_row_pass_registry_init
  fp="$(enterprise_e2e_install_fingerprint)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp "${TMPDIR:-/tmp}/row-pass-registry.XXXXXX")"
  jq --arg fp "$fp" \
    --arg row "$row_num" \
    --arg at "$now" \
    --arg log "$log_ref" \
    --argjson outcome "$([[ "$outcome_pass" == "true" ]] && echo true || echo false)" \
    '.by_install[$fp] = (.by_install[$fp] // {install_fp: $fp, rows: {}}) |
     .by_install[$fp].install_fp = $fp |
     .by_install[$fp].rows[$row] = {passed_at: $at, log_ref: $log, outcome_pass: $outcome}' \
    "$path" >"$tmp"
  mv "$tmp" "$path"
}

enterprise_e2e_row_pass_registry_pass_count() {
  local path fp
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || { printf '0\n'; return 0; }
  fp="$(enterprise_e2e_install_fingerprint)"
  jq -r --arg fp "$fp" \
    '(.by_install[$fp].rows // {}) | to_entries | map(select(.value.outcome_pass == true)) | length' \
    "$path" 2>/dev/null || printf '0\n'
}

enterprise_e2e_row_pass_registry_list_rows() {
  local path fp
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || return 0
  fp="$(enterprise_e2e_install_fingerprint)"
  jq -r --arg fp "$fp" \
    '(.by_install[$fp].rows // {}) | to_entries[] | select(.value.outcome_pass == true) | .key' \
    "$path" 2>/dev/null | sort -n
}
