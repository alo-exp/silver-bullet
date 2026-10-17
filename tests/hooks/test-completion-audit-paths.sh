#!/usr/bin/env bash
# hooks/completion-audit.sh end-to-end paths: bootstrap/exit guards, jq-less behaviour, the
# planning tier, the delivery tier, release gates, composer/devops selection and verdict messages.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

# Skills: installed ones exist under this root; anything else is "not installed anywhere".
SKILLS="$TL_TMP/skills"
for s in inst-a inst-b verify-tests silver-quality-gates-extra devops-quality-gates silver-blast-radius; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done

STATE="$SB_RUNTIME_STATE_DIR/state-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"
export SILVER_BULLET_QUALITY_GATE_STATE_FILE="$SB_RUNTIME_STATE_DIR/quality-gate-test"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"

# mkproj <name> [jq filter applied to the base config]: git project with SB files; sets PROJ.
mkproj() {
  PROJ="$TL_TMP/$1"
  tl_git_repo "$PROJ"
  printf '# Silver Bullet\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" '{config_version:$v, sb_initiated:true,
      project:{active_workflow:"full-dev-cycle"},
      skills:{required_planning:["inst-a"], required_deploy:["inst-a","inst-b"]}}' \
    | jq "${2:-.}" >"$PROJ/.silver-bullet.json"
  GH_RUN_LIST_OVERRIDE="$(jq -cn --arg sha "$(git -C "$PROJ" rev-parse HEAD)" \
    '[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"}]')"
  export GH_RUN_LIST_OVERRIDE
  : >"$STATE"
}
state() { printf '%s\n' "$@" >"$STATE"; }

# run_ca <event> <command> [VAR=val ...]: run the hook from $PROJ.
run_ca() {
  local event="$1" cmd="$2"
  shift 2
  local json
  json="$(jq -cn --arg e "$event" --arg c "$cmd" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}')"
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "$2"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
decision() { # decision of the last run: deny|block|allow|none
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -r 'if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -r '.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // ""' <<<"$TL_OUT"; }

# ── guards that exit silently ────────────────────────────────────────────────
mkproj basic
run_ca PreToolUse 'gh pr create' SB_AGENT_CERT_RUN=1
assert_eq "cert run bypasses the gate" "none" "$(decision)"
assert_eq "cert run exits 0" 0 "$TL_STATUS"
tl_run_stdin "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"x"}}')" bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "non-shell tool is ignored" "" "$TL_OUT"
run_ca PreToolUse ''
assert_eq "empty command is ignored" "" "$TL_OUT"
run_ca PreToolUse 'ls -la'
assert_eq "non-delivery command is ignored" "" "$TL_OUT"
run_ca PreToolUse 'scripts/silver-bullet invoke-skill git-commit'
assert_eq "skill adapter invocation is not gated" "" "$TL_OUT"

NOPROJ="$TL_TMP/noproj"; tl_git_repo "$NOPROJ"
RUN_DIR="$NOPROJ" run_ca PreToolUse 'git commit -m x'
assert_eq "git repo without SB config: silent exit" "" "$TL_OUT"
NOGIT="$TL_TMP/nogit-noproj"; mkdir -p "$NOGIT"
RUN_DIR="$NOGIT" run_ca PreToolUse 'git commit -m x'
assert_eq "directory without SB config or git: silent exit" "" "$TL_OUT"
mkdir -p "$PROJ/sub/dir"
RUN_DIR="$PROJ/sub/dir" run_ca PreToolUse 'git commit -m x'
assert_eq "config found by walking up from a subdirectory" "deny" "$(decision)"

# ── state/trivial path validation and trivial bypass ─────────────────────────
run_ca PreToolUse 'git commit -m x' SILVER_BULLET_STATE_FILE=/tmp/outside-state
assert_eq "state file outside runtime root falls back (still gated)" "deny" "$(decision)"
state inst-a
run_ca PreToolUse 'git commit -m x' SILVER_BULLET_STATE_FILE="$STATE" SILVER_BULLET_VERIFY_TESTS_STATE_FILE=/tmp/outside-vt SILVER_BULLET_QUALITY_GATE_STATE_FILE=/tmp/outside-qg
assert_contains "out-of-root verify/quality-gate paths fall back, planning passes" "$(message)" "Planning verified"
cfg_trivial="$SB_RUNTIME_STATE_DIR/trivial"
jq --arg t "/tmp/outside-trivial" '.state.trivial_file=$t | .release.quality_gate_state_file="/tmp/outside-qg2"' "$PROJ/.silver-bullet.json" >"$PROJ/c.tmp" && mv "$PROJ/c.tmp" "$PROJ/.silver-bullet.json"
: >"$STATE"
run_ca PreToolUse 'git commit -m x'
assert_eq "trivial file outside runtime root is ignored" "deny" "$(decision)"
jq 'del(.state)|del(.release)' "$PROJ/.silver-bullet.json" >"$PROJ/c.tmp" && mv "$PROJ/c.tmp" "$PROJ/.silver-bullet.json"
touch "$cfg_trivial"
run_ca PreToolUse 'git commit -m x'
assert_eq "trivial marker bypasses the gate" "" "$TL_OUT"
rm -f "$cfg_trivial"
ln -s /dev/null "$cfg_trivial"
run_ca PreToolUse 'git commit -m x'
assert_eq "symlinked trivial marker does not bypass" "deny" "$(decision)"
rm -f "$cfg_trivial"

# ── environment: non-git dir and odd branch names ────────────────────────────
NG="$TL_TMP/nogit-proj"; mkdir -p "$NG"; printf '# SB\n' >"$NG/silver-bullet.md"; cp "$PROJ/.silver-bullet.json" "$NG/"
RUN_DIR="$NG" run_ca PreToolUse 'git commit -m x'
assert_eq "project outside git still enforced" "deny" "$(decision)"
git -C "$PROJ" checkout -q -b 'feat+odd'
run_ca PreToolUse 'git commit -m x'
assert_eq "unsafe branch name is ignored, gate still enforced" "deny" "$(decision)"
git -C "$PROJ" checkout -q feature/test

# ── hook event formats ───────────────────────────────────────────────────────
run_ca PreToolUse 'git commit -m x'
assert_contains "PreToolUse block is a permission deny" "$TL_OUT" '"permissionDecision":"deny"'
assert_contains "block reason names the missing skill" "$(message)" "/inst-a"
run_ca PostToolUse 'git commit -m x'
assert_eq "PostToolUse block is a decision block" "block" "$(decision)"
assert_contains "PostToolUse block repeats the reason in the message" "$TL_OUT" '"hookSpecificOutput":{"message"'

# ── planning tier ────────────────────────────────────────────────────────────
state inst-a
run_ca PreToolUse 'git commit -m x'
assert_eq "planning complete: allowed" "allow" "$(decision)"
assert_contains "planning complete message" "$(message)" "Planning verified. Intermediate commit allowed."
mkproj planning '.skills.required_planning=["inst-a","ghost-skill"]'
state inst-a
run_ca PreToolUse 'git commit -m x'
assert_contains "uninstalled planning skill is ignored with a notice" "$(message)" "ghost-skill (not installed anywhere invocable)"
assert_eq "ignored skill does not block" "allow" "$(decision)"
: >"$STATE"
run_ca PreToolUse 'git push'
assert_contains "installed planning skill still blocks" "$(message)" "COMMIT BLOCKED"
assert_contains "block lists ignored skills too" "$(message)" "Ignored required skills"

mkproj devops '.project.active_workflow="devops-cycle" | .skills.required_planning_devops=["inst-b"]'
state inst-a
run_ca PreToolUse 'git commit -m x'
assert_contains "devops planning list is used when configured" "$(message)" "/inst-b"
state inst-b
run_ca PreToolUse 'git commit -m x'
assert_eq "devops planning satisfied" "allow" "$(decision)"
mkproj devops2 '.project.active_workflow="devops-cycle" | del(.skills.required_planning_devops) | del(.skills.required_planning)'
: >"$STATE"
run_ca PreToolUse 'git commit -m x'
assert_contains "devops default planning list when unconfigured" "$(message)" "/silver-blast-radius"

# plan-seal commits
mkproj seal
SEAL='git commit -m "docs(01-02): complete"'
state inst-a
run_ca PreToolUse "$SEAL"
assert_contains "plan seal without completion audit" "$(message)" "PLAN SEAL BLOCKED"
assert_contains "plan seal names completion-audit" "$(message)" "completion-audit has not been recorded"
state inst-a silver-completion-audit
run_ca PreToolUse "$SEAL"
assert_contains "plan seal without verify" "$(message)" "requires /sb:verify"
state inst-a silver-completion-audit silver-verify
run_ca PreToolUse "$SEAL"
assert_contains "plan seal without VERIFICATION.md" "$(message)" "No VERIFICATION.md found"
mkdir -p "$PROJ/.planning/phases/01-x"
echo real >"$TL_TMP/real-verification.md"
ln -s "$TL_TMP/real-verification.md" "$PROJ/.planning/VERIFICATION.md"
run_ca PreToolUse "$SEAL"
assert_contains "symlinked VERIFICATION.md does not count" "$(message)" "No VERIFICATION.md found"
echo ok >"$PROJ/.planning/phases/01-x/01-VERIFICATION.md"
run_ca PreToolUse "$SEAL"
assert_contains "phase VERIFICATION.md satisfies the plan seal" "$(message)" "Planning verified"
rm -f "$PROJ/.planning/VERIFICATION.md" "$PROJ/.planning/phases/01-x/01-VERIFICATION.md"
echo ok >"$PROJ/.planning/VERIFICATION.md"
run_ca PreToolUse "$SEAL"
assert_contains "top-level VERIFICATION.md satisfies the plan seal" "$(message)" "Planning verified"

tl_results
