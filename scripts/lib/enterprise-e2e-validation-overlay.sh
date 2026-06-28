#!/usr/bin/env bash
# Shared checks for enterprise E2E validation overlay (user-outcome / claims layer).
# Sourced by scripts/run-enterprise-e2e-validation-overlay.sh — not executed directly.
set -euo pipefail

validation_overlay_sb_root() {
  printf '%s\n' "${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
}

validation_overlay_pass() {
  echo "PASS: $1"
  VALIDATION_OVERLAY_PASS=$((VALIDATION_OVERLAY_PASS + 1))
}

validation_overlay_fail() {
  echo "FAIL: $1"
  VALIDATION_OVERLAY_FAIL=$((VALIDATION_OVERLAY_FAIL + 1))
}

validation_overlay_skip() {
  echo "SKIP: $1"
  VALIDATION_OVERLAY_SKIP=$((VALIDATION_OVERLAY_SKIP + 1))
}

validation_overlay_wf_help_slug() {
  local wf_id="$1"
  local base="${wf_id#WF-SILVER-}"
  base="${base#WF-}"
  base="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  if [[ "$base" == router || "$base" == feature || "$base" == bugfix ]]; then
    printf 'silver-%s\n' "$base"
  elif [[ "$base" == post-exec-gates || "$base" == validate-substep ]]; then
    printf '\n'
  elif [[ "$base" == review-triad || "$base" == ship-readiness || "$base" == process-maintenance ]]; then
    printf 'silver-%s\n' "$base"
  else
    printf 'silver-%s\n' "$base"
  fi
}

validation_overlay_check_apo_catalog_counts() {
  local root="$1"
  local catalog="${root}/docs/apo-catalog.json"
  if [[ ! -f "$catalog" ]]; then
    validation_overlay_fail "apo-catalog.json missing"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    validation_overlay_skip "apo-catalog counts (jq missing)"
    return
  fi
  local wf_count af_count
  wf_count="$(jq '.workflows | length' "$catalog")"
  af_count="$(jq '.atomic_flows | length' "$catalog")"
  if [[ "$wf_count" -eq 22 ]]; then
    validation_overlay_pass "apo-catalog has 22 workflows"
  else
    validation_overlay_fail "apo-catalog workflows=${wf_count} (expected 22)"
  fi
  if [[ "$af_count" -eq 27 ]]; then
    validation_overlay_pass "apo-catalog has 27 atomic flows"
  else
    validation_overlay_fail "apo-catalog atomic_flows=${af_count} (expected 27)"
  fi
}

validation_overlay_check_help_version_sync() {
  local root="$1"
  local pkg_ver help_ver
  if ! command -v jq >/dev/null 2>&1; then
    validation_overlay_skip "help version sync (jq missing)"
    return
  fi
  pkg_ver="$(jq -r '.version // empty' "${root}/package.json")"
  help_ver="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "${root}/site/help/index.html" 2>/dev/null | head -1 | tr -d 'v' || true)"
  if [[ -z "$pkg_ver" || -z "$help_ver" ]]; then
    validation_overlay_fail "help version sync — could not read package ($pkg_ver) or help ($help_ver)"
    return
  fi
  if [[ "$pkg_ver" == "$help_ver" ]]; then
    validation_overlay_pass "help center version matches package.json (${pkg_ver})"
  else
    validation_overlay_fail "help center version ${help_ver} != package.json ${pkg_ver}"
  fi
}

validation_overlay_check_help_workflow_coverage() {
  local root="$1"
  local catalog="${root}/docs/apo-catalog.json"
  local help_dir="${root}/site/help/workflows"
  if [[ ! -f "$catalog" || ! -d "$help_dir" ]]; then
    validation_overlay_fail "help workflow coverage — missing catalog or help dir"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    validation_overlay_skip "help workflow coverage (jq missing)"
    return
  fi
  local missing=0
  local wf_id slug
  while IFS= read -r wf_id; do
    [[ -z "$wf_id" ]] && continue
    slug="$(validation_overlay_wf_help_slug "$wf_id")"
    if [[ -z "$slug" ]]; then
      validation_overlay_pass "help optional for internal workflow ${wf_id}"
      continue
    fi
    if [[ -f "${help_dir}/${slug}.html" ]]; then
      validation_overlay_pass "help page exists for ${wf_id} -> ${slug}.html"
    else
      validation_overlay_fail "help page missing for ${wf_id} (expected ${slug}.html)"
      missing=$((missing + 1))
    fi
  done < <(jq -r '.workflows[].id' "$catalog")
  if [[ "$missing" -eq 0 ]]; then
    validation_overlay_pass "all user-facing catalog workflows have help pages"
  fi
}

validation_overlay_check_tri_host_install() {
  local root="$1"
  local ok=1
  for script in install-claude.sh install-codex.sh install-cursor.sh; do
    if [[ -x "${root}/scripts/${script}" || -f "${root}/scripts/${script}" ]]; then
      validation_overlay_pass "tri-host script exists: ${script}"
    else
      validation_overlay_fail "tri-host script missing: ${script}"
      ok=0
    fi
  done
  if [[ -f "${root}/hooks/cursor-hook-bridge.sh" ]]; then
    validation_overlay_pass "cursor-hook-bridge.sh exists under hooks/"
  else
    validation_overlay_fail "cursor-hook-bridge.sh missing under hooks/"
    ok=0
  fi
  if [[ "$ok" -eq 1 ]]; then
    validation_overlay_pass "tri-host install surface complete"
  fi
}

validation_overlay_check_hook_surface() {
  local root="$1"
  local hooks_dir="${root}/hooks"
  local count=0
  if [[ ! -d "$hooks_dir" ]]; then
    validation_overlay_fail "hooks/ directory missing"
    return
  fi
  count="$(find "$hooks_dir" -maxdepth 1 -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -ge 12 ]]; then
    validation_overlay_pass "hooks/ has ${count} top-level hook scripts (>= 12)"
  else
    validation_overlay_fail "hooks/ has ${count} scripts (expected >= 12)"
  fi
}

validation_overlay_check_sb_diagnostics() {
  local root="$1"
  if [[ -x "${root}/scripts/sb-diagnostics.sh" ]]; then
    validation_overlay_pass "sb-diagnostics.sh executable"
  else
    validation_overlay_fail "sb-diagnostics.sh missing or not executable"
  fi
}

validation_overlay_check_help_catalog_sot() {
  local root="$1"
  if grep -qF 'docs/apo-catalog.json' "${root}/site/help/index.html" 2>/dev/null; then
    validation_overlay_pass "help index references docs/apo-catalog.json"
  else
    validation_overlay_fail "help index missing docs/apo-catalog.json reference"
  fi
}

validation_overlay_check_help_tri_host() {
  local root="$1"
  local found=0
  for host in Claude Codex Cursor; do
    if grep -q "$host" "${root}/site/help/index.html" 2>/dev/null; then
      found=$((found + 1))
    fi
  done
  if [[ "$found" -ge 3 ]]; then
    validation_overlay_pass "help index mentions Claude, Codex, and Cursor"
  else
    validation_overlay_fail "help index tri-host mentions incomplete (${found}/3)"
  fi
}

validation_overlay_check_claims_audit() {
  local root="$1"
  if RTK_DISABLED=1 bash "${root}/scripts/claims-audit.sh" >/dev/null 2>&1; then
    validation_overlay_pass "claims-audit.sh green"
  else
    validation_overlay_fail "claims-audit.sh failed"
  fi
}

validation_overlay_check_apo_invariants() {
  local root="$1"
  local checker="${root}/scripts/check-apo-invariants.py"
  if [[ ! -f "$checker" ]]; then
    validation_overlay_skip "check-apo-invariants.py missing"
    return
  fi
  local check failed=0
  for check in site-doc-freshness apo-hierarchy-integrity; do
    if python3 "$checker" "$check" >/dev/null 2>&1; then
      validation_overlay_pass "check-apo-invariants.py ${check} green"
    else
      validation_overlay_fail "check-apo-invariants.py ${check} failed"
      failed=1
    fi
  done
  [[ "$failed" -eq 0 ]] || return
}

validation_overlay_check_registry() {
  local root="$1"
  local registry="${root}/docs/testing/validation-claims-registry.json"
  if [[ ! -f "$registry" ]]; then
    validation_overlay_fail "validation-claims-registry.json missing"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    validation_overlay_skip "validation registry parse (jq missing)"
    return
  fi
  local claim_count gate_count backlog telemetry_only excluded
  claim_count="$(jq '.claims | length' "$registry")"
  gate_count="$(jq '[.claims[] | select((.validation_scope // "gate") == "gate" and (.status // "active") != "excluded")] | length' "$registry")"
  backlog="$(jq '[.claims[] | select(.status == "backlog" and ((.validation_scope // "gate") == "gate" or (.validation_scope // "gate") == "live"))] | length' "$registry")"
  telemetry_only="$(jq '[.claims[] | select(.validation_scope == "telemetry_only")] | length' "$registry")"
  excluded="$(jq '[.claims[] | select(.validation_scope == "excluded")] | length' "$registry")"
  if [[ "$gate_count" -ge 4 ]]; then
    validation_overlay_pass "validation registry has ${gate_count} outcome claims (${claim_count} total incl. telemetry/backlog)"
  else
    validation_overlay_fail "validation registry outcome claims too few (${gate_count})"
  fi
  validation_overlay_pass "validation registry gate backlog items: ${backlog}"
  if [[ "$telemetry_only" -gt 0 || "$excluded" -gt 0 ]]; then
    validation_overlay_pass "validation registry out-of-gate scope: telemetry_only=${telemetry_only} excluded=${excluded}"
  fi
}

validation_overlay_check_help_ship_readiness_page() {
  local root="$1"
  if [[ -f "${root}/site/help/workflows/silver-ship-readiness.html" ]]; then
    validation_overlay_pass "help page exists: silver-ship-readiness.html"
  else
    validation_overlay_fail "help page missing: silver-ship-readiness.html"
  fi
}

validation_overlay_check_evidence_gates_surface() {
  local root="$1"
  if grep -qF 'blocks unsafe commits' "${root}/site/index.html" 2>/dev/null; then
    validation_overlay_pass "homepage documents evidence-gates outcome"
  else
    validation_overlay_fail "homepage missing evidence-gates outcome copy"
  fi
}

validation_overlay_matrix_row_claims() {
  local root="$1"
  local ledger="${SB_E2E_LEDGER_FILE:-}"
  [[ -n "$ledger" && -f "$ledger" ]] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    validation_overlay_skip "matrix row claim overlay (jq missing)"
    return
  fi
  local registry="${root}/docs/testing/validation-claims-registry.json"
  [[ -f "$registry" ]] || return 0
  local row_map
  row_map="$(jq -r '.matrix_row_claim_map | keys[]' "$registry" 2>/dev/null || true)"
  local row
  for row in $row_map; do
    if grep -qE "^\\| ${row} \\|" "$ledger" 2>/dev/null && grep -qE "^\\| ${row} \\|.*Pass" "$ledger" 2>/dev/null; then
      validation_overlay_pass "matrix row ${row} Pass — linked validation claims satisfied by row evidence"
    else
      validation_overlay_skip "matrix row ${row} not Pass in ledger — claim overlay deferred"
    fi
  done
}
