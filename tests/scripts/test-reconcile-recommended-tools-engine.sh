#!/usr/bin/env bash
# Engine tests for scripts/reconcile-recommended-tools.sh: argument handling, library
# layouts, host evidence, the apply/repair/convergence sequencing, reload receipts and
# result rendering. The script runs from a staged tree whose probe/repair/receipt/
# heartbeat libraries are logging stubs driven by STUB_* variables; common.sh and the
# hooks/lib helpers are the real ones.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
cd "$TL_TMP"
unset RT_PROJECT_ROOT RT_HOST RT_MODE RT_SCOPE RT_FORMAT RT_ENTRY_POINT RT_CROSS_TOOL_BATCH SB_RT_APPLY_ACTIVE RT_REPO_ROOT

LOG="$TL_TMP/calls.log"; export LOG TL_TMP
ST="$TL_TMP/stage"
LIBD="$ST/scripts/lib/recommended-tools"
mkdir -p "$LIBD" "$ST/hooks"
cp "$TL_REPO_ROOT/scripts/reconcile-recommended-tools.sh" "$ST/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
ln -s "$TL_REPO_ROOT/scripts/lib/recommended-tools/common.sh" "$LIBD/common.sh"
R="$ST/scripts/reconcile-recommended-tools.sh"

# ---- stub component libraries ----
for c in graphify agentmemory rtk context_mode leanctx alumnium search_cli cross_tool; do
  case "$c" in context_mode) f="probe-context-mode.sh" ;; cross_tool) f="probe-cross-tool.sh" ;; *) f="probe-$c.sh" ;; esac
  cat >"$LIBD/$f" <<EOF2
rt_probe_$c() {
  local n=0 cf="\$TL_TMP/count-$c"
  [[ -f "\$cf" ]] && n="\$(cat "\$cf")"
  n=\$((n + 1)); echo "\$n" >"\$cf"
  echo "probe $c #\$n batch=\${RT_CROSS_TOOL_BATCH:-}" >>"\$LOG"
  [[ "\${STUB_PROBE_FAIL_$c:-0}" == 1 ]] && return 1
  local v=STUB_PROBE_$c
  if [[ \$n -gt 1 && -n "\${STUB_PROBE_AFTER_$c:-}" ]]; then v=STUB_PROBE_AFTER_$c; fi
  printf '%s' "\${!v:-{\\"component\\":\\"$c\\",\\"consent\\":\\"disabled\\",\\"canonical_state\\":\\"disabled\\",\\"activation_status\\":\\"none\\",\\"evidence\\":[],\\"repairable\\":false,\\"actions\\":[],\\"failures\\":[]\\}}"
}
[[ " \${STUB_NO_REPAIR:-} " == *" $c "* ]] || rt_repair_$c() {
  echo "repair $c" >>"\$LOG"
  local v=STUB_REPAIR_$c
  printf '%s' "\${!v:-{\\"actions\\":[],\\"failures\\":[],\\"restart_required\\":false\\}}"
}
EOF2
done
: >"$LIBD/repair-graphify.sh"
cat >"$LIBD/heartbeat.sh" <<'EOF2'
rt_heartbeat_cleanup_expired() { echo "heartbeat-cleanup" >>"$LOG"; return "${STUB_HB_RC:-0}"; }
EOF2
cat >"$LIBD/receipts.sh" <<'EOF2'
rt_host_evidence_read_stdin() {
  echo "evidence-stdin: $(cat)" >>"$LOG"
  RT_HOST_EVIDENCE_ERROR="${STUB_EVID_ERR:-}"
  RT_HOST_EVIDENCE_JSON="${STUB_EVID_JSON:-}"
  [[ -z "${STUB_EVID_FAIL:-}" ]]
}
rt_receipt_consume_host_evidence() { echo "consume-evidence" >>"$LOG"; return "${STUB_CONSUME_RC:-0}"; }
rt_reconcile_receipt_state() {
  [[ -z "${STUB_RECEIPT_FAIL:-}" ]] || return 1
  printf '%s' "${STUB_RECEIPT:-{\}}"
}
rt_apply_host_convergence_batches() { echo "convergence $1" >>"$LOG"; printf '%s' "${STUB_CONV:-{\}}"; }
EOF2

PROJ="$TL_TMP/proj"; mkdir -p "$PROJ"
git -C "$PROJ" init -q
CANON="$(cd "$PROJ" && pwd -P)"
cfg() { printf '%s\n' "$1" >"$PROJ/.silver-bullet.json"; }
cfg '{"sb_initiated":true,"recommended_tools":{}}'
comp() {  # id state [repairable] [activation]
  jq -nc --arg id "$1" --arg st "$2" --argjson rp "${3:-false}" --arg act "${4:-none}" \
    '{component:$id,consent:"enabled",canonical_state:$st,activation_status:$act,evidence:[],repairable:$rp,actions:[],failures:[]}'
}
reset() { : >"$LOG"; rm -f "$TL_TMP"/count-*; }
# run_r VAR=val ... -- args: run the staged reconciler
run_r() {
  local envs=()
  while [[ "${1:-}" != "--" ]]; do envs+=("$1"); shift; done
  shift; reset
  tl_run env "${envs[@]}" bash "$R" "$@"
}
logs() { cat "$LOG"; }
R_ARGS=(--project-root "$PROJ" --host cursor)

# ---------- arguments ----------
run_r X=1 -- --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help text" "$TL_OUT" "Usage: bash scripts/reconcile-recommended-tools.sh [options]"
run_r X=1 -- --bogus
assert_eq "unknown argument exits 2" "2" "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "Unknown argument: --bogus"
for opt in --project-root --host --mode --scope --format --entry-point; do
  run_r X=1 -- "$opt"
  assert_eq "trailing $opt exits 2" "2" "$TL_STATUS"
  assert_contains "trailing $opt explained" "$TL_ERR" "ERROR: $opt requires a value"
done

# ---------- project root resolution ----------
mkdir -p "$PROJ/sub/dir"
reset
tl_run bash -c 'cd "$1" && shift && exec env X=1 bash "$@"' _ "$PROJ/sub/dir" "$R" --format json
assert_eq "defaults to the git toplevel" "$CANON" "$(jq -r '.project_root' <<<"$TL_OUT")"
NOGIT="$TL_TMP/nogit"; mkdir -p "$NOGIT"
tl_run bash -c 'cd "$1" && shift && exec env GIT_CEILING_DIRECTORIES="$1/.." X=1 bash "$@"' _ "$NOGIT" "$R" --format json
assert_eq "defaults to PWD outside git" "$(cd "$NOGIT" && pwd -P)" "$(jq -r '.project_root' <<<"$TL_OUT")"
run_r X=1 -- --project-root "$TL_TMP/nope" --format json
assert_eq "missing project root fails" "1" "$TL_STATUS"

# ---------- library layouts ----------
ALT="$TL_TMP/alt"; mkdir -p "$ALT/scripts" "$ALT/hooks"
cp "$R" "$ALT/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ALT/hooks/lib"
cp -rL "$LIBD" "$ALT/scripts/recommended-tools"
tl_run bash "$ALT/scripts/reconcile-recommended-tools.sh" "${R_ARGS[@]}" --format json
assert_eq "sibling recommended-tools directory is used" "0" "$TL_STATUS"
assert_eq "sibling layout produced components" "8" "$(jq -r '.components | length' <<<"$TL_OUT")"
NOLIB="$TL_TMP/nolib"; mkdir -p "$NOLIB/scripts" "$NOLIB/hooks"
cp "$R" "$NOLIB/scripts/"
tl_run bash "$NOLIB/scripts/reconcile-recommended-tools.sh" "${R_ARGS[@]}"
assert_eq "no library directory fails" "1" "$TL_STATUS"
assert_contains "missing common.sh reported" "$TL_ERR" "recommended-tools/common.sh"

# ---------- validation ----------
run_r X=1 -- "${R_ARGS[@]}" --host nope
assert_eq "unknown host exits 2" "2" "$TL_STATUS"
assert_contains "unknown host text" "$TL_ERR" "ERROR: unknown host: nope (allowed: cursor|claude|codex|opencode|pi|goose|hermes)"
run_r X=1 -- "${R_ARGS[@]}" --host nope --format json
assert_eq "unknown host json exits 2" "2" "$TL_STATUS"
assert_eq "unknown host json error" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_contains "unknown host json message" "$(jq -r '.error' <<<"$TL_OUT")" "unknown host: nope"
run_r X=1 -- "${R_ARGS[@]}" --entry-point init
assert_eq "entry point with verify exits 2" "2" "$TL_STATUS"
assert_contains "entry point failure text" "$TL_ERR" "ERROR: entry-point supplied with mode=verify; fail closed"
run_r X=1 -- "${R_ARGS[@]}" --entry-point init --format json
assert_eq "entry point failure json" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_contains "entry point failure json error" "$(jq -r '.error' <<<"$TL_OUT")" "fail closed"
run_r X=1 -- "${R_ARGS[@]}" --mode apply
assert_eq "apply without entry point exits 2" "2" "$TL_STATUS"
assert_contains "apply without entry point text" "$TL_ERR" "apply requires exactly one --entry-point"

# ---------- host evidence on stdin ----------
run_r STUB_EVID_FAIL=1 STUB_EVID_ERR=host_evidence_oversized -- "${R_ARGS[@]}" --host-evidence-stdin
assert_eq "rejected evidence exits 2" "2" "$TL_STATUS"
assert_contains "rejected evidence text" "$TL_ERR" "ERROR: host_evidence_oversized"
run_r STUB_EVID_FAIL=1 -- "${R_ARGS[@]}" --host-evidence-stdin --format json
assert_eq "rejected evidence json ok flag" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_eq "rejected evidence default error" "host_evidence_invalid" "$(jq -r '.error' <<<"$TL_OUT")"
run_r STUB_EVID_FAIL=1 -- "${R_ARGS[@]}" --host-evidence-stdin
assert_contains "rejected evidence default text" "$TL_ERR" "ERROR: host_evidence_invalid"
reset
tl_run_stdin '{"a":1}' env STUB_EVID_JSON='{"a":1}' bash "$R" "${R_ARGS[@]}" --host-evidence-stdin
assert_eq "accepted evidence continues" "0" "$TL_STATUS"
assert_contains "stdin reaches the evidence reader" "$(logs)" 'evidence-stdin: {"a":1}'
assert_not_contains "evidence is only consumed on apply" "$(logs)" "consume-evidence"
reset
tl_run_stdin '{"a":1}' env STUB_EVID_JSON='{"a":1}' bash "$R" "${R_ARGS[@]}" --host-evidence-stdin --mode apply --entry-point doctor-fix
assert_contains "apply consumes evidence" "$(logs)" "consume-evidence"
reset
tl_run_stdin '{"a":1}' env STUB_EVID_JSON='{"a":1}' STUB_CONSUME_RC=1 bash "$R" "${R_ARGS[@]}" --host-evidence-stdin --mode apply --entry-point doctor-fix
assert_eq "failing evidence consumption tolerated" "0" "$TL_STATUS"
run_r X=1 -- "${R_ARGS[@]}" --mode apply --entry-point doctor-fix
assert_not_contains "no evidence, nothing consumed" "$(logs)" "consume-evidence"

# ---------- verify rendering and exit codes ----------
run_r X=1 -- "${R_ARGS[@]}"
assert_eq "all disabled is ok" "0" "$TL_STATUS"
assert_contains "text header" "$TL_OUT" "=== reconcile-recommended-tools (verify/all host=cursor) ==="
assert_contains "text component line" "$TL_OUT" "graphify: disabled (activation=none)"
assert_contains "all eight components probed" "$(logs)" "probe cross_tool #1"
assert_not_contains "no restart banner" "$TL_OUT" "RESTART_REQUIRED"
assert_not_contains "no receipt line" "$TL_OUT" "RELOAD_RECEIPT"
run_r STUB_PROBE_rtk="$(comp rtk failed)" -- "${R_ARGS[@]}"
assert_eq "failed component exits 1 (text)" "1" "$TL_STATUS"
assert_contains "failed component rendered" "$TL_OUT" "rtk: failed (activation=none)"
run_r STUB_PROBE_rtk="$(comp rtk failed)" -- "${R_ARGS[@]}" --format json
assert_eq "failed component exits 1 (json)" "1" "$TL_STATUS"
assert_eq "failed component json ok" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" -- "${R_ARGS[@]}" --format json
assert_eq "repairable component is not ok" "1" "$TL_STATUS"
run_r STUB_PROBE_rtk="$(comp rtk reload_required)" -- "${R_ARGS[@]}" --format json
assert_eq "reload_required component is not ok" "1" "$TL_STATUS"
run_r STUB_PROBE_rtk="$(comp rtk ready)" -- "${R_ARGS[@]}" --format json --scope host --host claude
assert_eq "ready json exits 0" "0" "$TL_STATUS"
assert_eq "json carries mode scope host" "verify|host|claude" "$(jq -r '"\(.mode)|\(.scope)|\(.host)"' <<<"$TL_OUT")"
assert_eq "json entry_point is null for verify" "null" "$(jq -r '.entry_point' <<<"$TL_OUT")"
assert_eq "scope host probes only host components" "alumnium,context_mode,cross_tool,leanctx,rtk" "$(jq -r '[.components[].component] | sort | join(",")' <<<"$TL_OUT")"
assert_eq "schema version" "1.0.0" "$(jq -r '.schema' <<<"$TL_OUT")"
run_r STUB_PROBE_FAIL_rtk=1 -- "${R_ARGS[@]}" --format json
assert_eq "a failing probe aborts the run" "1" "$TL_STATUS"

# unknown config keys are reported
cfg '{"sb_initiated":true,"recommended_tools":{"rtk":{},"mystery_tool":{"enabled_by_user":true}}}'
run_r X=1 -- "${R_ARGS[@]}" --format json
assert_eq "unknown config keys listed" '["mystery_tool"]' "$(jq -c '.unknown_keys' <<<"$TL_OUT")"
cfg 'this is not json'
run_r X=1 -- "${R_ARGS[@]}" --format json
assert_eq "invalid project config: no unknown keys" "[]" "$(jq -c '.unknown_keys' <<<"$TL_OUT")"
cfg '{"sb_initiated":true,"recommended_tools":{}}'
rm -f "$PROJ/.silver-bullet.json"
run_r X=1 -- "${R_ARGS[@]}" --format json
assert_eq "no project config: no unknown keys" "[]" "$(jq -c '.unknown_keys' <<<"$TL_OUT")"
cfg '{"sb_initiated":true,"recommended_tools":{}}'

# ---------- apply: repair sequencing ----------
RP='{"actions":["did-it"],"failures":["could-not-x"],"restart_required":true}'
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" STUB_PROBE_AFTER_rtk="$(comp rtk ready)" STUB_REPAIR_rtk="$RP" -- "${R_ARGS[@]}" --mode apply --entry-point doctor-fix --format json
assert_eq "repaired component re-probed" "ready" "$(jq -r '.components[] | select(.component=="rtk") | .canonical_state' <<<"$TL_OUT")"
assert_eq "repair actions merged" '["did-it"]' "$(jq -c '.components[] | select(.component=="rtk") | .actions' <<<"$TL_OUT")"
assert_eq "repair failures aggregated" '["could-not-x"]' "$(jq -c '.failures' <<<"$TL_OUT")"
assert_eq "restart required propagated" "true" "$(jq -r '.restart_required' <<<"$TL_OUT")"
assert_eq "entry point reported" "doctor-fix" "$(jq -r '.entry_point' <<<"$TL_OUT")"
assert_contains "repair ran" "$(logs)" "repair rtk"
assert_contains "probe ran before and after" "$(logs)" "probe rtk #2"
assert_not_contains "doctor-fix skips heartbeat cleanup" "$(logs)" "heartbeat-cleanup"
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" STUB_REPAIR_rtk='{"actions":[],"failures":[],"restart_required":false}' -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_contains "init apply cleans expired heartbeats" "$(logs)" "heartbeat-cleanup"
assert_eq "no restart without a restart request" "false" "$(jq -r '.restart_required' <<<"$TL_OUT")"
run_r STUB_HB_RC=1 -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_contains "heartbeat cleanup attempted" "$(logs)" "heartbeat-cleanup"
assert_eq "failing heartbeat cleanup tolerated" "0" "$TL_STATUS"
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_eq "repairable without a repair result: default repair merged" "rtk" "$(jq -r '.components[] | select(.component=="rtk") | .component' <<<"$TL_OUT")"
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" STUB_NO_REPAIR=rtk -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_not_contains "no repair function, nothing repaired" "$(logs)" "repair rtk"
assert_eq "unrepaired component stays repairable" "repairable" "$(jq -r '.components[] | select(.component=="rtk") | .canonical_state' <<<"$TL_OUT")"
run_r STUB_PROBE_rtk="$(comp rtk repairable false)" -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_not_contains "non-repairable component is left alone" "$(logs)" "repair rtk"
run_r STUB_PROBE_rtk="$(comp rtk repairable true)" -- "${R_ARGS[@]}" --format json
assert_not_contains "verify never repairs" "$(logs)" "repair "
run_r STUB_PROBE_rtk='' -- "${R_ARGS[@]}" --mode apply --entry-point init --format json
assert_not_contains "empty probe output is skipped" "$TL_OUT" '"component":"rtk"'

# apply exports the reentrancy marker and the batch flag
run_r X=1 -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_contains "batch flag exported for cross_tool" "$(logs)" "probe cross_tool #1 batch=1"
run_r X=1 -- "${R_ARGS[@]}" --mode apply --entry-point update --scope project --format json
assert_contains "project scope still includes cross_tool" "$(logs)" "batch=1"
run_r X=1 -- "${R_ARGS[@]}" --mode apply --entry-point installer --scope packages --format json
assert_contains "packages scope without cross_tool: no batch flag" "$(logs)" "probe rtk #1 batch="
assert_not_contains "no batch flag without cross_tool" "$(logs)" "batch=1"

# ---------- apply: cross-tool repair re-probes siblings ----------
run_r STUB_PROBE_cross_tool="$(comp cross_tool repairable true)" STUB_PROBE_AFTER_cross_tool="$(comp cross_tool ready)" \
  STUB_PROBE_rtk="$(comp rtk ready false act1)" STUB_PROBE_AFTER_rtk="$(comp rtk ready false act2)" -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_contains "cross_tool repair triggers sibling re-probe" "$(logs)" "probe rtk #2"
assert_eq "sibling carries its fresh probe" "act2" "$(jq -r '.components[] | select(.component=="rtk") | .activation_status' <<<"$TL_OUT")"
assert_not_contains "cross_tool is not re-probed as a sibling" "$(logs)" "probe cross_tool #3"
assert_not_contains "no forced convergence after a cross_tool repair" "$(logs)" "convergence"

# a probe reporting a component without a probe function keeps its result
WEIRD="$(comp weird_tool ready)"
run_r STUB_PROBE_rtk="$WEIRD" STUB_PROBE_cross_tool="$(comp cross_tool repairable true)" -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_eq "component without probe function is kept as is" "ready" "$(jq -r '.components[] | select(.component=="weird_tool") | .canonical_state' <<<"$TL_OUT")"

# ---------- apply: forced host convergence ----------
cfg '{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
CONV='{"failures":["conv-failed"],"restart_required":true}'
run_r STUB_CONV="$CONV" -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_contains "forced convergence runs" "$(logs)" "convergence true"
assert_eq "convergence failures aggregated" '["conv-failed"]' "$(jq -c '.failures' <<<"$TL_OUT")"
assert_eq "convergence restart propagated" "true" "$(jq -r '.restart_required' <<<"$TL_OUT")"
assert_contains "siblings re-probed after convergence" "$(logs)" "probe rtk #2"
run_r STUB_CONV='{"failures":[],"restart_required":false}' -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_eq "clean convergence: no restart" "false" "$(jq -r '.restart_required' <<<"$TL_OUT")"
run_r STUB_CONV="$CONV" -- "${R_ARGS[@]}" --mode apply --entry-point update --scope packages --format json
assert_not_contains "no convergence without the cross-tool batch" "$(logs)" "convergence"
cfg '{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":false}}}'
run_r STUB_CONV="$CONV" -- "${R_ARGS[@]}" --mode apply --entry-point update --format json
assert_not_contains "no convergence when no tool is opted in" "$(logs)" "convergence"
run_r STUB_CONV="$CONV" -- "${R_ARGS[@]}" --format json
assert_not_contains "verify never converges" "$(logs)" "convergence"
cfg '{"sb_initiated":true,"recommended_tools":{}}'

# ---------- reload receipts ----------
REC='{"has_receipt":true,"canonical_state":"reload_required","activation_status":"pending","clear_eligible":false}'
run_r STUB_RECEIPT="$REC" STUB_PROBE_rtk="$(comp rtk ready)" STUB_PROBE_leanctx="$(comp leanctx failed)" -- "${R_ARGS[@]}"
assert_eq "reload receipt makes the run fail" "1" "$TL_STATUS"
assert_contains "ready component becomes reload_required" "$TL_OUT" "rtk: reload_required (activation=pending)"
assert_contains "non-ready component untouched" "$TL_OUT" "leanctx: failed (activation=none)"
assert_contains "restart banner" "$TL_OUT" "RESTART_REQUIRED: yes — reload Cursor MCP after host config changes"
assert_contains "configured/live line" "$TL_OUT" "CONFIGURED: yes | LIVE: no | ACTION:"
assert_contains "receipt line" "$TL_OUT" "RELOAD_RECEIPT: active (activation=pending, clear_eligible=false)"
run_r STUB_RECEIPT="$REC" STUB_PROBE_rtk="$(comp rtk ready)" -- "${R_ARGS[@]}" --format json
assert_eq "reload receipt json not ok" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_eq "reload receipt marks the component" "true" "$(jq -r '.components[] | select(.component=="rtk") | .reload_receipt' <<<"$TL_OUT")"
assert_eq "receipt embedded" "pending" "$(jq -r '.receipt.activation_status' <<<"$TL_OUT")"
run_r STUB_RECEIPT='{"has_receipt":true,"canonical_state":"ready","activation_status":"active","clear_eligible":true}' -- "${R_ARGS[@]}"
assert_eq "satisfied receipt keeps the run ok" "0" "$TL_STATUS"
assert_contains "satisfied receipt reported" "$TL_OUT" "RELOAD_RECEIPT: active (activation=active, clear_eligible=true)"
assert_not_contains "satisfied receipt needs no restart" "$TL_OUT" "RESTART_REQUIRED"
run_r STUB_RECEIPT_FAIL=1 -- "${R_ARGS[@]}" --format json
assert_eq "failing receipt evaluation falls back to {}" "0" "$TL_STATUS"
assert_eq "empty receipt object" "{}" "$(jq -c '.receipt' <<<"$TL_OUT")"

tl_results
