# shellcheck shell=bash
# Autonomous orchestrator state — intent, flow queue, workflow binding (Wave 0.3, 0.7).

_sb_orch_state_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_sb_orch_state_lib_dir}/orchestrator-io.sh" ]]; then
  # shellcheck source=lib/orchestrator-io.sh
  source "${_sb_orch_state_lib_dir}/orchestrator-io.sh"
fi
if ! declare -f sb_orchestrator_flow_to_skill >/dev/null 2>&1 && [[ -f "${_sb_orch_state_lib_dir}/orchestrator-directive.sh" ]]; then
  # shellcheck source=lib/orchestrator-directive.sh
  source "${_sb_orch_state_lib_dir}/orchestrator-directive.sh"
fi

sb_orchestrator_state_file() {
  printf '%s/orchestrator.json' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_orchestrator_composition_log() {
  local root="${1:-$PWD}"
  printf '%s/.planning/orchestrator-composition-log.jsonl' "$root"
}

sb_orchestrator_is_composer_skill() {
  case "$1" in
    silver|silver-feature|silver-ui|silver-devops|silver-bugfix|silver-deep-research|silver-release|silver-fast|silver-new-workflow|silver-benchmark|silver-canary|silver-content|silver-deploy|silver-forensics|silver-incident|silver-refactor|silver-retro|silver-test)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sb_orchestrator_is_flow_atom() {
  case "$1" in
    silver-quality-gates|silver-context|silver-plan|silver-execute|silver-verify|silver-ship|silver-review|silver-review-request|silver-review-triage|silver-review-fix-ladder|silver-secure|silver-validate|silver-clarify|silver-deep-research|silver-scan|silver-ensure-docs|silver-handoff|silver-spec|silver-debug|silver-ui-contract|silver-ui-review|silver-blast-radius|devops-quality-gates|devops-skill-router|silver-branch-finish|silver-completion-audit|silver-create-release|security|silver-triage|tdd|verify-tests|silver-agent-codex|silver-agent-cursor|silver-fixture-read-a|silver-fixture-read-b)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Canonical post-execution chain (FLOW 10 → 12 → 11 → validate → FLOW 13 → FLOW 14).
# Maps to docs/composable-flows-contracts.md § Post-execution sequencing.
sb_orchestrator_post_exec_queue() {
  local preship_qg="${1:-FLOW-QUALITY-GATE-PRESHIP}"
  printf '%s' "silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,${preship_qg},silver-branch-finish,silver-completion-audit,silver-ship"
}

# Planning-floor skills (required_planning) for a composer: the project's configured list when
# repo_root has one, else the shipped template default, else the built-in three. devops
# composers (devops, canary, deploy, incident) and projects whose active_workflow is devops-cycle
# use required_planning_devops.
# dev-cycle-check and completion-audit refuse source
# edits and commits until these are recorded, so every queue that reaches silver-execute must
# contain them (R10-02).
sb_orchestrator_planning_floor_csv() {
  _sb_orch_floor_csv required_planning "$1" "${2:-}" \
    "silver-quality-gates,silver-context,silver-plan" \
    "silver-blast-radius,devops-quality-gates,silver-context,silver-plan"
}

# The configured skill list KEY (required_planning / required_deploy; the _devops variant for devops
# composers and devops-cycle projects): project config, else shipped template, else FALLBACK.
_sb_orch_floor_csv() {
  local base="$1" composer="$2" repo_root="${3:-}" fallback="$4" devops_fallback="$5"
  local key="$base" cfg csv="" tpl
  case "$composer" in silver-devops|silver-canary|silver-deploy|silver-incident) key="${base}_devops" ;; esac
  cfg="$repo_root/.silver-bullet.json"
  # The hooks pick the list from the project's active workflow, so the queue does the same.
  if [[ -n "$repo_root" && -f "$cfg" ]] && command -v jq >/dev/null 2>&1 \
     && [[ "$(jq -r '.project.active_workflow // ""' "$cfg" 2>/dev/null || true)" == "devops-cycle" ]]; then
    key="${base}_devops"
  fi
  if command -v jq >/dev/null 2>&1; then
    [[ -n "$repo_root" && -f "$cfg" ]] && csv="$(jq -r --arg k "$key" '(.skills[$k] // []) | join(",")' "$cfg" 2>/dev/null || true)"
    if [[ -z "$csv" ]]; then
      tpl="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../templates/silver-bullet.config.json.default"
      [[ -f "$tpl" ]] && csv="$(jq -r --arg k "$key" '(.skills[$k] // []) | join(",")' "$tpl" 2>/dev/null || true)"
    fi
  fi
  if [[ -z "$csv" ]]; then
    csv="$fallback"
    [[ "$key" == "${base}_devops" ]] && csv="$devops_fallback"
  fi
  printf '%s' "$csv"
}

# Delivery floor (R10-02 part B): the required_deploy skills that no queue token stands for. A queue
# that reaches silver-ship through the review triad is given silver-triage (after review-triage),
# verify-tests (after verify) and tdd (before execute) when the configured required_deploy list
# asks for them, so following the queue exactly leaves `gh pr create` unblocked. Config is
# authoritative: a project that drops one of them from required_deploy does not get it queued.
sb_orchestrator_apply_deploy_floor() {
  local queue="$1" deploy_csv="$2" token out="" skill
  case ",$queue," in *,silver-ship,*) ;; *) printf '%s' "$queue"; return 0 ;; esac
  case ",$queue," in *,silver-review-triage,*) ;; *) printf '%s' "$queue"; return 0 ;; esac
  local IFS=','
  local -a tokens
  read -ra tokens <<< "$queue"
  local want_triage=false want_vt=false want_tdd=false
  case ",$deploy_csv," in *,silver-triage,*) want_triage=true ;; esac
  case ",$deploy_csv," in *,verify-tests,*) want_vt=true ;; esac
  case ",$deploy_csv," in *,tdd,*) want_tdd=true ;; esac
  for token in "${tokens[@]}"; do
    skill="$(sb_orchestrator_flow_to_skill "$token")"
    if [[ "$want_tdd" == true && "$token" == "silver-execute" && ",$queue," != *,tdd,* ]]; then
      out="${out:+$out,}tdd"
    fi
    out="${out:+$out,}$token"
    if [[ "$want_triage" == true && "$skill" == "silver-review-triage" && ",$queue," != *,silver-triage,* ]]; then
      out="$out,silver-triage"
    fi
    if [[ "$want_vt" == true && "$skill" == "silver-verify" && ",$queue," != *,verify-tests,* ]]; then
      out="$out,verify-tests"
    fi
  done
  printf '%s' "$out"
}

# Insert the floor skills the queue lacks, in floor order, right before its silver-plan (or, when
# the queue has no plan step, before its first silver-execute).
# A queue token counts as present when it maps to the same skill (FLOW-QUALITY-GATE is
# silver-quality-gates). Queues without an execute step are left alone.
sb_orchestrator_apply_planning_floor() {
  local queue="$1" floor_csv="$2" token skill have="" out="" missing="" floor anchor="silver-execute"
  local IFS=','
  local -a tokens floor_skills
  case ",$queue," in *,silver-execute,*) ;; *) printf '%s' "$queue"; return 0 ;; esac
  case ",$queue," in *,silver-plan,*) anchor="silver-plan" ;; esac
  read -ra tokens <<< "$queue"
  read -ra floor_skills <<< "$floor_csv"
  # Only what runs up to the anchor counts: the pre-ship quality gate comes after execute.
  for token in "${tokens[@]}"; do
    skill="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || true)"
    have="$have,$token,$skill"
    [[ "$token" == "$anchor" ]] && break
  done
  for floor in "${floor_skills[@]}"; do
    [[ -n "$floor" ]] || continue
    case "$have," in *,"$floor",*) ;; *) missing="${missing:+$missing,}$floor" ;; esac
  done
  [[ -n "$missing" ]] || { printf '%s' "$queue"; return 0; }
  local inserted=false
  for token in "${tokens[@]}"; do
    if [[ "$token" == "$anchor" && "$inserted" == false ]]; then
      out="${out:+$out,}$missing"
      inserted=true
    fi
    out="${out:+$out,}$token"
  done
  printf '%s' "$out"
}

sb_orchestrator_default_queue_for_composer() {
  local composer="$1"
  local q
  q="$(sb_orchestrator_apply_planning_floor "$(_sb_orch_raw_queue_for_composer "$composer")" "$(sb_orchestrator_planning_floor_csv "$composer")")"
  sb_orchestrator_apply_deploy_floor "$q" "$(_sb_orch_floor_csv required_deploy "$composer" "" "" "")"
}

_sb_orch_raw_queue_for_composer() {
  local composer="$1"
  local post_exec
  case "$composer" in
    # Enforcement queue: FLOW 13 pre-plan → FLOW 6 pre-chain → FLOW 8 → post-exec (FLOW 10–14).
    # Optional FLOW 1–5 atoms are parent-inserted per composer SKILL.md context scan.
    silver-feature)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-validate,silver-execute,${post_exec}"
      ;;
    silver-ui)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "FLOW-QUALITY-GATE,silver-context,silver-plan,silver-ui-contract,silver-validate,silver-execute,silver-ui-review,${post_exec}"
      ;;
    silver-devops)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-blast-radius,devops-skill-router,devops-quality-gates,security,silver-context,silver-plan,silver-validate,silver-execute,${post_exec}"
      ;;
    silver-bugfix)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-debug,silver-plan,silver-execute,${post_exec}"
      ;;
    silver-deep-research)
      printf '%s' 'silver-clarify,silver-deep-research,silver-ensure-docs,silver-validate'
      ;;
    silver-new-workflow)
      printf '%s' 'silver-clarify,silver-scan,silver-deep-research,silver-plan,silver-review-fix-ladder,silver-execute,silver-verify,silver-validate,silver-ensure-docs'
      ;;
    silver-fast)
      printf '%s' 'FLOW-QUALITY-GATE,silver-plan,silver-validate,silver-execute,silver-verify'
      ;;
    silver-release)
      # FLOW 18 delivery tail — audit/gap steps are parent-driven (see sb:release SKILL.md).
      printf '%s' 'FLOW-QUALITY-GATE,silver-review-request,silver-review,silver-review-triage,silver-verify,security,silver-secure,silver-validate,silver-branch-finish,silver-completion-audit,silver-ship,silver-create-release'
      ;;
    silver)
      printf '%s' 'silver-context'
      ;;
    silver-benchmark)
      printf '%s' 'silver-context,silver-plan,silver-execute,silver-verify,silver-ensure-docs'
      ;;
    silver-canary)
      printf '%s' 'silver-blast-radius,silver-plan,silver-execute,silver-verify,silver-ship'
      ;;
    silver-content)
      printf '%s' 'silver-clarify,silver-plan,silver-execute,silver-verify,silver-ensure-docs'
      ;;
    silver-deploy)
      printf '%s' 'silver-blast-radius,devops-quality-gates,silver-plan,silver-execute,silver-verify,security,silver-secure,silver-ship'
      ;;
    silver-forensics)
      printf '%s' 'silver-debug,silver-execute,silver-ensure-docs,silver-validate'
      ;;
    silver-incident)
      printf '%s' 'silver-blast-radius,silver-debug,silver-plan,silver-execute,security,silver-secure,silver-verify,silver-ensure-docs'
      ;;
    silver-refactor)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-plan,silver-validate,silver-execute,${post_exec}"
      ;;
    silver-retro)
      printf '%s' 'silver-context,silver-execute,silver-ensure-docs'
      ;;
    silver-test)
      printf '%s' 'silver-plan,silver-validate,silver-execute,silver-verify'
      ;;
    *)
      post_exec="$(sb_orchestrator_post_exec_queue 'FLOW-QUALITY-GATE-PRESHIP')"
      printf '%s' "silver-context,silver-plan,silver-execute,${post_exec}"
      ;;
  esac
}

# Resolve composer queue with runtime conditionals (silver-clarify --spec then silver-spec when SPEC.md absent).
sb_orchestrator_queue_for_composer() {
  local composer="$1"
  local repo_root="${2:-}"
  local queue
  queue="$(_sb_orch_raw_queue_for_composer "$composer")"
  case "$composer" in
    silver-feature|silver-ui)
      if [[ -n "$repo_root" && ! -f "$repo_root/.planning/SPEC.md" ]]; then
        queue="${queue//silver-context/silver-clarify,silver-spec,silver-context}"
      fi
      ;;
  esac
  queue="$(sb_orchestrator_apply_planning_floor "$queue" "$(sb_orchestrator_planning_floor_csv "$composer" "$repo_root")")"
  sb_orchestrator_apply_deploy_floor "$queue" "$(_sb_orch_floor_csv required_deploy "$composer" "$repo_root" "" "")"
}

sb_orchestrator_flow_label_for_token() {
  local line="$1"
  case "$line" in
    FLOW-QUALITY-GATE|FLOW-QUALITY-GATE-PRESHIP|FLOW-DEVOPS-QUALITY-GATE-PRESHIP) line="QUALITY GATE" ;;
    devops-skill-router) line="DEVOPS SKILL ROUTER" ;;
    silver-blast-radius) line="BLAST RADIUS" ;;
    silver-branch-finish) line="BRANCH FINISH" ;;
    silver-completion-audit) line="COMPLETION AUDIT" ;;
    silver-validate) line="VALIDATE" ;;
    silver-quality-gates|devops-quality-gates) line="QUALITY GATE" ;;
    silver-create-release) line="CREATE RELEASE" ;;
    silver-deep-research) line="RESEARCH" ;;
    security) line="SECURITY" ;;
    FLOW-DESIGN-HANDOFF|DESIGN-HANDOFF|DESIGN\ HANDOFF|silver-handoff) line="DESIGN HANDOFF" ;;
    FLOW-DOCUMENT|DOCUMENT|silver-ensure-docs) line="DOCUMENT" ;;
    silver-*) line="$(printf '%s' "${line#silver-}" | tr '[:lower:]' '[:upper:]')" ;;
  esac
  printf '%s' "$line"
}

sb_orchestrator_flow_csv_for_workflows() {
  local composer="$1" repo_root="${2:-}" line out="" queue
  queue="$(sb_orchestrator_queue_for_composer "$composer" "$repo_root")"
  local IFS=','
  read -ra tokens <<< "$queue"
  for line in "${tokens[@]}"; do
    [[ -z "$line" ]] && continue
    line="$(sb_orchestrator_flow_label_for_token "$line")"
    out="${out:+$out,}$line"
  done
  printf '%s' "$out"
}

# Resolve queue index for a completed atom skill, matching raw tokens or FLOW-* aliases.
sb_orchestrator_queue_index_for_atom() {
  local atom_skill="$1" file="$2" start="${3:-0}"
  local _lib_dir queue_len i token skill
  _lib_dir="$(dirname "${BASH_SOURCE[0]}")"
  if [[ -f "${_lib_dir}/orchestrator-directive.sh" ]]; then
    # shellcheck source=lib/orchestrator-directive.sh
    source "${_lib_dir}/orchestrator-directive.sh"
  fi
  queue_len="$(jq '.flow_queue | length' "$file" 2>/dev/null || echo 0)"
  for ((i = start; i < queue_len; i++)); do
    token="$(jq -r --argjson i "$i" '.flow_queue[$i] // ""' "$file" 2>/dev/null || true)"
    [[ -z "$token" ]] && continue
    if [[ "$token" == "$atom_skill" ]] || \
       { skill="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || true)"; [[ -n "$skill" && "$skill" == "$atom_skill" ]]; }; then
      # Never jump over unfinished positions to a later twin of an atom that already ran
      # (silver-quality-gates again vs FLOW-QUALITY-GATE-PRESHIP): that is a re-run, and
      # honouring it skips review, verify and secure (R4-05).
      if (( i > start )) && _sb_orch_queue_ran_before "$atom_skill" "$file" "$start"; then
        return 1
      fi
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

# True when a queue position before $3 already stands for skill $1 (finished or skipped).
_sb_orch_queue_ran_before() {
  local atom_skill="$1" file="$2" before="$3" i=0 token skill
  while IFS= read -r token; do
    (( i < before )) || break
    i=$((i + 1))
    [[ -n "$token" ]] || continue
    skill="$(sb_orchestrator_flow_to_skill "$token")"
    if [[ "$token" == "$atom_skill" || ( -n "$skill" && "$skill" == "$atom_skill" ) ]]; then
      return 0
    fi
  done < <(jq -r '.flow_queue[]?' "$file" 2>/dev/null)
  return 1
}

# Detect full-software intent for cross-session queue seeding (Wave 0.7).
sb_orchestrator_detect_full_software_intent() {
  local text="$1"
  grep -qiE <<<"$text" \
    'build (me |an |a )?(full |complete |entire )?(app|application|product|platform|system|software)|entire software|full software|from scratch|greenfield|new product|new app' \
    && return 0
  return 1
}

sb_orchestrator_full_software_queue() {
  printf '%s' 'silver-clarify,silver-spec,silver-feature,silver-ship,silver-release'
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
  sb_orchestrator_atomic_write "$(sb_orchestrator_state_file)" "$json"
}

sb_orchestrator_seed_intent() {
  sb_orchestrator_with_lock _sb_orchestrator_seed_intent "$@"
}

_sb_orchestrator_seed_intent() {
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

  local doc norm_root=""
  if [[ -n "$repo_root" ]]; then
    if declare -f sb_orchestrator_normalize_repo_root >/dev/null 2>&1; then
      norm_root="$(sb_orchestrator_normalize_repo_root "$repo_root")"
    else
      norm_root="$(cd "$repo_root" 2>/dev/null && pwd || printf '%s' "$repo_root")"
    fi
  fi
  doc="$(jq -n \
    --arg intent "$intent" \
    --arg composer "$composer" \
    --arg now "$now" \
    --arg repo_root "$norm_root" \
    --argjson queue "$flow_queue_json" \
    '{
      active_intent: $intent,
      composer: $composer,
      repo_root: $repo_root,
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
  sb_orchestrator_with_lock _sb_orchestrator_on_composer_start "$@"
}

_sb_orchestrator_on_composer_start() {
  local composer_skill="$1"
  local intent="${2:-}"
  local repo_root="${3:-}"
  [[ -n "$composer_skill" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  sb_orchestrator_seed_intent "$intent" "$composer_skill" "$repo_root"

  local catalog_wf="" _sched_lib _evt_lib now wf_bin wf_id flows_csv
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  _sched_lib="$(dirname "${BASH_SOURCE[0]}")/orchestrator-scheduler.sh"
  if [[ -f "$_sched_lib" ]]; then
    # shellcheck source=lib/orchestrator-scheduler.sh
    source "$_sched_lib"
    catalog_wf="$(sb_scheduler_composer_catalog_workflow_id "$composer_skill" 2>/dev/null || true)"
    sb_scheduler_apply_doc_only_tailoring "$repo_root" "$composer_skill" "$intent" 2>/dev/null || true
    sb_scheduler_apply_observability_tailoring "$repo_root" "$composer_skill" "$intent" 2>/dev/null || true
    sb_scheduler_apply_multi_workflow_chain "$repo_root" "$composer_skill" "$intent" 2>/dev/null || true
    sb_scheduler_apply_net_new_workflow_route "$repo_root" "$composer_skill" "$intent" 2>/dev/null || true
  fi

  wf_bin=""
  if [[ -x "$repo_root/scripts/workflows.sh" ]]; then
    wf_bin="$repo_root/scripts/workflows.sh"
  elif [[ -x "scripts/workflows.sh" ]]; then
    wf_bin="scripts/workflows.sh"
  fi
  flows_csv="$(sb_orchestrator_flow_csv_for_workflows "$composer_skill" "$repo_root")"
  if [[ -n "$wf_bin" ]]; then
    wf_id="$("$wf_bin" start "/sb:${composer_skill#silver-}" "${intent:-autonomous route}" "$flows_csv" 2>/dev/null || true)"
  else
    wf_id=""
  fi

  if [[ -n "$wf_id" ]]; then
    local file updated
    file="$(sb_orchestrator_state_file)"
    updated="$(jq --arg wid "$wf_id" --arg now "$now" \
      '.workflow_id = $wid | .updated_at = $now' \
      "$file" 2>/dev/null || true)"
    [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
  fi

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
      --arg swf "${catalog_wf:-}" \
      '{at:$at, composer:$composer, intent:$intent, workflow_id:$wid, selected_workflow:(if $swf != "" then $swf else null end), flows:$flows, mode:"autonomous"}' \
      >>"$logfile" 2>/dev/null || true
  fi

  # Phase B: catalog-driven scheduler plan + dispatch records (runtime proof; parent Task spawn required).
  if [[ -f "$_sched_lib" ]] && declare -f sb_scheduler_runtime_enabled >/dev/null 2>&1 && sb_scheduler_runtime_enabled; then
    local sched_plan
    sched_plan="$(sb_scheduler_plan_queue_from_state "$repo_root" 2>/dev/null || true)"
    if [[ -n "$sched_plan" && -n "$repo_root" && -d "$repo_root/.planning" ]]; then
      sb_scheduler_append_composition_log "$repo_root" "$sched_plan" 2>/dev/null || true
      sb_scheduler_refresh_active_batch_dispatch "$repo_root" 2>/dev/null || true
    fi
  fi
  _evt_lib="$(dirname "${BASH_SOURCE[0]}")/orchestrator-event-log.sh"
  if [[ -f "$_evt_lib" ]]; then
    # shellcheck source=lib/orchestrator-event-log.sh
    source "$_evt_lib"
    sb_orchestrator_event_append "composer_start" "$(jq -nc \
      --arg composer "$composer_skill" --arg intent "$intent" --arg wid "${wf_id:-}" --arg swf "${catalog_wf:-}" \
      '{composer: $composer, intent: $intent, workflow_id: $wid, selected_workflow: (if $swf != "" then $swf else null end)}')" 2>/dev/null || true
  fi

  printf '%s' "$wf_id"
}

sb_orchestrator_clear_queue() {
  local file
  file="$(sb_orchestrator_state_file 2>/dev/null || printf '%s/orchestrator.json' "${SB_RUNTIME_STATE_DIR:-/tmp}")"
  rm -f -- "$file" "${SB_RUNTIME_STATE_DIR:-/tmp}/orchestrator-stop-blocks.json" 2>/dev/null || true
  if declare -f sb_orchestrator_directive_clear >/dev/null 2>&1; then
    sb_orchestrator_directive_clear
  else
    rm -f -- "${SB_RUNTIME_STATE_DIR}/orchestrator-directive.json" 2>/dev/null || true
  fi
  if declare -f sb_orchestrator_clear_worker_marker >/dev/null 2>&1; then
    sb_orchestrator_clear_worker_marker
  fi
}

# Parent Stop blocks (queue pending / scheduler work pending) must not trap a session forever
# when nothing can move (R4-05). Each call counts one block that is about to be issued; the
# count restarts whenever orchestrator.json changed since the previous block. After
# SB_ORCHESTRATOR_STOP_BLOCK_LIMIT (default 5) blocks with no progress this returns 0: the caller
# skips only the orchestrator block (all other Stop checks still run) and a stop_release event is logged. Otherwise 1: keep blocking.
sb_orchestrator_stop_block_released() {
  local file counter stamp prior_stamp prior_count count limit
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  counter="${SB_RUNTIME_STATE_DIR:-/tmp}/orchestrator-stop-blocks.json"
  stamp="$(cksum <"$file" 2>/dev/null | cut -d' ' -f1)"
  prior_stamp=""
  prior_count=0
  if [[ -f "$counter" && ! -L "$counter" ]]; then
    prior_stamp="$(jq -r '.stamp // ""' "$counter" 2>/dev/null || true)"
    prior_count="$(jq -r '.count // 0' "$counter" 2>/dev/null || echo 0)"
  fi
  [[ "$prior_count" =~ ^[0-9]+$ ]] || prior_count=0
  if [[ "$prior_stamp" == "$stamp" ]]; then
    count=$((prior_count + 1))
  else
    count=1
  fi
  sb_orchestrator_atomic_write "$counter" "$(jq -nc --arg stamp "$stamp" --argjson count "$count" '{stamp:$stamp,count:$count}')" || true
  limit="${SB_ORCHESTRATOR_STOP_BLOCK_LIMIT:-5}"
  [[ "$limit" =~ ^[0-9]+$ ]] || limit=5
  if (( count == limit + 1 )) && declare -f sb_orchestrator_event_append >/dev/null 2>&1 \
     && sb_orchestrator_event_append "stop_release" "$(jq -nc --argjson n "$count" '{blocks_without_progress: $n}')" 2>/dev/null; then
    :  # logged
  fi
  (( count > limit ))
}

# Clear stale flow queue when the user interrupts with a new goal or informational query.
sb_orchestrator_clear_queue_on_interrupt() {
  local prompt="${1:-}"
  [[ -n "$prompt" ]] || return 1
  sb_orchestrator_parent_queue_pending || return 1
  if declare -f sb_prompt_is_orchestrator_followup >/dev/null 2>&1 \
    && sb_prompt_is_orchestrator_followup "$prompt"; then
    return 1
  fi
  if declare -f sb_prompt_is_informational_query >/dev/null 2>&1 \
    && sb_prompt_is_informational_query "$prompt"; then
    sb_orchestrator_clear_queue
    return 0
  fi
  if declare -f sb_prompt_is_bare_work_request >/dev/null 2>&1 \
    && sb_prompt_is_bare_work_request "$prompt"; then
    sb_orchestrator_clear_queue
    return 0
  fi
  return 1
}

# Advance to the next catalog composer when the current flow_queue is drained (multi-WF chain).
sb_orchestrator_try_advance_composer_chain() {
  sb_orchestrator_with_lock _sb_orchestrator_try_advance_composer_chain "$@"
}

_sb_orchestrator_try_advance_composer_chain() {
  local repo_root="${1:-}"
  local file next_composer intent saved_chain updated msg completed_composer
  command -v jq >/dev/null 2>&1 || return 1
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 1
  next_composer="$(jq -r '.composer_chain[0] // empty' "$file" 2>/dev/null || true)"
  [[ -n "$next_composer" && "$next_composer" != "null" ]] || return 1
  completed_composer="$(jq -r '.composer // ""' "$file" 2>/dev/null || true)"
  saved_chain="$(jq -c '.composer_chain[1:] // []' "$file" 2>/dev/null || echo '[]')"
  intent="$(jq -r '.active_intent // ""' "$file" 2>/dev/null || true)"
  updated="$(jq --argjson chain "$saved_chain" '.composer_chain = $chain' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
  if declare -f sb_orchestrator_event_record_advance >/dev/null 2>&1; then
    sb_orchestrator_event_record_advance "$completed_composer" "$next_composer" false 2>/dev/null || true
  fi
  sleep 1
  sb_orchestrator_on_composer_start "$next_composer" "$intent" "$repo_root" >/dev/null 2>&1 || true
  file="$(sb_orchestrator_state_file)"
  [[ -f "$file" ]] || return 0
  updated="$(jq --argjson chain "$saved_chain" '.composer_chain = $chain' "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
  msg="SB orchestrator ► Composer chain advanced to ${next_composer} (multi-workflow; invoke without user prompt)"
  printf '%s' "$msg"
}

sb_orchestrator_advance_on_atom() {
  sb_orchestrator_with_lock _sb_orchestrator_advance_on_atom "$@"
}

_sb_orchestrator_advance_on_atom() {
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
      flow_name="$(sb_orchestrator_flow_label_for_token "$atom_skill")"
      "$wf_bin" complete-flow "$wid" "$flow_name" 2>/dev/null || \
        "$wf_bin" complete-flow "$wid" "$atom_skill" 2>/dev/null || true
    fi
  fi

  local queue_len idx next_idx now last_idx
  queue_len="$(jq '.flow_queue | length' "$file" 2>/dev/null || echo 0)"
  last_idx="$(jq -r '.last_completed_index // -1' "$file" 2>/dev/null || echo -1)"
  idx="$(sb_orchestrator_queue_index_for_atom "$atom_skill" "$file" "$((last_idx + 1))" 2>/dev/null || true)"

  local _sched_lib sched_on=false join_result="no-batch" hold_for_batch=false
  _sched_lib="$(dirname "${BASH_SOURCE[0]}")/orchestrator-scheduler.sh"
  if [[ -f "$_sched_lib" ]] && declare -f sb_scheduler_runtime_enabled >/dev/null 2>&1 && sb_scheduler_runtime_enabled; then
    sched_on=true
  fi
  if [[ -z "$idx" && "$sched_on" != true ]]; then
    # Ignore stale or optional atom completions that are not still pending in
    # this queue. Rewinding to an earlier match corrupts current_flow.
    return 0
  fi

  if [[ "$sched_on" == true ]]; then
    # shellcheck source=lib/orchestrator-scheduler.sh
    source "$_sched_lib"
    sb_scheduler_mark_handoff_joined "" "$atom_skill" 2>/dev/null || true
    join_result="${SB_SCHEDULER_JOIN_RESULT:-no-batch}"
    local catalog_file atom_id
    catalog_file="$(sb_scheduler_catalog_file "$repo_root" 2>/dev/null || true)"
    if [[ -n "$catalog_file" ]]; then
      atom_id="$(sb_scheduler_resolve_atom_id "$catalog_file" "$atom_skill" 2>/dev/null || true)"
      if [[ -n "$atom_id" ]]; then
        sb_scheduler_refresh_join_gate "$repo_root" "$atom_id" >/dev/null 2>&1 || true
      fi
    fi
    # Hold current_flow only while THIS batch still waits for sibling joins. The decision comes
    # from the join itself: once the last handoff joins, the next batch is dispatched at once,
    # and asking "does the batch have pending joins" would see that new batch (R4-05).
    [[ "$join_result" == "batch-pending" ]] && hold_for_batch=true
    if [[ -z "$idx" ]]; then
      # A parallel sibling that finished out of order sits behind last_completed_index. Only the
      # join that completes the batch moves the queue, to the position after the last finisher.
      [[ "$join_result" == "batch-complete" && "$last_idx" -ge 0 ]] || return 0
      idx="$last_idx"
    fi
  fi

  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [[ "$hold_for_batch" == true ]]; then
    updated="$(jq --arg completed "$atom_skill" --arg now "$now" --argjson idx "$idx" \
      '.last_completed = $completed | .last_completed_index = ([.last_completed_index // -1, $idx] | max) | .updated_at = $now' \
      "$file" 2>/dev/null || true)"
    [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
    if declare -f sb_orchestrator_event_record_advance >/dev/null 2>&1; then
      sb_orchestrator_event_record_advance "$atom_skill" "$(jq -r '.current_flow // ""' <<<"$updated")" true 2>/dev/null || true
    fi
    sb_scheduler_write_batch_directive "$repo_root" 2>/dev/null || true
    return 0
  fi

  next_idx=$((idx + 1))
  if [[ "$next_idx" -ge "$queue_len" ]]; then
    next_flow=""
  else
    next_flow="$(jq -r --argjson i "$next_idx" '.flow_queue[$i] // ""' "$file" 2>/dev/null || true)"
  fi

  updated="$(jq --arg completed "$atom_skill" --arg next "$next_flow" --arg now "$now" --argjson idx "$idx" \
    '.current_flow = $next | .last_completed = $completed | .last_completed_index = $idx | .updated_at = $now' \
    "$file" 2>/dev/null || true)"
  [[ -n "$updated" ]] && sb_orchestrator_write_json "$updated"
  if declare -f sb_orchestrator_event_record_advance >/dev/null 2>&1; then
    sb_orchestrator_event_record_advance "$atom_skill" "$next_flow" false 2>/dev/null || true
  fi

  if [[ -n "$next_flow" ]]; then
    msg="SB orchestrator ► Next flow: ${next_flow} (auto-chained; invoke without user prompt)"
    if [[ "$join_result" == "batch-complete" ]] && sb_scheduler_active_batch_has_pending_joins 2>/dev/null; then
      # The scheduler already dispatched the next batch and wrote its directive (with the
      # handoff metadata); a plain per-flow directive would overwrite it.
      :
    elif [[ -f "${_lib_dir:-}/orchestrator-directive.sh" ]]; then
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
    local chain_msg=""
    chain_msg="$(sb_orchestrator_try_advance_composer_chain "$repo_root" 2>/dev/null || true)"
    if [[ -n "$chain_msg" ]]; then
      printf '%s' "$chain_msg"
      return 0
    fi
    if [[ -f "${_lib_dir:-}/orchestrator-directive.sh" ]]; then
      source "${_lib_dir}/orchestrator-directive.sh"
      sb_orchestrator_directive_clear
    elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh" ]]; then
      source "$(dirname "${BASH_SOURCE[0]}")/orchestrator-directive.sh"
      sb_orchestrator_directive_clear
    fi
  fi
}
