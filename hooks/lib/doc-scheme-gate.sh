# shellcheck shell=bash
# Silver Bullet — doc-scheme contract gate helpers.
#
# Runtime source of truth:
#   - docs/doc-scheme.json (machine-enforced contract)
#   - docs/doc-scheme.md   (human-readable policy; must stay in sync)
#
# This helper enforces per-task checklist completeness based on the JSON contract.
# It is used by stop-check.sh (task completion gate) and completion-audit.sh
# (delivery gate).
#
# Runtime paths are host-specific; source the selector so state directories
# resolve to the active host runtime root.

_sb_runtime_paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_sb_runtime_paths_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_sb_runtime_paths_dir/runtime-paths.sh"
fi

sb_doc_scheme__mtime_epoch() {
  local path="$1"
  local value=""
  if [[ "$(uname)" == "Darwin" ]]; then
    value=$(stat -f %m "$path" 2>/dev/null || true)
  else
    value=$(stat --format=%Y "$path" 2>/dev/null || true)
  fi
  [[ "$value" =~ ^[0-9]+$ ]] && printf '%s' "$value" || printf '0'
}

sb_doc_scheme__status_valid() {
  local status="${1:-}"
  case "$status" in
    updated|not-needed:*|n/a:*) return 0 ;;
    *) return 1 ;;
  esac
}

sb_doc_scheme__key_state() {
  local repo_root="$1"
  local month="$2"
  local doc_key="$3"
  local full=""
  local f=""
  local m=0

  SB_DOC_KEY_LABEL="$doc_key"
  SB_DOC_KEY_EXISTS=0
  SB_DOC_KEY_MTIME=0

  case "$doc_key" in
    "docs/knowledge/YYYY-MM.md")
      SB_DOC_KEY_LABEL="docs/knowledge/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/knowledge/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(sb_doc_scheme__mtime_epoch "$f")
        if (( m > SB_DOC_KEY_MTIME )); then
          SB_DOC_KEY_EXISTS=1
          SB_DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    "docs/lessons/YYYY-MM.md")
      SB_DOC_KEY_LABEL="docs/lessons/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/lessons/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(sb_doc_scheme__mtime_epoch "$f")
        if (( m > SB_DOC_KEY_MTIME )); then
          SB_DOC_KEY_EXISTS=1
          SB_DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    *)
      full="$repo_root/$doc_key"
      if [[ -f "$full" && ! -L "$full" ]]; then
        SB_DOC_KEY_EXISTS=1
        SB_DOC_KEY_MTIME=$(sb_doc_scheme__mtime_epoch "$full")
      fi
      ;;
  esac
}

sb_doc_scheme__write_gap_report() {
  local mode="$1"
  local repo_root="$2"
  local state_dir="$3"
  local task_id="$4"
  local task_granularity="$5"
  local checklist_path="$6"
  local contract_path="$7"
  local issues="$8"
  local generated_at=""
  local repo_slug=""
  local gap_dir=""
  local gap_path=""
  local issues_json=""

  generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  repo_slug=$(printf '%s' "$repo_root" | sed 's#[^A-Za-z0-9._-]#-#g')
  [[ -n "$repo_slug" ]] || repo_slug="repo"

  gap_dir="${state_dir}/doc-scheme-gaps"
  mkdir -p "$gap_dir"
  gap_path="${gap_dir}/${repo_slug}.json"

  issues_json=$(printf '%s' "$issues" | jq -R -s 'split("\n") | map(select(length > 0))')

  jq -n \
    --arg mode "$mode" \
    --arg repo_root "$repo_root" \
    --arg generated_at "$generated_at" \
    --arg task_id "$task_id" \
    --arg task_granularity "$task_granularity" \
    --arg checklist_path "$checklist_path" \
    --arg contract_path "$contract_path" \
    --argjson issues "$issues_json" \
    '{
      mode: $mode,
      repo_root: $repo_root,
      generated_at: $generated_at,
      task_id: $task_id,
      task_granularity: $task_granularity,
      checklist_path: $checklist_path,
      contract_path: $contract_path,
      issues: $issues
    }' > "$gap_path"

  SB_DOC_SCHEME_GAP_REPORT_PATH="$gap_path"
}

# Enforce doc-scheme contract.
# Args:
#   $1 mode ("task" or "delivery")
#   $2 repo_root
#   $3 sb_state_dir
#   $4 emit_fn (function name; called with one string argument)
# Behavior:
#   - returns 0 when gate is not applicable or passes
#   - calls emit_fn + exits 0 when blocked
sb_doc_scheme_gate_enforce() {
  local mode="$1"
  local repo_root="$2"
  local state_dir="$3"
  local emit_fn="$4"

  local doc_scheme_md="$repo_root/docs/doc-scheme.md"
  local contract_file="$repo_root/docs/doc-scheme.json"
  local checklist=""
  local session_start_file="${SILVER_BULLET_SESSION_START_FILE:-${state_dir}/session-start-time}"
  local session_start=""
  local gate_issues=""
  local checklist_mtime=0
  local month=""
  local task_id="unknown-task"
  local task_granularity_raw=""
  local task_granularity=""
  local enabled="true"
  local should_enforce="false"
  local remediation_cmd=""
  local mode_label=""

  # Gate applies only when the repo opted into doc-scheme governance.
  if [[ ! -f "$doc_scheme_md" && ! -f "$contract_file" ]]; then
    return 0
  fi

  mode_label="Task completion"
  if [[ "$mode" == "delivery" ]]; then
    mode_label="Delivery"
  fi

  if [[ ! -f "$doc_scheme_md" || -L "$doc_scheme_md" ]]; then
    gate_issues+="  - Missing required policy file: docs/doc-scheme.md"$'\n'
  fi
  if [[ ! -f "$contract_file" || -L "$contract_file" ]]; then
    gate_issues+="  - Missing required contract file: docs/doc-scheme.json"$'\n'
  fi

  session_start_file="${session_start_file/#\~/$HOME}"
  case "$session_start_file" in
    "$SB_RUNTIME_HOME_ROOT"/.silver-bullet/*) ;;
    *) session_start_file="${state_dir}/session-start-time" ;;
  esac
  session_start=$(cat "$session_start_file" 2>/dev/null || true)
  if ! [[ "$session_start" =~ ^[0-9]+$ ]]; then
    gate_issues+="  - Missing/invalid session marker: ${session_start_file}"$'\n'
  fi

  if [[ -n "$gate_issues" ]]; then
    sb_doc_scheme__write_gap_report "$mode" "$repo_root" "$state_dir" "$task_id" "$task_granularity_raw" "docs/task-doc-checklist.json" "docs/doc-scheme.json" "$gate_issues"
    remediation_cmd="/silver:ensure-docs --recover-scheme"
    message=$(cat <<EOF
🛑 DOC-SCHEME GATE — ${mode_label} blocked.

Silver Bullet requires both \`docs/doc-scheme.md\` and \`docs/doc-scheme.json\`, plus a valid session marker, before docs enforcement can proceed.

Fix these items:
${gate_issues}Guided recovery:
\`${remediation_cmd}\`

Latest gap report:
\`${SB_DOC_SCHEME_GAP_REPORT_PATH}\`
EOF
)
    "$emit_fn" "$message"
    exit 0
  fi

  if ! jq empty "$contract_file" >/dev/null 2>&1; then
    gate_issues+="  - Invalid JSON: docs/doc-scheme.json"$'\n'
    sb_doc_scheme__write_gap_report "$mode" "$repo_root" "$state_dir" "$task_id" "$task_granularity_raw" "docs/task-doc-checklist.json" "docs/doc-scheme.json" "$gate_issues"
    message=$(cat <<EOF
🛑 DOC-SCHEME GATE — ${mode_label} blocked.

\`docs/doc-scheme.json\` is malformed.

Fix these items:
${gate_issues}Guided recovery:
\`/silver:ensure-docs --recover-scheme\`

Latest gap report:
\`${SB_DOC_SCHEME_GAP_REPORT_PATH}\`
EOF
)
    "$emit_fn" "$message"
    exit 0
  fi

  checklist=$(jq -r '.sync.task_checklist_path // "docs/task-doc-checklist.json"' "$contract_file" 2>/dev/null || true)
  [[ -n "$checklist" ]] || checklist="docs/task-doc-checklist.json"
  if [[ "$checklist" = /* ]]; then
    checklist="$repo_root/${checklist#/}"
  else
    checklist="$repo_root/$checklist"
  fi

  enabled=$(jq -r '.enforcement.enabled // true' "$contract_file" 2>/dev/null || true)
  if [[ "$enabled" != "true" ]]; then
    return 0
  fi

  # Determine whether this task granularity is in scope for enforcement.
  task_id=$(jq -r '.task_id // "unknown-task"' "$checklist" 2>/dev/null || true)
  task_granularity_raw=$(jq -r '.task_granularity // empty' "$checklist" 2>/dev/null || true)
  if [[ "$task_granularity_raw" =~ ^[0-9]+$ ]]; then
    task_granularity="$task_granularity_raw"
  fi

  _sb_granularity_levels=()
  while IFS= read -r _level; do
    [[ -n "$_level" ]] || continue
    _sb_granularity_levels+=("$_level")
  done < <(jq -r '.enforcement.granularity_levels // [2,3] | .[]' "$contract_file" 2>/dev/null || true)
  if ((${#_sb_granularity_levels[@]} == 0)); then
    _sb_granularity_levels=(2 3)
  fi

  if [[ -n "$task_granularity" ]]; then
    local level=""
    for level in "${_sb_granularity_levels[@]}"; do
      if [[ "$task_granularity" == "$level" ]]; then
        should_enforce="true"
        break
      fi
    done
  fi

  if [[ "$should_enforce" != "true" ]]; then
    if [[ -z "$task_granularity" ]]; then
      gate_issues+="  - Missing numeric task granularity in checklist ('task_granularity')."$'\n'
      gate_issues+="  - Contract enforces these levels: $(printf '%s ' "${_sb_granularity_levels[@]}" | sed 's/ $//')."$'\n'
    else
      # Explicitly out-of-scope granularity: do not gate this task.
      return 0
    fi
  fi

  month=$(date '+%Y-%m')

  if [[ ! -f "$checklist" || -L "$checklist" ]]; then
    gate_issues+="  - Missing checklist: ${checklist#"$repo_root"/}"$'\n'
  else
    checklist_mtime=$(sb_doc_scheme__mtime_epoch "$checklist")
    if (( checklist_mtime < session_start )); then
      gate_issues+="  - Stale checklist (not updated this session): ${checklist#"$repo_root"/}"$'\n'
    fi
    if ! jq -e '.docs | type == "object"' "$checklist" >/dev/null 2>&1; then
      gate_issues+="  - Invalid checklist: .docs object missing in ${checklist#"$repo_root"/}"$'\n'
    fi
  fi

  _sb_required_doc_keys=()
  while IFS= read -r _doc_key; do
    [[ -n "$_doc_key" ]] || continue
    _sb_required_doc_keys+=("$_doc_key")
  done < <(jq -r '.required_docs[]?.key // empty' "$contract_file" 2>/dev/null || true)
  if ((${#_sb_required_doc_keys[@]} == 0)); then
    gate_issues+="  - Invalid contract: required_docs[] is empty in docs/doc-scheme.json"$'\n'
  fi

  _sb_mandatory_updated=()
  while IFS= read -r _mandatory_key; do
    [[ -n "$_mandatory_key" ]] || continue
    _sb_mandatory_updated+=("$_mandatory_key")
  done < <(
    jq -r '
      (
        (.mandatory_updated_docs // [])
        + ((.required_docs // []) | map(select(.mandatory_updated == true) | .key))
      ) | .[]?
    ' "$contract_file" 2>/dev/null || true
  )

  if [[ -f "$checklist" && ! -L "$checklist" ]] && jq -e '.docs | type == "object"' "$checklist" >/dev/null 2>&1; then
    local doc_key=""
    local status=""
    local mandatory_key=""
    local section=""
    local section_status=""
    local mandatory=false

    for doc_key in "${_sb_required_doc_keys[@]}"; do
      [[ -n "$doc_key" ]] || continue
      status=$(jq -r --arg k "$doc_key" '.docs[$k] // empty' "$checklist" 2>/dev/null || true)
      if [[ -z "$status" ]]; then
        gate_issues+="  - Missing checklist entry: ${doc_key}"$'\n'
      elif ! sb_doc_scheme__status_valid "$status"; then
        gate_issues+="  - Invalid checklist status: ${doc_key} -> ${status}"$'\n'
      fi

      mandatory=false
      for mandatory_key in "${_sb_mandatory_updated[@]}"; do
        [[ "$mandatory_key" == "$doc_key" ]] || continue
        mandatory=true
        break
      done

      if [[ "$mandatory" == true && "$status" != "updated" ]]; then
        gate_issues+="  - Required status 'updated': ${doc_key}"$'\n'
      fi

      if [[ "$status" == "updated" ]]; then
        sb_doc_scheme__key_state "$repo_root" "$month" "$doc_key"
        if (( SB_DOC_KEY_EXISTS == 0 )); then
          gate_issues+="  - Missing file marked updated: ${SB_DOC_KEY_LABEL}"$'\n'
        elif (( SB_DOC_KEY_MTIME < session_start )); then
          gate_issues+="  - Stale file marked updated: ${SB_DOC_KEY_LABEL} (not updated this session)"$'\n'
        fi
      fi

      while IFS= read -r section; do
        [[ -n "$section" ]] || continue
        section_status=$(jq -r --arg k "$doc_key" --arg s "$section" '.sections[$k][$s] // empty' "$checklist" 2>/dev/null || true)
        if [[ -z "$section_status" ]]; then
          gate_issues+="  - Missing section checklist entry: ${doc_key} :: ${section}"$'\n'
          continue
        fi
        if ! sb_doc_scheme__status_valid "$section_status"; then
          gate_issues+="  - Invalid section status: ${doc_key} :: ${section} -> ${section_status}"$'\n'
        fi
      done < <(jq -r --arg k "$doc_key" '.required_docs[] | select(.key == $k) | .required_sections[]? // empty' "$contract_file" 2>/dev/null || true)
    done
  fi

  if [[ -n "$gate_issues" ]]; then
    sb_doc_scheme__write_gap_report "$mode" "$repo_root" "$state_dir" "$task_id" "$task_granularity_raw" "${checklist#"$repo_root"/}" "docs/doc-scheme.json" "$gate_issues"
    remediation_cmd="/silver:ensure-docs --from-hook --task ${task_id:-unknown-task} --gaps ${SB_DOC_SCHEME_GAP_REPORT_PATH}"
    message=$(cat <<EOF
🛑 DOC-SCHEME GATE — ${mode_label} blocked.

\`docs/doc-scheme.json\` enforcement requires complete checklist coverage for this task and current-session updates for all mandated docs.

Fix these items:
${gate_issues}Run:
\`${remediation_cmd}\`

If scheme files are missing/corrupt, recover first:
\`/silver:ensure-docs --recover-scheme\`
EOF
)
    "$emit_fn" "$message"
    exit 0
  fi

  return 0
}
