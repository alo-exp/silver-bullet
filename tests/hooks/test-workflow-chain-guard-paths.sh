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
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Read"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "non-edit tool ignored" "" "$TL_OUT"
for t in Write MultiEdit apply_patch; do
  dg_run "$P" "$H" "$(jq -cn --arg t "$t" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{}}')" SILVER_BULLET_STATE_FILE="$STATE"
  assert_eq "$t edits are gated" "deny" "$(dec)"
done
run SB_AGENT_CERT_RUN=1
assert_eq "cert run bypass" "" "$TL_OUT"
mkdir -p "$TL_TMP/outside"
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(edit)"
assert_eq "outside an SB project: inert" "" "$TL_OUT"

# --- workflow discovery ------------------------------------------------------
fresh
run
assert_eq "no workflow files: not gated" "none" "$(dec)"
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
run SB_WORKFLOW_ID=missing
assert_eq "unknown SB_WORKFLOW_ID still blocked" "deny" "$(dec)"

# --- state file resolution ---------------------------------------------------
fresh; workflow wf1 /sb:release
printf '{"state":{"state_file":"%s"}}\n' "$ST/cfg-state" >"$P/.silver-bullet.json"
printf 'silver-quality-gates\n' >"$ST/cfg-state"
dg_run "$P" "$H" "$(edit)"
assert_eq "state file from config is honoured" "none" "$(dec)"
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
echo '{"sb_initiated":true}' >"$P/.silver-bullet.json"
rm -f "$STATE"
dg_run "$P" "$H" "$(edit)"
assert_eq "absent state file means nothing recorded" "deny" "$(dec)"

# --- catalog aliases -----------------------------------------------------------
fresh; workflow wf1 /sb:release
mkdir -p "$P/docs/generated"
echo '{"runtime_queue_tokens":{"silver-quality-gates":"flow-quality-gates"}}' >"$P/docs/generated/atomic-flow-index.json"
: >"$STATE"
run
assert_eq "catalog entity not recorded: still blocked" "deny" "$(dec)"
markers flow-quality-gates
run
assert_eq "catalog entity recorded satisfies the marker" "none" "$(dec)"
echo 'not json' >"$P/docs/generated/atomic-flow-index.json"
run
assert_eq "unparsable catalog: marker stays missing" "deny" "$(dec)"
echo '{"runtime_queue_tokens":{}}' >"$P/docs/generated/atomic-flow-index.json"
run
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

# --- degraded: helper libraries unavailable ----------------------------------
AUDIT='sb_hook_audit_record() { :; }; export -f sb_hook_audit_record'
fresh; printf '# s\n' >"$P/.planning/SPEC.md"; workflow wf1 /sb:release
: >"$STATE"
dg_run_with_fn "$P" "$H" "$(edit)" "cd() { [[ \"\$1\" == */lib ]] && return 1; builtin cd \"\$@\"; }; export -f cd; $AUDIT" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no libs: literal marker lookup blocks when missing" "deny" "$(dec)"
markers silver-quality-gates
dg_run_with_fn "$P" "$H" "$(edit)" "cd() { [[ \"\$1\" == */lib ]] && return 1; builtin cd \"\$@\"; }; export -f cd; $AUDIT" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no libs: literal marker lookup passes when recorded" "none" "$(dec)"
echo '{"runtime_queue_tokens":{"silver-quality-gates":"alt-entity"}}' >/dev/null
fresh; workflow wf1 /sb:release
mkdir -p "$P/docs/generated"
echo '{"runtime_queue_tokens":{"silver-quality-gates":"alt-entity"}}' >"$P/docs/generated/atomic-flow-index.json"
markers alt-entity
dg_run_with_fn "$P" "$H" "$(edit)" "cd() { [[ \"\$1\" == */lib ]] && return 1; builtin cd \"\$@\"; }; export -f cd; $AUDIT" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no libs: catalog entity literal lookup passes" "none" "$(dec)"
markers other
dg_run_with_fn "$P" "$H" "$(edit)" "cd() { [[ \"\$1\" == */lib ]] && return 1; builtin cd \"\$@\"; }; export -f cd; $AUDIT" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no libs: catalog entity literal lookup blocks when absent" "deny" "$(dec)"

tl_results
