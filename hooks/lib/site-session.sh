# shellcheck shell=bash
# shellcheck disable=SC2034  # the SB_SITE_* variables are outputs, read by the hooks that source this file
# shellcheck disable=SC2016  # the jq programs use jq variables ($at, $seq...), not shell expansion
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

# ---- the site profile -----------------------------------------------------------------------------
# The site gates enforce a project's website workflow, so they run only for a project that opts in with a
# `site_profile` section in its own .silver-bullet.json (protected by the integrity record):
#   {"site_profile": {"enabled": true, "dir": "site",
#                     "regression_scripts": ["tests/scripts/test-site-chrome-regression.sh", ...],
#                     "live_url": "https://example.com/", "preview_port": 8765, "preview_script": "site/serve.sh"}}
# Everything the gates run, fetch or probe comes from that profile, never from a literal in this plugin.
# Without the section every site hook is inert (R9-02).
_sb_site_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=path-canonical.sh
source "$_sb_site_lib_dir/path-canonical.sh"
# The profile is read from the verified record of the project (integrity.sh), never from the live file.
# shellcheck source=integrity.sh
[[ -f "$_sb_site_lib_dir/integrity.sh" ]] && source "$_sb_site_lib_dir/integrity.sh"

SB_SITE_ROOT=""
SB_SITE_DIR="site"
SB_SITE_REGRESSION_SCRIPTS=""
SB_SITE_LIVE_URL=""
SB_SITE_PROFILE_PORT=""
SB_SITE_PREVIEW_SCRIPT=""
SB_SITE_LIVE_MAX_AGE=86400
SB_SITE_STOP_LIMIT=3
SB_SITE_TRUSTED_HELPERS=""

# A profile path: relative, no "..", no absolute or home-relative spelling.
_sb_site_relpath_ok() {
  case "${1:-}" in
    "" | /* | \~* | ../* | */../* | */.. | ..) return 1 ;;
  esac
  return 0
}

# One profile value from the verified record; empty when the filter fails (every use treats empty as unset).
_sb_site_cfg() { sb_iv_jq -r "$1" 2>/dev/null || true; }

# sb_site_profile_load: read the profile of the project of $PWD from its verified integrity record into SB_SITE_*.
# Returns 1 (and leaves the gates inert) outside a project or unless site_profile.enabled is true.
sb_site_profile_load() {
  local line port
  SB_SITE_ROOT="" SB_SITE_DIR="site" SB_SITE_REGRESSION_SCRIPTS="" SB_SITE_LIVE_URL=""
  SB_SITE_PREVIEW_SCRIPT="" SB_SITE_LIVE_MAX_AGE=86400 SB_SITE_PROFILE_PORT="" SB_SITE_STOP_LIMIT=3 SB_SITE_TRUSTED_HELPERS=""
  sb_integrity_gate "$PWD" || return 1
  sb_iv_jq -e '.site_profile.enabled == true' >/dev/null 2>&1 || return 1
  SB_SITE_ROOT="$(cd "$SB_IV_ROOT" && pwd -P)"
  line="$(_sb_site_cfg '.site_profile.dir // "site" | strings')"
  if _sb_site_relpath_ok "$line"; then SB_SITE_DIR="${line%/}"; fi
  while IFS= read -r line; do
    _sb_site_relpath_ok "$line" || continue
    SB_SITE_REGRESSION_SCRIPTS="${SB_SITE_REGRESSION_SCRIPTS}${line}"$'\n'
  done < <(_sb_site_cfg '.site_profile.regression_scripts // [] | .[]? | strings')
  line="$(_sb_site_cfg '.site_profile.live_url // "" | strings')"
  case "$line" in http://* | https://*) SB_SITE_LIVE_URL="$line" ;; esac
  line="$(_sb_site_cfg '.site_profile.preview_script // "" | strings')"
  if _sb_site_relpath_ok "$line"; then SB_SITE_PREVIEW_SCRIPT="$line"; fi
  port="$(_sb_site_cfg '.site_profile.preview_port // empty | numbers')"
  if [[ "$port" =~ ^[0-9]+$ ]]; then SB_SITE_PROFILE_PORT="$port"; fi
  line="$(_sb_site_cfg '.site_profile.live_evidence_max_age_seconds // empty | numbers')"
  if [[ "$line" =~ ^[0-9]+$ ]] && ((line > 0)); then SB_SITE_LIVE_MAX_AGE="$line"; fi
  while IFS= read -r line; do
    _sb_site_relpath_ok "$line" || continue
    SB_SITE_TRUSTED_HELPERS="${SB_SITE_TRUSTED_HELPERS}${line}"$'\n'
  done < <(_sb_site_cfg '.site_profile.trusted_helpers // [] | .[]? | strings')
  line="$(_sb_site_cfg '.site_profile.stop_block_limit // empty | numbers')"
  if [[ "$line" =~ ^[0-9]+$ ]] && ((line > 0)); then SB_SITE_STOP_LIMIT="$line"; fi
  return 0
}

# sb_site_set_cwd INPUT: relative paths in a payload are relative to the payload's cwd, else to the hook's.
sb_site_set_cwd() {
  SB_SITE_CWD="$(printf '%s' "${1:-}" | jq -r '.cwd // empty | strings' 2>/dev/null || true)"
  [[ -n "$SB_SITE_CWD" && -d "$SB_SITE_CWD" ]] || SB_SITE_CWD="$PWD"
}

# A path inside <project>/<site dir>, judged on the canonical path: a project that merely lives under a directory
# called "site", or node_modules/x/site/, is not a site edit (R9-02).
sb_site_session_path_is_site() {
  local file_path="${1:-}" abs
  [[ -n "$file_path" && -n "$SB_SITE_ROOT" ]] || return 1
  abs="$(sb_path_normalize "$file_path" "${SB_SITE_CWD:-$PWD}" 2>/dev/null)"
  sb_path_is_within "$abs" "$SB_SITE_ROOT/$SB_SITE_DIR" "${SB_SITE_CWD:-$PWD}"
}

sb_site_prompt_is_site_intent() {
  local prompt lower
  prompt="${1:-}"
  [[ -n "$prompt" ]] || return 1
  lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  grep -Eq '(site/|help center|help-center|homepage|github pages|publish.*site|site.*publish|help/.*html|chrome\.css|tokens\.css)' <<<"$lower"
}

# Agent delegation text is not a site spawn (#244/#245).
sb_site_text_is_agent_delegation_intent() {
  local text="${1:-}"
  [[ -n "$text" ]] || return 1
  grep -qiE 'silver-agent-(codex|claude|opencode|pi)|AF-AGENT-DELEGATE|agent.delegat' <<<"$text"
}

# The session belongs to one project root (a worktree has its own): state left by another project is not this one's.
# The branch is not part of the scope: `git checkout -b x` carries the uncommitted site edits along, so a branch
# switch must not drop the session (it is stamped for information only).
sb_site_session_scope() {
  printf '%s' "$SB_SITE_ROOT"
}

sb_site_session_branch() {
  git -C "$SB_SITE_ROOT" symbolic-ref -q --short HEAD 2>/dev/null || true
}

_sb_site_json_update() { # FILE jq-args...
  local outfile="$1"
  shift
  if jq "$@" "$outfile" >"${outfile}.tmp" 2>/dev/null; then mv "${outfile}.tmp" "$outfile"; fi
}

# sb_site_session_touch REASON: a site edit. It starts the session (or restarts one left by another project or
# branch) and counts the edit: regression and visual evidence must cover the latest edit (edit_seq), a counter,
# so a one-second timestamp can never decide it (R9-13).
sb_site_session_touch() {
  local reason="${1:-edit}"
  local outfile now scope epoch
  outfile="$(sb_site_session_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  epoch="$(date +%s)"
  scope="$(sb_site_session_scope)"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  if sb_site_session_active; then
    _sb_site_json_update "$outfile" --arg at "$now" --arg r "$reason" --arg b "$(sb_site_session_branch)" --argjson ep "$epoch" \
      '.last_touch_at = $at | .touch_reason = $r | .branch = $b | .last_edit_epoch = $ep | .edit_seq = ((.edit_seq // 0) + 1)'
  else
    jq -n --arg at "$now" --arg r "$reason" --arg scope "$scope" --arg b "$(sb_site_session_branch)" --argjson ep "$epoch" --arg nonce "$epoch-$$-$RANDOM" \
      '{active:true, scope:$scope, branch:$b, nonce:$nonce, last_edit_epoch:$ep, started_at:$at, last_touch_at:$at, touch_reason:$r, edit_seq:1, regression_passed_at:null, regression_passed_seq:0, push_intent:false, live_claim_pending:false}' \
      >"$outfile" 2>/dev/null || true
  fi
}

# sb_site_session_note REASON [FLAG]: a prompt, push or live claim. Never starts a session and never moves the
# edit counter: it only annotates a session that already holds real site edits (R9-01, R9-02, R9-13).
sb_site_session_note() {
  local reason="${1:-note}" flag="${2:-}" outfile
  outfile="$(sb_site_session_file)"
  sb_site_session_gates_apply || return 0
  _sb_site_json_update "$outfile" --arg r "$reason" --arg f "$flag" \
    '.touch_reason = $r | (if $f != "" then .[$f] = true else . end)'
}

sb_site_session_mark_site_intent() { sb_site_session_note "site-intent"; }
sb_site_session_mark_push_intent() { sb_site_session_note "push-intent" push_intent; }
sb_site_session_mark_live_claim_pending() { sb_site_session_note "live-claim" live_claim_pending; }

sb_site_session_active() {
  local outfile
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" && ! -L "$outfile" ]] || return 1
  jq -e --arg scope "$(sb_site_session_scope)" '.active == true and (.scope // "") == $scope' "$outfile" >/dev/null 2>&1
}

# True once the session holds a real site edit (an edit counted by touch), not a push or a prompt.
sb_site_session_has_site_work() {
  local outfile
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" ]] || return 1
  jq -e '(.edit_seq // 0) > 0' "$outfile" >/dev/null 2>&1
}

# Site Stop/PreToolUse gates apply only to a profile project with real site edits this branch. Nothing the
# agent runs or says (an agent delegation, a prompt word) switches them off (R9-04, R9-12).
sb_site_session_gates_apply() {
  [[ -n "$SB_SITE_ROOT" ]] || return 1
  sb_site_session_active || return 1
  sb_site_session_has_site_work
}

# ---- Stop loop breaker (R9-03) ---------------------------------------------------------------------
# A Stop gate must not trap a session it cannot help, and must not become a one-time warning either. The host sets
# stop_hook_active on EVERY Stop that follows a Stop-hook block, so that flag alone proves nothing about whether the
# agent can clear the condition. A gate therefore releases only
#   - a condition the agent cannot clear (a gate setup failure) once the host reports stop_hook_active, or
#   - a condition that has blocked SB_SITE_STOP_LIMIT consecutive times with an identical fingerprint (nothing the
#     agent did changed it; default 3, site_profile.stop_block_limit),
# and logs every release to stop-loop-release.log. A changed fingerprint, or a gate that passes
# (sb_site_stop_loop_reset), starts the count again.
_sb_site_stop_loop_file() { printf '%s/site-stop-loop.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"; }

_sb_site_stop_loop_log() { # GATE WHY
  printf '%s\t%s released: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" \
    >>"${SB_RUNTIME_STATE_DIR:-/tmp}/stop-loop-release.log" 2>/dev/null || true
}

# sb_site_stop_loop_release GATE INPUT FINGERPRINT [UNCLEARABLE]: status 0 = release (do not block this Stop).
sb_site_stop_loop_release() {
  local gate="$1" input="${2:-}" fp="${3:-}" unclearable="${4:-}" f prior
  f="$(_sb_site_stop_loop_file)"
  if [[ -n "$unclearable" && "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" == "true" ]]; then
    _sb_site_stop_loop_log "$gate" "$unclearable (stop_hook_active)"
    return 0
  fi
  prior=0
  if [[ -f "$f" && ! -L "$f" ]]; then
    prior="$(jq -r --arg g "$gate" --arg fp "$fp" '(.[$g] // {}) | if .fp == $fp then .count else 0 end' "$f" 2>/dev/null)"
  fi
  [[ "$prior" =~ ^[0-9]+$ ]] || prior=0
  if ((prior >= SB_SITE_STOP_LIMIT)); then
    _sb_site_stop_loop_log "$gate" "unchanged after $prior consecutive blocks ($fp)"
    sb_site_stop_loop_reset "$gate"
    return 0
  fi
  _sb_site_stop_loop_store "$gate" "$fp" "$((prior + 1))"
  return 1
}

_sb_site_stop_loop_store() { # GATE FP COUNT
  local f
  f="$(_sb_site_stop_loop_file)"
  [[ -f "$f" && ! -L "$f" ]] || printf '{}' >"$f"
  jq -e . "$f" >/dev/null 2>&1 || printf '{}' >"$f"
  _sb_site_json_update "$f" --arg g "$1" --arg fp "$2" --argjson c "$3" '.[$g] = {fp:$fp, count:$c}'
}

# The gate passes: its consecutive-block count starts again.
sb_site_stop_loop_reset() {
  local f
  f="$(_sb_site_stop_loop_file)"
  [[ -f "$f" && ! -L "$f" ]] || return 0
  _sb_site_json_update "$f" --arg g "$1" 'del(.[$g])'
}

sb_site_session_subagent_input_is_site_related() {
  local tool_input="${1:-}"
  [[ -n "$tool_input" ]] || return 1
  if sb_site_text_is_agent_delegation_intent "$tool_input"; then
    return 1
  fi
  grep -qiE <<<"$tool_input" \
    'sb:content|site/[[:alnum:]_./-]+|site/\*\*|help[[:space:]-]center|sb\.alolabs\.dev|github[[:space:]]+pages|publish.*site|site.*publish|homepage'
}

sb_site_session_regression_current() {
  local outfile
  outfile="$(sb_site_session_file)"
  [[ -f "$outfile" ]] || return 1
  jq -e '(.regression_passed_seq // 0) >= (.edit_seq // 0)' "$outfile" >/dev/null 2>&1
}

# sb_site_session_mark_regression_pass SEQ: the suites passed against the edits counted up to SEQ.
sb_site_session_mark_regression_pass() {
  local outfile now
  outfile="$(sb_site_session_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  [[ -f "$outfile" ]] || return 0
  _sb_site_json_update "$outfile" --arg at "$now" --argjson seq "${1:-0}" \
    '.regression_passed_at = $at | .regression_passed_seq = $seq'
}

# The regression scripts are repository code the agent can edit, so a pass is refused for a script that is not
# committed as it stands (untracked, or changed in the index or work tree against HEAD): replacing one with
# `exit 0` takes a commit that stays in the history (R9-07). Prints the names of the scripts it does not trust.
sb_site_regression_untrusted() {
  local root="$1" script bad=""
  # The scripts and the helpers the profile lists (what the scripts run: a pass is only as good as those files).
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    if [[ -L "$root/$script" ]] \
      || ! git -C "$root" ls-files --error-unmatch -- "$script" >/dev/null 2>&1 \
      || ! git -C "$root" diff --quiet HEAD -- "$script" >/dev/null 2>&1; then
      bad="${bad}${script} "
    fi
  done <<<"${SB_SITE_REGRESSION_SCRIPTS}${SB_SITE_TRUSTED_HELPERS}"
  printf '%s' "${bad% }"
}

# Run the profile's regression scripts from the project root. Status: 0 pass, 90 a configured script is missing,
# 91 no log file, 92 a script is not committed as it stands (sb_site_regression_untrusted names them), else the
# failing script's status. Prints the log path.
sb_site_session_run_regression_tests() {
  local repo_root="$1"
  local log_file log_base state_dir rc script seq
  [[ -n "$repo_root" ]] || return 90
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    [[ -f "$repo_root/$script" ]] || return 90
  done <<<"$SB_SITE_REGRESSION_SCRIPTS"
  [[ -z "$(sb_site_regression_untrusted "$repo_root")" ]] || return 92
  # BSD/macOS mktemp only randomizes a TRAILING run of X's. A template like
  # site-regression.XXXXXX.log is taken literally, so the first call creates
  # that exact filename and every later call fails EEXIST — wedging the gate.
  # Create with trailing X's, then add the .log suffix. Ensure the state dir
  # exists; if mktemp still fails, fall back to an unwedgeable pid path so
  # log-alloc failure is never mistaken for a test failure.
  state_dir="${SB_RUNTIME_STATE_DIR:-/tmp}"
  mkdir -p "$state_dir" 2>/dev/null || true
  log_base="$(mktemp "${state_dir}/site-regression.XXXXXX" 2>/dev/null)" || log_base=""
  if [[ -n "$log_base" ]]; then
    log_file="${log_base}.log"
    if ! mv "$log_base" "$log_file" 2>/dev/null; then
      log_file="$log_base"
    fi
  else
    # mktemp failed (dir missing/unwritable). Do not retry the same directory —
    # use an unwedgeable pid path under TMPDIR so log-alloc is never a test failure.
    log_file="${TMPDIR:-/tmp}/site-regression-$$.log"
    if ! : >"$log_file" 2>/dev/null; then
      log_file="${SB_SITE_REGRESSION_FALLBACK_DIR:-/tmp}/site-regression-$$.log"
      : >"$log_file" 2>/dev/null || return 91
    fi
  fi
  seq="$(jq -r '.edit_seq // 0' "$(sb_site_session_file)" 2>/dev/null || echo 0)"
  (
    cd "$repo_root" || exit 1
    while IFS= read -r script; do
      [[ -n "$script" ]] || continue
      bash "$script" || exit $?
    done <<<"$SB_SITE_REGRESSION_SCRIPTS"
  ) >"$log_file" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    sb_site_session_mark_regression_pass "$seq"
  fi
  printf '%s' "$log_file"
  return $rc
}

# Live-publish evidence is written only by scripts/site-live-evidence.sh (it fetches the profile's live_url and
# matches the markers itself), and counts only for this project's current HEAD while it is fresh (R9-03, R9-08).
sb_live_publish_evidence_valid() {
  local evidence_file head
  evidence_file="$(sb_site_session_live_evidence_file)"
  [[ -f "$evidence_file" && ! -L "$evidence_file" ]] || return 1
  head="$(git -C "$SB_SITE_ROOT" rev-parse HEAD 2>/dev/null)" || return 1
  jq -e --arg head "$head" --arg root "$SB_SITE_ROOT" --argjson now "$(date +%s)" --argjson max "$SB_SITE_LIVE_MAX_AGE" '
    (.status == "LIVE" or .status == "NOT_LIVE")
    and .commit_sha == $head
    and .project == $root
    and ((.urls // []) | length > 0)
    and ((.markers_matched // []) | length > 0)
    and (.verified_epoch | type == "number")
    and ($now - .verified_epoch) <= $max
    and ($now - .verified_epoch) >= -300
  ' "$evidence_file" >/dev/null 2>&1
}

sb_site_session_record_subagent_spawn() {
  local tool_input="${1:-}"
  local line now
  [[ -n "$tool_input" ]] || return 0
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  line="$(jq -nc --arg at "$now" --arg raw "$tool_input" \
    '{spawned_at:$at, tool_input_preview: ($raw | .[0:500]), site_related: ($raw | test("site|help|publish|homepage"; "i"))}')"
  printf '%s\n' "$line" >>"$(sb_site_session_subagent_log)" 2>/dev/null || true
  if sb_site_session_subagent_input_is_site_related "$tool_input"; then
    sb_site_session_note "subagent-site"
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
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  [[ -f "$outfile" ]] || sb_site_session_init_vloops
  jq --arg id "$step_id" --arg ref "$evidence_ref" --arg at "$now" '
    .updated_at = $at
    | (.steps[] | select(.id == $id)) |= (.status = "done" | .evidence_ref = (if $ref != "" then $ref else .evidence_ref end))
  ' "$outfile" >"${outfile}.tmp" 2>/dev/null && mv "${outfile}.tmp" "$outfile"
}

sb_site_session_vloop_pending() {
  local outfile
  outfile="$(sb_site_session_vloop_file)"
  [[ -f "$outfile" ]] || return 1
  jq -e '[.steps[] | select(.status != "done" and .required != false)] | length > 0' "$outfile" >/dev/null 2>&1
}

sb_site_session_vloop_pending_summary() {
  local outfile
  outfile="$(sb_site_session_vloop_file)"
  [[ -f "$outfile" ]] || return 0
  jq -r '
    [.steps[] | select(.status != "done") | "- \(.label) (\(.id)): \(.status)"]
    | if length == 0 then "" else "Site V-loop rollup — incomplete steps:\n" + (join("\n")) end
  ' "$outfile" 2>/dev/null || true
}

# The rollup is derived from the evidence on every call, never remembered: a step that was done for another
# project, branch or earlier edit does not stay done (R9-08).
sb_site_session_sync_vloops_from_state() {
  local outfile
  outfile="$(sb_site_session_vloop_file)"
  sb_site_session_init_vloops
  if sb_site_session_regression_current; then
    sb_site_session_vloop_mark "preflight" "site-session regression_passed_seq"
    sb_site_session_vloop_mark "regression" "site-regression-gate"
  fi
  if sb_site_session_active; then
    sb_site_session_vloop_mark "implement" "site-session active"
  fi
  if sb_live_publish_evidence_valid; then
    sb_site_session_vloop_mark "publish" "$(sb_site_session_live_evidence_file)"
  fi
  if sb_site_session_visual_evidence_valid; then
    sb_site_session_vloop_mark "visual" "$(sb_site_session_visual_evidence_file)"
  fi
  if jq -e '.push_intent == true' "$(sb_site_session_file)" >/dev/null 2>&1; then
    _sb_site_json_update "$outfile" '(.steps[] | select(.id == "publish")) |= (.required = true)'
  fi
}

# sb_site_session_mark_visual_evidence PATH: a screenshot file the recorder saw a browser tool take. It covers the
# edits counted up to now; a later edit needs a new screenshot.
sb_site_session_mark_visual_evidence() {
  local path="${1:-}"
  local outfile now seq paths nonce
  outfile="$(sb_site_session_visual_evidence_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  seq="$(jq -r '.edit_seq // 0' "$(sb_site_session_file)" 2>/dev/null || echo 0)"
  nonce="$(jq -r '.nonce // ""' "$(sb_site_session_file)" 2>/dev/null)"
  paths="[]"
  if [[ -f "$outfile" ]] && jq -e --argjson seq "$seq" --arg root "$SB_SITE_ROOT" --arg nonce "$nonce" '.edit_seq == $seq and .project == $root and .nonce == $nonce' "$outfile" >/dev/null 2>&1; then
    paths="$(jq -c '.paths // []' "$outfile")"
  fi
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  jq -n --arg at "$now" --arg p "$path" --arg root "$SB_SITE_ROOT" --arg nonce "$nonce" --argjson seq "$seq" --argjson old "$paths" \
    '{captured_at:$at, project:$root, nonce:$nonce, edit_seq:$seq, paths:(($old + [$p]) | unique), viewport:"1280", themes:["light","dark"]}' \
    >"$outfile" 2>/dev/null || true
  sb_site_session_vloop_mark "visual" "$path"
}

# Valid: recorded for this project after the latest counted edit, with a screenshot that still exists.
sb_site_session_visual_evidence_valid() {
  local outfile p
  outfile="$(sb_site_session_visual_evidence_file)"
  [[ -f "$outfile" && ! -L "$outfile" ]] || return 1
  jq -e --arg root "$SB_SITE_ROOT" --slurpfile sess "$(sb_site_session_file)" \
    '.project == $root and (.nonce // "x") == ($sess[0].nonce // "y") and (.edit_seq // -1) >= ($sess[0].edit_seq // 0) and (.captured_at // "" | length > 0)' \
    "$outfile" >/dev/null 2>&1 || return 1
  while IFS= read -r p; do
    [[ -n "$p" && -f "$p" && ! -L "$p" ]] && return 0
  done < <(jq -r '.paths // [] | .[]? | strings' "$outfile" 2>/dev/null)
  return 1
}

sb_site_session_mark_pending_completion_audit() {
  local outfile now task_preview
  outfile="$(sb_site_session_pending_audit_file)"
  task_preview="${1:-}"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
  jq -n --arg at "$now" --arg preview "$task_preview" \
    '{pending:true, task_returned_at:$at, task_preview:($preview | .[0:300])}' >"$outfile" 2>/dev/null || true
}

sb_site_session_pending_completion_audit() {
  local outfile
  outfile="$(sb_site_session_pending_audit_file)"
  [[ -f "$outfile" && ! -L "$outfile" ]] || return 1
  jq -e '.pending == true' "$outfile" >/dev/null 2>&1
}

sb_site_session_clear_pending_completion_audit() {
  rm -f -- "$(sb_site_session_pending_audit_file)" 2>/dev/null || true
}

sb_site_preview_healthy() {
  local port="${SB_SITE_PREVIEW_PORT:-$SB_SITE_PROFILE_PORT}"
  [[ -n "$port" ]] || return 1
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


# sb_site_shell_push_kind: after sb_tool_input_load of a shell payload, prints "feature" when the shell analysis
# proved every push in the command is a feature-branch push, "final" for any other push (default branch, or not
# provable), nothing and status 1 when the command pushes nothing. The same classifier as completion-audit
# (Invariant P): a global option (`git -C . push`) or doubled spaces cannot hide a push, and a command that
# only mentions "git push" is not one (R9-06).
sb_site_shell_push_kind() {
  local verdict
  case " ${SB_SA_ACTIONS:-} " in *" push "*) ;; *) return 1 ;; esac
  verdict="$(printf '%s' "${SB_SA_JSON:-}" | jq -rR 'try (fromjson | .push_scope.verdict // "strict") catch "strict"' 2>/dev/null)"
  if [[ "$verdict" == feature ]]; then printf 'feature'; else printf 'final'; fi
}

# sb_site_is_image_file FILE: a regular, non-symlink file whose first bytes are a PNG, JPEG or WebP header.
sb_site_is_image_file() {
  local f="${1:-}" head
  [[ -f "$f" && ! -L "$f" ]] || return 1
  head="$(od -An -tx1 -N12 "$f" 2>/dev/null | tr -d ' \n')"
  case "$head" in
    89504e47* | ffd8ff* | 52494646????????57454250) return 0 ;;
  esac
  return 1
}

# The modification time of FILE in epoch seconds (python3 is a hard prerequisite; stat flags differ per platform).
sb_site_file_mtime() {
  python3 -c 'import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$1"
}

# sb_site_screenshot_dir_ok FILE: the file lies under the project or a temporary directory (the browser tool's
# output directory is one of them), never an arbitrary path.
sb_site_screenshot_dir_ok() {
  local f="${1:-}" d
  for d in "$SB_SITE_ROOT" "${TMPDIR:-/tmp}" /tmp /private/tmp /var/folders /private/var/folders; do
    [[ -n "$d" ]] && sb_path_is_within "$f" "$d" && return 0
  done
  return 1
}

# ---- shell writes the analysis cannot name (git apply, find -exec, a script that writes the site) -------------
# The CONTENT of the files under the site directory (tracked or not, ignoring ignored files) is fingerprinted, so a
# commit of unchanged content is not an edit; a change since the previous look is a site edit. The first look only records the baseline. Scripts that write the site BEFORE the
# first look in a session are not seen: that limit is documented in silver-bullet.md section 8.2.
sb_site_tree_digest() {
  git -C "$SB_SITE_ROOT" ls-files -z --cached --others --exclude-standard -- "$SB_SITE_DIR" 2>/dev/null \
    | (cd "$SB_SITE_ROOT" && xargs -0 git hash-object -- 2>/dev/null) | git hash-object --stdin 2>/dev/null
}

# Status 0 when the digest changed since the last call for this project (and records the new one).
sb_site_tree_changed() {
  local f cur prev
  f="${SB_RUNTIME_STATE_DIR:-/tmp}/site-tree-digest"
  cur="$SB_SITE_ROOT $(sb_site_tree_digest)"
  prev=""
  if [[ -f "$f" && ! -L "$f" ]]; then prev="$(cat "$f")"; fi
  printf '%s' "$cur" >"$f"
  [[ -n "$prev" && "${prev%% *}" == "$SB_SITE_ROOT" && "$prev" != "$cur" ]]
}
