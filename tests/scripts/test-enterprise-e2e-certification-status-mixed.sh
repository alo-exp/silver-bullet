#!/usr/bin/env bash
# Mixed-evidence scenarios (second half) for scripts/enterprise-e2e-certification-status.sh: a staged tree holds synthetic
# host-certification sources, ledgers, gate and audit documents, and a row-pass registry; the
# strict-clean check is stubbed (it passes for a ledger containing the marker STRICT-OK).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

STAGE="$TL_TMP/stage"
e2e_stage_scripts "$STAGE"
SCRIPT="$STAGE/scripts/enterprise-e2e-certification-status.sh"
e2e_stage_override "$STAGE" scripts/enterprise-e2e/strict-clean-check.sh 'echo "strict-clean args=$* rtk=${RTK_DISABLED:-}" >>"${STRICT_LOG:-/dev/null}"; [[ "$1" == "--ledger" ]] && grep -q STRICT-OK "$2"'
PLAN="$STAGE/.planning/enterprise-e2e"
mkdir -p "$PLAN" "$STAGE/docs/testing"
ARTIFACT="$TL_TMP/artifact/status.json"
REG="$TL_TMP/registry.json"
mapfile -t SPECS22 < <(e2e_all_pass_specs 22)

# host_json LEDGER GATES AUDIT: one host entry of the sources file ("" omits the key).
host_json() {
  jq -n --arg l "$1" --arg g "$2" --arg a "$3" \
    '{methodology_appendix: "Appendix X"}
     + (if $l != "" then {canonical_ledger: $l} else {} end)
     + (if $g != "" then {canonical_gates: $g} else {} end)
     + (if $a != "" then {product_audit: $a} else {} end)'
}
# write_sources CURSOR-JSON CODEX-JSON CLAUDE-JSON
write_sources() {
  jq -n --argjson cu "$1" --argjson cx "$2" --argjson cl "$3" '{version: 1, hosts: {cursor: $cu, codex: $cx, claude: $cl}}' \
    >"$STAGE/docs/testing/host-certification-sources.json"
}
# proven_ledger FILE: 22 passes with refs plus the marker the strict-clean stub looks for.
proven_ledger() {
  e2e_mk_ledger "$1" "${SPECS22[@]}"
  echo "STRICT-OK" >>"$1"
}
cert() {  # cert ARGS... -- ENV...
  local args=()
  while [[ "${1:-}" != "--" ]]; do
    args+=("$1")
    shift
  done
  shift
  _e2e_split_env -u RTK_DISABLED -u STRICT_LOG "SB_CERT_ARTIFACT=$ARTIFACT" "SB_E2E_ROW_PASS_REGISTRY=$REG" -u SB_E2E_LEDGER_FILE "$@"
  tl_run env "${E2E_ENV_ARGS[@]}" bash "$SCRIPT" ${args[@]+"${args[@]}"}
}
field() {  # field HOST JQ-EXPR  (reads the JSON on TL_OUT's last document)
  jq -r --arg h "$1" ".hosts[] | select(.host == \$h) | $2" "$ARTIFACT"
}

# Baseline documents (the all-proven fixtures the first half builds) so each file stands alone.
proven_ledger "$PLAN/cursor-ledger.md"
proven_ledger "$PLAN/codex-ledger.md"
proven_ledger "$PLAN/claude-ledger.md"
# --- mixed evidence: narratives, registry, audits, gates ---------------------------------------
# cursor: legacy ledger (no refs columns) with a narrative PASS for the matrix, reconcile and strict-clean.
cat >"$PLAN/cursor-ledger.md" <<'L'
# Legacy ledger
Full matrix 22/22 live **PASS**
Ledger reconcile: **COMPLETE** 22/22
Strict-clean verdict:** **PASS**
L
echo "void for the first attempt" >"$PLAN/cursor-gates.md"
# codex: narrative matrix only, no reconcile statement; audit is a failure -> proof held back.
cat >"$PLAN/codex-ledger.md" <<'L'
Matrix 22/22 live **PASS**
Round strict-clean (round 4) **PASS**
L
echo "audit: **FAIL** 0/22 product commits" >"$PLAN/codex-audit.md"
echo "smoke test pending" >"$PLAN/codex-gates.md"
# claude: partial ledger (5 of 22 rows pass); gates say nothing useful.
mapfile -t FAIL_6_22 < <(printf '%s:Fail\n' $(seq 6 22))
e2e_mk_ledger "$PLAN/claude-ledger.md" 1:Pass 2:Pass 3:Pass 4:Pass 5:Pass "${FAIL_6_22[@]}"
echo "no verdict phrases here" >"$PLAN/claude-gates.md"
cat >"$REG" <<'J'
{"installs": {
  "fp-old":  {"host": "claude", "rows": {"1": {"outcome_pass": true, "passed_at": "2026-01-01"}, "2": {"outcome_pass": true, "passed_at": "2026-02-01"}}},
  "fp-new":  {"host": "claude", "rows": {"1": {"outcome_pass": true, "passed_at": "2026-03-01"}, "2": {"outcome_pass": true, "passed_at": "2026-01-05"}}},
  "fp-less": {"host": "claude", "rows": {"1": {"outcome_pass": true, "passed_at": "2026-09-09"}}},
  "fp-none": {"host": "claude", "rows": {}},
  "fp-nullrows": {"host": "claude", "rows": null},
  "fp-cursor": {"host": "cursor", "rows": {"1": {"outcome_pass": true, "passed_at": "2026-04-04"}}}
}}
J
write_sources \
  "$(host_json .planning/enterprise-e2e/cursor-ledger.md .planning/enterprise-e2e/cursor-gates.md "")" \
  "$(host_json .planning/enterprise-e2e/codex-ledger.md .planning/enterprise-e2e/codex-gates.md .planning/enterprise-e2e/codex-audit.md)" \
  "$(host_json .planning/enterprise-e2e/claude-ledger.md .planning/enterprise-e2e/claude-gates.md "")"
cert --json --write --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "cursor narrative: complete reconcile" "NARRATIVE_COMPLETE" "$(field cursor .ledger_reconcile)"
assert_eq "cursor narrative: 22/22" "22/22" "$(field cursor .ledger_pass)"
assert_eq "cursor narrative: strict-clean from the narrative" "true" "$(field cursor .strict_clean_eligible)"
assert_eq "cursor 'void for' gates" "not_strict_clean" "$(field cursor .gates_verdict)"
assert_eq "cursor narrative: a void gate keeps it partial" "live_e2e_partial" "$(field cursor .proof_level)"
assert_eq "cursor gaps" '["strict_clean_narrative_only","ledger_format_legacy"]' "$(field cursor '.evidence_gaps' | jq -c .)"
assert_eq "cursor registry fingerprint" "fp-cursor" "$(field cursor .registry_best_install_fp)"
assert_eq "codex narrative matrix only" "NARRATIVE_MATRIX_ONLY" "$(field codex .ledger_reconcile)"
assert_eq "codex 'smoke' gates are in progress" "in_progress" "$(field codex .gates_verdict)"
assert_eq "codex failing audit" "fail" "$(field codex .product_audit_status)"
assert_eq "codex failing audit holds the proof back" "live_e2e_partial" "$(field codex .proof_level)"
assert_eq "codex gaps" '["ledger_reconcile_NARRATIVE_MATRIX_ONLY","strict_clean_narrative_only","ledger_format_legacy","product_audit_fail"]' "$(field codex '.evidence_gaps' | jq -c .)"
assert_eq "claude partial ledger pass count" "5/22" "$(field claude .ledger_pass)"
assert_eq "claude partial ledger reconcile" "LEDGER_MISMATCH" "$(field claude .ledger_reconcile)"
assert_eq "claude unclassified gates" "unknown" "$(field claude .gates_verdict)"
assert_eq "claude partial" "live_e2e_partial" "$(field claude .proof_level)"
assert_eq "claude best registry install: most rows, then newest" "fp-new" "$(field claude .registry_best_install_fp)"
assert_eq "claude registry rows" "2" "$(field claude .registry_best_row_count)"
assert_eq "claude registry passed_at" "2026-03-01" "$(field claude .registry_best_passed_at)"
assert_eq "claude gaps" '["ledger_reconcile_LEDGER_MISMATCH","matrix_incomplete_5_of_22","strict_clean_check_fail"]' "$(field claude '.evidence_gaps' | jq -c .)"

# registry fills in when the ledger is unreadable, and only then
rm -f "$PLAN/claude-ledger.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "registry supplies the pass count" "2/22" "$(field claude .ledger_pass)"
assert_eq "registry partial replaces UNREADABLE" "REGISTRY_PARTIAL" "$(field claude .ledger_reconcile)"
assert_eq "registry-backed host is partial" "live_e2e_partial" "$(field claude .proof_level)"
e2e_mk_ledger "$PLAN/claude-ledger.md" 1:Pass
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "a ledger with passes beats the registry count" "1/1" "$(field claude .ledger_pass)"
# stale (short) ledger with no passes recorded: registry count taken, STALE -> REGISTRY_PARTIAL
e2e_mk_ledger "$PLAN/claude-ledger.md" 1:Fail
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "stale ledger with zero passes falls back to the registry" "REGISTRY_PARTIAL" "$(field claude .ledger_reconcile)"
# a complete-but-failing ledger keeps its reconcile status when the registry fills the count
mapfile -t FAIL_1_22 < <(printf '%s:Fail\n' $(seq 1 22))
e2e_mk_ledger "$PLAN/claude-ledger.md" "${FAIL_1_22[@]}"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "mismatching ledger with zero passes keeps LEDGER_MISMATCH but takes the registry count" "LEDGER_MISMATCH 2/22" "$(field claude .ledger_reconcile) $(field claude .ledger_pass)"

# registry edge cases
rm -f "$REG"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "no registry file: no fingerprint" "null" "$(field claude .registry_best_install_fp)"
python3 - "$REG" <<'PY'
import json, sys
json.dump({"installs": {"fp\nodd": {"host": "claude", "rows": {"1": {"outcome_pass": True, "passed_at": "2026-05-05"}}}}}, open(sys.argv[1], "w"))
PY
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "a fingerprint with an embedded newline yields a non-numeric row count, treated as 0" "0" "$(field claude .registry_best_row_count)"
echo 'not json' >"$REG"
cert --json --
assert_eq "an unreadable registry is ignored" 0 "$TL_STATUS"
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "an unreadable registry gives no fingerprint" "null" "$(field claude .registry_best_install_fp)"

# --- gates / audit text classification (not_strict_clean via both phrases, audit 'unknown') -------------
echo "NOT STRICT-CLEAN" >"$PLAN/codex-gates.md"
echo "nothing decisive" >"$PLAN/codex-audit.md"
rm -f "$REG"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "NOT STRICT-CLEAN gates" "not_strict_clean" "$(field codex .gates_verdict)"
assert_eq "undecided audit is unknown" "unknown" "$(field codex .product_audit_status)"
assert_contains "undecided audit flagged for codex" "$(field codex '.evidence_gaps' | jq -c .)" "product_audit_unknown"
echo "strict-clean **NO**" >"$PLAN/codex-gates.md"
echo "19 product commits landed" >"$PLAN/codex-audit.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "'strict-clean NO' gates" "not_strict_clean" "$(field codex .gates_verdict)"
assert_eq "'19 product commit' audit text passes" "pass" "$(field codex .product_audit_status)"
echo "Status: **CLOSED Pass**" >"$PLAN/codex-gates.md"
echo "all void" >"$PLAN/codex-audit.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "'void' audit text fails" "fail" "$(field codex .product_audit_status)"
rm -f "$PLAN/codex-gates.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "configured but missing gates file" "missing" "$(field codex .gates_verdict)"
rm -f "$PLAN/codex-audit.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "configured but missing audit file" "n/a" "$(field codex .product_audit_status)"

# --- proof classification edge: complete ledger, strict-clean fails ---------------------------------------
e2e_mk_ledger "$PLAN/cursor-ledger.md" "${SPECS22[@]}"
write_sources \
  "$(host_json .planning/enterprise-e2e/cursor-ledger.md "" "")" \
  "$(host_json "" "" "")" "$(host_json "" "" "")"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "complete ledger without strict-clean is partial" "live_e2e_partial" "$(field cursor .proof_level)"
assert_eq "…with the strict-clean gap" '["strict_clean_check_fail"]' "$(field cursor '.evidence_gaps' | jq -c .)"
# complete + strict-clean + product audit failing for codex
proven_ledger "$PLAN/codex-ledger.md"
echo "**FAIL**" >"$PLAN/codex-audit.md"
write_sources "$(host_json "" "" "")" "$(host_json .planning/enterprise-e2e/codex-ledger.md "" .planning/enterprise-e2e/codex-audit.md)" "$(host_json "" "" "")"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "a failing product audit demotes an otherwise proven codex" "live_e2e_partial" "$(field codex .proof_level)"
assert_eq "…and is listed" '["product_audit_fail"]' "$(field codex '.evidence_gaps' | jq -c .)"
# narrative matrix-only + narrative strict-clean + audit passing -> proven via the narrative branch
cat >"$PLAN/codex-ledger.md" <<'L'
Matrix 22/22 live **PASS**
Round strict-clean (round 4) **PASS**
L
echo "**PASS**" >"$PLAN/codex-audit.md"
cert --json --
echo "$TL_OUT" >"$ARTIFACT"
assert_eq "narrative matrix + narrative strict-clean + passing audit is proven" "live_e2e_proven" "$(field codex .proof_level)"

tl_results
