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
dg_assert_ok "nested CLAUDE.md is not the root file: exits 0"
dg_run "$P" "$H" "$(write "$P/README.md")"
assert_eq "other files unaffected" "none" "$(dec)"
dg_assert_ok "other files unaffected: exits 0"
echo existing >"$P/CLAUDE.md"
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "updating an existing root CLAUDE.md allowed" "none" "$(dec)"
dg_assert_ok "updating an existing root CLAUDE.md allowed: exits 0"
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
dg_assert_ok "non-edit tool ignored: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse","tool_name":"Write"}'
assert_eq "non PreToolUse ignored" "" "$TL_OUT"
dg_assert_ok "non PreToolUse ignored: exits 0"
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass" "" "$TL_OUT"
dg_assert_ok "cert run bypass: exits 0"
dg_run_nojq "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "no jq: inert" "" "$TL_OUT"
dg_assert_ok "no jq: inert: exits 0"

mkdir -p "$TL_TMP/bare/.git"
dg_run "$TL_TMP/bare" "$H" "$(write "$TL_TMP/bare/CLAUDE.md")"
assert_eq "no SB markers up to the .git root: inert" "" "$TL_OUT"
dg_assert_ok "no SB markers up to the .git root: inert: exits 0"
mkdir -p "$TL_TMP/mdonly/.git"; echo x >"$TL_TMP/mdonly/silver-bullet.md"
dg_run "$TL_TMP/mdonly" "$H" "$(write "$TL_TMP/mdonly/CLAUDE.md")"
assert_eq "silver-bullet.md without .silver-bullet.json: inert" "" "$TL_OUT"
dg_assert_ok "silver-bullet.md without .silver-bullet.json: inert: exits 0"

dg_run "$P" "$H" "$(write "$P/CLAUDE.md")" PATH="$(tl_path_without python3)"
assert_eq "no python3: path normalisation falls back" "deny" "$(dec)"

dg_run_with_fn "$P" "$H" "$(write "$P/CLAUDE.md")" 'sb_project_active() { return 1; }; export -f sb_project_active'
assert_eq "project reported inactive: inert" "" "$TL_OUT"
dg_assert_ok "project reported inactive: inert: exits 0"
dg_stub_real jq file_paths
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")"
assert_eq "jq failing on the extra path fields: the analysed file_path still denies" "deny" "$(dec)"
rm -f "$TL_BIN/jq"

# --- Bash, case variants, patches, symlinks (R2-26) -------------------------------------------
sh() { tool Bash "$(jq -cn --arg c "$1" '{command:$c}')"; }
dg_run "$P" "$H" "$(sh "printf '# rules\\n' > CLAUDE.md")"
assert_eq "Bash redirect creating CLAUDE.md denied" "deny" "$(dec)"
assert_eq "the Bash deny is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
dg_run "$P" "$H" "$(sh "cp /dev/null AGENTS.md")"
assert_eq "Bash cp creating AGENTS.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "echo hi | tee '$P/CLAUDE.md'")"
assert_eq "tee creating CLAUDE.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "cd sub && echo hi > ../CLAUDE.md")"
assert_eq "cd plus a relative path is resolved" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "python3 -c \"open('CLAUDE.md','w').write('x')\"")"
assert_eq "an opaque writer naming CLAUDE.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "python3 -c 'print(1)'")"
assert_eq "an opaque writer that names no instruction file is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "cat CLAUDE.md; ls")"
assert_eq "reading an instruction file is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo notes > notes.md")"
assert_eq "other Bash writes are allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(write "$P/claude.md")"
assert_eq "case variant claude.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(write "$P/Agents.MD")"
assert_eq "case variant Agents.MD denied" "deny" "$(dec)"
echo existing >"$P/CLAUDE.md"
dg_run "$P" "$H" "$(write "$P/claude.md")"
assert_eq "a case variant of an existing instruction file is an update" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo more >> CLAUDE.md")"
assert_eq "appending to an existing CLAUDE.md allowed" "none" "$(dec)"
rm -f "$P/CLAUDE.md"
dg_run "$P" "$H" "$(tool NotebookEdit "$(jq -cn --arg p "$P/CLAUDE.md" '{notebook_path:$p}')")"
assert_eq "NotebookEdit path field checked" "deny" "$(dec)"
dg_run "$P" "$H" "$(tool apply_patch "$(jq -cn --arg i "*** Begin Patch
*** Update File: README.md
@@
-a
+b
*** Add File: $P/AGENTS.md
+x
*** End Patch" '{input:$i}')")"
assert_eq "a later path of a multi-file patch is checked" "deny" "$(dec)"
dg_run "$P" "$H" "$(tool apply_patch "$(jq -cn --arg i "*** Begin Patch
*** Update File: README.md
*** Move to: CLAUDE.md
*** End Patch" '{input:$i}')")"
assert_eq "a patch Move to target is checked" "deny" "$(dec)"
ln -s CLAUDE.md "$P/rules.md" 2>/dev/null || true
dg_run "$P" "$H" "$(write "$P/rules.md")"
assert_eq "a symlink to a not-yet-created CLAUDE.md is the same target" "deny" "$(dec)"
rm -f "$P/rules.md"

# --- review repair: unseen commands, MCP tools, truncated payloads ------------------------------
PADF="$TL_TMP/pad.txt"; head -c 600000 /dev/zero | tr '\0' 'a' >"$PADF"
dg_run "$P" "$H" "$(jq -cn --rawfile pad "$PADF" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:("echo hi > CLAUDE.md; # " + $pad)}}')"
assert_eq "an over-budget command is refused" "deny" "$(dec)"
assert_contains "with the reason and the way forward" "$TL_OUT" "cannot inspect this command"
dg_run "$P" "$H" "$(sh 'eval "$X"')"
assert_eq "eval of computed text is refused" "deny" "$(dec)"
mcp() { jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{path:$p,content:"x"}}'; }
dg_run "$P" "$H" "$(mcp mcp__filesystem__write_file "$P/CLAUDE.md")"
assert_eq "an MCP write that would create CLAUDE.md is refused" "deny" "$(dec)"
dg_run "$P" "$H" "$(mcp mcp__filesystem__create_directory "$P/CLAUDE.md")"
assert_eq "any MCP create tool is judged" "deny" "$(dec)"
dg_run "$P" "$H" "$(mcp mcp__filesystem__read_file "$P/CLAUDE.md")"
assert_eq "an MCP read tool is not a write" "none" "$(dec)"
echo existing >"$P/CLAUDE.md"
dg_run "$P" "$H" "$(mcp mcp__filesystem__write_file "$P/CLAUDE.md")"
assert_eq "an MCP update of an existing CLAUDE.md passes" "none" "$(dec)"
rm -f "$P/CLAUDE.md"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x > CLAUDE.md'
assert_eq "a truncated payload that names CLAUDE.md fails closed" "deny" "$(dec)"

# --- python3 missing: the shell analysis helper is unavailable ----------------------------
NOPY="$(tl_path_without python3)"
dg_run "$P" "$H" "$(sh "echo x > CLAUDE.md")" PATH="$NOPY"
assert_contains "no python3: a command naming CLAUDE.md is refused with the fix" "$TL_OUT" "python3"
dg_run "$P" "$H" "$(sh "ls -la")" PATH="$NOPY"
assert_eq "no python3: a command naming no instruction file is allowed silently" "" "$TL_OUT"
dg_run "$P" "$H" "$(sh "cat CLAUDE.md")" PATH="$NOPY"
assert_eq "no python3: a plainly read-only command naming it gets no message" "" "$TL_OUT"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash"}'
assert_eq "an empty Bash payload is ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(sh "echo 'unterminated > CLAUDE.md")"
assert_contains "an unparsable command naming CLAUDE.md fails closed" "$TL_OUT" "cannot inspect"
dg_run "$P" "$H" "$(write "$P/CLAUDE.md")" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass still applies" "" "$TL_OUT"

tl_results
