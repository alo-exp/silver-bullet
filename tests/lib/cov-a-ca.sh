#!/usr/bin/env bash
# shellcheck shell=bash
# Shared completion-audit fixture (sourced after tl_init).
_ca_tpl() {
  if [[ -z "${_CA_TPL:-}" ]]; then
    _CA_TPL="$TL_TMP/.tpl"
    tl_git_repo "$_CA_TPL"
    _CA_SHA="$(git -C "$_CA_TPL" rev-parse HEAD)"
    GH_OK="$(jq -cn --arg sha "$_CA_SHA" '[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"}]')"
  fi
}
mkproj() {
  PROJ="$TL_TMP/$1"
  _ca_tpl
  cp -a "$_CA_TPL" "$PROJ"
  printf '# Silver Bullet\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" "{config_version:\$v, sb_initiated:true,
      project:{active_workflow:\"full-dev-cycle\"},
      skills:{required_planning:[\"inst-a\"], required_deploy:[\"inst-a\",\"inst-b\"]}} | ${2:-.}" >"$PROJ/.silver-bullet.json"
  GH_RUN_LIST_OVERRIDE="$GH_OK"
  export GH_RUN_LIST_OVERRIDE
  : >"$STATE"
  rm -f "$SB_RUNTIME_STATE_DIR"/release-live-matrix "$SB_RUNTIME_STATE_DIR"/e2e-live-matrix "$SB_RUNTIME_STATE_DIR"/inline-e2e-matrix "$QG"
}

HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

SKILLS="$TL_TMP/skills"
for s in inst-a inst-b verify-tests devops-quality-gates silver-blast-radius; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done

STATE="$SB_RUNTIME_STATE_DIR/state-test"
QG="$SB_RUNTIME_STATE_DIR/quality-gate-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"
export SILVER_BULLET_QUALITY_GATE_STATE_FILE="$QG"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"

state() { printf '%s\n' "$@" >"$STATE"; }
run_ca() {
  local event="$1" cmd="$2"
  shift 2
  local json
  json="$(jq -cn --arg e "$event" --arg c "$cmd" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}')"
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "$2"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
decision() {
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -r 'if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -r '.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // ""' <<<"$TL_OUT"; }
release_ready() {
  printf 'matrix=claude-only\n' >"$SB_RUNTIME_STATE_DIR/release-live-matrix"
  printf 'matrix=claude-only\n' >"$SB_RUNTIME_STATE_DIR/e2e-live-matrix"
  printf 'matrix=inline-full-surface\n' >"$SB_RUNTIME_STATE_DIR/inline-e2e-matrix"
  printf '%s\n' adversarial-review-clean sentinel-skills-clean quality-gate-stage-3 full-test-suite-rerun >"$QG"
}
# write_exec <file> <exit-code>: install an executable validator atomically (write, chmod, rename)
# so an immediate exec cannot race an open writer ("Text file busy").
write_exec() {
  printf '#!/usr/bin/env bash\nexit %s\n' "$2" >"$1.tmp"
  chmod +x "$1.tmp"
  mv -f "$1.tmp" "$1"
}
PR='gh pr create --fill'

