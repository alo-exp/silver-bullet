#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# shellcheck source=lib/workflow-utils.sh
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck disable=SC1091
[[ -f "$_lib_dir/workflow-utils.sh" ]] && source "$_lib_dir/workflow-utils.sh"
# Fallback definitions if sourcing failed (e.g. in test environments or path resolution issues)
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| (complete|skipped)' "$1" 2>/dev/null || echo 0; }
fi

# shellcheck source=lib/skill-discovery.sh
if [[ -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/skill-discovery.sh"
fi
if ! declare -f sb_skill_is_installed >/dev/null 2>&1; then
  sb_skill_is_installed() { return 0; }
fi

# shellcheck source=lib/github-run-list.sh
if [[ -f "$_lib_dir/github-run-list.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/github-run-list.sh"
fi
if ! declare -f sb_github_run_list_json >/dev/null 2>&1; then
  sb_github_run_list_json() { return 1; }
fi

# shellcheck source=lib/doc-scheme-gate.sh
if [[ -f "$_lib_dir/doc-scheme-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/doc-scheme-gate.sh"
fi

# shellcheck source=lib/evidence-schema-gate.sh
if [[ -f "$_lib_dir/evidence-schema-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/evidence-schema-gate.sh"
fi

# shellcheck source=lib/enforcement-tier-gate.sh
if [[ -f "$_lib_dir/enforcement-tier-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/enforcement-tier-gate.sh"
fi

# shellcheck source=lib/artifact-substance-gate.sh
if [[ -f "$_lib_dir/artifact-substance-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/artifact-substance-gate.sh"
fi

# HOOK-04 (informational half): source the phase-path lib for the
# `_phase_lock_peek_on_exit` EXIT-trap helper. The trap emits a stderr
# WARN if the phase resolved from $PWD has no active lock or is owned
# by a non-claude runtime — non-blocking, preserves original $?.
# shellcheck source=lib/phase-path.sh
if [[ -f "$_lib_dir/phase-path.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/phase-path.sh"
  if declare -f _phase_lock_peek_on_exit >/dev/null 2>&1; then
    trap _phase_lock_peek_on_exit EXIT
  fi
fi

# Pre+PostToolUse hook (matcher: Bash)
# Detects git commit/push/deploy commands and blocks if workflow is incomplete.
#
# TWO-TIER ENFORCEMENT:
#   Intermediate commits (git commit, git push to feature branches):
#     → Only require required_planning skills (default: silver-quality-gates)
#     → Allows GSD execute-phase to make atomic commits during development
#   Final delivery (gh pr create, deploy, gh release create):
#     → Require full required_deploy skill list
#
# This prevents the deadlock where GSD's execution subagents cannot commit
# because final-delivery skills (GSD review, branch finishing, verify-tests, etc.) are not done yet.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so standalone Codex/Kay hook processes do not
# depend on host-provided SB_RUNTIME_* environment variables.
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/required-skills.sh"
fi
if [[ -f "$_lib_dir/quality-gates-mode.sh" ]]; then
  # shellcheck source=lib/quality-gates-mode.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/quality-gates-mode.sh"
fi
# DEFAULT_* / DEVOPS_DEFAULT_* populated by required-skills.sh (single source of truth).
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

# jq is required for enforcement — block delivery/intermediate gates when missing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

# Read JSON from stdin
input=$(cat)

# Detect hook event type (PreToolUse vs PostToolUse) — best-effort without jq
hook_event="PostToolUse"
if command -v jq >/dev/null 2>&1; then
  hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')
fi

# Emit a block in the correct format for the hook event type
emit_block() {
  local reason="$1"
  local json_reason
  if command -v jq >/dev/null 2>&1; then
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  elif command -v python3 >/dev/null 2>&1; then
    json_reason=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$reason")
  else
    json_reason='"enforcement blocked"'
  fi
  sb_hook_audit_record "completion-audit" "$hook_event" "deny" "$reason" "${cmd:-}"
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  _ca_config=""
  _ca_search="$PWD"
  while true; do
    if [[ -f "$_ca_search/.silver-bullet.json" && -f "$_ca_search/silver-bullet.md" ]]; then
      _ca_config="$_ca_search/.silver-bullet.json"
      break
    fi
    if [[ -d "$_ca_search/.git" ]] || [[ "$_ca_search" == "/" ]]; then
      break
    fi
    _ca_search=$(dirname "$_ca_search")
  done
  if [[ -n "$_ca_config" ]] && declare -f sb_project_is_initiated >/dev/null 2>&1 && sb_project_is_initiated "$_ca_config"; then
    sb_jq_enforcement_block "completion-audit" "emit_block"
    exit 0
  fi
  if printf '%s' "$input" | grep -qE 'git commit|git push|gh pr create|gh release create|\bdeploy\b'; then
    sb_jq_enforcement_block "completion-audit" "emit_block"
  fi
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

emit_warn() {
  local reason="$1"
  jq -n --arg m "$reason" '{"hookSpecificOutput":{"message":$m}}'
}

capture_evidence_warn() {
  EVIDENCE_SCHEMA_WARN="$1"
}

# Extract the command being run
if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
fi
if declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
  sb_tool_is_shell_like "$tool_name" || exit 0
fi
if declare -f sb_tool_command_string >/dev/null 2>&1; then
  cmd="$(sb_tool_command_string "$input")"
else
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
fi
[[ -z "$cmd" ]] && exit 0

# ── Classify the command ──────────────────────────────────────────────────────
# is_intermediate: git commit / git push (atomic commits during development)
# is_completion:   gh pr create / deploy / gh release create (final delivery gates)
#
# BUG-04 fix: classify against the FIRST LINE of the command only.
# Heredoc bodies (lines 2+) can contain text matching these patterns — e.g. a
# commit message that mentions "deploy" or "gh release create" — causing false-
# positive COMMIT BLOCKED blocks. The actual invocation is always on line 1.
is_intermediate=false
is_completion=false
cmd_first_line=$(printf '%s' "$cmd" | head -1)
if declare -f sb_shell_command_unwrap_rtk >/dev/null 2>&1; then
  cmd_first_line="$(sb_shell_command_unwrap_rtk "$cmd_first_line")"
fi

shell_payload_is_sb_skill_adapter_invocation() {
  local payload="$1"
  [[ -n "$payload" ]] || return 1
  [[ "$payload" != *$'\n'* ]] || return 1
  python3 - "$payload" <<'PY' >/dev/null 2>&1
import pathlib
import re
import shlex
import sys

payload = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
try:
    lexer = shlex.shlex(payload, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    raise SystemExit(1)

if not tokens:
    raise SystemExit(1)
if any(token in {";", "|", "||", "&", "&&", ">", ">>", "<", "<<"} for token in tokens):
    raise SystemExit(1)

idx = 0
if tokens[idx] == "env":
    idx += 1
while idx < len(tokens) and assignment_re.match(tokens[idx]):
    idx += 1
if idx + 1 >= len(tokens):
    raise SystemExit(1)

command = tokens[idx]
if not (command == "scripts/silver-bullet" or command.endswith("/scripts/silver-bullet")):
    raise SystemExit(1)
if tokens[idx + 1] != "invoke-skill":
    raise SystemExit(1)

print("adapter")
PY
}

workflow_id_from_shell_assignment() {
  local payload="$1"
  local first_line
  first_line=$(printf '%s' "$payload" | sed -n '1p')
  first_line="${first_line#"${first_line%%[![:space:]]*}"}"

  if [[ "$first_line" =~ ^export[[:space:]]+SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]]*[\;] ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$first_line" =~ ^env[[:space:]]+ ]]; then
    first_line="${first_line#env }"
    first_line="${first_line#"${first_line%%[![:space:]]*}"}"
  fi

  if [[ "$first_line" =~ (^|[[:space:]])SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]] ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

if shell_payload_is_sb_skill_adapter_invocation "$cmd"; then
  exit 0
fi

if printf '%s' "$cmd_first_line" | grep -qE '\bgit commit\b'; then
  is_intermediate=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgit push\b'; then
  is_intermediate=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgit (write-tree|commit-tree)\b'; then
  is_intermediate=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgit hash-object\b.*\s-w\b'; then
  is_intermediate=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgit update-ref\b.*\brefs/heads/'; then
  is_intermediate=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgh pr create\b'; then
  is_completion=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgh pr merge\b'; then
  is_completion=true
elif printf '%s' "$cmd_first_line" | grep -iqE '\bdeploy\b'; then
  is_completion=true
elif printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
  is_completion=true
fi

# Skip commands that don't match any gate
[[ "$is_intermediate" == false && "$is_completion" == false ]] && exit 0

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  completion-audit.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# No config → project not set up with Silver Bullet — silent exit
[[ -z "$config_file" ]] && exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_is_initiated "$config_file" || exit 0
fi

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR"
state_file="${SB_STATE_DIR}/state"
trivial_file="${SB_STATE_DIR}/trivial"
quality_gate_state_file="${SB_STATE_DIR}/quality-gate-state"
verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
required_planning_cfg=""
required_deploy_cfg=""
required_deploy_devops_cfg=""
required_planning_devops_cfg=""
active_workflow="full-dev-cycle"
release_require_plugin_runtime_matrix="false"
release_require_pre_release_quality_gate="false"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_planning // []) | join(" ")),
  ((.skills.required_planning_devops // []) | join(" ")),
  ((.skills.required_deploy // []) | join(" ")),
  ((.skills.required_deploy_devops // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle"),
  (.release.quality_gate_state_file // ""),
  ((.release.require_plugin_runtime_matrix // false) | tostring),
  ((.release.require_pre_release_quality_gate // false) | tostring)
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_planning_cfg=$(printf '%s' "$config_vals" | sed -n '3p')
required_planning_devops_cfg=$(printf '%s' "$config_vals" | sed -n '4p')
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '5p')
required_deploy_devops_cfg=$(printf '%s' "$config_vals" | sed -n '6p')
active_workflow=$(printf '%s' "$config_vals" | sed -n '7p')
cfg_quality_gate_state_file=$(printf '%s' "$config_vals" | sed -n '8p')
[[ -n "$cfg_quality_gate_state_file" ]] && quality_gate_state_file="${cfg_quality_gate_state_file/#\~/$HOME}"
release_require_plugin_runtime_matrix=$(printf '%s' "$config_vals" | sed -n '9p')
release_require_pre_release_quality_gate=$(printf '%s' "$config_vals" | sed -n '10p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"
# Env var override for pre-release quality gate file
quality_gate_state_file="${SILVER_BULLET_QUALITY_GATE_STATE_FILE:-$quality_gate_state_file}"
# Env var override for the test execution gate file
verify_tests_state_file="${SILVER_BULLET_VERIFY_TESTS_STATE_FILE:-$verify_tests_state_file}"

# Security: validate paths stay within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$state_file"; then
  state_file="${SB_STATE_DIR}/state"
fi
if ! sb_runtime_path_is_state_scoped "$trivial_file"; then
  trivial_file="${SB_STATE_DIR}/trivial"
fi
if ! sb_runtime_path_is_state_scoped "$quality_gate_state_file"; then
  quality_gate_state_file="${SB_STATE_DIR}/quality-gate-state"
fi
if ! sb_runtime_path_is_state_scoped "$verify_tests_state_file"; then
  verify_tests_state_file="${SB_STATE_DIR}/verify-tests-state"
fi

# ── Trivial bypass (reject symlinks) ─────────────────────────────────────────
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0
fi

# ── Composed-workflow gate (Pass 2 — strict, final delivery only) ────────────
# When one or more `.planning/workflows/<id>.md` files exist AND the current
# command is a final-delivery operation (gh release create / gh pr create /
# deploy / gh pr merge), the active workflow must be fully complete before
# the delivery is allowed. Strict matching: the workflow id is supplied via
# the SB_WORKFLOW_ID env var. The composer (e.g. /silver-feature) is expected
# to export this when the composition starts.
#
# Behavior matrix:
#   • No `.planning/workflows/` dir or no active files → fall through to the
#     legacy required-skills gate. (Backward compatible: workflows tracker is
#     opt-in for downstream projects that haven't migrated yet.)
#   • Final delivery + active workflow(s) present:
#       – SB_WORKFLOW_ID unset                       → BLOCK
#       – SB_WORKFLOW_ID does not match a file       → BLOCK
#       – Matching file has incomplete flows         → BLOCK
#       – All flows complete                         → fall through to the
#                                                       required-skills gate
#                                                       (still must pass)
#   • Intermediate commits / non-completion commands → not affected; this
#     block only fires under the `is_completion` branch later in this file.
#
# The check itself is implemented inside the `is_completion` branch below to
# keep the data-flow linear; this comment is the design contract.

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

# ── Detect current git branch ─────────────────────────────────────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# Validate branch name: only allow safe characters
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
on_main=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main=true
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

has_skill() {
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$state_contents" "$1"
    return $?
  fi
  printf '%s\n' "$state_contents" | grep -Fqx -- "$1" 2>/dev/null
}

# Line number of a skill in the state file (for ordering checks); 0 if absent
skill_line() {
  if declare -F sb_required_skill_line >/dev/null 2>&1; then
    sb_required_skill_line "$state_contents" "$1"
    return 0
  fi
  local line
  line=$(printf '%s\n' "$state_contents" | grep -Fnx -- "$1" | head -1 | cut -d: -f1)
  printf '%s' "${line:-0}"
}

# ── TIER 1: Intermediate commit check (git commit / git push) ─────────────────
if [[ "$is_intermediate" == true ]]; then
  # Determine planning skills required for intermediate commits
  # DevOps workflow requires silver-blast-radius + devops-quality-gates instead of silver-quality-gates
  # DEFAULT_PLANNING populated by required-skills.sh (sourced at top).
  default_planning="${DEFAULT_PLANNING:-${__SB_RS_PLANNING_FALLBACK:-silver-quality-gates silver-context silver-plan}}"
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    default_planning="${DEVOPS_DEFAULT_PLANNING:-${__SB_RS_DEVOPS_PLANNING_FALLBACK:-silver-blast-radius devops-quality-gates silver-context silver-plan}}"
  fi
  if [[ "$active_workflow" == "devops-cycle" && -n "$required_planning_devops_cfg" ]]; then
    configured_planning="$required_planning_devops_cfg"
  else
    configured_planning="$required_planning_cfg"
  fi
  if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
    planning_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$configured_planning" "$default_planning")"
  else
    planning_skills="${configured_planning:-$default_planning}"
  fi

  missing_planning=""
  ignored_planning=""
  for skill in $planning_skills; do
    if ! has_skill "$skill"; then
      if sb_skill_is_installed "$skill"; then
        missing_planning="${missing_planning:+$missing_planning }$skill"
      else
        ignored_planning="${ignored_planning:+$ignored_planning }$skill"
      fi
    fi
  done

  if [[ -n "$missing_planning" ]]; then
    missing_lines=""
    for skill in $missing_planning; do
      missing_lines="${missing_lines}  ❌ /${skill}\n"
    done
    msg=$(printf '🚫 COMMIT BLOCKED — Planning incomplete.\n\nYou must complete these planning steps before any commits:\n%s\nRun the missing planning skills first, then commit.' "$missing_lines")
    if [[ -n "$ignored_planning" ]]; then
      ignored_lines=""
      for skill in $ignored_planning; do
        ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
      done
      msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$msg" "$ignored_lines")
    fi
    emit_block "$msg"
    exit 0
  fi

  # VFY-01 plan-boundary: block plan-seal commits without completion-audit since last plan work
  if printf '%s' "$cmd" | grep -qE 'docs\([0-9]+-[0-9]+\): complete'; then
    if ! has_skill "silver-completion-audit"; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — Plan completion commit detected but /silver:completion-audit has not been recorded this session.\n\nRun /silver:completion-audit to verify completion claims, then retry the plan-seal commit.')"
      exit 0
    fi
    # VFY-01 extension (P3): require silver-verify + non-stale VERIFICATION.md
    if ! has_skill "silver-verify"; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — Phase completion requires /silver:verify recorded this session.\n\nRun /silver:verify and refresh VERIFICATION.md before plan-seal commit.')"
      exit 0
    fi
    _pr="$(dirname "$config_file")"
    [[ -z "$_pr" ]] && _pr="$PWD"
    vfile=""
    for candidate in "$_pr/.planning/VERIFICATION.md" "$_pr/.planning/phases"/*/*-VERIFICATION.md; do
      [[ -f "$candidate" && ! -L "$candidate" ]] || continue
      vfile="$candidate"
      break
    done
    if [[ -z "$vfile" ]]; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — No VERIFICATION.md found under .planning/. Run /silver:verify before plan-seal commit.')"
      exit 0
    fi
  fi

  # Planning is done — intermediate commits are allowed
  if [[ -n "$ignored_planning" ]]; then
    ignored_lines=""
    for skill in $ignored_planning; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '✅ Planning verified. Intermediate commit allowed.\n\nIgnored required skills:\n%s' "$ignored_lines")
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  else
    printf '{"hookSpecificOutput":{"message":"✅ Planning verified. Intermediate commit allowed."}}'
  fi
  exit 0
fi

# ── TIER 2: Final delivery check (gh pr create / deploy / release) ────────────

# Pass 2 strict workflow gate — runs before the required-skills check.
# repo root = directory of the resolved config_file (or $PWD as fallback).
project_root="$(dirname "$config_file")"
[[ -z "$project_root" ]] && project_root="$PWD"
run_enforcement_tier_delivery_gate
run_workflow_strict_gate "$project_root"
run_doc_scheme_delivery_gate "$project_root"
run_evidence_schema_delivery_gate "$project_root"
run_artifact_substance_delivery_gate "$project_root"

release_live_matrix_file="${SB_RUNTIME_STATE_DIR}/release-live-matrix"
e2e_live_matrix_file="${SB_RUNTIME_STATE_DIR}/e2e-live-matrix"
inline_e2e_matrix_file="${SB_RUNTIME_STATE_DIR}/inline-e2e-matrix"
if printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
  if [[ "$release_require_plugin_runtime_matrix" == "true" || "${SB_REQUIRE_PLUGIN_RELEASE_MATRIX:-0}" == "1" ]]; then
    release_matrix_value=""
    e2e_matrix_value=""
    inline_matrix_value=""
    if [[ -f "$release_live_matrix_file" && ! -L "$release_live_matrix_file" ]]; then
      release_matrix_value=$(grep -E '^matrix=' "$release_live_matrix_file" 2>/dev/null || true)
    fi
    if [[ -f "$e2e_live_matrix_file" && ! -L "$e2e_live_matrix_file" ]]; then
      e2e_matrix_value=$(grep -E '^matrix=' "$e2e_live_matrix_file" 2>/dev/null || true)
    fi
    if [[ -f "$inline_e2e_matrix_file" && ! -L "$inline_e2e_matrix_file" ]]; then
      inline_matrix_value=$(grep -E '^matrix=' "$inline_e2e_matrix_file" 2>/dev/null || true)
    fi

    if [[ "$release_matrix_value" == 'matrix=full-claude-codex' && "$e2e_matrix_value" == 'matrix=full-claude-codex' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    elif [[ "$release_matrix_value" == 'matrix=codex-only' && "$e2e_matrix_value" == 'matrix=codex-only' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    elif [[ "$release_matrix_value" == 'matrix=cursor-smoke' && "$e2e_matrix_value" == 'matrix=codex-only' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    else
      emit_block "$(printf '🛑 RELEASE BLOCKED — The plugin-runtime release matrix has not completed for this release session.\n\nThis gate is enabled for SB plugin releases. Run bash scripts/run-release-live-matrix.sh and tests/e2e-live/run-e2e-live-tests.sh in the standard Kay/OpenCode Go/DeepSeek V4 Flash low configuration, ensure the enterprise-grade-test-app journey records matrix=inline-full-surface in the host runtime inline-e2e-matrix (or complete the Claude supervised enterprise-e2e-matrix per .planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md), then retry. A full Claude/Codex matrix is still accepted when explicitly run, but it is no longer required for the release gate.' )"
      exit 0
    fi
  fi

  if [[ "$release_require_pre_release_quality_gate" == "true" || "${SB_REQUIRE_PRE_RELEASE_QUALITY_GATE:-0}" == "1" ]]; then
    quality_gate_ready=false
    if [[ -f "$quality_gate_state_file" && ! -L "$quality_gate_state_file" ]]; then
      quality_gate_ready=true
      for marker in \
        adversarial-review-clean \
        sentinel-skills-clean \
        quality-gate-stage-3 \
        full-test-suite-rerun; do
        if ! grep -Fqx -- "$marker" "$quality_gate_state_file" 2>/dev/null; then
          quality_gate_ready=false
          break
        fi
      done
    fi

    if [[ "$quality_gate_ready" != true ]]; then
      emit_block "$(printf '🛑 RELEASE BLOCKED — The configured pre-release quality sequence has not been completed in this session.\n\nComplete docs/internal/pre-release-quality-gate.md (adversarial + SENTINEL per-skill + public content + test rerun), record adversarial-review-clean, sentinel-skills-clean, quality-gate-stage-3, and full-test-suite-rerun in %s, then retry.' "$quality_gate_state_file" )"
      exit 0
    fi

    # Optional automated validation when scripts exist (non-fatal when absent in test fixtures).
    _qg_validate_launch="${project_root}/scripts/validate-launch-review.sh"
    if [[ -x "$_qg_validate_launch" ]]; then
      if ! "$_qg_validate_launch" >/dev/null 2>&1; then
        emit_block "$(printf '🛑 RELEASE BLOCKED — LAUNCH-REVIEW.md does not satisfy adversarial exit criteria (status: clean, discovery_clean_streak >= 2).\n\nRun bash scripts/validate-launch-review.sh for details, complete ENHANCED adversarial review, then retry.' )"
        exit 0
      fi
    fi
    _qg_validate_sentinel="${project_root}/scripts/validate-sentinel-skills-manifest.sh"
    if [[ -x "$_qg_validate_sentinel" ]]; then
      if ! "$_qg_validate_sentinel" >/dev/null 2>&1; then
        emit_block "$(printf '🛑 RELEASE BLOCKED — SENTINEL per-skill manifest is incomplete (docs/audits/sentinel-skills/manifest.json must show 85/85 clean rows).\n\nRun bash scripts/validate-sentinel-skills-manifest.sh for details, complete per-skill SENTINEL audits, record sentinel-skills-clean, then retry.' )"
        exit 0
      fi
    fi
  fi

  release_commit_sha=$(git -C "$project_root" rev-parse HEAD 2>/dev/null || true)
  if [[ -z "$release_commit_sha" ]]; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — Unable to determine the current HEAD commit for this release session.\n\nRe-run the release flow from a valid git checkout after CI finishes.' )"
    exit 0
  fi

  release_runs_json=""
  if ! release_runs_json=$(sb_github_run_list_json "$release_commit_sha"); then
    emit_block "$(printf '🛑 RELEASE BLOCKED — Unable to verify GitHub Actions status for commit %s.\n\nInstall the gh CLI or rerun the release after CI has finished and GitHub Actions status can be verified.' "$release_commit_sha")"
    exit 0
  fi

  if ! printf '%s' "$release_runs_json" | jq empty >/dev/null 2>&1; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — GitHub Actions status payload for commit %s is invalid.\n\nWait for CI to finish and retry the release.' "$release_commit_sha")"
    exit 0
  fi

  release_total_runs=$(printf '%s' "$release_runs_json" | jq -r --arg commit_sha "$release_commit_sha" '[.[] | select((.headSha // "") == $commit_sha)] | length')
  if [[ "${release_total_runs:-0}" -eq 0 ]]; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — No GitHub Actions runs were found for commit %s yet.\n\nWait for CI to start and finish successfully before creating the release.' "$release_commit_sha")"
    exit 0
  fi

  blocked_runs=$(printf '%s' "$release_runs_json" | jq -r --arg commit_sha "$release_commit_sha" '
    [ .[]
      | select((.headSha // "") == $commit_sha)
    ]
    | sort_by(.workflowName // .name // "unknown")
    | group_by(.workflowName // .name // "unknown")
    | map(max_by(.createdAt // ""))
    | map(select(
        ((.status // "") != "completed")
        or (((.conclusion // "") as $conclusion | (["success", "skipped", "neutral"] | index($conclusion)) == null))
      ))
    | .[]
    | [(.workflowName // .name // "unknown"), (.status // ""), (.conclusion // ""), (.createdAt // "")]
    | @tsv
  ')

  if [[ -n "$blocked_runs" ]]; then
    blocked_lines=""
    while IFS=$'\t' read -r wf status conclusion created_at; do
      [[ -z "$wf" ]] && continue
      line=$(printf '  • %s — status=%s conclusion=%s created=%s' "$wf" "$status" "$conclusion" "$created_at")
      if [[ -n "$blocked_lines" ]]; then
        blocked_lines+=$'\n'"$line"
      else
        blocked_lines="$line"
      fi
    done <<< "$blocked_runs"
    emit_block "$(printf '🛑 RELEASE BLOCKED — GitHub Actions for commit %s are still running or not green yet.\n\nWait until the latest run for each workflow on this commit is completed successfully before releasing.\n\nCurrent non-green run(s):\n%s\n\nThis release gate is intentionally conservative so we never cut a release in the middle of CI.' "$release_commit_sha" "$blocked_lines")"
    exit 0
  fi
fi

# Build required skills list (DEFAULT_* already populated by required-skills.sh at top).
DEFAULT_REQUIRED="${DEFAULT_REQUIRED:-${__SB_RS_FALLBACK:-silver-quality-gates silver-completion-audit verify-tests}}"
DEVOPS_DEFAULT_REQUIRED="${DEVOPS_DEFAULT_REQUIRED:-${__SB_RS_FALLBACK:-silver-quality-gates silver-completion-audit verify-tests}}"

# DevOps workflow substitutes silver-quality-gates with silver-blast-radius + devops-quality-gates
delivery_uses_devops_deploy=false
if [[ "$active_workflow" == "devops-cycle" ]]; then
  delivery_uses_devops_deploy=true
  DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
else
  project_root_for_composer="$(dirname "$config_file")"
  [[ -z "$project_root_for_composer" ]] && project_root_for_composer="$PWD"
  wf_dir_for_composer="$project_root_for_composer/.planning/workflows"
  composer_wf_id="${SB_WORKFLOW_ID:-}"
  if [[ -z "$composer_wf_id" ]]; then
    composer_wf_id="$(workflow_id_from_shell_assignment "$cmd" 2>/dev/null || true)"
  fi
  if [[ -n "$composer_wf_id" && -f "$wf_dir_for_composer/$composer_wf_id.md" ]]; then
    composer_slug_raw="$(awk -F': ' '/^composer: / { print $2; exit }' "$wf_dir_for_composer/$composer_wf_id.md" 2>/dev/null || true)"
    composer_slug_norm="$(printf '%s' "$composer_slug_raw" | tr '[:upper:]' '[:lower:]' | sed 's|[:/]| |g' | awk '{print $NF}')"
    if [[ "$composer_slug_norm" == "silver-devops" || "$composer_slug_norm" == "devops" ]]; then
      delivery_uses_devops_deploy=true
      DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
    fi
  fi
fi

if [[ "$delivery_uses_devops_deploy" == true ]]; then
  if [[ -n "$required_deploy_devops_cfg" ]]; then
    required_deploy_cfg="$required_deploy_devops_cfg"
  fi
fi

# When on main/master branch, branch finishing is not applicable
if [[ "$on_main" == true ]]; then
  # Remove from DEFAULT_REQUIRED and from any config-supplied required_deploy
  DEFAULT_REQUIRED=$(printf '%s' "$DEFAULT_REQUIRED" | tr ' ' '\n' | grep -vE '^(finishing-a-development-branch|silver-branch-finish)$' | tr '\n' ' ' | sed 's/ $//')
  required_deploy_cfg=$(printf '%s' "$required_deploy_cfg" | tr ' ' '\n' | grep -vE '^(finishing-a-development-branch|silver-branch-finish)$' | tr '\n' ' ' | sed 's/ $//')
fi

# Current-version config-supplied required_deploy remains the sole source of
# truth. Legacy configs are normalized so old projects inherit current gates
# and retired dependencies do not deadlock delivery.
if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  all_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$required_deploy_cfg" "$DEFAULT_REQUIRED")"
elif [[ -n "$required_deploy_cfg" ]]; then
  all_skills="$required_deploy_cfg"
else
  all_skills="$DEFAULT_REQUIRED"
fi

# Release commands also require release-only skills (e.g. silver-create-release).
if printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
  release_defaults="${DEFAULT_RELEASE_REQUIRED:-silver-create-release}"
  if [[ "$delivery_uses_devops_deploy" == true ]]; then
    release_defaults="${DEVOPS_DEFAULT_RELEASE_REQUIRED:-silver-create-release}"
  fi
  release_cfg=""
  if command -v jq >/dev/null 2>&1 && [[ -f "$config_file" ]]; then
    if [[ "$delivery_uses_devops_deploy" == true ]]; then
      release_cfg=$(jq -r '(.skills.required_release_devops // .skills.required_release // []) | join(" ")' "$config_file" 2>/dev/null || true)
    else
      release_cfg=$(jq -r '(.skills.required_release // []) | join(" ")' "$config_file" 2>/dev/null || true)
    fi
  fi
  if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
    release_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$release_cfg" "$release_defaults")"
  elif [[ -n "$release_cfg" ]]; then
    release_skills="$release_cfg"
  else
    release_skills="$release_defaults"
  fi
  all_skills="$all_skills $release_skills"
fi

# Deduplicate
required_skills=""
for skill in $all_skills; do
  already=false
  for existing in $required_skills; do
    if [[ "$existing" == "$skill" ]]; then
      already=true
      break
    fi
  done
  if [[ "$already" == false ]]; then
    required_skills="${required_skills:+$required_skills }$skill"
  fi
done

# ── Check required skills ─────────────────────────────────────────────────────
missing=""
ignored=""
for skill in $required_skills; do
  if ! has_skill "$skill"; then
    if sb_skill_is_installed "$skill"; then
      missing="${missing:+$missing }$skill"
    else
      ignored="${ignored:+$ignored }$skill"
    fi
  fi
done

# Pre-ship quality-gates must record adversarial mode when VERIFICATION.md passed.
if declare -f sb_qg_repo_requires_pre_ship_marker >/dev/null 2>&1 \
   && declare -f sb_qg_pre_ship_marker_recorded >/dev/null 2>&1; then
  project_root_qg="$(dirname "$config_file")"
  [[ -z "$project_root_qg" || "$project_root_qg" == "." ]] && project_root_qg="$PWD"
  if sb_qg_repo_requires_pre_ship_marker "$project_root_qg"; then
    if [[ "$delivery_uses_devops_deploy" == true ]] \
       && declare -f sb_dqg_pre_ship_marker_recorded >/dev/null 2>&1; then
      if ! sb_dqg_pre_ship_marker_recorded "$state_contents"; then
        if has_skill "devops-quality-gates"; then
          missing="${missing:+$missing }devops-quality-gates-adversarial"
        else
          missing="${missing:+$missing }devops-quality-gates"
        fi
      fi
    elif ! sb_qg_pre_ship_marker_recorded "$state_contents"; then
      if has_skill "silver-quality-gates"; then
        missing="${missing:+$missing }silver-quality-gates-adversarial"
      else
        missing="${missing:+$missing }silver-quality-gates"
      fi
    fi
  fi
fi

# ── Check code review ordering ───────────────────────────────────────────────
# Enforce: review-request frames the review, silver-review produces REVIEW.md,
# and review-triage handles findings after review output exists.
ordering_issues=""
if has_skill "silver-review-request" && has_skill "silver-review"; then
  req_line=$(skill_line "silver-review-request")
  cr_line=$(skill_line "silver-review")
  if [[ "$req_line" -gt 0 && "$cr_line" -gt 0 && "$cr_line" -lt "$req_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review was run BEFORE /silver-review-request (wrong order)\n"
  fi
fi
if has_skill "silver-review" && has_skill "silver-review-triage"; then
  cr_line=$(skill_line "silver-review")
  recv_line=$(skill_line "silver-review-triage")
  if [[ "$cr_line" -gt 0 && "$recv_line" -gt 0 && "$recv_line" -lt "$cr_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review-triage was run BEFORE /silver-review (wrong order)\n"
  fi
fi
if has_skill "silver-review-request" && has_skill "silver-review-triage"; then
  req_line=$(skill_line "silver-review-request")
  recv_line=$(skill_line "silver-review-triage")
  if [[ "$req_line" -gt 0 && "$recv_line" -gt 0 && "$recv_line" -lt "$req_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review-triage was run BEFORE /silver-review-request (wrong order)\n"
  fi
fi

# ── Artifact existence check (blocking for recorded lifecycle work) ───────────
# Verifies that key SB lifecycle phases produced expected output files.
# These checks prove the work was done, not just that the skill was invoked.
artifact_blocks=""
project_root=$(dirname "$config_file")

find_planning_artifact() {
  local pattern="$1"
  [[ -d "$project_root/.planning" ]] || return 1
  find "$project_root/.planning" -type f -name "$pattern" -print -quit 2>/dev/null | grep -q .
}

# silver-execute should produce .planning/STATE.md
if has_skill "silver-execute" && [[ ! -f "$project_root/.planning/STATE.md" ]]; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-execute was recorded but .planning/STATE.md is absent — was execution actually completed?\n"
fi

# silver-verify should produce UAT/verification artifacts.
if has_skill "silver-verify" && \
   [[ ! -f "$project_root/.planning/UAT.md" ]] && \
   ! find_planning_artifact '*-UAT.md' && \
   ! find_planning_artifact '*VERIFICATION.md' && \
   ! find_planning_artifact 'VERIFICATION.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-verify was recorded but no UAT/VERIFICATION artifact was found under .planning/ — was verification actually completed?\n"
fi

if has_skill "silver-review" && \
   [[ ! -f "$project_root/.planning/REVIEW.md" ]] && \
   ! find_planning_artifact '*-REVIEW.md' && \
   ! find_planning_artifact 'REVIEW.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-review was recorded but no REVIEW artifact was found under .planning/ — was code review actually completed?\n"
fi

if has_skill "silver-secure" && \
   ! find_planning_artifact '*-SECURITY.md' && \
   ! find_planning_artifact 'SECURITY.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-secure was recorded but no SECURITY artifact was found under .planning/ — was security verification actually completed?\n"
fi

if has_skill "silver-validate" && \
   ! find_planning_artifact '*-VALIDATION.md' && \
   ! find_planning_artifact 'VALIDATION.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-validate was recorded but no VALIDATION artifact was found under .planning/ — was validation actually completed?\n"
fi

# Fresh test execution marker: if verify-tests is required and has been recorded,
# the marker must still exist or the run is stale.
verify_tests_required=false
for skill in $required_skills; do
  if [[ "$skill" == "verify-tests" ]]; then
    verify_tests_required=true
    break
  fi
done
test_freshness_warning=""
if [[ "$verify_tests_required" == true ]] && has_skill "verify-tests" && [[ ! -f "$verify_tests_state_file" ]]; then
  test_freshness_warning=$(printf '🛑 TEST GATE STALE — /verify-tests was recorded earlier, but the freshness marker is missing at %s.\n\nSource changes invalidate the marker. Re-run /verify-tests before creating the PR, deploy, or release.' "$verify_tests_state_file")
fi

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  ❌ /${skill}\n"
  done
  ordering_note=""
  [[ -n "$ordering_issues" ]] && ordering_note=$(printf '\n⚠️  Ordering issues detected:\n%s' "$ordering_issues")
  msg=$(printf '🛑 COMPLETION BLOCKED — Workflow incomplete.\n\nYou are attempting to create a PR/deploy but these required steps are missing:\n%s%sComplete ALL required workflow steps before finalizing.\nDo NOT proceed with this action.' "$missing_lines" "$ordering_note")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$test_freshness_warning" ]]; then
  msg="$test_freshness_warning"
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$ordering_issues" ]]; then
  msg=$(printf '🛑 ORDERING BLOCKED — Code Review Triad ran out of order:\n%s\nRe-run /silver:review-request → /silver:review → /silver:review-triage before delivery.' "$ordering_issues")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$artifact_blocks" ]]; then
  msg=$(printf '🛑 ARTIFACT BLOCKED — SB lifecycle markers were recorded but expected output files are missing. This may indicate vacuous skill invocation or an incomplete workflow:\n\n%s\nComplete the owning SB workflow step and produce the artifact before final delivery.' "$artifact_blocks")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
else
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '✅ Workflow compliance verified. Proceed.\n\nIgnored required skills:\n%s' "$ignored_lines")
    if [[ -n "${EVIDENCE_SCHEMA_WARN:-}" ]]; then
      msg=$(printf '%s\n\n%s' "$msg" "$EVIDENCE_SCHEMA_WARN")
    fi
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  elif [[ -n "${EVIDENCE_SCHEMA_WARN:-}" ]]; then
    msg=$(printf '✅ Workflow compliance verified. Proceed.\n\n%s' "$EVIDENCE_SCHEMA_WARN")
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  else
    printf '{"hookSpecificOutput":{"message":"✅ Workflow compliance verified. Proceed."}}'
  fi
fi
