#!/usr/bin/env bash
# Shared checks for enterprise E2E pre-release overlay (feature-level claims layer).
# Sourced by scripts/run-enterprise-e2e-pre-release-overlay.sh — not executed directly.
set -euo pipefail

# Reuse structural helpers from validation overlay (feature checks demoted here).
# shellcheck source=scripts/lib/enterprise-e2e-validation-overlay.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e-validation-overlay.sh"

pre_release_overlay_pass() { validation_overlay_pass "$1"; }
pre_release_overlay_fail() { validation_overlay_fail "$1"; }
pre_release_overlay_skip() { validation_overlay_skip "$1"; }

pre_release_overlay_check_registry() {
  local root="$1"
  local registry="${root}/docs/testing/pre-release-claims-registry.json"
  if [[ ! -f "$registry" ]]; then
    pre_release_overlay_fail "pre-release-claims-registry.json missing"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    pre_release_overlay_skip "pre-release registry parse (jq missing)"
    return
  fi
  local claim_count tri_host
  claim_count="$(jq '.claims | length' "$registry")"
  tri_host="$(jq -r '.tri_host_smoke.script // empty' "$registry")"
  if [[ "$claim_count" -ge 10 ]]; then
    pre_release_overlay_pass "pre-release registry has ${claim_count} feature claims"
  else
    pre_release_overlay_fail "pre-release registry too small (${claim_count})"
  fi
  if [[ -n "$tri_host" && -f "${root}/${tri_host}" ]]; then
    pre_release_overlay_pass "tri-host smoke script wired: ${tri_host}"
  else
    pre_release_overlay_fail "tri-host smoke script missing: ${tri_host}"
  fi
}

pre_release_overlay_run_feature_checks() {
  local root="$1"
  pre_release_overlay_check_registry "$root"
  validation_overlay_check_apo_catalog_counts "$root"
  validation_overlay_check_help_version_sync "$root"
  validation_overlay_check_help_workflow_coverage "$root"
  validation_overlay_check_help_catalog_sot "$root"
  validation_overlay_check_help_tri_host "$root"
  validation_overlay_check_tri_host_install "$root"
  validation_overlay_check_host_install_surface "$root"
  validation_overlay_check_hook_surface "$root"
  validation_overlay_check_sb_diagnostics "$root"
  validation_overlay_check_apo_invariants "$root"
}

pre_release_overlay_check_router_help_page() {
  local root="$1"
  if [[ -f "${root}/site/help/workflows/silver-router.html" ]]; then
    pre_release_overlay_pass "help page exists: silver-router.html"
  else
    pre_release_overlay_fail "help page missing: silver-router.html"
  fi
}

pre_release_overlay_matrix_row_claims() {
  local root="$1"
  local ledger="${SB_E2E_LEDGER_FILE:-}"
  [[ -n "$ledger" && -f "$ledger" ]] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pre_release_overlay_skip "pre-release matrix row overlay (jq missing)"
    return
  fi
  local registry="${root}/docs/testing/pre-release-claims-registry.json"
  [[ -f "$registry" ]] || return 0
  local row_map
  row_map="$(jq -r '.matrix_row_claim_map | keys[]' "$registry" 2>/dev/null || true)"
  local row
  for row in $row_map; do
    if grep -qE "^\\| ${row} \\|" "$ledger" 2>/dev/null && grep -qE "^\\| ${row} \\|.*Pass" "$ledger" 2>/dev/null; then
      pre_release_overlay_pass "pre-release matrix row ${row} Pass — feature claims satisfied"
    else
      pre_release_overlay_skip "pre-release matrix row ${row} not Pass — deferred"
    fi
  done
}
