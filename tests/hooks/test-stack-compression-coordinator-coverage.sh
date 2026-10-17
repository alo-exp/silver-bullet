#!/usr/bin/env bash
# Behavior tests for hooks/lib/stack-compression-coordinator.sh and
# hooks/lib/token-compression-tools-gate.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# shellcheck source=../../hooks/lib/token-compression-tools-gate.sh
source "$TL_REPO_ROOT/hooks/lib/token-compression-tools-gate.sh"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }

LEAN="$TL_TMP/lean.json"   # leanctx + rtk + context_mode, default profile with routes
TWO="$TL_TMP/two.json"     # rtk + context_mode only (no leanctx)
ONE="$TL_TMP/one.json"     # rtk only
NONE="$TL_TMP/none.json"
cat >"$LEAN" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true},"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}},
 "optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx","sb_shell":"rtk","sb_graph":"graphify","sb_remember":"agentmemory","sb_webfetch":"context_mode","sb_slice":"context_mode","sb_grep":"context_mode"}}}}
J
cat >"$TWO" <<'J'
{"recommended_tools":{"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}}}
J
cat >"$ONE" <<'J'
{"recommended_tools":{"rtk":{"enabled_by_user":true}}}
J
printf '{}' >"$NONE"

# ---------- state paths ----------
assert_eq "coordinator state path" "$SB_RUNTIME_STATE_DIR/stack-compression-coordinator" "$(sb_stack_coordinator_state_path)"
assert_eq "mutex state path" "$SB_RUNTIME_STATE_DIR/stack-compression-mutex" "$(sb_stack_mutex_state_path)"
assert_eq "lifecycle state path" "$SB_RUNTIME_STATE_DIR/stack-compression-lifecycle" "$(sb_stack_lifecycle_state_path)"
assert_eq "state path falls back to HOME/.silver-bullet" "$HOME/.silver-bullet/stack-compression-mutex" "$(env -u SB_RUNTIME_STATE_DIR bash -c 'source "$1"; sb_stack_mutex_state_path' _ "$TL_REPO_ROOT/hooks/lib/stack-compression-coordinator.sh")"

# ---------- enabled count / coordinator needed ----------
assert_eq "count three" "3" "$(sb_stack_compression_tools_enabled_count "$LEAN")"
assert_eq "count two" "2" "$(sb_stack_compression_tools_enabled_count "$TWO")"
assert_eq "count one" "1" "$(sb_stack_compression_tools_enabled_count "$ONE")"
assert_eq "count zero" "0" "$(sb_stack_compression_tools_enabled_count "$NONE")"
assert_eq "count without config" "0" "$(sb_stack_compression_tools_enabled_count)"
yes_t "needed with leanctx" sb_stack_coordinator_needed "$LEAN"
yes_t "needed with two tools" sb_stack_coordinator_needed "$TWO"
no_t "not needed with one tool" sb_stack_coordinator_needed "$ONE"
no_t "not needed without config" sb_stack_coordinator_needed ""
no_t "not needed with missing file" sb_stack_coordinator_needed "$TL_TMP/absent.json"
yes_t "mutual exclusion required (needed)" sb_stack_mutual_exclusion_required "$TWO"
no_t "mutual exclusion not required" sb_stack_mutual_exclusion_required "$ONE"

# ---------- default route owner / route owner ----------
for pair in sb_wire:leanctx sb_read:leanctx sb_pathjail:leanctx sb_injection:leanctx sb_grep:context_mode sb_slice:context_mode sb_webfetch:context_mode sb_shell:rtk sb_graph:graphify sb_remember:agentmemory; do
  assert_eq "default owner ${pair%%:*}" "${pair##*:}" "$(sb_stack_default_route_owner "${pair%%:*}")"
done
no_t "default owner unknown" sb_stack_default_route_owner bogus
no_t "default owner empty" sb_stack_default_route_owner ""

no_t "route owner no config" sb_stack_route_owner "" sb_read
no_t "route owner missing file" sb_stack_route_owner "$TL_TMP/absent.json" sb_read
no_t "route owner empty route" sb_stack_route_owner "$LEAN" ""
assert_eq "route owner from profile" "leanctx" "$(sb_stack_route_owner "$LEAN" sb_read)"
assert_eq "route owner profile shell" "rtk" "$(sb_stack_route_owner "$LEAN" sb_shell)"
# leanctx active, route missing from profile -> default owner
cat >"$TL_TMP/lean-partial.json" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true,"optimization_profile":"custom"}},"optimization_profiles":{"custom":{"routes":{"sb_shell":"rtk"}}}}
J
assert_eq "route owner falls back to default owner" "leanctx" "$(sb_stack_route_owner "$TL_TMP/lean-partial.json" sb_wire)"
no_t "route owner unknown route with leanctx" sb_stack_route_owner "$TL_TMP/lean-partial.json" bogus
# jq failure on profile lookups falls back
REAL_JQ="$(command -v jq)"
tl_stub jq 'for a in "$@"; do case "$a" in *optimization_profile*) exit 1;; esac; done; exec '"$REAL_JQ"' "$@"'
hash -r
assert_eq "route owner survives jq failure" "leanctx" "$(sb_stack_route_owner "$LEAN" sb_read)"
rm -f "$TL_BIN/jq"; hash -r
# no leanctx: legacy mapping
assert_eq "legacy sb_read" "context_mode" "$(sb_stack_route_owner "$TWO" sb_read)"
assert_eq "legacy sb_grep" "context_mode" "$(sb_stack_route_owner "$TWO" sb_grep)"
assert_eq "legacy sb_slice" "context_mode" "$(sb_stack_route_owner "$TWO" sb_slice)"
assert_eq "legacy sb_webfetch" "context_mode" "$(sb_stack_route_owner "$TWO" sb_webfetch)"
assert_eq "legacy sb_shell" "rtk" "$(sb_stack_route_owner "$TWO" sb_shell)"
assert_eq "legacy sb_graph" "graphify" "$(sb_stack_route_owner "$TWO" sb_graph)"
assert_eq "legacy sb_remember" "agentmemory" "$(sb_stack_route_owner "$TWO" sb_remember)"
no_t "legacy sb_wire has none" sb_stack_route_owner "$TWO" sb_wire

# ---------- surface owner recording ----------
no_t "record surface needs route" sb_stack_record_surface_owner "$LEAN" "" rtk
no_t "record surface needs owner" sb_stack_record_surface_owner "$LEAN" sb_shell ""
no_t "recorded owner none before" sb_stack_surface_recorded_owner "$LEAN" sb_shell
tl_stub date 'echo 1700000000'
hash -r
sb_stack_record_surface_owner "$LEAN" sb_shell rtk
S="$(sb_stack_coordinator_state_path)"
assert_eq "surface recorded owner" "rtk" "$(jq -r '.surfaces.sb_shell.owner' "$S")"
assert_eq "surface recorded epoch" "1700000000" "$(jq -r '.surfaces.sb_shell.epoch' "$S")"
sb_stack_record_surface_owner "$LEAN" sb_read leanctx
assert_eq "second surface appended" "leanctx" "$(jq -r '.surfaces.sb_read.owner' "$S")"
assert_eq "first surface kept" "rtk" "$(jq -r '.surfaces.sb_shell.owner' "$S")"
assert_eq "recorded owner lookup" "leanctx" "$(sb_stack_surface_recorded_owner "$LEAN" sb_read)"
assert_eq "recorded owner unknown route empty" "" "$(sb_stack_surface_recorded_owner "$LEAN" sb_graph)"
printf 'garbage' >"$S"
no_t "record surface fails on corrupt state" sb_stack_record_surface_owner "$LEAN" sb_graph graphify
assert_eq "corrupt state untouched" "garbage" "$(cat "$S")"
assert_eq "recorded owner on corrupt state empty" "" "$(sb_stack_surface_recorded_owner "$LEAN" sb_read)"
rm -f "$S"; mkdir "$S"
no_t "record surface fails when state path is a directory" sb_stack_record_surface_owner "$LEAN" sb_graph graphify
rmdir "$S"

# ---------- double compression / mutex ----------
M="$(sb_stack_mutex_state_path)"
yes_t "mutex clean without state" sb_stack_mutual_exclusion_is_clean "$LEAN"
sb_stack_record_double_compression "$LEAN" sb_shell leanctx rtk
assert_eq "violation recorded" "leanctx" "$(jq -r '.violations[0].attempted' "$M")"
assert_eq "violation reason" "sb_stack_double_compression" "$(jq -r '.violations[0].reason' "$M")"
assert_eq "violation epoch" "1700000000" "$(jq -r '.violations[0].epoch' "$M")"
sb_stack_record_double_compression "$LEAN" sb_read rtk leanctx
assert_eq "violation appended" "2" "$(jq -r '.violations | length' "$M")"
no_t "mutex not clean with violations" sb_stack_mutual_exclusion_is_clean "$LEAN"
printf 'garbage' >"$M"
no_t "record double fails on corrupt state" sb_stack_record_double_compression "$LEAN" sb_read a b
yes_t "mutex corrupt state treated as clean" sb_stack_mutual_exclusion_is_clean "$LEAN"
sb_stack_clear_mutex_violations "$LEAN"
assert_file_absent "mutex cleared" "$M"
yes_t "mutex clean after clear" sb_stack_mutual_exclusion_is_clean "$LEAN"
mkdir "$M"
no_t "record double fails when state path is a directory" sb_stack_record_double_compression "$LEAN" sb_read a b
rmdir "$M"
printf '{"violations":[]}' >"$M"
yes_t "mutex clean with empty violations" sb_stack_mutual_exclusion_is_clean "$LEAN"
rm -f "$M"

# routed owner success clears violations and records the surface
sb_stack_record_double_compression "$LEAN" sb_shell leanctx rtk
rm -f "$S"
sb_stack_record_routed_owner_success "$LEAN" sb_shell rtk
assert_file_absent "success clears violations" "$M"
assert_eq "success records owner" "rtk" "$(jq -r '.surfaces.sb_shell.owner' "$S")"
sb_stack_record_double_compression "$LEAN" sb_shell leanctx rtk
rm -f "$S"
sb_stack_record_routed_owner_success "$LEAN" "" ""
assert_file_absent "success without route still clears" "$M"
assert_file_absent "success without route records nothing" "$S"

# ---------- messages ----------
assert_contains "mutex message" "$(sb_stack_mutual_exclusion_block_message)" "STACK COMPRESSION CONFLICT"
assert_contains "bash deny message" "$(sb_stack_bash_deny_message)" "Bash double-compression blocked"
m="$(sb_stack_read_deny_message_leanctx /p/file.py 9000 4000)"
assert_contains "read deny message size" "$m" "9000 bytes > 4000 byte threshold"
assert_contains "read deny message path" "$m" "Path: /p/file.py"
m="$(sb_stack_mcp_deny_message "$LEAN" lctx_read_ast)"
assert_contains "mcp deny derives route" "$m" "lctx_read_ast blocked on sb_read (owner: leanctx)"
m="$(sb_stack_mcp_deny_message "$LEAN" ctx_search sb_custom someone)"
assert_contains "mcp deny uses explicit route/owner" "$m" "ctx_search blocked on sb_custom (owner: someone)"

# ---------- bash helpers ----------
no_t "rtk_rewritten empty cmd" sb_stack_bash_rtk_rewritten ""
no_t "rtk_rewritten without unwrap helper" sb_stack_bash_rtk_rewritten "rtk git status"
sb_shell_command_unwrap_rtk() { case "$1" in "rtk "*) printf '%s' "${1#rtk }" ;; *) printf '%s' "$1" ;; esac; }
yes_t "rtk_rewritten when unwrapped differs" sb_stack_bash_rtk_rewritten "rtk git status"
no_t "rtk_rewritten when unchanged" sb_stack_bash_rtk_rewritten "git status"
no_t "marker empty" sb_stack_bash_leanctx_shell_marker ""
yes_t "marker env" sb_stack_bash_leanctx_shell_marker "SB_LEANCTX_SHELL=1 ls"
yes_t "marker lean-ctx shell" sb_stack_bash_leanctx_shell_marker "echo x | lean-ctx shell ls"
yes_t "marker leanctx shell" sb_stack_bash_leanctx_shell_marker "leanctx shell ls"
yes_t "marker lctx_shell" sb_stack_bash_leanctx_shell_marker "run lctx_shell now"
no_t "marker plain" sb_stack_bash_leanctx_shell_marker "ls -la"

# ---------- mcp tool routing ----------
for pair in lctx_read_ast:sb_read lctx_read_file:sb_read lctx_graph_q:sb_graph lctx_remember_x:sb_remember lctx_fetch_a:sb_webfetch lctx_webfetch_b:sb_webfetch lctx_shell_c:sb_shell ctx_execute:sb_slice ctx_execute_file:sb_slice ctx_batch_execute:sb_slice ctx_search:sb_slice ctx_index:sb_slice ctx_fetch_and_index:sb_slice; do
  assert_eq "mcp route ${pair%%:*}" "${pair##*:}" "$(sb_stack_mcp_tool_route "${pair%%:*}")"
done
assert_eq "mcp route unknown prints nothing" "" "$(sb_stack_mcp_tool_route something_else)"
assert_eq "mcp route empty prints nothing" "" "$(sb_stack_mcp_tool_route)"
no_t "looks_like_code empty" sb_stack_mcp_query_looks_like_code ""
yes_t "looks_like_code graphify" sb_stack_mcp_query_looks_like_code "ask Graphify things"
yes_t "looks_like_code path" sb_stack_mcp_query_looks_like_code "see hooks/foo"
yes_t "looks_like_code ext" sb_stack_mcp_query_looks_like_code "open app.py"
no_t "looks_like_code prose" sb_stack_mcp_query_looks_like_code "weather tomorrow"

# ---------- should_deny_mcp_tool ----------
deny() { sb_stack_should_deny_mcp_tool "$@"; }
no_t "deny: no config" deny "" srv lctx_read_ast
no_t "deny: no tool" deny "$LEAN" srv ""
no_t "deny: coordinator not needed" deny "$ONE" srv lctx_read_ast
no_t "deny: unmapped tool" deny "$LEAN" srv some_tool
cat >"$TL_TMP/no-owner.json" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{}}}}
J
# lctx_read_ast with leanctx owning: allowed (owner empty -> default owner leanctx), no incumbent
no_t "deny: leanctx owner reading with leanctx" deny "$LEAN" srv lctx_read_ast
# owner map without route and default also absent -> sb_wire etc. are fine; use a route with no default: none exist, so cover via legacy path
# lctx_remember*: denied unless agentmemory owns sb_remember
yes_t "deny: lctx_remember when agentmemory owns" deny "$LEAN" srv lctx_remember_x
cat >"$TL_TMP/lean-remember.json" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_remember":"leanctx","sb_graph":"graphify","sb_webfetch":"leanctx","sb_shell":"leanctx","sb_slice":"leanctx"}}}}
J
no_t "deny: lctx_remember when leanctx owns" deny "$TL_TMP/lean-remember.json" srv lctx_remember_x
# lctx_graph*
yes_t "deny: lctx_graph code query when graphify owns" deny "$LEAN" srv lctx_graph_q "find symbol foo"
no_t "deny: lctx_graph non-code query" deny "$LEAN" srv lctx_graph_q "weather"
no_t "deny: lctx_graph when owner not graphify" deny "$TL_TMP/lean-remember.json" srv lctx_graph_q "x"
# fetch
yes_t "deny: lctx_fetch when context_mode owns" deny "$LEAN" srv lctx_fetch_a
no_t "deny: lctx_fetch when leanctx owns" deny "$TL_TMP/lean-remember.json" srv lctx_fetch_a
# shell
yes_t "deny: lctx_shell when rtk owns" deny "$LEAN" srv lctx_shell_c
no_t "deny: lctx_shell when leanctx owns" deny "$TL_TMP/lean-remember.json" srv lctx_shell_c
# ctx_fetch_and_index: route is sb_slice
no_t "deny: ctx_fetch_and_index when context_mode owns slice" deny "$LEAN" srv ctx_fetch_and_index
yes_t "deny: ctx_fetch_and_index when leanctx owns slice" deny "$TL_TMP/lean-remember.json" srv ctx_fetch_and_index
# generic lctx_* with non-leanctx owner (sb_read -> context_mode in custom profile)
cat >"$TL_TMP/lean-cm-read.json" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"context_mode","sb_grep":"context_mode"}}}}
J
no_t "deny: lctx_read owned by context_mode route sb_read (no case arm)" deny "$TL_TMP/lean-cm-read.json" srv lctx_read_ast
# incumbent mismatch denies; matching incumbent allows
rm -f "$S"
sb_stack_record_surface_owner "$LEAN" sb_read context_mode
yes_t "deny: incumbent differs from owner" deny "$LEAN" srv lctx_read_ast
rm -f "$S"
sb_stack_record_surface_owner "$LEAN" sb_read leanctx
no_t "deny: incumbent equals owner" deny "$LEAN" srv lctx_read_ast
rm -f "$S"
# lctx_ tool on a non-leanctx-owned route hits the case table
cat >"$TL_TMP/lean-cm-owner.json" <<'J'
{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"context_mode","sb_slice":"context_mode","sb_shell":"leanctx"}}}}
J
cat >"$TL_TMP/mk.sh" <<'S'
# usage: mk <file> <route> <owner> : write a leanctx config mapping one route to an owner
mk() { printf '{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"routes":{"%s":"%s"}}}}' "$2" "$3" >"$1"; }
S
# shellcheck source=/dev/null
source "$TL_TMP/mk.sh"
# lctx_* tools whose route table arm applies: lctx_read* -> sb_read (not in the arms), so use tools mapping to arms below
# arms sb_slice/sb_grep/sb_shell/sb_webfetch/sb_graph/sb_remember are only reachable for lctx_* tools via the earlier case; the
# generic block therefore only matters for lctx_read* (sb_read), covered above.
# non-lctx tool (ctx_search -> sb_slice) with owner not leanctx and no incumbent
mk "$TL_TMP/c1.json" sb_slice context_mode
no_t "deny: ctx_search owned by context_mode" deny "$TL_TMP/c1.json" srv ctx_search
mk "$TL_TMP/c2.json" sb_slice leanctx
rm -f "$S"; sb_stack_record_surface_owner "$TL_TMP/c2.json" sb_slice context_mode
yes_t "deny: ctx_search incumbent differs" deny "$TL_TMP/c2.json" srv ctx_search
rm -f "$S"

# ---------- bash double wrap ----------
dw() { sb_stack_should_deny_bash_double_wrap "$@"; }
no_t "double-wrap: coordinator not needed" dw "$ONE" "ls"
no_t "double-wrap: shell owner not rtk" dw "$TL_TMP/lean-remember.json" "ls"
rm -f "$S" "$M"
no_t "double-wrap: plain command" dw "$LEAN" "ls"
no_t "double-wrap: rtk rewritten without marker" dw "$LEAN" "rtk ls"
assert_eq "double-wrap records rtk incumbent" "rtk" "$(jq -r '.surfaces.sb_shell.owner' "$S")"
assert_file_absent "no violation for plain rewrite" "$M"
yes_t "double-wrap: rtk rewritten with marker" dw "$LEAN" "rtk ls SB_LEANCTX_SHELL=1"
assert_eq "double-wrap violation logged" "leanctx" "$(jq -r '.violations[0].attempted' "$M")"
rm -f "$M"
yes_t "double-wrap: marker with rtk incumbent" dw "$LEAN" "lctx_shell ls"
assert_eq "double-wrap marker violation logged" "rtk" "$(jq -r '.violations[0].incumbent' "$M")"
rm -f "$M" "$S"
no_t "double-wrap: marker without incumbent" dw "$LEAN" "lctx_shell ls"
assert_file_absent "no violation without incumbent" "$M"

# ---------- read deny defer ----------
yes_t "defer to leanctx" sb_stack_read_deny_defer_to_leanctx "$LEAN"
no_t "no defer when leanctx inactive" sb_stack_read_deny_defer_to_leanctx "$TWO"
no_t "no defer when read owned by context_mode" sb_stack_read_deny_defer_to_leanctx "$TL_TMP/lean-cm-read.json"

# ---------- compliant routed owner ----------
cro() { sb_stack_tool_is_compliant_routed_owner "$@"; }
no_t "compliant: no config" cro "" Bash
no_t "compliant: no tool" cro "$LEAN" ""
no_t "compliant: coordinator not needed" cro "$ONE" Bash
rm -f "$S" "$M"
assert_eq "compliant bash" "sb_shell rtk" "$(cro "$LEAN" Bash "" "" "ls")"
assert_eq "compliant exec_command" "sb_shell rtk" "$(cro "$LEAN" exec_command "" "" "ls")"
no_t "compliant: bash double wrap" cro "$LEAN" Bash "" "" "rtk ls SB_LEANCTX_SHELL=1"
rm -f "$M" "$S"
assert_eq "compliant bash (profile without explicit shell route)" "sb_shell rtk" "$(cro "$TL_TMP/lean-partial.json" Bash "" "" "ls")"
(
  sb_stack_route_owner() { return 1; }
  cro "$LEAN" Bash "" "" "ls" >/dev/null && exit 1
  cro "$LEAN" MCP srv lctx_read_ast >/dev/null && exit 2
  sb_stack_should_deny_mcp_tool "$LEAN" srv lctx_read_ast && exit 3
  exit 0
) && tl_pass "compliant/deny: unresolvable route owner fails closed" || tl_fail "compliant/deny: unresolvable route owner fails closed (exit $?)"
no_t "compliant: mcp without tool" cro "$LEAN" MCP srv ""
no_t "compliant: mcp unmapped tool" cro "$LEAN" MCP srv unknown_tool
no_t "compliant: mcp denied" cro "$LEAN" CallMcpTool srv lctx_remember_x
assert_eq "compliant mcp read" "sb_read leanctx" "$(cro "$LEAN" CallMcpTool srv lctx_read_ast)"
assert_eq "compliant mcp ctx_search" "sb_slice context_mode" "$(cro "$LEAN" MCP srv ctx_search)"
no_t "compliant: other tool" cro "$LEAN" Read
# shell route without an owner: leanctx profile that has no sb_shell and legacy default exists -> use failing jq to force empty owner is not possible; covered by default owner

# ---------- lifecycle ----------
L="$(sb_stack_lifecycle_state_path)"
no_t "lifecycle_mark needs phase" sb_stack_lifecycle_mark ""
sb_stack_lifecycle_mark context_mode_precompact
assert_eq "lifecycle mark writes epoch" "1700000000" "$(cat "$L.context_mode_precompact")"
no_t "phase epoch missing" sb_stack_lifecycle_phase_epoch agentmemory_snapshot
assert_eq "phase epoch value" "1700000000" "$(sb_stack_lifecycle_phase_epoch context_mode_precompact)"
assert_eq "phase epoch custom state path" "42" "$(printf '42\n' >"$TL_TMP/lc.x"; sb_stack_lifecycle_phase_epoch x "$TL_TMP/lc")"
yes_t "order ok with missing phases" sb_stack_lifecycle_order_ok
printf '10\n' >"$L.context_mode_precompact"; printf '20\n' >"$L.agentmemory_snapshot"; printf '30\n' >"$L.leanctx_compact"
yes_t "order ok ascending" sb_stack_lifecycle_order_ok
printf '20\n' >"$L.leanctx_compact"
yes_t "order ok equal" sb_stack_lifecycle_order_ok
printf '15\n' >"$L.leanctx_compact"
no_t "order wrong (am after lc)" sb_stack_lifecycle_order_ok
printf '30\n' >"$L.leanctx_compact"; printf '5\n' >"$L.agentmemory_snapshot"
no_t "order wrong (cm after am)" sb_stack_lifecycle_order_ok
chmod -R u+w "$SB_RUNTIME_STATE_DIR"
rm -f "$L".*
mkdir "$L.context_mode_precompact"
no_t "lifecycle_mark fails when target is a directory" sb_stack_lifecycle_mark context_mode_precompact
rmdir "$L.context_mode_precompact"

# ---------- fault injection: failing helpers / unwritable state ----------
# A state dir that is really a file makes every mkdir -p and state write fail.
BADDIR="$TL_TMP/not-a-dir"; printf 'file' >"$BADDIR"
(
  export SB_RUNTIME_STATE_DIR="$BADDIR/state"
  sb_stack_record_surface_owner "$LEAN" sb_shell rtk && exit 1
  sb_stack_record_double_compression "$LEAN" sb_shell a b && exit 2
  sb_stack_lifecycle_mark context_mode_precompact && exit 3
  exit 0
) && tl_pass "unwritable state dir makes writers fail" || tl_fail "unwritable state dir makes writers fail (exit $?)"
rm -rf "$M"; mkdir -p "$M/sub"
sb_stack_clear_mutex_violations "$LEAN"
assert_eq "clear_mutex tolerates rm failure (still a directory)" "yes" "$([[ -d "$M/sub" ]] && echo yes || echo no)"
rm -rf "$M"
(
  sb_stack_mcp_tool_route() { return 1; }
  cro "$LEAN" MCP srv lctx_read_ast >/dev/null && exit 1
  sb_stack_should_deny_mcp_tool "$LEAN" srv lctx_read_ast && exit 2
  m="$(sb_stack_mcp_deny_message "$LEAN" lctx_read_ast)"
  [[ "$m" == *"blocked on  (owner: "* ]] || exit 3
  exit 0
) && tl_pass "route lookup failure fails closed / blank in message" || tl_fail "route lookup failure (exit $?)"
(
  sb_stack_route_owner() { return 1; }
  m="$(sb_stack_mcp_deny_message "$LEAN" lctx_read_ast)"
  [[ "$m" == *"blocked on sb_read (owner: )"* ]] || exit 1
  dw "$LEAN" "ls" && exit 2
  exit 0
) && tl_pass "owner lookup failure handled" || tl_fail "owner lookup failure (exit $?)"
(
  sb_shell_command_unwrap_rtk() { return 1; }
  sb_stack_bash_rtk_rewritten "rtk ls" && exit 1
  exit 0
) && tl_pass "unwrap failure means not rewritten" || tl_fail "unwrap failure means not rewritten"
(
  sb_stack_surface_owner() { return 1; }
  sb_stack_read_deny_defer_to_leanctx "$LEAN" && exit 1
  exit 0
) && tl_pass "surface owner failure means no defer" || tl_fail "surface owner failure means no defer"
(
  # generic lctx_* handling for routes other than sb_read (route table arms)
  sb_stack_mcp_tool_route() { printf '%s' "${FAKE_ROUTE:-}"; }
  fake() { FAKE_ROUTE="$1" sb_stack_should_deny_mcp_tool "$2" srv lctx_read_ast; }
  mk "$TL_TMP/f1.json" sb_slice context_mode;  fake sb_slice "$TL_TMP/f1.json" || exit 1
  mk "$TL_TMP/f2.json" sb_grep context_mode;   fake sb_grep "$TL_TMP/f2.json" || exit 2
  mk "$TL_TMP/f3.json" sb_shell rtk;           fake sb_shell "$TL_TMP/f3.json" || exit 3
  mk "$TL_TMP/f4.json" sb_webfetch context_mode; fake sb_webfetch "$TL_TMP/f4.json" || exit 4
  mk "$TL_TMP/f5.json" sb_graph graphify;      fake sb_graph "$TL_TMP/f5.json" || exit 5
  mk "$TL_TMP/f6.json" sb_remember agentmemory; fake sb_remember "$TL_TMP/f6.json" || exit 6
  mk "$TL_TMP/f7.json" sb_slice rtk;           fake sb_slice "$TL_TMP/f7.json" && exit 7
  exit 0
) && tl_pass "generic lctx_* tool denied on routes owned by another tool" || tl_fail "generic lctx_* route arms (exit $?)"
rm -f "$L".*
yes_t "lifecycle order ok with no phase files" sb_stack_lifecycle_order_ok

# ================= token-compression-tools-gate =================
TC="$TL_TMP/tc.json"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed","cli_command":"mycli","usage_ttl_seconds":120,"usage_state_file":"~/custom-usage"}}}' >"$TC"
assert_eq "cli_command configured" "mycli" "$(sb_token_tool_cli_command "$TC" rtk)"
assert_eq "cli_command defaults to id" "other" "$(sb_token_tool_cli_command "$TC" other)"
assert_eq "ttl configured" "120" "$(sb_token_tool_usage_ttl_seconds "$TC" rtk)"
assert_eq "ttl default" "1800" "$(sb_token_tool_usage_ttl_seconds "$TC" other)"
printf '{"recommended_tools":{"rtk":{"usage_ttl_seconds":30}}}' >"$TL_TMP/tc-low.json"
assert_eq "ttl below floor uses default" "1800" "$(sb_token_tool_usage_ttl_seconds "$TL_TMP/tc-low.json" rtk)"
printf '{"recommended_tools":{"rtk":{"usage_ttl_seconds":"abc"}}}' >"$TL_TMP/tc-nan.json"
assert_eq "ttl non numeric uses default" "1800" "$(sb_token_tool_usage_ttl_seconds "$TL_TMP/tc-nan.json" rtk)"
assert_eq "state path ~ expanded" "$HOME/custom-usage" "$(sb_token_tool_usage_state_path "$TC" rtk)"
assert_eq "state path default" "$SB_RUNTIME_STATE_DIR/other-usage" "$(sb_token_tool_usage_state_path "$TC" other)"
assert_eq "state path default without runtime dir" "$HOME/.cursor/.silver-bullet/other-usage" "$(env -u SB_RUNTIME_STATE_DIR bash -c 'source "$1"; sb_token_tool_usage_state_path "$2" other' _ "$TL_REPO_ROOT/hooks/lib/token-compression-tools-gate.sh" "$TC")"
yes_t "install_ready" sb_token_tool_install_ready "$TC" rtk
no_t "install_ready false" sb_token_tool_install_ready "$TC" other
yes_t "enforced" sb_token_tool_enforced "$TC" rtk
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}' >"$TL_TMP/tc-noinst.json"
no_t "enforced requires install_status" sb_token_tool_enforced "$TL_TMP/tc-noinst.json" rtk
no_t "enforced requires consent" sb_token_tool_enforced "$TC" other
tl_stub mycli 'exit 0'
hash -r
yes_t "cli_available" sb_token_tool_cli_available "$TC" rtk
no_t "cli_available missing" sb_token_tool_cli_available "$TC" other_missing_cli

US="$HOME/custom-usage"
no_t "usage not fresh without file" sb_token_tool_usage_is_fresh "$TC" rtk
tl_stub date 'echo 1000'
hash -r
printf 'garbage\n' >"$US"
no_t "usage not fresh with garbage" sb_token_tool_usage_is_fresh "$TC" rtk
printf '900\n' >"$US"
yes_t "usage fresh within ttl" sb_token_tool_usage_is_fresh "$TC" rtk
printf '880\n' >"$US"
yes_t "usage fresh at ttl boundary" sb_token_tool_usage_is_fresh "$TC" rtk
printf '879\n' >"$US"
no_t "usage stale past ttl" sb_token_tool_usage_is_fresh "$TC" rtk
printf '2000\n' >"$US"
no_t "usage in the future is not fresh" sb_token_tool_usage_is_fresh "$TC" rtk
rm -f "$US"
sb_token_tool_record_usage "$TC" rtk
assert_eq "record_usage writes epoch" "1000" "$(cat "$US")"
mkdir -p "$TL_TMP/dirstate"
printf '{"recommended_tools":{"rtk":{"usage_state_file":"%s"}}}' "$TL_TMP/dirstate" >"$TL_TMP/tc-dir.json"
no_t "record_usage fails when target is a directory" sb_token_tool_record_usage "$TL_TMP/tc-dir.json" rtk
(
  export SB_RUNTIME_STATE_DIR="$BADDIR/state"
  printf '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}' >"$TL_TMP/tc-plain.json"
  sb_token_tool_record_usage "$TL_TMP/tc-plain.json" rtk && exit 1
  exit 0
) && tl_pass "record_usage fails when state dir cannot be created" || tl_fail "record_usage fails when state dir cannot be created"
printf '900\n' >"$US"
tl_stub tr 'exit 1'
hash -r
no_t "usage not fresh when state unreadable" sb_token_tool_usage_is_fresh "$TC" rtk
rm -f "$TL_BIN/tr"; hash -r
yes_t "match: cli word" sb_token_tool_command_matches "mycli run" rtk mycli
yes_t "match: path prefix" sb_token_tool_command_matches "/usr/bin/mycli" rtk mycli
no_t "match: different cli" sb_token_tool_command_matches "othercli run" rtk mycli
no_t "match: empty command" sb_token_tool_command_matches "" rtk mycli
no_t "match: empty cli" sb_token_tool_command_matches "mycli" rtk ""
m="$(sb_token_tool_block_message "$TC" rtk)"
assert_contains "block message names tool" "$m" "RTK USAGE REQUIRED — run mycli"
assert_contains "block message ttl" "$m" "every 120s"
assert_contains "mutual exclusion message uses coordinator" "$(sb_token_compression_mutual_exclusion_block_message)" "sb_stack_double_compression"
(
  unset -f sb_stack_mutual_exclusion_block_message
  [[ "$(sb_token_compression_mutual_exclusion_block_message)" == *"double-compression detected."* ]]
) && tl_pass "mutual exclusion message fallback" || tl_fail "mutual exclusion message fallback"

# prompt reminder
printf '{}' >"$TL_TMP/tc-pending.json"
assert_contains "reminder pending" "$(sb_token_tool_prompt_reminder_line "$TL_TMP/tc-pending.json" rtk)" "consent pending"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":false}}}' >"$TL_TMP/tc-off.json"
assert_contains "reminder opted out" "$(sb_token_tool_prompt_reminder_line "$TL_TMP/tc-off.json" rtk)" "opted out"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":true}}}' >"$TL_TMP/tc-susp.json"
assert_contains "reminder suspended" "$(sb_token_tool_prompt_reminder_line "$TL_TMP/tc-susp.json" rtk)" "enforcement suspended"
assert_contains "reminder install pending" "$(sb_token_tool_prompt_reminder_line "$TL_TMP/tc-noinst.json" rtk)" "install_status not installed yet"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed","cli_command":"nonexistent-cli-xyz"}}}' >"$TL_TMP/tc-nocli.json"
assert_contains "reminder cli missing" "$(sb_token_tool_prompt_reminder_line "$TL_TMP/tc-nocli.json" rtk)" "CLI \`nonexistent-cli-xyz\` missing"
printf '900\n' >"$US"
assert_contains "reminder fresh" "$(sb_token_tool_prompt_reminder_line "$TC" rtk)" "fresh usage recorded"
printf '1\n' >"$US"
assert_contains "reminder stale" "$(sb_token_tool_prompt_reminder_line "$TC" rtk)" "USAGE REQUIRED — run \`mycli\` before substantive work (TTL 120s)"

tl_results
