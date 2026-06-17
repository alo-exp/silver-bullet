# shellcheck shell=bash
# Autonomous orchestrator state — intent, flow queue, workflow binding (Wave 0.3, 0.7).

sb_orchestrator_state_file() {
  printf '%s/orchestrator.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_orchestrator_composition_log() {
  local root="${1:-$PWD}"
  printf '%s/.planning/orchestrator-composition-log.jsonl' "$root"
}

sb_orchestrator_is_composer_skill() {
  case "$1" in
    silver-feature|silver-ui|silver-devops|silver-bugfix|silver-research|silver-release|silver-fast)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sb_orchestrator_is_flow_atom() {
  case "$1" in
    silver-quality-gates|silver-context|silver-plan|silver-execute|silver-verify|silver-ship|silver-review|silver-review-request|silver-review-triage|silver-secure|silver-validate|silver-clarify|silver-spec|silver-debug|silver-ui-contract|silver-ui-review|silver-blast-radius|devops-quality-gates|devops-skill-router|silver-branch-finish|silver-completion-audit|silver-create-release|security)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Canonical post-execution chain (review triad → verify → secure → validate → pre-ship QG → ship prep).
sb_orchestrator_post_exec_queue() {
  local preship_qg="${1:-FLOW-QUALITY-GATE-PRESHIP}"
  printf '%s' "silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,${preship_qg},silver-branch-finish,silver-completion-audit,silver-ship"
}

sb_orchestrator_default_queue_for_composer() {
  local composer="$1"
  local post_exec
  case "$composer" in
    silver-feature)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-validate,silver-execute,${post_exec}"
      ;;
    silver-ui)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-ui-contract,silver-validate,silver-execute,silver-ui-review,${post_exec}"
      ;;
    silver-devops)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-DEVOPS-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-blast-radius,devops-skill-router,devops-quality-gates,security,silver-context,silver-plan,silver-validate,silver-execute,${post_exec}"
      ;;
    silver-bugfix)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-debug,silver-plan,silver-execute,${post_exec}"
      ;;
    silver-research)
      printf '%s' 'silver-clarify,silver-research'
      ;;
    silver-fast)
      printf '%s' 'FLOW-QUALITY-GATE,silver-plan,silver-validate,silver-execute,silver-verify'
      ;;
    silver-release)
      printf '%s' 'silver-quality-gates,silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,silver-branch-finish,silver-completion-audit,silver-ship,silver-create-release'
      ;;
    *)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-context,silver-plan,silver-execute,${post_exec}"
      ;;
  esac
}

# Resolve composer queue with runtime conditionals (e.g. silver-spec when SPEC.md absent).
sb_orchestrator_queue_for_composer() {
  local composer="$1"
  local repo_root="${2:-}"
  local queue
  queue="$(sb_orchestrator_default_queue_for_composer "$composer")"
  case "$composer" in
    silver-feature|silver-ui)
      if [[ -n "$repo_root" && ! -f "$repo_root/.planning/SPEC.md" ]]; then
        queue="${queue//silver-context/silver-spec,silver-context}"
      fi
      ;;
  esac
  printf '%s' "$queue"
}

sb_orchestrator_flow_csv_for_workflows() {
  local composer="$1" line out=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      FLOW-QUALITY-GATE|FLOW-QUALITY-GATE-PRESHIP|FLOW-DEVOPS-QUALITY-GATE-PRESHIP) line="QUALITY GATE" ;;
      devops-skill-router) line="DEVOPS SKILL ROUTER" ;;
      security) line="SECURE" ;;
      silver-*) line="$(printf '%s' "${line#silver-}" | tr '[:lower:]' '[:upper:]')" ;;
    esac
    out="${out:+$out,}$line"
  done < <(sb_orchestrator_queue_for_composer "$composer" | tr ',' '\n')
  printf '%s' "$out"
}

# Detect full-software intent for cross-session queue seeding (Wave 0.7).
sb_orchestrator_detect_full_software_intent() {
  local text="$1"
  printf '%s' "$text" | grep -qiE \
    'build (me |an |a )?(full |complete |entire )?(app|application|product|platform|system|software)|entire software|full software|from scratch|greenfield|new product|new app' \
    && return 0
  return 1
}

sb_orchestrator_full_software_queue() {
  printf '%s' 'silver-spec,silver-feature,silver-ship,silver-release'
}

sb_orchestrator_read() {
  local file
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  cat "$file"
}

sb_orchestrator_write_json() {
  local json="$1"
  [[ -n "$json" ]] || return 1
  local file dir
  file="$(sb_orchestrator_state_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || true
  printf '%s' "$json" >"${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file"
}

sb_orchestrator_seed_intent() {
  local intent="$1"
  local composer="${2:-}"
  local repo_root="${3:-}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  command -v jq >/dev/null 2>&1 || return 0

  local queue_csv flow_queue_json
  if sb_orchestrator_detect_full_software_intent "$intent"; then
    queue_csv="$(sb_orchestrator_full_software_queue)"
  elif [[ -n "$composer" ]]; then
    queue_csv="$(sb_orchestrator_queue_for_composer "$composer" "$repo_root")"
  else
    queue_csv="silver-context,silver-plan,silver-execute,silver-verify,silver-ship"
  fi

  flow_queue_json="$(printf '%s' "$queue_csv" | tr ',' '\n' | jq -R . | jq -s .)"

  local doc
  doc="$(jq -n \
    --arg intent "$intent" \
    --arg composer "$composer" \
    --arg now "$now" \
    --argjson queue "$flow_queue_json" \
    '{
      active_intent: $intent,
      composer: $composer,
      flow_queue: $queue,
      current_flow: ($queue[0] // ""),
      intent_graph: {
        scope: (if ($queue | length) > 4 then "full-software" else "single-workflow" end),
        seeded_at: $now
      },
      workflow_id: "",
      updated_at: $now
    }' 2>/dev/null || true)"
  [[ -n "$doc" ]] && sb_orchestrator_write_json "$doc"

  local _od_lib
  _od_lib="$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh"
  if [[ -f "$_od_lib" ]]; then
    # shellcheck source=lib/orchestrator-directive.sh
    source "$_od_lib"
    local first_skill
    first_skill="$(sb_orchestrator_flow_to_skill "$(printf '%s' "$queue_csv" | cut -d, -f1)")"
    sb_orchestrator_directive_write "$first_skill" "$intent" "Composer ${composer} started — invoke first queued flow" true
  fi
}

sb_orchestrator_on_composer_start() {
  local composer_skill="$1"
  local intent="${2:-}"
  local repo_root="${3:-}"
  [[ -n "$composer_skill" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  sb_orchestrator_seed_intent "$intent" "$composer_skill" "$repo_root"

  local wf_bin wf_id flows_csv
  wf_bin=""
  if [[ -x "$repo_root/scripts/workflows.sh" ]]; then
    wf_bin="$repo_root/scripts/workflows.sh"
  elif [[ -x "scripts/workflows.sh" ]]; then
    wf_bin="scripts/workflows.sh"
  fi
  [[ -n "$wf_bin" ]] || return 0

  flows_csv="$(sb_orchestrator_flow_csv_for_workflows "$composer_skill")"
  wf_id="$("$wf_bin" start "/silver:${composer_skill#silver-}" "${intent:-autonomous route}" "$flows_csv" 2>/dev/null || true)"
  [[ -n "$wf_id" ]] || return 0

  local file now
  file="$(sb_orchestrator_state_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local updated
  updated="$(jq --arg wid "$wf_id" --arg now "$now" \
    '.workflow_id = $wid | .updated_at = $now' \
    "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"

  # M-05: committed composition log artifact
  if [[ -n "$repo_root" && -d "$repo_root/.planning" ]]; then
    local logfile
    logfile="$(sb_orchestrator_composition_log "$repo_root")"
    mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
    jq -nc \
      --arg at "$now" \
      --arg composer "$composer_skill" \
      --arg intent "$intent" \
      --arg wid "$wf_id" \
      --arg flows "$flows_csv" \
      '{at:$at, composer:$composer, intent:$intent, workflow_id:$wid, flows:$flows, mode:"autonomous"}' \
      >>"$logfile" 2>/dev/null || true
  fi

  printf '%s' "$wf_id"
}

sb_orchestrator_advance_on_atom() {
  local atom_skill="$1"
  local repo_root="${2:-}"
  local file wid wf_bin next_flow msg

  sb_orchestrator_is_flow_atom "$atom_skill" || return 0
  command -v jq >/dev/null 2>&1 || return 0

  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 0

  wid="$(jq -r '.workflow_id // ""' "$file" 2>/dev/null || true)"
  if [[ -n "$wid" && -n "$repo_root" ]]; then
    wf_bin=""
    [[ -x "$repo_root/scripts/workflows.sh" ]] && wf_bin="$repo_root/scripts/workflows.sh"
    if [[ -n "$wf_bin" ]]; then
      flow_name="${atom_skill#silver-}"
      flow_name="$(printf '%s' "$flow_name" | tr '[:lower:]' '[:upper:]')"
      [[ "$atom_skill" == "silver-quality-gates" || "$atom_skill" == "devops-quality-gates" ]] && flow_name="QUALITY GATE"
      "$wf_bin" complete-flow "$wid" "$flow_name" 2>/dev/null || \
        "$wf_bin" complete-flow "$wid" "$atom_skill" 2>/dev/null || true
    fi
  fi

  local queue_len idx next_idx now last_idx
  queue_len="$(jq '.flow_queue | length' "$file" 2>/dev/null || echo 0)"
  last_idx="$(jq -r '.last_completed_index // -1' "$file" 2>/dev/null || echo -1)"
  idx="$(jq -r --arg atom "$atom_skill" --argjson start "$((last_idx + 1))" '
    (.flow_queue | to_entries[] | select(.key >= $start and .value == $atom) | .key) // empty
  ' "$file" 2>/dev/null || true)"
  if [[ -z "$idx" ]]; then
    idx="$(jq -r --arg atom "$atom_skill" '
      (.flow_queue | to_entries[] | select(.value == $atom) | .key) // empty
    ' "$file" 2>/dev/null || true)"
  fi
  [[ -n "$idx" ]] || idx="$(jq -r --arg atom "$atom_skill" '
    (.flow_queue | to_entries[] | select(.value | contains($atom)) | .key) // 0
  ' "$file" 2>/dev/null || echo 0)"

  next_idx=$((idx + 1))
  if [[ "$next_idx" -ge "$queue_len" ]]; then
    next_flow=""
  else
    next_flow="$(jq -r --argjson i "$next_idx" '.flow_queue[$i] // ""' "$file" 2>/dev/null || true)"
  fi

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  updated="$(jq --arg completed "$atom_skill" --arg next "$next_flow" --arg now "$now" --argjson idx "$idx" \
    '.current_flow = $next | .last_completed = $completed | .last_completed_index = $idx | .updated_at = $now' \
    "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"

  if [[ -n "$next_flow" ]]; then
    msg="SB orchestrator ► Next flow: ${next_flow} (auto-chained; invoke without user prompt)"
    if [[ -f "${_lib_dir:-}/orchestrator-directive.sh" ]]; then
      # shellcheck source=lib/orchestrator-directive.sh
      source "${_lib_dir}/orchestrator-directive.sh"
      local next_skill intent
      next_skill="$(sb_orchestrator_flow_to_skill "$next_flow")"
      intent="$(jq -r '.active_intent // ""' "$file" 2>/dev/null || true)"
      sb_orchestrator_directive_write "$next_skill" "$intent" "Flow ${atom_skill} complete — orchestrator queued ${next_flow}" true
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh" ]]; then
      # shellcheck source=lib/orchestrator-directive.sh
      source "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh"
      next_skill="$(sb_orchestrator_flow_to_skill "$next_flow")"
      intent="$(jq -r '.active_intent // ""' "$file" 2>/dev/null || true)"
      sb_orchestrator_directive_write "$next_skill" "$intent" "Flow ${atom_skill} complete — orchestrator queued ${next_flow}" true
    fi
    printf '%s' "$msg"
  else
    if [[ -f "${_lib_dir:-}/orchestrator-directive.sh" ]]; then
      source "${_lib_dir}/orchestrator-directive.sh"
      sb_orchestrator_directive_clear
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh" ]]; then
      source "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh"
      sb_orchestrator_directive_clear
    fi
  fi
}
