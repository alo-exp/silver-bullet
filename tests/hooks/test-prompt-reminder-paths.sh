#!/usr/bin/env bash
# hooks/prompt-reminder.sh: planning/delivery tiers, bare-prompt routing per host,
# orchestrator directive, opt-in tool lines and library fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/prompt-reminder.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
CUR_VER="$(jq -r .config_version "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

prompt_json() { jq -cn --arg p "$1" '{prompt:$p}'; }
run_pr() { # prompt [hook]   (cwd = $EC_RUN_DIR)
  tl_run_stdin "$(prompt_json "${1:-}")" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "${2:-$HOOK}"
}
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
cfg() { # json fragment merged over the base config
  ec_cfg "$(jq -cn --arg v "$CUR_VER" --argjson x "${1:-{\}}" '{config_version:$v,sb_initiated:true,project:{active_workflow:"full-dev-cycle"}} * $x')"
}
reset() {
  local f
  for f in state trivial session-rules-injected orchestrator.json orchestrator-directive.json outcomes-session.json \
    ups-coalesce-turn ups-coalesce-seen orchestrator-worker-active.json rtk-usage context_mode-usage; do
    rm -f "${SD:?}/${f:?}"
  done
  rm -rf "${EC_PROJ:?}/.planning"
  cfg '{"skills":{"required_planning":["silver-quality-gates","silver-context"]}}'
  EC_RUN_DIR="$EC_PROJ"
}

# ---- tiers ------------------------------------------------------------------
reset
run_pr "continue with the parser"
assert_contains "planning floor shown" "$(ctx)" "Silver Bullet [planning floor] -- Missing: silver-quality-gates, silver-context (0 of 2 complete)"
reset
printf 'silver-quality-gates\nsilver-context\n' >"$SD/state"
run_pr "continue with the parser"
assert_contains "floor complete" "$(ctx)" "planning floor complete"
reset
run_pr "please ship this release"
assert_contains "delivery prompt shows the delivery tier" "$(ctx)" "[delivery]"
reset
printf 'silver-execute\n' >"$SD/state"
run_pr "keep going"
assert_contains "execute recorded: delivery tier" "$(ctx)" "[delivery]"
reset
cfg '{"skills":{"required_deploy":["only-this-one"]}}'
printf 'only-this-one\n' >"$SD/state"
run_pr "ship it"
assert_contains "delivery complete message" "$(ctx)" "all required delivery skills complete"
# devops
reset
cfg '{"project":{"active_workflow":"devops-cycle"},"skills":{"required_planning_devops":["devops-quality-gates"]}}'
run_pr "continue"
assert_contains "devops planning list" "$(ctx)" "Missing: devops-quality-gates"
cfg '{"project":{"active_workflow":"devops-cycle"},"skills":{}}'
run_pr "continue"
assert_contains "devops default planning" "$(ctx)" "devops-quality-gates"
# main branch drops finishing skills
reset
git -C "$EC_PROJ" checkout -q main
cfg '{"skills":{"required_deploy":["silver-branch-finish","finishing-a-development-branch","real-one"]}}'
run_pr "ship it"
assert_contains "main keeps other deploy skills" "$(ctx)" "real-one"
assert_not_contains "main drops silver-branch-finish" "$(ctx)" "silver-branch-finish"
git -C "$EC_PROJ" checkout -q feature/test
# branch name with unsafe characters is ignored
git -C "$EC_PROJ" checkout -q -b 'odd+branch'
run_pr "ship it"
assert_contains "unsafe branch: works" "$(ctx)" "Silver Bullet"
git -C "$EC_PROJ" checkout -q feature/test
# a branch that cannot be determined is not main: the finishing skills stay required
cfg '{"skills":{"required_deploy":["silver-branch-finish","real-one"]}}'
ec_fail git '*"rev-parse"*'
run_pr "ship it"
ec_unfail git
assert_contains "unknown branch: finishing skill kept" "$(ctx)" "silver-branch-finish"
assert_contains "unknown branch: other deploy skills kept" "$(ctx)" "real-one"

# ---- bypass / gating --------------------------------------------------------
reset
: >"$SD/trivial"
run_pr "ship it"
assert_eq "trivial file: no-op payload" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$TL_OUT"
reset
mkdir -p "$TL_TMP/plain"
EC_RUN_DIR="$TL_TMP/plain"
run_pr "ship it"
assert_eq "no project: no-op payload" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"
mkdir -p "$EC_PROJ/a/b"
EC_RUN_DIR="$EC_PROJ/a/b"
run_pr "continue"
assert_contains "config found by walking up" "$(ctx)" "Silver Bullet"
EC_RUN_DIR="$EC_PROJ"
ec_stage_hooks "$TL_TMP/gateless" sb-project-gate.sh project-active.sh
sb_project_is_initiated() { return 1; }
export -f sb_project_is_initiated
reset
run_pr "continue" "$TL_TMP/gateless/hooks/prompt-reminder.sh"
assert_eq "inherited initiated check rejecting: no-op" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}' "$TL_OUT"
unset -f sb_project_is_initiated

# ---- bare prompts per host ---------------------------------------------------
reset
SILVER_BULLET_RUNTIME=claude run_pr "please fix the failing login test"
assert_contains "claude host: Skill tool routing" "$(ctx)" 'invoke the Skill tool with skill "sb" (Claude/Cursor)'
reset
SILVER_BULLET_RUNTIME=codex run_pr "please fix the failing login test"
assert_contains "codex parent: prefers the Skill tool" "$(ctx)" "(parent mode)"
reset
SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_RUNTIME=codex run_pr "please fix the user's login test"
assert_contains "codex worker: adapter invocation" "$(ctx)" "invoke-skill sb"
assert_contains "codex worker: prompt is shell-quoted" "$(ctx)" "'please fix the user'\\''s login test'"
assert_contains "codex worker: adapter resolved to the packaged script" "$(ctx)" "$TL_REPO_ROOT/scripts/silver-bullet"
ec_stage_hooks "$TL_TMP/noadapter"
reset
CODEX_BIN="$HOME/.codex/bin"
mkdir -p "$CODEX_BIN"
printf '#!/bin/sh\n' >"$CODEX_BIN/silver-bullet"
SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_RUNTIME=codex run_pr "please fix the failing login test" "$TL_TMP/noadapter/hooks/prompt-reminder.sh"
assert_contains "adapter resolved from the runtime bin dir" "$(ctx)" "$CODEX_BIN/silver-bullet"
rm -f "${CODEX_BIN:?}/silver-bullet" "${SD:?}/ups-coalesce-turn" "${SD:?}/ups-coalesce-seen"
SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_RUNTIME=codex run_pr "please fix the failing login test" "$TL_TMP/noadapter/hooks/prompt-reminder.sh"
assert_contains "adapter falls back to the bare command name" "$(ctx)" '"silver-bullet" invoke-skill sb'
reset
run_pr "what are the pending gates"
assert_not_contains "informational prompt is not intercepted" "$(ctx)" "BARE PROMPT"

# ---- orchestrator directive -------------------------------------------------
reset
jq -n '{next_skill:"silver-execute",next_worker_template:"EXECUTE",blocking:true,reason:"queued"}' >"$SD/orchestrator-directive.json"
run_pr "carry on with the parser"
assert_contains "directive injected" "$(ctx)" "next_skill: silver-execute"
reset
jq -n '{next_skill:"silver-execute",blocking:true}' >"$SD/orchestrator-directive.json"
run_pr "yes please"
assert_not_contains "short follow-up skips the directive" "$(ctx)" "next_skill"
reset
printf '{"current_flow":"FLOW-EXECUTE","repo_root":"%s"}' "$EC_PROJ" >"$SD/orchestrator.json"
printf '{}' >"$SD/outcomes-session.json"
run_pr "carry on with the parser"
assert_contains "queued flow becomes the directive even with a pending outcome file" "$(ctx)" "next_skill: silver-execute"

# ---- rules injection --------------------------------------------------------
reset
: >"$SD/session-rules-injected"
run_pr "continue"
assert_contains "compact reference after session start" "$(ctx)" "SB enforcement rules active (injected at session start"
reset
run_pr "continue"
assert_contains "full verified rules without the marker" "$(ctx)" "Non-Negotiable Rules"
ec_stage_hooks "$TL_TMP/nopin"
rm -f "$TL_TMP/nopin/hooks/core-rules.sha256"
reset
run_pr "continue" "$TL_TMP/nopin/hooks/prompt-reminder.sh"
assert_contains "unverifiable rules: integrity warning" "$(ctx)" "core-rules.md"
assert_not_contains "unverifiable rules: not injected" "$(ctx)" "Non-Negotiable Rules"
ec_stage_hooks "$TL_TMP/nointegrity" core-rules-integrity.sh
reset
run_pr "continue" "$TL_TMP/nointegrity/hooks/prompt-reminder.sh"
assert_contains "no integrity lib: unavailable notice" "$(ctx)" "integrity check unavailable"

# ---- opt-in tool lines ------------------------------------------------------
reset
cfg '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}'
run_pr "continue"
assert_contains "graphify reminder" "$(ctx)" "Graphify"
assert_contains "agentmemory reminder" "$(ctx)" "agentmemory"
assert_contains "code intelligence synergy on the first prompt" "$(ctx)" "CODE INTELLIGENCE"
reset
: >"$SD/session-rules-injected"
cfg '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}'
run_pr "continue"
assert_not_contains "no synergy line once rules were injected" "$(ctx)" "CODE INTELLIGENCE"
reset
cfg '{"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed"},"context_mode":{"enabled_by_user":true,"install_status":"installed"}}}'
run_pr "continue"
assert_contains "rtk reminder" "$(ctx)" 'RTK: CLI `rtk` missing'
assert_contains "context mode reminder" "$(ctx)" 'Context Mode: CLI `context_mode` missing'
reset
cfg '{"recommended_tools":{"rtk":{"enabled_by_user":true,"install_status":"installed"}}}'
date +%s >"$SD/rtk-usage"
run_pr "continue"
assert_not_contains "fresh rtk usage suppresses the reminder" "$(ctx)" 'RTK: CLI'

# ---- fallbacks without helper libraries -------------------------------------
ec_stage_hooks "$TL_TMP/minimal" required-skills.sh prompt-classifier.sh ups-coalesce.sh enforcement-tier-gate.sh
reset
cfg '{"skills":{"required_planning":["cfg-skill-a"],"required_deploy":["cfg-deploy-a"]}}'
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no required-skills lib: configured planning list" "$(ctx)" "Missing: cfg-skill-a"
printf 'cfg-skill-a\n' >"$SD/state"
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no required-skills lib: grep fallback sees recorded skills" "$(ctx)" "planning floor complete"
printf 'silver-execute\n' >"$SD/state"
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no required-skills lib: execute recorded via grep fallback" "$(ctx)" "Missing: cfg-deploy-a"
reset
cfg '{"skills":{"required_deploy":["cfg-deploy-a"]}}'
printf 'silver-execute\n' >"$SD/state"
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no lib, no planning config: built-in defaults" "$(ctx)" "cfg-deploy-a"
reset
cfg '{"skills":{}}'
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no lib, no config: default planning floor" "$(ctx)" "Silver Bullet"
# delivery tier with neither the library nor any configured list: the built-in default list, never an empty one
printf 'silver-execute\n' >"$SD/state"
run_pr "continue" "$TL_TMP/minimal/hooks/prompt-reminder.sh"
assert_contains "no lib, no config, delivery tier: the built-in default deploy list" "$(ctx)" "silver-ship"
assert_contains "no lib, no config, delivery tier: names the missing default skills" "$(ctx)" "silver-completion-audit"

tl_results
