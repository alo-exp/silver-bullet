#!/usr/bin/env bash
# Review package G3: failure-path coverage for the sha256 helpers, audit log, seal and markers.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE SB_E2E_ENTERPRISE_MATRIX
SD="$SB_RUNTIME_STATE_DIR"
source "$TL_REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
source "$TL_REPO_ROOT/hooks/lib/outcomes-gate.sh"
source "$TL_REPO_ROOT/hooks/lib/prompt-classifier.sh"
source "$TL_REPO_ROOT/hooks/lib/orchestrator-parent.sh"
source "$TL_REPO_ROOT/hooks/lib/orchestrator-state.sh"
source "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
NOSHA256="$(tl_path_without sha256sum)"
NOSHA2="$(tl_path_without sha256sum shasum)"
NOSHA3="$(tl_path_without sha256sum shasum openssl)"

# ---- e2e marker library ---------------------------------------------------------------------
export SB_E2E_ENTERPRISE_MATRIX=1
assert_eq "e2e: no state dir, no marker path" 1 "$(SB_RUNTIME_STATE_DIR= rc sb_e2e_matrix_routing_row_marker_file)"
assert_eq "e2e: no state dir, never active" 1 "$(SB_RUNTIME_STATE_DIR= rc sb_e2e_matrix_routing_row_active)"
assert_eq "e2e: no state dir, set refused" 1 "$(SB_RUNTIME_STATE_DIR= rc sb_e2e_matrix_set_routing_row_marker)"
assert_eq "e2e: no state dir, clear is a no-op" 0 "$(SB_RUNTIME_STATE_DIR= rc sb_e2e_matrix_clear_routing_row_marker)"
assert_eq "e2e: no marker, not active" 1 "$(rc sb_e2e_matrix_routing_row_active)"
sb_e2e_matrix_set_routing_row_marker
assert_eq "e2e: harness marker active" 0 "$(rc sb_e2e_matrix_routing_row_active)"
M="$(sb_e2e_matrix_routing_row_marker_file)"
mv "$M" "$M.real"; ln -s "$M.real" "$M"
assert_eq "e2e: a symlinked marker is ignored" 1 "$(rc sb_e2e_matrix_routing_row_active)"
rm -f "$M" "$M.real"
unset SB_E2E_ENTERPRISE_MATRIX

# ---- sha256 helper fallbacks and failures (override audit + outcomes seal) -----------------------
printf 'abc' >"$TL_TMP/f"
want="$(printf 'abc' | sha256sum | awk '{print $1}')"
assert_eq "directive sha: sha256sum" "$want" "$(printf abc | sb_orchestrator_sha256)"
assert_eq "directive sha: shasum fallback" "$want" "$(PATH="$NOSHA256" bash -c 'source "$1"; printf abc | sb_orchestrator_sha256' _ "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh")"
assert_eq "directive sha: openssl fallback" "$want" "$(PATH="$NOSHA2" bash -c 'source "$1"; printf abc | sb_orchestrator_sha256' _ "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh")"
assert_eq "directive sha: no tool" 1 "$(PATH="$NOSHA3" bash -c 'source "$1"; printf abc | sb_orchestrator_sha256' _ "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh" >/dev/null 2>&1; echo $?)"
assert_eq "outcomes sha: sha256sum" "$want" "$(sb_outcomes_sha256_of "$TL_TMP/f")"
assert_eq "outcomes sha: shasum fallback" "$want" "$(PATH="$NOSHA256" sb_outcomes_sha256_of "$TL_TMP/f")"
assert_eq "outcomes sha: openssl fallback" "$want" "$(PATH="$NOSHA2" sb_outcomes_sha256_of "$TL_TMP/f")"
assert_eq "outcomes sha: no tool" 1 "$(PATH="$NOSHA3" rc sb_outcomes_sha256_of "$TL_TMP/f")"
for tool in sha256sum shasum openssl; do
  tl_stub "$tool" 'exit 1'; hash -r
  case "$tool" in
    sha256sum) P="$PATH" ;;
    shasum) P="$TL_BIN:$NOSHA256" ;;
    openssl) P="$TL_BIN:$NOSHA2" ;;
  esac
  assert_eq "directive sha: failing $tool" 1 "$(PATH="$P" bash -c 'source "$1"; printf abc | sb_orchestrator_sha256' _ "$TL_REPO_ROOT/hooks/lib/orchestrator-directive.sh" >/dev/null 2>&1; echo $?)"
  assert_eq "outcomes sha: failing $tool" 1 "$(PATH="$P" rc sb_outcomes_sha256_of "$TL_TMP/f")"
  rm -f "$TL_BIN/$tool"; hash -r
done

# ---- outcomes seal and tamper log -------------------------------------------------------------------
OF="$(sb_outcomes_session_file)"
assert_eq "seal: no state dir" 0 "$(SB_RUNTIME_STATE_DIR= rc sb_outcomes_seal)"
assert_eq "reject: no state dir" 0 "$(SB_RUNTIME_STATE_DIR= rc sb_outcomes_reject_tampered)"
rm -f "$OF" "$OF.sha256"
assert_eq "seal: no outcomes file" 0 "$(rc sb_outcomes_seal)"
assert_eq "reject: no outcomes file" 0 "$(rc sb_outcomes_reject_tampered)"
printf '{"outcomes":[{"id":"route","status":"done","evidence":"x"}]}' >"$OF"
PATH="$NOSHA3" sb_outcomes_seal
assert_file_absent "seal: no sha tool writes nothing" "$OF.sha256"
mkdir "$OF.sha256"
sb_outcomes_seal
assert_eq "seal: an unwritable seal is tolerated" 0 "$?"
rmdir "$OF.sha256"
mkdir "$SD/outcomes-tamper.log"
sb_outcomes_reject_tampered
assert_eq "reject: unwritable tamper log tolerated, file still reset" pending "$(jq -r '.outcomes[0].status' "$OF")"
rmdir "$SD/outcomes-tamper.log"

# ---- queue-clear log failure does not stop the clear ------------------------------------------------
mkdir "$SD/queue-clear.log"
printf '{"current_flow":"silver-plan","flow_queue":["silver-plan"]}' >"$SD/orchestrator.json"
sb_orchestrator_clear_queue_on_interrupt "please build the login page" && r=cleared || r=kept
assert_eq "queue clear still happens with an unwritable log" cleared "$r"
rmdir "$SD/queue-clear.log"

# ---- override audit failure paths -----------------------------------------------------------------------
proj="$TL_TMP/ovproj"; mkdir -p "$proj"
mkdir -p "$proj/.planning/orchestrator-override-log.jsonl"
sb_orchestrator_log_override "$proj" "reason long enough" silver-plan && r=0 || r=$?
assert_eq "audit: a log that cannot be appended refuses" 1 "$r"
rm -rf "$proj/.planning/orchestrator-override-log.jsonl"
sb_orchestrator_log_override "$proj" "first reason ok" silver-plan
PATH="$NOSHA3" sb_orchestrator_log_override "$proj" "second reason ok" silver-plan && r=0 || r=$?
assert_eq "audit: the chain hash cannot be computed: refused" 1 "$r"
rm -rf "$proj/.planning"
tl_stub jq 'case "$*" in *directive-override*) exit 1;; esac; exec '"$(ec_real jq)"' "$@"'; hash -r
sb_orchestrator_log_override "$proj" "reason long enough" silver-plan && r=0 || r=$?
assert_eq "audit: line cannot be built" 1 "$r"
rm -f "$TL_BIN/jq"; hash -r
# apply: no sha tool still audits (hash left empty); a failing provenance build falls back to {}
mkdir -p "$proj/.planning"; rm -f "$proj/.planning/orchestrator-override-log.jsonl"
PATH="$NOSHA3" sb_orchestrator_override_apply '{"session_id":"s1"}' "SB OVERRIDE: long enough reason" "$proj" && r=0 || r=$?
assert_eq "apply without a sha tool still audits" 0 "$r"
assert_eq "prompt hash left empty" "" "$(jq -r .prompt_sha256 "$proj/.planning/orchestrator-override-log.jsonl")"
rm -f "$proj/.planning/orchestrator-override-log.jsonl"
tl_stub jq 'case "$*" in *prompt_sha256*) exit 1;; esac; exec '"$(ec_real jq)"' "$@"'; hash -r
sb_orchestrator_override_apply '{"session_id":"s1"}' "SB OVERRIDE: long enough reason" "$proj" && r=0 || r=$?
rm -f "$TL_BIN/jq"; hash -r
assert_eq "apply with a failing provenance build still audits" 0 "$r"
assert_eq "provenance falls back to the bare record" "null" "$(jq -r .session_id "$proj/.planning/orchestrator-override-log.jsonl")"
rm -f "$SD/orchestrator-override-log.jsonl"
ln -s /dev/null "$SD/orchestrator-override-log.jsonl"
assert_eq "mirror: a symlinked mirror is left alone" 0 "$(rc sb_orchestrator_mirror_override x)"
rm -f "$SD/orchestrator-override-log.jsonl"

tl_results
