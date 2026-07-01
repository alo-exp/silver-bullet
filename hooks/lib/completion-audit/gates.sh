#!/usr/bin/env bash
# completion-audit: composed-workflow and delivery gate runners
run_workflow_strict_gate() {
  local repo_root="$1"
  local wf_dir="$repo_root/.planning/workflows"

  # No directory or no active files → no-op (caller falls through).
  [[ -d "$wf_dir" && ! -L "$wf_dir" ]] || return 0
  shopt -s nullglob
  local active=()
  for _wf in "$wf_dir"/*.md; do
    [[ -f "$_wf" ]] && active+=("$_wf")
  done
  shopt -u nullglob
  [[ ${#active[@]} -eq 0 ]] && return 0

  local id="${SB_WORKFLOW_ID:-}"
  if [[ -z "$id" ]]; then
    id="$(workflow_id_from_shell_assignment "$cmd" 2>/dev/null || true)"
  fi
  if [[ -z "$id" ]]; then
    local active_names=""
    for _wf in "${active[@]}"; do
      active_names+="  • $(basename "$_wf" .md)"$'\n'
    done
    emit_block "$(printf '🛑 WORKFLOW GATE — SB_WORKFLOW_ID is not set.\n\nActive composed workflow(s):\n%s\nFinal delivery requires SB_WORKFLOW_ID to identify which workflow this delivery completes. Set SB_WORKFLOW_ID to the active workflow id, then retry.' "$active_names")"
    exit 0
  fi

  # Validate id format and resolve file (no path traversal).
  if ! [[ "$id" =~ ^[0-9]{8}T[0-9]{6}Z-[a-z0-9]+-[a-z0-9-]+$ ]]; then
    emit_block "$(printf '🛑 WORKFLOW GATE — SB_WORKFLOW_ID has invalid format: %s\n\nExpected: <UTCcompact>-<6char>-<composer>' "$id")"
    exit 0
  fi
  local wf_file="$wf_dir/$id.md"
  if [[ ! -f "$wf_file" || -L "$wf_file" ]]; then
    emit_block "$(printf '🛑 WORKFLOW GATE — No active workflow file matches SB_WORKFLOW_ID=%s\n\nLook in .planning/workflows/ for the correct id, or restart the composition with /silver:*.' "$id")"
    exit 0
  fi

  # Count Flow Log rows: total vs complete. Strict structural anchor "^| N |"
  # excludes phase-iteration / autonomous-decision tables by requiring numeric
  # first column only.
  local total complete
  total=$(count_flow_log_rows "$wf_file")
  complete=$(count_complete_flow_rows "$wf_file")
  total=${total:-0}
  complete=${complete:-0}

  if [[ "$total" -eq 0 ]]; then
    emit_block "$(printf '🛑 WORKFLOW GATE — Workflow %s has no Flow Log rows; cannot verify completion.' "$id")"
    exit 0
  fi
  if [[ "$complete" -lt "$total" ]]; then
    emit_block "$(printf '🛑 WORKFLOW GATE — Workflow %s is incomplete: %d of %d flows complete.\n\nComplete remaining flows via .planning/scripts/workflows.sh complete-flow %s <flow>, then retry.' "$id" "$complete" "$total" "$id")"
    exit 0
  fi
  # All flows complete — fall through to the required-skills gate.
  return 0
}

# Platform-aware stat helper: returns file mtime as epoch seconds
_mtime_epoch() {
  local _v
  if [[ "$(uname)" == "Darwin" ]]; then
    _v=$(stat -f %m "$1" 2>/dev/null || true)
  else
    _v=$(stat --format=%Y "$1" 2>/dev/null || true)
  fi
  [[ "$_v" =~ ^[0-9]+$ ]] && printf '%s' "$_v" || printf '0'
}

# shellcheck disable=SC2034
# Resolve a checklist doc key to file state for the current repo/month.
# Inputs:
#   $1 repo root
#   $2 month (YYYY-MM)
#   $3 checklist key
# Outputs (globals):
#   DOC_KEY_LABEL, DOC_KEY_EXISTS (0|1), DOC_KEY_MTIME
resolve_doc_key_state() {
  local repo_root="$1"
  local month="$2"
  local doc_key="$3"
  local full=""
  local f=""
  local m=0

  DOC_KEY_LABEL="$doc_key"
  DOC_KEY_EXISTS=0
  DOC_KEY_MTIME=0

  case "$doc_key" in
    "docs/knowledge/YYYY-MM.md")
      DOC_KEY_LABEL="docs/knowledge/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/knowledge/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(_mtime_epoch "$f")
        if (( m > DOC_KEY_MTIME )); then
          DOC_KEY_EXISTS=1
          DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    "docs/learnings/YYYY-MM.md")
      DOC_KEY_LABEL="docs/learnings/${month}*.md"
      shopt -s nullglob
      for f in "$repo_root/docs/learnings/${month}"*.md; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        m=$(_mtime_epoch "$f")
        if (( m > DOC_KEY_MTIME )); then
          DOC_KEY_EXISTS=1
          DOC_KEY_MTIME=$m
        fi
      done
      shopt -u nullglob
      ;;
    *)
      full="$repo_root/$doc_key"
      if [[ -f "$full" && ! -L "$full" ]]; then
        DOC_KEY_EXISTS=1
        DOC_KEY_MTIME=$(_mtime_epoch "$full")
      fi
      ;;
  esac
}

# Build the governed checklist key set:
#   - mandatory every-task keys (with monthly wildcards)
#   - every concrete doc file under docs/ (excluding monthly files represented
#     by wildcard keys and placeholder .gitkeep files)
#   - root README.md / CHANGELOG.md when present
#
# Output (global array):
#   DOC_SCHEME_CHECKLIST_KEYS
build_doc_scheme_checklist_keys() {
  local repo_root="$1"
  local rel=""
  local key=""
  local deduped=()
  local seen=$'\n'

  DOC_SCHEME_CHECKLIST_KEYS=(
    "docs/CHANGELOG.md"
    "docs/knowledge/YYYY-MM.md"
    "docs/learnings/YYYY-MM.md"
  )

  if [[ -d "$repo_root/docs" && ! -L "$repo_root/docs" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      # Monthly docs are represented by wildcard keys above.
      if [[ "$rel" =~ ^docs/knowledge/[0-9]{4}-[0-9]{2}([-.].*)?\.md$ ]]; then
        continue
      fi
      if [[ "$rel" =~ ^docs/learnings/[0-9]{4}-[0-9]{2}([-.].*)?\.md$ ]]; then
        continue
      fi
      # Ignore placeholder files that are not real documentation content.
      if [[ "$rel" == ".gitkeep" || "$rel" == */.gitkeep ]]; then
        continue
      fi
      DOC_SCHEME_CHECKLIST_KEYS+=("$rel")
    done < <(cd "$repo_root" && find docs -type f -print | LC_ALL=C sort)
  fi

  if [[ -f "$repo_root/README.md" && ! -L "$repo_root/README.md" ]]; then
    DOC_SCHEME_CHECKLIST_KEYS+=("README.md")
  fi
  if [[ -f "$repo_root/CHANGELOG.md" && ! -L "$repo_root/CHANGELOG.md" ]]; then
    DOC_SCHEME_CHECKLIST_KEYS+=("CHANGELOG.md")
  fi

  for key in "${DOC_SCHEME_CHECKLIST_KEYS[@]}"; do
    [[ -n "$key" ]] || continue
    if [[ "$seen" == *$'\n'"$key"$'\n'* ]]; then
      continue
    fi
    deduped+=("$key")
    seen+="$key"$'\n'
  done
  DOC_SCHEME_CHECKLIST_KEYS=("${deduped[@]}")
}

# ── Doc-scheme delivery gate (delivery-only) ─────────────────────────────────
# If docs/doc-scheme.md exists, final delivery commands must prove that this
# session updated required docs and completed a per-task checklist:
#   - checklist file: docs/task-doc-checklist.json (updated this session)
#   - required-updated entries:
#       docs/CHANGELOG.md
#       docs/knowledge/YYYY-MM.md
#       docs/learnings/YYYY-MM.md
#   - complete checklist coverage for governed docs.
#
# Granularity: delivery-only by design. Intermediate commits are unaffected.
run_doc_scheme_delivery_gate() {
  local repo_root="$1"
  if declare -f sb_doc_scheme_gate_enforce >/dev/null 2>&1; then
    sb_doc_scheme_gate_enforce "delivery" "$repo_root" "$SB_STATE_DIR" "emit_block"
  fi
  return 0
}

# ── Evidence schema delivery gate (warn-first) ───────────────────────────────
run_evidence_schema_delivery_gate() {
  local repo_root="$1"
  EVIDENCE_SCHEMA_WARN=""
  local strict="${SILVER_BULLET_EVIDENCE_SCHEMA_STRICT:-}"
  if [[ -z "$strict" && -n "${config_file:-}" && -f "$config_file" ]]; then
    strict=$(jq -r '.hooks.evidence_schema.strict // "true"' "$config_file" 2>/dev/null || echo "true")
  fi
  if [[ -z "$strict" ]]; then
    strict="1"
  fi
  case "$strict" in
    1|true|yes|on) strict="1" ;;
    *) strict="0" ;;
  esac
  export SILVER_BULLET_EVIDENCE_SCHEMA_STRICT="$strict"
  if declare -f sb_evidence_schema_gate_enforce >/dev/null 2>&1; then
    sb_evidence_schema_gate_enforce "delivery" "$repo_root" "capture_evidence_warn" "emit_block"
  fi
  return 0
}

run_enforcement_tier_delivery_gate() {
  local cfg="${config_file:-}"
  [[ -n "$cfg" && -f "$cfg" ]] || return 0
  if [[ "${SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
    # shellcheck source=lib/sb-project-gate.sh
    source "$_lib_dir/sb-project-gate.sh"
    sb_project_is_initiated "$cfg" || return 0
  fi
  if declare -f sb_enforcement_tier_delivery_allowed >/dev/null 2>&1; then
    if ! sb_enforcement_tier_delivery_allowed "$cfg"; then
      local tier
      tier="$(sb_enforcement_tier_effective "$cfg")"
      emit_block "$(sb_enforcement_tier_block_message "$tier")"
      exit 0
    fi
  fi
  return 0
}

run_artifact_substance_delivery_gate() {
  local repo_root="$1"
  if declare -f sb_artifact_substance_gate_enforce >/dev/null 2>&1; then
    sb_artifact_substance_gate_enforce "$repo_root" "capture_evidence_warn" "emit_block" "1" "${state_contents:-}"
  fi
  return 0
}
