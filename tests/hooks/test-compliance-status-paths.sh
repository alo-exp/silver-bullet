#!/usr/bin/env bash
# hooks/compliance-status.sh: config cache, workflow progress, devops planning and fallbacks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/compliance-status.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_WORKFLOW_ID SILVER_BULLET_DEBUG_HOOK_EVENTS SILVER_BULLET_STATE_FILE
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
CUR_VER="$(jq -r .config_version "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

run_cs() { # [hook] [payload]
  tl_run_stdin "${2:-{\}}" bash -c 'cd "$1" && exec bash "$2"' _ "${EC_RUN_DIR:-$EC_PROJ}" "${1:-$HOOK}"
}
msg() { jq -r '.hookSpecificOutput.message // ""' <<<"$TL_OUT"; }
reset() {
  local f
  rm -f "${SD:?}/state" "${SD:?}/mode"
  for f in "$SD"/config-cache-*; do [[ -e "$f" ]] && rm -f "$f"; done
  rm -rf "${EC_PROJ:?}/.planning"
  ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,project:{active_workflow:"full-dev-cycle"},skills:{required_planning:["silver-quality-gates","silver-context"]}}')"
  EC_RUN_DIR="$EC_PROJ"
}

# ---- no state: zero summary -------------------------------------------------
reset
run_cs
assert_contains "no state file: zero summary" "$(msg)" "Silver Bullet: 0 steps | Mode: interactive"
assert_contains "no state file: planning total" "$(msg)" "PLANNING 0/2"
assert_contains "no state file: next step is first planning skill" "$(msg)" "Next: /silver-quality-gates"

# ---- state with progress ----------------------------------------------------
printf 'silver-quality-gates\nsilver-review\n' >"$SD/state"
run_cs
assert_contains "planning progress" "$(msg)" "PLANNING 1/2"
assert_contains "review progress" "$(msg)" "REVIEW 1/3"
printf 'autonomous' >"$SD/mode"
run_cs
assert_contains "autonomous mode shown" "$(msg)" "Mode: autonomous"
printf 'weird' >"$SD/mode"
run_cs
assert_contains "invalid mode coerced" "$(msg)" "Mode: interactive"
printf '' >"$SD/mode"
run_cs
assert_contains "empty mode file coerced" "$(msg)" "Mode: interactive"

# state file outside the state root is replaced by the default
reset
printf 'silver-quality-gates\n' >"$SD/state"
ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,state:{state_file:"/etc/not-allowed-state"},skills:{required_planning:["silver-quality-gates"]}}')"
run_cs
assert_contains "out-of-scope state file ignored" "$(msg)" "PLANNING 1/1"
assert_contains "state step count from the default file" "$(msg)" "Silver Bullet: 1 steps"
# env override wins
printf 'a\nb\nc\n' >"$SD/other-state"
SILVER_BULLET_STATE_FILE="$SD/other-state" run_cs
assert_contains "state override honoured" "$(msg)" "Silver Bullet: 3 steps"

# ---- devops workflow --------------------------------------------------------
reset
printf 'devops-quality-gates\n' >"$SD/state"
ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,project:{active_workflow:"devops-cycle"},skills:{required_planning_devops:["devops-quality-gates","silver-plan"]}}')"
run_cs
assert_contains "devops planning list used" "$(msg)" "PLANNING 1/2"
ec_cfg "$(jq -cn --arg v "$CUR_VER" '{config_version:$v,sb_initiated:true,project:{active_workflow:"devops-cycle"},skills:{required_planning:["silver-plan"]}}')"
run_cs
assert_contains "devops falls back to required_planning" "$(msg)" "PLANNING 0/1"

# ---- workflow progress ------------------------------------------------------
reset
WF="$EC_PROJ/.planning/workflows"
mkdir -p "$WF"
ID="20260101T000000Z-abc123-silver-feature"
printf 'x' >"$WF/other.md"
run_cs
assert_contains "workflows without id: count only" "$(msg)" "WORKFLOWS: 1 active (SB_WORKFLOW_ID unset)"
cat >"$WF/$ID.md" <<'EOF'
## Flow Log
| 1 | FLOW 1 | complete |
| 2 | FLOW 2 | skipped |
| 3 | FLOW 3 | pending |
EOF
SB_WORKFLOW_ID="$ID" run_cs
assert_contains "flow progress from the Flow Log" "$(msg)" "FLOW 2/3 (id=$ID)"
printf '## Flow Log\n' >"$WF/$ID.md"
SB_WORKFLOW_ID="$ID" run_cs
assert_contains "empty Flow Log: single zero counts" "$(msg)" "FLOW 0/0 (id=$ID)"
SB_WORKFLOW_ID="bad id" run_cs
assert_contains "invalid id ignored" "$(msg)" "WORKFLOWS: 2 active"
rm -rf "${WF:?}"
ln -s "$TL_TMP" "$WF"
run_cs
assert_contains "symlinked workflows dir ignored" "$(msg)" "FLOW: N/A"
rm -f "${WF:?}"

# without workflow-utils.sh the built-in counters apply (and must print one number)
ec_stage_hooks "$TL_TMP/noutils" workflow-utils.sh
reset
mkdir -p "$WF"
printf '## Flow Log\n' >"$WF/$ID.md"
SB_WORKFLOW_ID="$ID" run_cs "$TL_TMP/noutils/hooks/compliance-status.sh"
assert_contains "fallback counters: empty log prints single zeros" "$(msg)" "FLOW 0/0 (id=$ID)"
printf '| 1 | FLOW 1 | complete |\n| 2 | FLOW 2 | pending |\n' >"$WF/$ID.md"
SB_WORKFLOW_ID="$ID" run_cs "$TL_TMP/noutils/hooks/compliance-status.sh"
assert_contains "fallback counters count rows" "$(msg)" "FLOW 1/2 (id=$ID)"

# ---- config discovery and cache ---------------------------------------------
reset
printf 'silver-quality-gates\n' >"$SD/state"
tl_stub md5 'cat >/dev/null; echo fixedhash'
run_cs
assert_file_exists "md5 (BSD) cache key used" "$SD/config-cache-fixedhash"
assert_eq "cache records the config path" "$EC_CFG" "$(sed -n 1p "$SD/config-cache-fixedhash")"
run_cs
assert_contains "cached config reused" "$(msg)" "PLANNING 1/2"
printf '/nonexistent/.silver-bullet.json\n123' >"$SD/config-cache-fixedhash"
run_cs
assert_contains "cache pointing at a missing file is dropped and rebuilt" "$(msg)" "PLANNING 1/2"
assert_eq "cache rebuilt" "$EC_CFG" "$(sed -n 1p "$SD/config-cache-fixedhash")"
printf '%s\n1' "$EC_CFG" >"$SD/config-cache-fixedhash"
run_cs
assert_eq "stale mtime: cache refreshed" "$EC_CFG" "$(sed -n 1p "$SD/config-cache-fixedhash")"
assert_match "stale mtime: new mtime stored" '^[0-9]{5,}$' "$(sed -n 2p "$SD/config-cache-fixedhash")"
rm -f "${TL_BIN:?}/md5"
mkdir -p "$EC_PROJ/x/y"
EC_RUN_DIR="$EC_PROJ/x/y"
run_cs
assert_contains "config found by walking up from a subdirectory" "$(msg)" "Silver Bullet"
EC_RUN_DIR="$EC_PROJ"
mkdir -p "$TL_TMP/plain"
EC_RUN_DIR="$TL_TMP/plain"
run_cs
assert_eq "outside any SB project: silent" "" "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"
PATH="$(tl_path_without md5 md5sum)" run_cs
assert_contains "no hashing tool: works without a cache" "$(msg)" "Silver Bullet"
PATH="$(tl_path_without jq)" run_cs
assert_eq "no jq: silent" "" "$TL_OUT"

# ---- debug event log --------------------------------------------------------
reset
SILVER_BULLET_DEBUG_HOOK_EVENTS=1 run_cs "$HOOK" '{"hook_event_name":"PostToolUse","tool_name":"Bash"}'
assert_contains "debug log records the event" "$(cat "$SD/hook-events.debug.log")" "hook_event=PostToolUse"
assert_contains "debug log records the tool" "$(cat "$SD/hook-events.debug.log")" "tool_name=Bash"

# ---- library fallbacks ------------------------------------------------------
ec_stage_hooks "$TL_TMP/nolibs" nofollow-guard.sh required-skills.sh sb-project-gate.sh project-active.sh hook-output.sh
reset
printf 'silver-quality-gates\n' >"$SD/state"
run_cs "$TL_TMP/nolibs/hooks/compliance-status.sh"
assert_eq "no hook-output lib: no output" "" "$TL_OUT"
ec_stage_hooks "$TL_TMP/nogate" sb-project-gate.sh project-active.sh
printf '%s\n' 'sb_project_is_initiated() { return 1; }' >"$TL_TMP/nogate/hooks/lib/project-active.sh"
sb_project_is_initiated() { return 1; }
export -f sb_project_is_initiated
run_cs "$TL_TMP/nogate/hooks/compliance-status.sh"
assert_eq "inherited initiated check rejecting: silent" "" "$TL_OUT"
unset -f sb_project_is_initiated

# ---- next step across the later phases ----------------------------------------
reset
printf 'silver-quality-gates\nsilver-context\nsilver-review-request\nsilver-review\nsilver-review-triage\n' >"$SD/state"
run_cs
assert_contains "planning and review done: next is the first finalization skill" "$(msg)" "Next: /silver-branch-finish"
printf 'silver-quality-gates\nsilver-context\nsilver-review-request\nsilver-review\nsilver-review-triage\nsilver-branch-finish\nsilver-completion-audit\ntdd\nverify-tests\n' >"$SD/state"
run_cs
assert_contains "everything but the release done: next is the release skill" "$(msg)" "Next: /silver-create-release"

# ---- a config cache that cannot be moved into place --------------------------------
reset
ec_fail mv '*"config-cache"*'
run_cs
ec_unfail mv
assert_contains "failed cache move: the summary is still printed" "$(msg)" "Silver Bullet: 0 steps"
assert_eq "failed cache move: no temporary cache file is left" "0" "$(find "$SD" -maxdepth 1 -name 'config-cache-*' | wc -l | tr -d ' ')"

tl_results
