#!/usr/bin/env bash
# Behavior and path coverage for hooks/instruction-file-guard.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/instruction-file-guard.sh
P="$TL_TMP/proj"
rm -rf "$P"; dg_project "$P"; mkdir -p "$P/sub/deeper"
tool() { jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}'; }
write() { tool Write "$(jq -cn --arg p "$1" '{file_path:$p}')"; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }

dg_run "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "creating root CLAUDE.md denied" "deny" "$(dec)"
assert_contains "reason mentions silver-bullet.md" "$TL_OUT" "silver-bullet.md"
dg_run "$P" "$H" "$(write "$P/AGENTS.md")"
assert_eq "creating root AGENTS.md denied" "deny" "$(dec)"
dg_run "$P/sub/deeper" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "repo root found from sub-directory" "deny" "$(dec)"
dg_run "$P" "$H" "$(write "CLAUDE.md")"
assert_eq "relative path resolves against cwd" "deny" "$(dec)"
dg_run "$P" "$H" "$(write "$P/sub/CLAUDE.md")"
assert_eq "nested CLAUDE.md is not the root file" "none" "$(dec)"
dg_run "$P" "$H" "$(write "$P/README.md")"
assert_eq "other files unaffected" "none" "$(dec)"
echo existing >"$P/CLAUDE.md"
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "updating an existing root CLAUDE.md allowed" "none" "$(dec)"
rm -f "$P/CLAUDE.md"

dg_run "$P" "$H" "$(tool MultiEdit "$(jq -cn --arg a "$P/x.md" --arg b "$P/AGENTS.md" '{file_paths:[$a,"",$b]}')")"
assert_eq "file_paths list checked (blank entries skipped)" "deny" "$(dec)"
dg_run "$P" "$H" "$(tool apply_patch "$(jq -cn --arg i "*** Begin Patch
*** Add File: $P/CLAUDE.md
+x
*** End Patch" '{input:$i}')")"
assert_eq "apply_patch Add File of root CLAUDE.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(tool apply_patch "$(jq -cn --arg i "*** Begin Patch
*** Add File: $P/docs/a.md
+x
*** End Patch" '{input:$i}')")"
assert_eq "apply_patch of other file allowed" "none" "$(dec)"

dg_run "$P" "$H" "$(tool Read '{"file_path":"/x"}')"
assert_eq "non-edit tool ignored" "" "$TL_OUT"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse","tool_name":"Write"}'
assert_eq "non PreToolUse ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass" "" "$TL_OUT"
dg_run_nojq "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "no jq: inert" "" "$TL_OUT"

mkdir -p "$TL_TMP/bare/.git"
dg_run "$TL_TMP/bare" "$H" "$(write "$TL_TMP/bare/CLAUDE.md")"
assert_eq "no SB markers up to the .git root: inert" "" "$TL_OUT"
mkdir -p "$TL_TMP/mdonly/.git"; echo x >"$TL_TMP/mdonly/silver-bullet.md"
dg_run "$TL_TMP/mdonly" "$H" "$(write "$TL_TMP/mdonly/CLAUDE.md")"
assert_eq "silver-bullet.md without .silver-bullet.json: inert" "" "$TL_OUT"

dg_run "$P" "$H" "$(write "$P/CLAUDE.md")" PATH="$(tl_path_without python3)"
assert_eq "no python3: path normalisation falls back" "deny" "$(dec)"

dg_run_with_fn "$P" "$H" "$(write "$P/CLAUDE.md")" 'sb_project_active() { return 1; }; export -f sb_project_active'
assert_eq "project reported inactive: inert" "" "$TL_OUT"
dg_stub_real jq file_paths
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "path extraction failing: nothing denied" "" "$TL_OUT"
rm -f "$TL_BIN/jq"

# --- library fallbacks via a staged copy ------------------------------------------
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" sb-project-gate.sh tool-input.sh cert-bypass.sh
dg_run "$P" "$S1/hooks/instruction-file-guard.sh" "$(write "$P/CLAUDE.md")"
assert_eq "no gate/tool-input libs: guard still denies" "deny" "$(dec)"
dg_run "$P" "$S1/hooks/instruction-file-guard.sh" "$(tool apply_patch '{"input":"x"}')"
assert_eq "no tool-input lib: apply_patch falls back to file_path keys" "" "$TL_OUT"
dg_run_with_fn "$P" "$S1/hooks/instruction-file-guard.sh" "$(write "$P/CLAUDE.md")" 'sb_project_is_initiated() { return 1; }; export -f sb_project_is_initiated'
assert_eq "initiated-check fallback can opt out" "" "$TL_OUT"
dg_run_with_fn "$P" "$S1/hooks/instruction-file-guard.sh" "$(tool apply_patch '{"input":"x"}')" 'sb_tool_patch_paths() { return 1; }; export -f sb_tool_patch_paths'
assert_eq "failing patch-path helper tolerated" "" "$TL_OUT"
S2="$TL_TMP/s2"; dg_stage_hooks "$S2" cert-bypass.sh
dg_run "$P" "$S2/hooks/instruction-file-guard.sh" "$(write "$P/CLAUDE.md")" SB_AGENT_CERT_RUN=1
assert_eq "no cert-bypass lib: bypass flag has no effect" "deny" "$(dec)"
dg_run_nolib_in "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "lib dir unresolvable: guard still denies" "deny" "$(dec)"

tl_results
