#!/usr/bin/env bash
# Release Confidence Score (RCS) — basic version per ENTERPRISE-E2E-EFFECTIVENESS-PLAN §7.
#
# Usage:
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh --ledger PATH
#   SB_E2E_LEDGER_FILE=... bash scripts/enterprise-e2e-rcs.sh --json
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_ROOT
JSON_OUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    --ledger)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --ledger" >&2
        exit 2
      fi
      export SB_E2E_LEDGER_FILE="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Computes Release Confidence Score from ledger + optional matrix log.

Options:
  --ledger PATH   Ledger markdown (default: SB_E2E_LEDGER_FILE or ROUND-1-LEDGER.md)

Components (weights): run-all-tests 20%, structural/contract 15%, ladder 15%,
matrix ledger 25%, claims audit 15%, tri-host smoke 10%.

Pass threshold for release consideration: RCS >= 85 (see plan §7).
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"

score_run_all=0
score_structural=0
score_ladder=0
score_matrix=0
score_claims=0
score_trihost=0
score_validation=0

# run-all-tests (20%) — caller may set SB_E2E_RCS_RUN_ALL_TESTS=pass|fail
case "${SB_E2E_RCS_RUN_ALL_TESTS:-unknown}" in
  pass) score_run_all=20 ;;
  fail) score_run_all=0 ;;
  *) score_run_all=10 ;;
esac

# structural + contract + tui-contract (15%)
structural_ok=1
for t in \
  "${SB_ROOT}/tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh" \
  "${SB_ROOT}/tests/tui-contract/test-bypass-disclaimer.sh" \
  "${SB_ROOT}/scripts/claims-audit.sh"; do
  if [[ -x "$t" ]] || [[ -f "$t" ]]; then
    :
  else
    structural_ok=0
  fi
done
if [[ "$structural_ok" -eq 1 ]]; then
  score_structural=15
fi

# ladder (15%) — SB_E2E_RCS_LADDER=8/8 or partial
ladder="${SB_E2E_RCS_LADDER:-unknown}"
if [[ "$ladder" == "8/8" ]]; then
  score_ladder=15
elif [[ "$ladder" =~ ^[0-9]+/[0-9]+$ ]]; then
  rung="${ladder%%/*}"
  score_ladder=$(( rung * 15 / 8 ))
else
  score_ladder=8
fi

# matrix ledger (25%)
read -r pass_count _ _ < <(enterprise_e2e_ledger_pass_summary "$(enterprise_e2e_ledger_file_path)")
pass_count="${pass_count:-0}"
if [[ "$pass_count" -ge 22 ]]; then
  score_matrix=25
elif [[ "$pass_count" -ge 20 ]]; then
  score_matrix=20
else
  score_matrix=$(( pass_count * 25 / 22 ))
fi

# reconcile penalty
if ! enterprise_e2e_ledger_reconcile_ok 2>/dev/null; then
  score_matrix=$(( score_matrix * 80 / 100 ))
fi

# claims audit (15%)
if RTK_DISABLED=1 bash "${SB_ROOT}/scripts/claims-audit.sh" >/dev/null 2>&1; then
  score_claims=15
fi

# validation overlay advisory (included in claims weight when pass — see VALIDATION-PLAN)
case "${SB_E2E_RCS_VALIDATION_OVERLAY:-unknown}" in
  pass) score_validation=5 ;;
  fail) score_validation=0 ;;
  *) score_validation=2 ;;
esac
if [[ "$score_validation" -gt 0 && "$score_claims" -lt 15 ]]; then
  score_claims=$((score_claims + score_validation))
  [[ "$score_claims" -gt 15 ]] && score_claims=15
fi

# tri-host smoke (10%) — Claude required; others warn
case "${SB_E2E_RCS_TRIHOST:-claude-only}" in
  full) score_trihost=10 ;;
  partial) score_trihost=5 ;;
  *) score_trihost=3 ;;
esac

total=$((score_run_all + score_structural + score_ladder + score_matrix + score_claims + score_trihost))

if [[ "$JSON_OUT" -eq 1 ]]; then
  jq -n \
    --argjson total "$total" \
    --argjson run_all "$score_run_all" \
    --argjson structural "$score_structural" \
    --argjson ladder "$score_ladder" \
    --argjson matrix "$score_matrix" \
    --argjson claims "$score_claims" \
    --argjson trihost "$score_trihost" \
    --argjson validation_overlay "$score_validation" \
    --arg ledger_pass "${pass_count}/22" \
    --arg reconcile "$(enterprise_e2e_ledger_reconcile_status)" \
    '{
      rcs: $total,
      components: {
        run_all_tests: $run_all,
        structural_contract: $structural,
        ladder: $ladder,
        matrix_ledger: $matrix,
        claims_audit: $claims,
        tri_host_smoke: $trihost,
        validation_overlay: $validation_overlay
      },
      ledger_pass: $ledger_pass,
      ledger_reconcile: $reconcile
    }'
else
  echo "Release Confidence Score: ${total}/100"
  echo "  run-all-tests:        ${score_run_all}/20"
  echo "  structural/contract:  ${score_structural}/15"
  echo "  ladder:               ${score_ladder}/15"
  echo "  matrix ledger:        ${score_matrix}/25 (${pass_count}/22 pass, reconcile=$(enterprise_e2e_ledger_reconcile_status))"
  echo "  claims audit:         ${score_claims}/15 (validation overlay ${score_validation}/5 advisory)"
  echo "  tri-host smoke:       ${score_trihost}/10"
fi

[[ "$total" -ge 85 ]]
