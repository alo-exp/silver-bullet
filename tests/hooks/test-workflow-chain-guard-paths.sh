#!/usr/bin/env bash
# Path coverage for hooks/workflow-chain-guard.sh: every composer policy, workflow
# selection, state-file resolution, catalog aliases and degraded modes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/workflow-chain-guard.sh
P="$TL_TMP/proj"
ST="$SB_RUNTIME_STATE_DIR"
STATE="$ST/state"
edit() { jq -cn --arg p "$P/src/a.sh" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p}}'; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT"; }
fresh() {
  rm -rf "$P"
  dg_project "$P"
  mkdir -p "$P/.planning/workflows" "$P/src"
  : >"$STATE"
}
workflow() { printf -- '---\nid: %s\ncomposer: %s\n---\n' "$1" "$2" >"$P/.planning/workflows/$1.md"; }
markers() { printf '%s\n' "$@" >"$STATE"; }
run() { dg_run "$P" "$H" "$(edit)" SILVER_BULLET_STATE_FILE="$STATE" "$@"; }

# --- composer policies: blocked with empty state, allowed with the full chain --
policy() { # composer; markers...
  local composer="$1"; shift
  fresh
  printf '# spec\n' >"$P/.planning/SPEC.md"
  workflow wf1 "$composer"
  : >"$STATE"
  run
  assert_eq "$composer: blocked with empty state" "deny" "$(dec)"
  assert_contains "$composer: names the workflow" "$(reason)" "(wf1)"
  markers "$@"
  run
  assert_eq "$composer: allowed with full chain" "none" "$(dec)"
  if [[ $# -gt 1 ]]; then
    markers "${@:2}"
    run
    assert_eq "$composer: still blocked when '$1' is missing" "deny" "$(dec)"
    assert_contains "$composer: reports missing '$1'" "$(reason)" "• $1"
  fi
}
policy /sb:feature silver-quality-gates silver-context silver-plan silver-validate
policy /sb:ui silver-quality-gates silver-context silver-plan silver-ui-contract silver-validate
policy /sb:devops silver-blast-radius devops-skill-router devops-quality-gates security silver-context silver-plan silver-validate
policy /sb:deep-research silver-clarify silver-deep-research
policy /sb:new-workflow silver-clarify silver-scan silver-plan silver-validate
policy /sb:bugfix silver-debug silver-plan
policy /sb:fast silver-quality-gates silver-plan silver-validate
policy /sb:release silver-quality-gates
policy /sb silver-context
policy /sb:benchmark silver-context silver-plan
policy /sb:canary silver-blast-radius silver-plan
policy /sb:content silver-clarify silver-plan
policy /sb:deploy silver-blast-radius devops-quality-gates silver-plan
policy /sb:forensics silver-debug
policy /sb:incident silver-blast-radius silver-debug silver-plan
policy /sb:refactor silver-plan silver-validate
policy /sb:retro silver-context
policy /sb:test silver-plan silver-validate
policy silver-feature silver-quality-gates silver-context silver-plan silver-validate
policy "SB:Feature" silver-quality-gates silver-context silver-plan silver-validate

fresh; workflow wf1 /unknown:thing
run
assert_eq "unknown composer is not gated" "none" "$(dec)"

# greenfield feature: clarify + spec are required when SPEC.md is absent
fresh; workflow wf1 /sb:feature
markers silver-quality-gates silver-context silver-plan silver-validate
run
assert_eq "feature without SPEC.md still needs clarify+spec" "deny" "$(dec)"
assert_contains "clarify missing" "$(reason)" "• silver-clarify"
assert_contains "spec missing" "$(reason)" "• silver-spec"
markers silver-quality-gates silver-context silver-plan silver-validate silver-clarify silver-spec
run
assert_eq "feature without SPEC.md passes once clarify+spec recorded" "none" "$(dec)"

# quality-gates design variants satisfy the pre-plan marker
fresh; printf '# s\n' >"$P/.planning/SPEC.md"; workflow wf1 /sb:feature
markers silver-quality-gates-design silver-context silver-plan silver-validate
run
assert_eq "design-mode quality gates marker accepted" "none" "$(dec)"
fresh; workflow wf1 /sb:deploy
markers silver-blast-radius devops-quality-gates-design silver-plan
run
assert_eq "devops design-mode marker accepted" "none" "$(dec)"

# --- tool / event filtering -------------------------------------------------
fresh; workflow wf1 /sb:feature
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse","tool_name":"Edit"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "non PreToolUse ignored" "" "$TL_OUT"
dg_assert_ok "non PreToolUse ignored: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Read"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "non-edit tool ignored" "" "$TL_OUT"
dg_assert_ok "non-edit tool ignored: exits 0"
for t in Write MultiEdit apply_patch; do
  dg_run "$P" "$H" "$(jq -cn --arg t "$t" --arg p "$P/src/a.sh" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p,input:("*** Begin Patch\n*** Update File: " + $p + "\n@@\n-a\n+b\n*** End Patch")}}')" SILVER_BULLET_STATE_FILE="$STATE"
  assert_eq "$t edits are gated" "deny" "$(dec)"
done
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{}}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a file tool call without any path writes nothing: not gated" "none" "$(dec)"
run SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass" "" "$TL_OUT"
dg_assert_ok "cert run bypass: exits 0"
mkdir -p "$TL_TMP/outside"
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(edit)"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project: inert: exits 0"

# --- workflow discovery ------------------------------------------------------
fresh
run
assert_eq "no workflow files: not gated" "none" "$(dec)"
dg_assert_ok "no workflow files: exits 0"
dg_run_closed_stdin "$P" "$H" SILVER_BULLET_STATE_FILE="$STATE"
dg_assert_ok "unreadable stdin (ERR trap): exits 0"
assert_eq "unreadable stdin: nothing emitted" "" "$TL_OUT"
rm -rf "$P/.planning/workflows"; mkdir -p "$TL_TMP/real-wf"; ln -s "$TL_TMP/real-wf" "$P/.planning/workflows"
echo 'composer: /sb:feature' >"$TL_TMP/real-wf/wf1.md"
run
assert_eq "symlinked workflows dir ignored" "none" "$(dec)"
rm -f "$P/.planning/workflows"
rm -rf "$P/.planning" "$P/.git"
mkdir -p "$TL_TMP/norepo"
echo '{}' >"$TL_TMP/norepo/.silver-bullet.json"; echo x >"$TL_TMP/norepo/silver-bullet.md"
dg_run "$TL_TMP/norepo" "$H" "$(edit)" SILVER_BULLET_STATE_FILE="$STATE" SILVER_BULLET_PROJECT_ROOT="$TL_TMP/norepo"
assert_eq "no repo root marker (.planning/.git): not gated" "" "$TL_OUT"
dg_assert_ok "no repo root marker (.planning/.git): not gated: exits 0"

fresh; workflow wf1 /sb:feature; workflow wf2 /sb:bugfix
run
assert_eq "multiple workflows without id: blocked" "deny" "$(dec)"
assert_contains "lists both workflows" "$(reason)" "• wf2"
assert_contains "mentions stale archival hint" "$(reason)" "auto-archived"
run SB_WORKFLOW_ID=wf2
assert_eq "SB_WORKFLOW_ID selects the bugfix workflow" "deny" "$(dec)"
assert_contains "scoped workflow gates on its own chain" "$(reason)" "• silver-debug"
markers silver-debug silver-plan
run SB_WORKFLOW_ID=wf2
assert_eq "scoped workflow passes with its chain" "none" "$(dec)"
dg_assert_ok "scoped workflow passes with its chain: exits 0"
run SB_WORKFLOW_ID=missing
assert_eq "unknown SB_WORKFLOW_ID still blocked" "deny" "$(dec)"

# --- state file resolution ---------------------------------------------------
fresh; workflow wf1 /sb:release
printf '{"state":{"state_file":"%s"}}\n' "$ST/cfg-state" >"$P/.silver-bullet.json"
printf 'silver-quality-gates\n' >"$ST/cfg-state"
dg_run "$P" "$H" "$(edit)"
assert_eq "state file from config is honoured" "none" "$(dec)"
dg_assert_ok "state file from config is honoured: exits 0"
printf '{"state":{"state_file":"%s"}}\n' "$TL_TMP/evil-state" >"$P/.silver-bullet.json"
printf 'silver-quality-gates\n' >"$TL_TMP/evil-state"
: >"$STATE"
dg_run "$P" "$H" "$(edit)"
assert_eq "state file outside the runtime root is ignored" "deny" "$(dec)"
echo 'not json' >"$P/.silver-bullet.json"
dg_run "$P" "$H" "$(edit)"
assert_eq "unparsable config falls back to the default state" "deny" "$(dec)"
rm -f "$P/.silver-bullet.json"
dg_run "$P" "$H" "$(edit)"
assert_eq "missing config falls back to the default state" "" "$TL_OUT"
dg_assert_ok "missing config falls back to the default state: exits 0"
echo '{"sb_initiated":true}' >"$P/.silver-bullet.json"
rm -f "$STATE"
dg_run "$P" "$H" "$(edit)"
assert_eq "absent state file means nothing recorded" "deny" "$(dec)"

# --- catalog aliases: the plugin's own catalog, never the project tree (R2-13) ---------------
fresh; workflow wf1 /sb:release
CAT="$TL_TMP/catalog.json"
echo '{"runtime_queue_tokens":{"silver-quality-gates":"flow-quality-gates"}}' >"$CAT"
: >"$STATE"
run SB_ATOMIC_FLOW_INDEX="$CAT"
assert_eq "catalog entity not recorded: still blocked" "deny" "$(dec)"
markers flow-quality-gates
run SB_ATOMIC_FLOW_INDEX="$CAT"
assert_eq "catalog entity recorded satisfies the marker" "none" "$(dec)"
run
assert_eq "without the plugin catalog the alias does not apply" "deny" "$(dec)"
mkdir -p "$P/docs/generated"
cp "$CAT" "$P/docs/generated/atomic-flow-index.json"
run
assert_eq "a catalog planted in the project tree is ignored" "deny" "$(dec)"
echo 'not json' >"$CAT"
run SB_ATOMIC_FLOW_INDEX="$CAT"
assert_eq "unparsable catalog: marker stays missing" "deny" "$(dec)"
echo '{"runtime_queue_tokens":{}}' >"$CAT"
run SB_ATOMIC_FLOW_INDEX="$CAT"
assert_eq "catalog without entry: marker stays missing" "deny" "$(dec)"

# --- jq missing ----------------------------------------------------------------
fresh; workflow wf1 /sb:feature
dg_run_nojq "$P" "$H" "$(edit)" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no jq in an SB project: fail closed" "deny" "$(dec)"
assert_contains "no jq: static reason" "$TL_OUT" "jq required for Silver Bullet enforcement"

# --- awk failing while reading the composer ------------------------------------
fresh; workflow wf1 /sb:feature
tl_stub awk 'exit 1'
run
assert_eq "composer unreadable: workflow not gated" "none" "$(dec)"
rm -f "$TL_BIN/awk"

# --- scope: the planning skills' own artifacts are never gated (R2-13) ---------------------
sbfile() { jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p}}'; }
sh() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
fresh; workflow wf1 /sb:ui
markers silver-quality-gates silver-context
mkdir -p "$P/.planning/phases/03-x" "$P/docs/specs"
dg_run "$P" "$H" "$(sbfile Write "$P/.planning/phases/03-x/CONTEXT.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "sb:context can write its CONTEXT.md while later markers are missing" "none" "$(dec)"
dg_run "$P" "$H" "$(sbfile Write "$P/.planning/phases/03-x/03-01-PLAN.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "sb:plan can write its PLAN.md while ui-contract and validate are missing" "none" "$(dec)"
dg_run "$P" "$H" "$(sbfile Write "$P/.planning/SPEC.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "sb:spec can write SPEC.md" "none" "$(dec)"
dg_run "$P" "$H" "$(sbfile Write "$P/docs/specs/feature.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "docs/specs artifacts are exempt" "none" "$(dec)"
dg_run "$P" "$H" "$(sbfile Write "$P/src/app.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "source is still gated" "deny" "$(dec)"
assert_eq "the deny is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
dg_run "$P" "$H" "$(sbfile NotebookEdit "$P/src/nb.ipynb" | jq -c '.tool_input={notebook_path:.tool_input.file_path}')" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "NotebookEdit is gated like Write" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "cat > src/app.py <<'EOF'
print(1)
EOF")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a Bash heredoc into src/ is gated (R2-13)" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "export SB_WORKFLOW_ID=wf1; echo x > src/app.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a first-line export does not open the gate" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "mkdir -p build && touch build/out.log && git status")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "mkdir/touch outside source are not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo '# notes' > docs/notes.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a Bash write to a doc outside source is not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo '# notes' > src/notes.md")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a Bash write to a non-logic file inside src is not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > src/app_test.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a Bash write to a test file is not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "cat src/app.py; ls src")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "reading source is not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "python3 -c \"open('src/app.py','w').write('x')\"")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an interpreter one-liner writing src is gated" "deny" "$(dec)"
dg_run "$P" "$H" "$(sh "python3 -c 'print(1)'")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an interpreter one-liner that names no path is not gated" "none" "$(dec)"
dg_run "$P" "$H" "$(sh "echo x > $TL_TMP/outside.txt")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a write outside the project is not gated" "none" "$(dec)"
markers silver-quality-gates silver-context silver-plan silver-ui-contract silver-validate
printf '# spec\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(sh "echo x > src/app.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "the full chain opens source writes" "none" "$(dec)"
# python3 missing: shell commands cannot be judged, file tools can
markers silver-context
rm -f "$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(sh "echo x > src/app.py")" SILVER_BULLET_STATE_FILE="$STATE" PATH="$(tl_path_without python3)"
assert_contains "no python3: a write is refused with the fix" "$TL_OUT" "python3"
dg_run "$P" "$H" "$(sh "ls -la")" SILVER_BULLET_STATE_FILE="$STATE" PATH="$(tl_path_without python3)"
assert_eq "no python3: a plainly read-only command gets no message" "" "$TL_OUT"
dg_run "$P" "$H" "$(sh "echo 'unterminated > src/app.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_contains "an unparsable write fails closed" "$TL_OUT" "cannot inspect"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":""}}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an empty command is ignored" "" "$TL_OUT"

# --- review repair: unseen commands and MCP write tools -----------------------------------------
fresh; workflow wf1 /sb:ui
markers silver-quality-gates
PADF="$TL_TMP/pad.txt"; head -c 600000 /dev/zero | tr '\0' 'a' >"$PADF"
dg_run "$P" "$H" "$(jq -cn --rawfile pad "$PADF" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:("echo x > src/app.py; # " + $pad)}}')" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an over-budget command is refused while the chain is incomplete" "deny" "$(dec)"
assert_contains "with the reason" "$TL_OUT" "cannot inspect this command"
dg_run "$P" "$H" "$(sh 'eval "$X"')" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "eval of computed text is refused" "deny" "$(dec)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/src/a.py" '{hook_event_name:"PreToolUse",tool_name:"mcp__filesystem__write_file",tool_input:{path:$p,content:"x"}}')" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an MCP write into source is gated like Write" "deny" "$(dec)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/src/a.py" '{hook_event_name:"PreToolUse",tool_name:"mcp__filesystem__read_file",tool_input:{path:$p}}')" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "an MCP read is not gated" "none" "$(dec)"

# --- the active workflow: the state file, a sole workflow file, the env override (R2-14) --------
fresh; workflow wf1 /sb:feature; workflow wf2 /sb:bugfix
: >"$STATE"
printf 'wf2\n' >"$ST/active-workflow"
run
assert_contains "the persisted active workflow selects wf2" "$(reason)" "(wf2)"
printf 'nope\n' >"$ST/active-workflow"
run
assert_contains "an unknown persisted id is ignored (multiple workflows still ambiguous)" "$(reason)" "multiple active composed workflows"
rm -f "$ST/active-workflow"
fresh; workflow wf1 /sb:bugfix
run
assert_contains "the only workflow is the active one without any variable" "$(reason)" "(wf1)"
dg_run "$P" "$H" "$(sh "export SB_WORKFLOW_ID=wf9; echo x > src/app.py")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "a first-line export selects among workflows but cannot open the gate" "deny" "$(dec)"

tl_results
