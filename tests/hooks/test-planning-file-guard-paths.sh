#!/usr/bin/env bash
# Path coverage for hooks/planning-file-guard.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/planning-file-guard.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning/phases/01-x" "$P/sub" "$TL_TMP/other/.planning"
ST="$SB_RUNTIME_STATE_DIR"
edit() { jq -cn --arg p "$1" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT"; }

# --- every protected artifact is denied with its owning-skill hint -------
check() { # path hint-fragment
  dg_run "$P" "$H" "$(edit "$P/$1")"
  assert_eq "deny: $1" "deny" "$(dec)"
  assert_contains "hint for $1" "$(reason)" "$2"
}
check .planning/ROADMAP.md "/sb:phase"
check .planning/STATE.md "/sb:execute"
check .planning/PROJECT.md "/sb:init"
check .planning/RELEASE.md "/sb:create-release"
check .planning/REQUIREMENTS.md "/sb:spec"
check .planning/UAT.md "/sb:verify"
check .planning/v1.0-MILESTONE-AUDIT.md "/sb:release"
check .planning/milestones/m1.md ""
check .planning/phases/01-x/01-PLAN.md "/sb:plan"
check .planning/phases/01-x/01-SUMMARY.md "/sb:execute, /sb:release"
check .planning/phases/01-x/01-REVIEW.md "/sb:review"
check .planning/phases/01-x/01-SECURITY.md "/sb:secure"
check .planning/phases/01-x/01-VERIFICATION.md "/sb:verify"
dg_run "$P" "$H" "$(edit ".planning/sub/../ROADMAP.md")"
assert_eq "relative traversal path is normalised and denied" "deny" "$(dec)"
dg_run "$P/sub" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "project found from a sub-directory" "deny" "$(dec)"

# --- not protected / not applicable --------------------------------------
dg_run "$P" "$H" "$(edit "$P/.planning/phases/01-x/PLAN.md")"
assert_eq "SB-native phase layout PLAN.md is not protected here" "none" "$(dec)"
dg_assert_ok "SB-native phase layout PLAN.md is not protected here: exits 0"
dg_run "$P" "$H" "$(edit "$P/.planning/NOTES.md")"
assert_eq "unlisted planning file allowed" "none" "$(dec)"
dg_assert_ok "unlisted planning file allowed: exits 0"
dg_run "$P" "$H" "$(edit "$P/src/a.sh")"
assert_eq "non-planning file allowed" "none" "$(dec)"
dg_assert_ok "non-planning file allowed: exits 0"
dg_run "$P" "$H" "$(edit "")"
assert_eq "empty path allowed" "" "$TL_OUT"
dg_assert_ok "empty path allowed: exits 0"
dg_run "$P" "$H" "$(edit "$TL_TMP/other/.planning/ROADMAP.md")"
assert_eq "planning file of another project not enforced" "none" "$(dec)"
dg_assert_ok "planning file of another project not enforced: exits 0"
mkdir -p "$TL_TMP/bare/.git"
dg_run "$TL_TMP/bare" "$H" "$(edit "$TL_TMP/bare/.planning/ROADMAP.md")"
assert_eq "directory without SB config not enforced" "none" "$(dec)"
dg_assert_ok "directory without SB config not enforced: exits 0"

# --- cert-run bypass & hook-bootstrap hook --------------------------------
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass allows" "none" "$(dec)"
dg_assert_ok "cert run bypass allows: exits 0"
dg_run_with_fn "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" 'sb_hook_exit_on_cert_run() { exit 0; }; export -f sb_hook_exit_on_cert_run'
assert_eq "sb_hook_exit_on_cert_run takes precedence when defined" "" "$TL_OUT"
dg_assert_ok "sb_hook_exit_on_cert_run takes precedence when defined: exits 0"

# --- env / file overrides --------------------------------------------------
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" SB_ALLOW_PLANNING_EDITS=1
assert_contains "env override allows with notice" "$TL_OUT" "SB_ALLOW_PLANNING_EDITS=1"
assert_eq "env override does not deny" "none" "$(dec)"
dg_assert_ok "env override does not deny: exits 0"

OV="$ST/planning-edit-override"
: >"$OV"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/01-x/01-PLAN.md")"
assert_contains "PLAN override allows PLAN edits" "$TL_OUT" "PLAN override active"
assert_contains "PLAN override is audited" "$(cat "$ST/planning-edit-override-audit.log")" "override-used path=01-PLAN.md"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "PLAN override does not cover ROADMAP" "deny" "$(dec)"
rm -f "$OV"; ln -s "$TL_TMP/target" "$OV"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/01-x/01-PLAN.md")"
assert_eq "symlinked override ignored" "deny" "$(dec)"
rm -f "$OV"
rm -f "$ST/planning-edit-override-audit.log"; mkdir -p "$ST/planning-edit-override-audit.log"
: >"$OV"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/01-x/01-PLAN.md")"
assert_contains "unwritable audit log does not block the override" "$TL_OUT" "PLAN override active"
rmdir "$ST/planning-edit-override-audit.log"; rm -f "$OV"

RO="$ST/roadmap-edit-override"
: >"$RO"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "roadmap override without the owning skill recorded is ignored (R2-08)" "deny" "$(dec)"
assert_not_contains "the deny no longer tells the agent how to arm an override" "$(reason)" "touch ${ST}/roadmap-edit-override"
assert_contains "the deny says the user decides" "$(reason)" "the user's decision"
printf 'silver-phase\n' >"$ST/state"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_contains "roadmap override allows ROADMAP" "$TL_OUT" "roadmap-edit-override active"
assert_contains "roadmap override audited" "$(cat "$ST/roadmap-edit-override-audit.log")" "override-used path=ROADMAP.md"
dg_run "$P" "$H" "$(edit "$P/.planning/STATE.md")"
assert_contains "roadmap override allows STATE" "$TL_OUT" "allowing STATE.md"
dg_run "$P" "$H" "$(edit "$P/.planning/PROJECT.md")"
assert_eq "roadmap override does not cover PROJECT.md" "deny" "$(dec)"
rm -f "$ST/roadmap-edit-override-audit.log"; mkdir -p "$ST/roadmap-edit-override-audit.log"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_contains "unwritable roadmap audit log tolerated" "$TL_OUT" "roadmap-edit-override active"
rmdir "$ST/roadmap-edit-override-audit.log"; rm -f "$RO"
ln -s "$TL_TMP/target" "$RO"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "symlinked roadmap override ignored" "deny" "$(dec)"
rm -f "$RO"

# --- trivial bypass ---------------------------------------------------------
: >"$ST/trivial"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "legacy trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "legacy trivial marker bypasses: exits 0"
rm -f "$ST/trivial"
printf '{"state":{"trivial_file":"%s"}}\n' "$ST/custom-trivial" >"$P/.silver-bullet.json"
: >"$ST/custom-trivial"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "a configured trivial file is not honoured (R2-04)" "deny" "$(dec)"
rm -f "$ST/custom-trivial"
printf '{"state":{"trivial_file":"%s"}}\n' "$TL_TMP/outside-trivial" >"$P/.silver-bullet.json"
: >"$TL_TMP/outside-trivial"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "trivial file outside the state root is ignored" "deny" "$(dec)"
echo 'not json' >"$P/.silver-bullet.json"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "unparsable config still denies" "deny" "$(dec)"
echo '{"sb_initiated":true}' >"$P/.silver-bullet.json"

# --- missing tools ----------------------------------------------------------
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" PATH="$(tl_path_without python3)"
assert_eq "no python3: path normalisation falls back to raw path" "deny" "$(dec)"
dg_run_nojq "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")"
assert_eq "no jq in an SB project: fail closed" "deny" "$(dec)"
assert_contains "no jq: reason explains" "$(reason)" "jq is required"
dg_run "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" PATH="$(tl_path_without jq python3)"
assert_contains "no jq and no python3: static deny" "$TL_OUT" "jq required for Silver Bullet enforcement"
mkdir -p "$TL_TMP/outside"
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(edit "$P/.planning/ROADMAP.md")" PATH="$(tl_path_without jq)"
assert_eq "no jq outside an SB project: allow" "" "$TL_OUT"
dg_assert_ok "no jq outside an SB project: allow: exits 0"

dg_run_with_fn "$P" "$H" "$(edit "$P/.planning/ROADMAP.md")" 'sb_project_active() { return 1; }; export -f sb_project_active'
assert_eq "project reported inactive: guard stands down" "" "$TL_OUT"
dg_assert_ok "project reported inactive: guard stands down: exits 0"

# --- apply_patch payload ----------------------------------------------------
dg_run "$P" "$H" "$(jq -cn --arg i "*** Begin Patch
*** Update File: $P/.planning/ROADMAP.md
@@
+x
*** End Patch" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$i}}')"
assert_eq "apply_patch header on ROADMAP denied" "deny" "$(dec)"

# --- shell writes, patches, symlinks, case variants, Windows spellings (R2-07, R2-35) -------
sh() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
rm -f "$ST/state" "$ST/roadmap-edit-override"
dg_run "$P" "$H" "$(sh "sed -i 's/- \\[ \\]/- [x]/' .planning/ROADMAP.md")"
assert_eq "sed -i on ROADMAP.md denied" "deny" "$(dec)"
assert_eq "the Bash deny is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
dg_run "$P" "$H" "$(sh "echo '- [x] done' >> .planning/STATE.md")"
assert_eq "redirect append to STATE.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "cp /tmp/x .planning/phases/01-x/01-SUMMARY.md")"
assert_eq "cp onto a SUMMARY denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "git mv .planning/ROADMAP.md .planning/OLD.md")"
assert_eq "git mv of ROADMAP.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "cd .planning && echo x > ROADMAP.md")"
assert_eq "cd plus a relative redirect resolved" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "rm .planning/REQUIREMENTS.md")"
assert_eq "rm of REQUIREMENTS.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "cat .planning/ROADMAP.md; grep -n Phase .planning/ROADMAP.md; git status")"
assert_eq "reading planning files is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo notes > .planning/NOTES.md")"
assert_eq "writing an unlisted planning file is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > src/a.sh")"
assert_eq "writing source is not this guard's business" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "git commit -m 'tick .planning/ROADMAP.md'")"
assert_eq "a commit message naming ROADMAP.md is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > $TL_TMP/other/.planning/ROADMAP.md")"
assert_eq "another project's planning file is not enforced" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > .planning/ROADMAP.md")" SB_ALLOW_PLANNING_EDITS=1
assert_eq "the user's env override covers Bash writes" "none" "$(dec)"
assert_eq "an override notice is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
ln -s .planning "$P/plan"
dg_run "$P" "$H" "$(edit "$P/plan/ROADMAP.md")"
assert_eq "Edit through a symlinked directory denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > plan/STATE.md")"
assert_eq "Bash write through a symlinked directory denied" "deny" "$(dec)"
rm -f "$P/plan"
dg_run "$P" "$H" "$(edit "$P/.planning/Roadmap.md")"
assert_eq "case variant Roadmap.md denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(edit "$P/.planning/phases/01-x/01-summary.MD")"
assert_eq "case variant of a SUMMARY denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(edit '.planning\ROADMAP.md')" OSTYPE=msys
assert_eq "Windows-style relative path denied" "deny" "$(dec)"
patch() { jq -cn --arg i "$1" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$i}}'; }
dg_run "$P" "$H" "$(patch "*** Begin Patch
*** Update File: README.md
@@
-a
+b
*** Update File: $P/.planning/ROADMAP.md
@@
-c
+d
*** End Patch")"
assert_eq "a later path of a multi-file patch is checked" "deny" "$(dec)"
dg_run "$P" "$H" "$(patch "*** Begin Patch
*** Update File: README.md
*** Move to: .planning/STATE.md
*** End Patch")"
assert_eq "a patch Move to target is checked" "deny" "$(dec)"
dg_run "$P" "$H" "$(patch "*** Begin Patch
*** Update File: README.md
@@
-a
+b
*** End Patch")"
assert_eq "an ordinary patch is allowed" "none" "$(dec)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/.planning/ROADMAP.md" '{hook_event_name:"PreToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p}}')"
assert_eq "NotebookEdit path field checked" "deny" "$(dec)"
: >"$ST/planning-edit-override"
dg_run "$P" "$H" "$(patch "*** Begin Patch
*** Update File: $P/.planning/phases/01-x/01-PLAN.md
@@
-a
+b
*** Update File: $P/.planning/ROADMAP.md
@@
-c
+d
*** End Patch")"
assert_eq "an override covering only one file of a patch still denies" "deny" "$(dec)"
rm -f "$ST/planning-edit-override" "$ST/planning-edit-override-audit.log"

dg_run "$P" "$H" "$(patch "*** Begin Patch
*** Update File: $P/.planning/ROADMAP.md
@@
-c
+d
*** Update File: $P/.planning/STATE.md
@@
-e
+f
*** End Patch")" SB_ALLOW_PLANNING_EDITS=1
assert_eq "several overridden files: still one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
assert_contains "and it names both notices" "$(jq -r .systemMessage <<<"$TL_OUT")" "ROADMAP.md"

# --- review repair: unseen commands, ancestor writes, MCP tools, truncated payloads -----------
rm -f "$ST/state" "$ST/roadmap-edit-override" "$ST/planning-edit-override"
PADF="$TL_TMP/pad.txt"; head -c 600000 /dev/zero | tr '\0' 'a' >"$PADF"
big="$(jq -cn --rawfile pad "$PADF" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:("echo x >> .planning/ROADMAP.md; # " + $pad)}}')"
dg_run "$P" "$H" "$big"
assert_eq "an over-budget command is refused, not silently allowed" "deny" "$(dec)"
assert_contains "the message says it cannot inspect, with the way forward" "$(reason)" "cannot inspect this command"
dg_run "$P" "$H" "$(sh 'eval "$X"')"
assert_eq "eval of computed text is refused" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh 'ls -la; git status')"
assert_eq "an ordinary command passes" "none" "$(dec)"
dg_run "$P" "$H" "$(sh 'npm test')"
assert_eq "running tests passes" "none" "$(dec)"
FK="$TL_TMP/fakeplan"; mkdir -p "$FK/.planning"; echo x >"$FK/.planning/ROADMAP.md"
for c in "cp -r $FK/.planning ." "cp -a $FK/.planning/. .planning/" "rsync -a $FK/.planning/ .planning/" "tar -xf p.tar -C .planning" "mv $FK/.planning ." "git checkout HEAD -- .planning" "tar -xf p.tar" "unzip -o p.zip"; do
  dg_run "$P" "$H" "$(sh "$c")"
  assert_eq "a write over the planning directory is refused: $c" "deny" "$(dec)"
done
for c in "cp -r src/. dist/" "cp notes.md .planning/NOTES.md" "rsync -a build/ out/" "tar -xf v.tar -C vendor" "mv a.txt b.txt"; do
  dg_run "$P" "$H" "$(sh "$c")"
  assert_eq "an honest copy passes: $c" "none" "$(dec)"
done
dg_run "$P" "$H" "$(sh 'mv .planning /tmp/pl')"
assert_eq "moving the planning directory away is refused" "deny" "$(dec)"
mcp() { jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{path:$p,content:"x"}}'; }
dg_run "$P" "$H" "$(mcp mcp__filesystem__write_file "$P/.planning/ROADMAP.md")"
assert_eq "an MCP write tool is judged like Write" "deny" "$(dec)"
dg_run "$P" "$H" "$(mcp mcp__filesystem__edit_file "$P/.planning/STATE.md")"
assert_eq "an MCP edit tool is judged" "deny" "$(dec)"
dg_run "$P" "$H" "$(mcp mcp__filesystem__read_file "$P/.planning/ROADMAP.md")"
assert_eq "an MCP read tool is not a write" "none" "$(dec)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/.planning/ROADMAP.md" '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:$p}}')"
assert_eq "the Read tool is not a write" "none" "$(dec)"
dg_run "$P" "$H" "$(mcp mcp__filesystem__write_file "$P/.planning/NOTES.md")"
assert_eq "an MCP write to an unlisted planning file passes" "none" "$(dec)"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x >> .planning/ROADMAP.md'
assert_eq "a truncated payload that names .planning fails closed" "deny" "$(dec)"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls'
assert_eq "a truncated payload that names nothing protected passes" "" "$TL_OUT"

# --- python3 missing: the analysis helper is unavailable ----------------------------------------
NOPY="$(tl_path_without python3)"
dg_run "$P" "$H" "$(sh "sed -i s/a/b/ .planning/ROADMAP.md")" PATH="$NOPY"
assert_contains "no python3: a command naming .planning is refused with the fix" "$TL_OUT" "python3"
dg_run "$P" "$H" "$(sh "ls -la")" PATH="$NOPY"
assert_eq "no python3: an unrelated command is allowed silently" "" "$TL_OUT"
dg_run "$P" "$H" "$(sh "cat .planning/ROADMAP.md")" PATH="$NOPY"
assert_eq "no python3: a plainly read-only command gets no message" "" "$TL_OUT"
dg_run "$P" "$H" "$(sh "echo 'unterminated > .planning/ROADMAP.md")"
assert_contains "an unparsable command naming .planning fails closed" "$TL_OUT" "cannot inspect"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash"}'
assert_eq "an empty payload is ignored" "" "$TL_OUT"

# --- round 2: glob, brace and variable targets, patch appliers ------------------------------------
: >"$P/.planning/ROADMAP.md"
sh() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
for c in 'echo x >> .planning/ROADMA?.md' 'cp /tmp/x .planning/R*.md' 'rm .planning/ROADMAP.m[d]' 'mv /tmp/x .planning/{ROADMAP,x}.md' 'cp /tmp/x .planning/$F' 'for f in .planning/ROADMAP.*; do echo x >> "$f"; done'; do
  dg_run "$P" "$H" "$(sh "$c")"
  assert_eq "a pattern that can name the roadmap is refused: $c" "deny" "$(dec)"
done
for c in 'ls .planning/ROADMA?.md' 'cat .planning/R*.md' 'rm -f build/*.o' 'echo x > .planning/notes-$(date +%s).txt'; do
  dg_run "$P" "$H" "$(sh "$c")"
  assert_eq "honest command passes: $c" "none" "$(dec)"
done
tl_results
