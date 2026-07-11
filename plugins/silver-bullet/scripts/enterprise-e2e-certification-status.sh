#!/usr/bin/env bash
# Derive tri-host enterprise E2E certification status from canonical evidence files.
#
# Replaces hand-maintained gate summaries with a reproducible JSON artifact.
#
# Usage:
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-certification-status.sh
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-certification-status.sh --json
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-certification-status.sh --write
#   RTK_DISABLED=1 bash scripts/enterprise-e2e-certification-status.sh --markdown
#
# Output default: human summary to stdout.
# --write persists .planning/enterprise-e2e/CERTIFICATION-STATUS.json
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_ROOT

JSON_ONLY=0
WRITE_ARTIFACT=0
MARKDOWN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_ONLY=1; shift ;;
    --write) WRITE_ARTIFACT=1; shift ;;
    --markdown) MARKDOWN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Derive tri-host certification status from ledger, gates, registry, and strict-clean checks.

Options:
  --json       Emit JSON only (no human preamble)
  --write      Write .planning/enterprise-e2e/CERTIFICATION-STATUS.json
  --markdown   Emit markdown summary (implies --write for artifact when combined)
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SOURCES="${SB_ROOT}/docs/testing/host-certification-sources.json"
BASELINE="${SB_ROOT}/docs/testing/autonomous-enterprise-proof-baseline.json"
ARTIFACT="${SB_ROOT}/.planning/enterprise-e2e/CERTIFICATION-STATUS.json"

if [[ ! -f "$SOURCES" ]]; then
  echo "FAIL: missing $SOURCES" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq required" >&2
  exit 1
fi

# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

gates_verdict() {
  local gates_file="$1"
  [[ -f "$gates_file" ]] || { printf '%s\n' "missing"; return 0; }
  if grep -qiE 'Status:\s*\*\*CLOSED Pass\*\*|strict-clean\s+\*\*Pass\*\*|product certification sign-off\s*—\s*PASS' "$gates_file" 2>/dev/null; then
    printf '%s\n' "closed_pass"
    return 0
  fi
  if grep -qiE 'strict-clean\s+\*\*NO\*\*|NOT STRICT-CLEAN|void for' "$gates_file" 2>/dev/null; then
    printf '%s\n' "not_strict_clean"
    return 0
  fi
  if grep -qiE '\*\*IN PROGRESS\*\*|PENDING|NOT STARTED|smoke' "$gates_file" 2>/dev/null; then
    printf '%s\n' "in_progress"
    return 0
  fi
  printf '%s\n' "unknown"
}

ledger_strict_clean_eligible() {
  local ledger="$1"
  [[ -f "$ledger" ]] || return 1
  if RTK_DISABLED=1 bash "${SB_ROOT}/scripts/enterprise-e2e/strict-clean-check.sh" --ledger "$ledger" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

registry_best_install() {
  local host="$1" reg
  reg="$(enterprise_e2e_row_pass_registry_file)"
  [[ -f "$reg" ]] || return 0
  python3 - "$reg" "$host" <<'PY'
import json, sys
path, host = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
best_fp, best_count, best_at = "", 0, ""
for fp, entry in doc.get("installs", {}).items():
    if entry.get("host") != host:
        continue
    rows = entry.get("rows") or {}
    count = sum(1 for r in rows.values() if r.get("outcome_pass"))
    passed_at = max((r.get("passed_at") or "" for r in rows.values()), default="")
    if count > best_count or (count == best_count and passed_at > best_at):
        best_fp, best_count, best_at = fp, count, passed_at
if best_fp:
    print(best_fp)
    print(best_count)
    print(best_at)
PY
}

classify_proof_level() {
  local reconcile="$1" pass_count="$2" strict_clean="$3" gates_verdict="$4" product_audit_ok="$5"
  local strict_ok=0
  [[ "$strict_clean" == "yes" || "$strict_clean" == "narrative_yes" ]] && strict_ok=1
  if [[ "$strict_ok" -eq 1 && "$pass_count" -ge 22 ]]; then
    if [[ "$reconcile" == "COMPLETE" || "$reconcile" == "NARRATIVE_COMPLETE" ]]; then
      if [[ "$gates_verdict" == "closed_pass" || "$gates_verdict" == "unknown" || "$gates_verdict" == "n/a" ]]; then
        if [[ "$product_audit_ok" == "required_fail" ]]; then
          printf '%s\n' "live_e2e_partial"
          return 0
        fi
        printf '%s\n' "live_e2e_proven"
        return 0
      fi
    fi
    if [[ "$reconcile" == "NARRATIVE_MATRIX_ONLY" && "$strict_clean" == "narrative_yes" ]]; then
      if [[ "$product_audit_ok" != "required_fail" ]]; then
        printf '%s\n' "live_e2e_proven"
        return 0
      fi
    fi
  fi
  if [[ "$pass_count" -ge 1 ]]; then
    printf '%s\n' "live_e2e_partial"
    return 0
  fi
  if [[ "$reconcile" == "COMPLETE" && "$pass_count" -ge 22 && "$strict_clean" != "yes" ]]; then
    printf '%s\n' "live_e2e_partial"
    return 0
  fi
  printf '%s\n' "not_started"
}

product_audit_status() {
  local audit_file="$1"
  [[ -n "$audit_file" && -f "$audit_file" ]] || { printf '%s\n' "n/a"; return 0; }
  if grep -qiE '\*\*PASS\*\*|product commits.*PASS|17/17 implement|19.*product commit' "$audit_file" 2>/dev/null; then
    printf '%s\n' "pass"
    return 0
  fi
  if grep -qiE '\*\*FAIL\*\*|0/22|void' "$audit_file" 2>/dev/null; then
    printf '%s\n' "fail"
    return 0
  fi
  printf '%s\n' "unknown"
}

# Legacy ledgers (e.g. Cursor-3 REAL) may lack graphify/agentmemory matrix columns.
ledger_narrative_matrix_complete() {
  local ledger="$1"
  [[ -f "$ledger" ]] || return 1
  grep -qiE 'Full matrix 22/22.*\*\*PASS\*\*|Matrix 22/22 live.*\*\*PASS\*\*|22/22 strict-clean' "$ledger" 2>/dev/null
}

ledger_narrative_strict_clean() {
  local ledger="$1"
  [[ -f "$ledger" ]] || return 1
  grep -qiE 'Strict-clean verdict:\*\* \*\*PASS\*\*|Round strict-clean.*\*\*PASS\*\*' "$ledger" 2>/dev/null
}

ledger_narrative_reconcile_complete() {
  local ledger="$1"
  [[ -f "$ledger" ]] || return 1
  grep -qiE 'ledger reconcile.*\*\*COMPLETE\*\*.*22/22|Ledger reconcile.*\*\*COMPLETE\*\*' "$ledger" 2>/dev/null
}

HOST_JSON_PARTS=()
for host in cursor codex claude; do
  ledger_rel="$(jq -r --arg h "$host" '.hosts[$h].canonical_ledger // empty' "$SOURCES")"
  gates_rel="$(jq -r --arg h "$host" '.hosts[$h].canonical_gates // empty' "$SOURCES")"
  audit_rel="$(jq -r --arg h "$host" '.hosts[$h].product_audit // empty' "$SOURCES")"
  appendix="$(jq -r --arg h "$host" '.hosts[$h].methodology_appendix // empty' "$SOURCES")"

  ledger_path=""
  gates_path=""
  audit_path=""
  [[ -n "$ledger_rel" ]] && ledger_path="${SB_ROOT}/${ledger_rel}"
  [[ -n "$gates_rel" ]] && gates_path="${SB_ROOT}/${gates_rel}"
  [[ -n "$audit_rel" ]] && audit_path="${SB_ROOT}/${audit_rel}"

  reconcile="UNREADABLE"
  pass_count=0
  total_count=0
  narrative_ok=0
  if [[ -n "$ledger_path" && -f "$ledger_path" ]]; then
    export SB_E2E_LEDGER_FILE="$ledger_path"
    reconcile="$(enterprise_e2e_ledger_reconcile_status)"
    read -r pass_count total_count _ < <(enterprise_e2e_ledger_pass_summary "$ledger_path")
    if [[ "$reconcile" != "COMPLETE" ]] && ledger_narrative_matrix_complete "$ledger_path"; then
      narrative_ok=1
      pass_count=22
      total_count=22
      if ledger_narrative_reconcile_complete "$ledger_path"; then
        reconcile="NARRATIVE_COMPLETE"
      else
        reconcile="NARRATIVE_MATRIX_ONLY"
      fi
    fi
  fi

  strict_clean="no"
  if [[ -n "$ledger_path" ]] && ledger_strict_clean_eligible "$ledger_path"; then
    strict_clean="yes"
  elif [[ -n "$ledger_path" ]] && ledger_narrative_strict_clean "$ledger_path"; then
    strict_clean="narrative_yes"
  fi

  gverdict="n/a"
  [[ -n "$gates_path" ]] && gverdict="$(gates_verdict "$gates_path")"

  paudit="n/a"
  [[ -n "$audit_path" ]] && paudit="$(product_audit_status "$audit_path")"
  product_required="no"
  [[ "$host" == "codex" ]] && product_required="yes"

  product_block="n/a"
  if [[ "$product_required" == "yes" ]]; then
    case "$paudit" in
      pass) product_block="ok" ;;
      fail) product_block="required_fail" ;;
      *) product_block="unknown" ;;
    esac
  fi

  reg_fp="" reg_rows=0 reg_at=""
  reg_lines="$(registry_best_install "$host" 2>/dev/null || true)"
  if [[ -n "$reg_lines" ]]; then
    reg_fp="$(printf '%s\n' "$reg_lines" | sed -n '1p')"
    reg_rows="$(printf '%s\n' "$reg_lines" | sed -n '2p')"
    reg_at="$(printf '%s\n' "$reg_lines" | sed -n '3p')"
  fi
  [[ -z "${reg_rows:-}" || ! "${reg_rows:-}" =~ ^[0-9]+$ ]] && reg_rows=0

  if [[ "${pass_count:-0}" -eq 0 && "${reg_rows:-0}" -gt 0 ]]; then
    pass_count=$reg_rows
    total_count=22
    if [[ "$reconcile" == "STALE" || "$reconcile" == "UNREADABLE" ]]; then
      reconcile="REGISTRY_PARTIAL"
    fi
  fi

  proof="$(classify_proof_level "$reconcile" "${pass_count:-0}" "$strict_clean" "$gverdict" "$product_block")"

  gaps=()
  [[ "$reconcile" != "COMPLETE" && "$reconcile" != "NARRATIVE_COMPLETE" ]] && gaps+=("ledger_reconcile_${reconcile}")
  [[ "${pass_count:-0}" -lt 22 ]] && gaps+=("matrix_incomplete_${pass_count:-0}_of_22")
  [[ "$strict_clean" == "no" ]] && gaps+=("strict_clean_check_fail")
  [[ "$strict_clean" == "narrative_yes" ]] && gaps+=("strict_clean_narrative_only")
  [[ "$narrative_ok" -eq 1 && "$reconcile" != "COMPLETE" ]] && gaps+=("ledger_format_legacy")
  [[ "$product_block" == "required_fail" ]] && gaps+=("product_audit_fail")
  [[ "$product_block" == "unknown" && "$product_required" == "yes" ]] && gaps+=("product_audit_unknown")

  if [[ ${#gaps[@]} -gt 0 ]]; then
    gaps_json="$(printf '%s\n' "${gaps[@]}" | jq -R -s 'split("\n") | map(select(length>0))')"
  else
    gaps_json='[]'
  fi

  ledger_pass_str="${pass_count:-0}/${total_count:-0}"

  host_obj="$(jq -n \
    --arg host "$host" \
    --arg ledger "$ledger_rel" \
    --arg gates "$gates_rel" \
    --arg audit "$audit_rel" \
    --arg appendix "$appendix" \
    --arg reconcile "$reconcile" \
    --arg ledger_pass "$ledger_pass_str" \
    --arg strict_clean "$strict_clean" \
    --arg gates_verdict "$gverdict" \
    --arg product_audit "$paudit" \
    --arg proof_level "$proof" \
    --arg reg_fp "$reg_fp" \
    --argjson reg_rows "${reg_rows:-0}" \
    --arg reg_at "$reg_at" \
    --argjson gaps "$gaps_json" \
    '{
      host: $host,
      proof_level: $proof_level,
      canonical_ledger: $ledger,
      canonical_gates: (if $gates == "" then null else $gates end),
      product_audit: (if $audit == "" then null else $audit end),
      methodology_appendix: $appendix,
      ledger_reconcile: $reconcile,
      ledger_pass: $ledger_pass,
      strict_clean_eligible: ($strict_clean == "yes" or $strict_clean == "narrative_yes"),
      gates_verdict: $gates_verdict,
      product_audit_status: $product_audit,
      registry_best_install_fp: (if $reg_fp == "" then null else $reg_fp end),
      registry_best_row_count: $reg_rows,
      registry_best_passed_at: (if $reg_at == "" then null else $reg_at end),
      evidence_gaps: $gaps
    }')"

  HOST_JSON_PARTS+=("$host_obj")
done

hosts_array="$(printf '%s\n' "${HOST_JSON_PARTS[@]}" | jq -s '.')"

sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
generated_at="$(utc_now)"

DOC="$(jq -n \
  --arg generated_at "$generated_at" \
  --arg sb_sha "$sb_sha" \
  --arg sources "docs/testing/host-certification-sources.json" \
  --arg baseline "docs/testing/autonomous-enterprise-proof-baseline.json" \
  --arg policy "docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md" \
  --argjson hosts "$hosts_array" \
  '{
    schema_version: 1,
    generated_at: $generated_at,
    sb_git_sha: $sb_sha,
    generator: "scripts/enterprise-e2e-certification-status.sh",
    sources_registry: $sources,
    proof_baseline: $baseline,
    policy_doc: $policy,
    hosts: $hosts,
    conservative_summary: {
      tri_host_live_e2e_proven: ([$hosts[] | select(.proof_level == "live_e2e_proven")] | length),
      tri_host_live_e2e_partial: ([$hosts[] | select(.proof_level == "live_e2e_partial")] | length),
      public_autonomous_enterprise_claim_ready: (([$hosts[] | select(.proof_level == "live_e2e_proven")] | length) == 3)
    }
  }')"

if [[ "$WRITE_ARTIFACT" -eq 1 || "$MARKDOWN" -eq 1 ]]; then
  mkdir -p "$(dirname "$ARTIFACT")"
  printf '%s\n' "$DOC" >"$ARTIFACT"
fi

if [[ "$JSON_ONLY" -eq 1 ]]; then
  printf '%s\n' "$DOC"
  exit 0
fi

if [[ "$MARKDOWN" -eq 1 ]]; then
  jq -r '
    "# Enterprise E2E certification status\n",
    "**Generated:** \(.generated_at) @ `\(.sb_git_sha)`\n",
    "| Host | Proof level | Ledger | Strict-clean | Gaps |",
    "|------|-------------|--------|--------------|------|",
    (.hosts[] |
      "| \(.host) | \(.proof_level) | \(.ledger_pass) (\(.ledger_reconcile)) | \(if .strict_clean_eligible then "yes" else "no" end) | \(.evidence_gaps | join(", ")) |"
    ),
    "\n**Public claim ready:** \(.conservative_summary.public_autonomous_enterprise_claim_ready)\n",
    "Artifact: `.planning/enterprise-e2e/CERTIFICATION-STATUS.json`"
  ' <<<"$DOC"
  exit 0
fi

echo "Enterprise E2E certification status @ ${generated_at} (${sb_sha})"
echo ""
jq -r '.hosts[] | "\(.host): proof=\(.proof_level) ledger=\(.ledger_pass) reconcile=\(.ledger_reconcile) strict_clean=\(.strict_clean_eligible) gaps=\(.evidence_gaps | join(","))"' <<<"$DOC"
echo ""
echo "Tri-host live_e2e_proven: $(jq -r '.conservative_summary.tri_host_live_e2e_proven' <<<"$DOC")/3"
echo "Public autonomous enterprise claim ready: $(jq -r '.conservative_summary.public_autonomous_enterprise_claim_ready' <<<"$DOC")"
if [[ "$WRITE_ARTIFACT" -eq 0 ]]; then
  echo ""
  echo "Run with --write to persist ${ARTIFACT#${SB_ROOT}/}"
fi

printf '%s\n' "$DOC"
