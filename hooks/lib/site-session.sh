# shellcheck shell=bash
# Site/help session profile — tracks site/** edits, regression, publish evidence.

sb_site_session_file() {
  printf '%s/site-session.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_live_evidence_file() {
  printf '%s/live-publish-evidence.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_subagent_log() {
  printf '%s/subagent-spawns.jsonl' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_repo_root() {
  local search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.silver-bullet.json" && -f "$search_dir/silver-bullet.md" ]]; then
      printf '%s' "$search_dir"
      return 0
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
  return 1
}

sb_site_session_path_is_site() {
  local file_path="$1"
  local repo_root rel
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    site/*|*/site/*) return 0 ;;
  esac
  repo_root="$(sb_site_session_repo_root 2>/dev/null || true)"
  [[ -n "$repo_root" ]] || return 1
  case "$file_path" in
    "$repo_root"/site/*) return 0 ;;
    /*)
      rel="${file_path#"$repo_root"/}"
      [[ "$rel" == site/* ]] && return 0
      ;;
  esac
  return 1
}

sb_site_prompt_is_site_intent() {
  local prompt lower
  prompt="${1:-}"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$lower" | grep -Eq '(site/|help center|help-center|homepage|github pages|sb\.alolabs\.dev|publish.*site|site.*publish|help/.*html|chrome\.css|tokens\.css)'
}

sb_site_session_touch() {
  local reason="${1:-edit}"
  local outfile now
  outfile="$(sb_site_session_file)"
  command -v jq >/dev/null 2>&1 || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  if [[ -f "$outfile" ]]; then
    jq --arg at "$now" --arg r "$reason" \
      '.active = true | .last_touch_at = $at | .touch_reason = $r | .regression_passed_at = (.regression_passed_at // null)' \
      "$outfile" >"${outfile}.tmp" 2>/dev/null \
      && mv "${outfile}.tmp" "$outfile"
  else
    jq -n --arg at "$now" --arg r "$reason" \
      '{active:true, started_at:$at, last_touch_at:$at, touch_reason:$r, regression_passed_at:null, push_intent:false, live_claim_pending:false}' \
      >"$outfile" 2>/dev/null || true
  fi
}

sb_site_session_mark_site_intent() {
  sb_site_session_touch "site-intent"
}

sb_site_session_mark_push_intent() {
  local outfile
  outfile="$(sb_site_session_file)"
  sb_site_session_touch "push-intent"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq '.push_intent = true' "$outfile" >"${outfile}.tmp" 2>/dev/null \
    && mv "${outfile}.tmp" "$outfile"
}

sb_site_session_mark_live_claim_pending() {
  local outfile
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" ]] || sb_site_session_touch "live-claim"
  command -v jq >/dev/null 2>&1 || return 0
  jq '.live_claim_pending = true' "$(sb_site_session_file)" >"${outfile}.tmp" 2>/dev/null \
    && mv "${outfile}.tmp" "$outfile"
}

sb_site_session_active() {
  local outfile
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '.active == true' "$outfile" >/dev/null 2>&1
}

sb_site_session_regression_current() {
  local outfile repo_root
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  repo_root="$(sb_site_session_repo_root 2>/dev/null || true)"
  [[ -n "$repo_root" ]] || return 1
  local passed_at touch_at
  passed_at="$(jq -r '.regression_passed_at // ""' "$outfile" 2>/dev/null || true)"
  touch_at="$(jq -r '.last_touch_at // ""' "$outfile" 2>/dev/null || true)"
  [[ -n "$passed_at" && -n "$touch_at" && ! "$passed_at" < "$touch_at" ]]
}

sb_site_session_mark_regression_pass() {
  local outfile now
  outfile="$(sb_site_session_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  command -v jq >/dev/null 2>&1 || return 0
  [[ -f "$outfile" ]] || sb_site_session_touch "regression"
  jq --arg at "$now" '.regression_passed_at = $at' "$(sb_site_session_file)" >"${outfile}.tmp" 2>/dev/null \
    && mv "${outfile}.tmp" "$outfile"
}

sb_site_session_run_regression_tests() {
  local repo_root="$1"
  local log_file rc
  [[ -n "$repo_root" && -d "$repo_root/tests" ]] || return 1
  log_file="$(mktemp "${SB_RUNTIME_STATE_DIR:-/tmp}/site-regression.XXXXXX.log" 2>/dev/null)" || return 1
  (
    cd "$repo_root" || exit 1
    bash tests/scripts/test-site-chrome-regression.sh \
      && bash tests/scripts/test-site-doc-freshness.sh \
      && bash tests/scripts/test-site-content-freshness.sh
  ) >"$log_file" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    sb_site_session_mark_regression_pass
  fi
  printf '%s' "$log_file"
  return $rc
}

sb_site_session_push_targets_main() {
  local cmd="$1"
  local unwrapped="${cmd:-}"
  if declare -f sb_shell_command_unwrap_rtk >/dev/null 2>&1; then
    unwrapped="$(sb_shell_command_unwrap_rtk "$cmd" 2>/dev/null || printf '%s' "$cmd")"
  fi
  printf '%s' "$unwrapped" | grep -qE '\bgit push\b' \
    && printf '%s' "$unwrapped" | grep -qE '\b(origin[[:space:]]+)?(main|master)\b|HEAD:main|HEAD:master'
}

sb_live_publish_evidence_valid() {
  local evidence_file repo_root
  evidence_file="$(sb_site_session_live_evidence_file)"
  [[ -f "$evidence_file" && ! -L "$evidence_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '
    (.status == "LIVE" or .status == "NOT_LIVE")
    and (.commit_sha // "" | length > 0)
    and ((.urls // []) | length > 0)
    and (.verified_at // "" | length > 0)
    and ((.markers_matched // []) | length > 0)
  ' "$evidence_file" >/dev/null 2>&1
}

sb_site_session_record_subagent_spawn() {
  local tool_input="${1:-}"
  local line now
  [[ -n "$tool_input" ]] || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if command -v jq >/dev/null 2>&1; then
    line="$(jq -nc --arg at "$now" --arg raw "$tool_input" \
      '{spawned_at:$at, tool_input_preview: ($raw | .[0:500]), site_related: ($raw | test("site|help|publish|homepage"; "i"))}')"
  else
    line="{\"spawned_at\":\"$now\"}"
  fi
  printf '%s\n' "$line" >>"$(sb_site_session_subagent_log)" 2>/dev/null || true
  if printf '%s' "$tool_input" | grep -qiE 'site|help|publish|homepage'; then
    sb_site_session_touch "subagent-site"
  fi
}

sb_site_session_subagents_spawned() {
  local log
  log="$(sb_site_session_subagent_log)"
  [[ -f "$log" ]] || return 1
  [[ -s "$log" ]]
}

sb_site_session_clear_subagent_log() {
  rm -f -- "$(sb_site_session_subagent_log)" 2>/dev/null || true
}

sb_site_session_vloop_file() {
  printf '%s/site-vloops.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_visual_evidence_file() {
  printf '%s/site-visual-evidence.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_pending_audit_file() {
  printf '%s/pending-completion-audit.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_site_session_init_vloops() {
  local outfile now
  outfile="$(sb_site_session_vloop_file)"
  command -v jq >/dev/null 2>&1 || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  jq -n --arg at "$now" '{
    profile: "site-content",
    steps: [
      {id:"preflight", label:"Preflight regression", status:"pending", evidence_ref:null, required:true},
      {id:"implement", label:"Site implement", status:"pending", evidence_ref:null, required:true},
      {id:"regression", label:"Chrome regression", status:"pending", evidence_ref:null, required:true},
      {id:"visual", label:"Visual evidence 1280px", status:"pending", evidence_ref:null, required:true},
      {id:"publish", label:"Publish evidence", status:"pending", evidence_ref:null, required:false}
    ],
    updated_at: $at
  }' >"$outfile" 2>/dev/null || true
}

sb_site_session_vloop_mark() {
  local step_id="${1:-}"
  local evidence_ref="${2:-}"
  local outfile now
  [[ -n "$step_id" ]] || return 1
  outfile="$(sb_site_session_vloop_file)"
  command -v jq >/dev/null 2>&1 || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  [[ -f "$outfile" ]] || sb_site_session_init_vloops
  jq --arg id "$step_id" --arg ref "$evidence_ref" --arg at "$now" '
    .updated_at = $at
    | (.steps[] | select(.id == $id)) |= (.status = "done" | .evidence_ref = (if $ref != "" then $ref else .evidence_ref end))
  ' "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
}

sb_site_session_vloop_pending() {
  local outfile push_intent
  outfile="$(sb_site_session_vloop_file)"
  [[ -f "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  push_intent=false
  if [[ -f "$(sb_site_session_file)" ]]; then
    jq -e '.push_intent == true' "$(sb_site_session_file)" >/dev/null 2>&1 && push_intent=true
  fi
  if [[ "$push_intent" == true ]]; then
    jq -e '[.steps[] | select(.status != "done" and (.required // true))] | length > 0' "$outfile" >/dev/null 2>&1
  else
    jq -e '[.steps[] | select(.status != "done" and (.required // true) and .id != "publish")] | length > 0' "$outfile" >/dev/null 2>&1
  fi
}

sb_site_session_vloop_pending_summary() {
  local outfile
  outfile="$(sb_site_session_vloop_file)"
  [[ -f "$outfile" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    [.steps[] | select(.status != "done") | "- \(.label) (\(.id)): \(.status)"]
    | if length == 0 then "" else "Site V-loop rollup — incomplete steps:\n" + (join("\n")) end
  ' "$outfile" 2>/dev/null || true
}

sb_site_session_sync_vloops_from_state() {
  local outfile
  outfile="$(sb_site_session_vloop_file)"
  [[ -f "$outfile" ]] || sb_site_session_init_vloops
  if sb_site_session_regression_current; then
    sb_site_session_vloop_mark "preflight" "site-session regression_passed_at"
    sb_site_session_vloop_mark "regression" "site-regression-gate"
  fi
  if sb_site_session_active; then
    sb_site_session_vloop_mark "implement" "site-session active"
  fi
  if sb_live_publish_evidence_valid; then
    sb_site_session_vloop_mark "publish" "$(sb_site_session_live_evidence_file)"
  fi
  if [[ -f "$(sb_site_session_visual_evidence_file)" ]]; then
    sb_site_session_vloop_mark "visual" "$(sb_site_session_visual_evidence_file)"
  fi
  if sb_site_session_active && ! jq -e '.push_intent == true' "$(sb_site_session_file)" >/dev/null 2>&1; then
    :
  elif sb_site_session_active && jq -e '.push_intent == true' "$(sb_site_session_file)" >/dev/null 2>&1; then
    outfile="$(sb_site_session_vloop_file)"
    jq '(.steps[] | select(.id == "publish")) |= (.required = true)' \
      "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
  fi
}

sb_site_session_mark_visual_evidence() {
  local path="${1:-}"
  local outfile now
  outfile="$(sb_site_session_visual_evidence_file)"
  command -v jq >/dev/null 2>&1 || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  jq -n --arg at "$now" --arg p "$path" \
    '{captured_at:$at, paths:[$p], viewport:"1280", themes:["light","dark"]}' >"$outfile" 2>/dev/null || true
  sb_site_session_vloop_mark "visual" "$path"
}

sb_site_session_visual_evidence_valid() {
  local outfile
  outfile="$(sb_site_session_visual_evidence_file)"
  [[ -f "$outfile" && ! -L "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '((.paths // []) | length > 0) and (.captured_at // "" | length > 0)' "$outfile" >/dev/null 2>&1
}

sb_site_session_mark_pending_completion_audit() {
  local outfile now task_preview
  outfile="$(sb_site_session_pending_audit_file)"
  task_preview="${1:-}"
  command -v jq >/dev/null 2>&1 || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  jq -n --arg at "$now" --arg preview "$task_preview" \
    '{pending:true, task_returned_at:$at, task_preview:($preview | .[0:300])}' >"$outfile" 2>/dev/null || true
}

sb_site_session_pending_completion_audit() {
  local outfile
  outfile="$(sb_site_session_pending_audit_file)"
  [[ -f "$outfile" && ! -L "$outfile" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '.pending == true' "$outfile" >/dev/null 2>&1
}

sb_site_session_clear_pending_completion_audit() {
  rm -f -- "$(sb_site_session_pending_audit_file)" 2>/dev/null || true
}

sb_site_preview_healthy() {
  local port="${SB_SITE_PREVIEW_PORT:-8765}"
  local host="${SB_SITE_PREVIEW_HOST:-127.0.0.1}"
  if command -v curl >/dev/null 2>&1; then
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://${host}:${port}/" 2>/dev/null || echo 000)"
    [[ "$code" == "200" ]]
    return $?
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  return 1
}
