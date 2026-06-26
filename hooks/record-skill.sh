#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse hook (matcher: Skill)
# Tracks skill invocations to a state file for workflow enforcement.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source symlink-write guard (SEC-02)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null)" || _repo_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_guard_nofollow() { [[ -L "$1" ]] && { printf 'ERROR: refusing to write through symlink: %s\n' "$1" >&2; exit 1; }; return 0; }
  sb_safe_write()    { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi
if [[ -n "$_lib_dir" && -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck source=lib/skill-discovery.sh
  source "$_lib_dir/skill-discovery.sh"
fi
if [[ -n "$_lib_dir" && -f "$_lib_dir/session-ledger.sh" ]]; then
  # shellcheck source=lib/session-ledger.sh
  source "$_lib_dir/session-ledger.sh"
fi
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  source "$_lib_dir/required-skills.sh"
fi
if [[ -f "$_lib_dir/quality-gates-mode.sh" ]]; then
  # shellcheck source=lib/quality-gates-mode.sh
  source "$_lib_dir/quality-gates-mode.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi
if [[ -f "$_lib_dir/hook-output.sh" ]]; then
  # shellcheck source=lib/hook-output.sh
  source "$_lib_dir/hook-output.sh"
fi

# jq is required for JSON parsing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "record-skill"
fi

# Read JSON from stdin
input=$(cat)

# Extract skill name from supported skill invocations. Bash commands that read
# `.../skills/<skill>/SKILL.md` are recorded as loaded-only metadata, not as
# completed workflow state; reading instructions is not proof that the workflow
# ran or produced its artifacts.
raw_skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
fi
if declare -f sb_tool_command_string >/dev/null 2>&1; then
  cmd="$(sb_tool_command_string "$input")"
else
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
fi

extract_invoke_skill_adapter_skill() {
  local command_str="$1"
  python3 - "$command_str" <<'PY' 2>/dev/null || true
import pathlib
import re
import shlex
import sys

command = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
shell_names = {"bash", "sh", "zsh"}


def parse(raw):
    try:
        return shlex.split(raw, posix=True)
    except Exception:
        return []


def skip_env_and_assignments(tokens):
    idx = 0
    if idx < len(tokens) and tokens[idx] == "env":
        idx += 1
    while idx < len(tokens) and assignment_re.match(tokens[idx]):
        idx += 1
    return idx


def inspect_tokens(tokens):
    idx = skip_env_and_assignments(tokens)
    if idx >= len(tokens):
        return None

    cmd = pathlib.Path(tokens[idx]).name
    args = tokens[idx + 1 :]

    if cmd in shell_names:
        for arg_index, arg in enumerate(args):
            if arg.startswith("-") and "c" in arg[1:] and arg_index + 1 < len(args):
                return inspect_tokens(parse(args[arg_index + 1]))
        script_index = 0
        while script_index < len(args) and args[script_index].startswith("-"):
            script_index += 1
        if script_index < len(args) and pathlib.Path(args[script_index]).name == "silver-bullet":
            script_args = args[script_index + 1 :]
            if len(script_args) >= 2 and script_args[0] == "invoke-skill":
                return script_args[1]
        return None

    if cmd == "silver-bullet" and len(args) >= 2 and args[0] == "invoke-skill":
        return args[1]
    return None


skill = inspect_tokens(parse(command))
if skill:
    print(skill)
PY
}

invoke_skill_adapter_receipt_is_valid() {
  local raw_skill="$1"
  local canonical_skill="$raw_skill"
  local receipt_dir cwd_real now max_age receipt

  if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    canonical_skill="$(sb_skill_canonical_name "$raw_skill")"
  fi

  cwd_real="$(python3 -c 'import pathlib; print(pathlib.Path.cwd().resolve())' 2>/dev/null || printf '%s' "$PWD")"
  now="$(date +%s)"
  max_age="${SILVER_BULLET_INVOKE_SKILL_RECEIPT_MAX_AGE_SECONDS:-300}"

  if ! declare -F sb_runtime_skill_receipt_dirs >/dev/null 2>&1; then
    sb_runtime_skill_receipt_dirs() {
      printf '%s\n' "${SB_RUNTIME_STATE_DIR}/skill-invocations"
    }
  fi

  while IFS= read -r receipt_dir; do
    [[ -d "$receipt_dir" && ! -L "$receipt_dir" ]] || continue
    shopt -s nullglob
    for receipt in "$receipt_dir"/*.json; do
      [[ -f "$receipt" && ! -L "$receipt" ]] || continue
      if jq -e \
        --arg channel "silver-bullet.invoke-skill" \
        --arg skill "$canonical_skill" \
        --arg cwd "$cwd_real" \
        --argjson now "$now" \
        --argjson max_age "$max_age" \
        '.channel == $channel
          and .status == "loaded"
          and .canonical_skill == $skill
          and .cwd == $cwd
          and ((.timestamp_epoch // 0) >= ($now - $max_age))
          and (.skill_file | type == "string")
          and (.script | type == "string")' \
        "$receipt" >/dev/null 2>&1; then
        shopt -u nullglob
        return 0
      fi
    done
    shopt -u nullglob
  done < <(sb_runtime_skill_receipt_dirs)

  return 1
}

skills_to_record=()
if [[ -n "$raw_skill" ]]; then
  skills_to_record+=("$raw_skill")
elif { [[ "$tool_name" == "Bash" ]] || { declare -f sb_tool_is_shell_like >/dev/null 2>&1 && sb_tool_is_shell_like "$tool_name"; }; }; then
  adapter_skill="$(extract_invoke_skill_adapter_skill "$cmd")"
  adapter_exit_code="$(printf '%s' "$input" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0' 2>/dev/null || printf '0')"
  if [[ -n "$adapter_skill" && "$adapter_exit_code" == "0" ]] && invoke_skill_adapter_receipt_is_valid "$adapter_skill"; then
    skills_to_record+=("$adapter_skill")
  elif [[ "$cmd" == *"SKILL.md"* ]]; then
    # Extract any SKILL.md paths embedded in the command string.
    while IFS= read -r token; do
      [[ -n "$token" ]] || continue
      token="${token#\"}"
      token="${token%\"}"
      token="${token#\'}"
      token="${token%\'}"
      token="${token#,}"
      token="${token%;}"
      token="${token#(}"
      token="${token%)}"
      [[ "$token" == *"SKILL.md"* ]] || continue

      # Prefer deriving the skill from the directory name so we can record the
      # canonical hyphenated marker (e.g. silver-init, silver-context).
      if [[ "$token" =~ /skills/([^/]+)/SKILL\.md$ ]]; then
        skills_to_record+=("loaded:${BASH_REMATCH[1]}")
      fi
    done < <(printf '%s' "$cmd" | grep -oE '[^[:space:]]+SKILL\.md' || true)
  fi
fi

[[ ${#skills_to_record[@]} -gt 0 ]] || exit 0

if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
  :
fi

debug_record_skill() {
  [[ "${SILVER_BULLET_DEBUG_RECORD_SKILL:-0}" == "1" ]] || return 0
  local dbg_dir="${SB_RUNTIME_STATE_DIR}"
  mkdir -p "$dbg_dir" 2>/dev/null || true
  local dbg_file="${dbg_dir}/record-skill.debug.log"
  {
    printf '--- %s ---\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
    printf 'pwd=%s\n' "$PWD"
    printf 'raw_skill=%s\n' "$raw_skill"
    printf 'canonical_skill=%s\n' "$skill"
    printf 'config_file=%s\n' "${config_file:-}"
  } >>"$dbg_file" 2>/dev/null || true
}

# --- Resolve config file by walking up from $PWD ---
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  # Stop at .git boundary or filesystem root
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

if [[ -n "$config_file" ]]; then
  if declare -f sb_project_active >/dev/null 2>&1; then
    sb_project_active "$config_file" || exit 0
  elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
    sb_project_is_initiated "$config_file" || exit 0
  fi
fi

# --- State file (env var override first, then config, then default) ---
SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
STATE_FILE="${SILVER_BULLET_STATE_FILE:-}"
if [[ -z "$STATE_FILE" && -n "$config_file" ]]; then
  STATE_FILE=$(jq -r '.state.state_file // ""' "$config_file")
  # Expand ~ to $HOME (config stores literal tilde)
  STATE_FILE="${STATE_FILE/#\~/$HOME}"
fi
STATE_FILE="${STATE_FILE:-${SB_STATE_DIR}/state}"

# Security: validate state file path stays within the host runtime state root (SB-002/SB-003)
if ! sb_runtime_path_is_state_scoped "$STATE_FILE"; then
  STATE_FILE="${SB_STATE_DIR}/state"
fi

# --- Tracked skills list ---
# SB lifecycle phases (tracked as current silver-* markers)
# Prefer the canonical tracked list from the packaged config template so
# bootstrap skills like silver:init are still recorded before a project-level
# .silver-bullet.json exists. Fall back to a small hardcoded list only if the
# template cannot be read for some reason.
DEFAULT_TRACKED=""
if [[ -n "${DEFAULT_ALL_TRACKED:-}" ]]; then
  DEFAULT_TRACKED="$DEFAULT_ALL_TRACKED"
elif [[ -n "${_repo_dir:-}" && -f "${_repo_dir}/templates/silver-bullet.config.json.default" ]]; then
  DEFAULT_TRACKED=$(jq -r '(.skills.all_tracked // []) | join(" ")' "${_repo_dir}/templates/silver-bullet.config.json.default" 2>/dev/null || true)
fi
if [[ -z "$DEFAULT_TRACKED" ]]; then
  DEFAULT_TRACKED="${__SB_RS_ALL_TRACKED_FALLBACK:-silver-quality-gates silver-quality-gates-design silver-quality-gates-adversarial verify-tests}"
fi

tracked_list="$DEFAULT_TRACKED"
if [[ -n "$config_file" ]]; then
  custom_tracked=$(jq -r '(.skills.all_tracked // []) | join(" ")' "$config_file")
  if [[ -n "$custom_tracked" ]]; then
    # Project configs may be partial, especially older scaffolds or live-test
    # workspaces generated by an agent. Treat custom tracked skills as additive
    # to the packaged defaults so core SB route markers remain recordable.
    tracked_list="$DEFAULT_TRACKED $custom_tracked"
  fi
fi

debug_record_skill

recorded_any=false
completed_skills_to_mark=()

for raw in "${skills_to_record[@]}"; do
  loaded_only=false
  if [[ "$raw" == loaded:* ]]; then
    loaded_only=true
    raw="${raw#loaded:}"
  fi

  skill="$raw"

  if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    skill="$(sb_skill_canonical_name "$skill")"
  else
    while printf '%s' "$skill" | grep -qE '^[a-zA-Z0-9_-]+:'; do
      skill=$(printf '%s' "$skill" | sed 's/^[a-zA-Z0-9_-]*://')
    done
  fi

  # Canonical TDD marker: required_deploy lists "tdd", not "silver-tdd".
  case "$skill" in
    silver-tdd|test-driven-development) skill="tdd" ;;
  esac

  # --- Check if skill is tracked ---
  is_tracked=false
  for t in $tracked_list; do
    if [[ "$t" == "$skill" ]]; then
      is_tracked=true
      break
    fi
  done

  if [[ "$is_tracked" == false ]]; then
    continue
  fi

  if [[ "$loaded_only" == true ]]; then
    loaded_file="${STATE_FILE}.loaded"
    mkdir -p "$(dirname "$loaded_file")" 2>/dev/null || true
    sb_guard_nofollow "$loaded_file"
    touch -- "$loaded_file"
    if ! grep -Fqx -- "$skill" "$loaded_file" 2>/dev/null; then
      printf '%s\n' "$skill" >> "$loaded_file"
    fi
    continue
  fi

  completed_skills_to_mark+=("$skill")

  # --- Record completed skill invocation (no duplicates) ---
  mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
  # SEC-02: refuse to write through a symlink at STATE_FILE
  sb_guard_nofollow "$STATE_FILE"
  touch -- "$STATE_FILE"
  if ! grep -Fqx -- "$skill" "$STATE_FILE" 2>/dev/null; then
    printf '%s\n' "$skill" >> "$STATE_FILE"
    recorded_any=true
  fi

  # Distinguishable pre-plan vs pre-ship quality-gates markers (fixes invocation theater).
  if [[ "$skill" == "silver-quality-gates" ]] && declare -f sb_qg_detect_mode >/dev/null 2>&1; then
    repo_root_for_qg=""
    if [[ -n "$config_file" ]]; then
      repo_root_for_qg="$(dirname "$config_file")"
    else
      repo_root_for_qg="$PWD"
    fi
    qg_mode="$(sb_qg_detect_mode "$repo_root_for_qg")"
    mode_marker="$(sb_qg_mode_marker "$qg_mode")"
    if ! grep -Fqx -- "$mode_marker" "$STATE_FILE" 2>/dev/null; then
      printf '%s\n' "$mode_marker" >> "$STATE_FILE"
      recorded_any=true
    fi
  fi
  if [[ "$skill" == "devops-quality-gates" ]] && declare -f sb_qg_detect_mode >/dev/null 2>&1; then
    repo_root_for_qg=""
    if [[ -n "$config_file" ]]; then
      repo_root_for_qg="$(dirname "$config_file")"
    else
      repo_root_for_qg="$PWD"
    fi
    qg_mode="$(sb_qg_detect_mode "$repo_root_for_qg")"
    mode_marker="$(sb_dqg_mode_marker "$qg_mode")"
    if ! grep -Fqx -- "$mode_marker" "$STATE_FILE" 2>/dev/null; then
      printf '%s\n' "$mode_marker" >> "$STATE_FILE"
      recorded_any=true
    fi
  fi
done

if [[ ${#completed_skills_to_mark[@]} -gt 0 ]] && declare -F sb_session_ledger_mark_completed >/dev/null 2>&1; then
  for skill in "${completed_skills_to_mark[@]}"; do
    sb_session_ledger_mark_completed "$skill" || true
  done
fi

if [[ "$recorded_any" == true ]]; then
  if [[ -f "$_lib_dir/orchestrator-directive.sh" ]]; then
    # shellcheck source=lib/orchestrator-directive.sh
    source "$_lib_dir/orchestrator-directive.sh"
    expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
    if [[ -n "$expected" ]]; then
      state_contents=""
      [[ -f "$STATE_FILE" ]] && state_contents="$(cat "$STATE_FILE" 2>/dev/null || true)"
      for skill in "${completed_skills_to_mark[@]}"; do
        if [[ "$skill" == "$expected" ]] || sb_orchestrator_directive_skill_recorded "$expected" "$state_contents"; then
          sb_orchestrator_directive_clear
          break
        fi
      done
    fi
  fi
  sb_emit_hook_message "PostToolUse" "✅ Skill recorded"
else
  # No tracked skills inferred from this hook invocation.
  sb_emit_hook_message "PostToolUse" "ℹ️ No completed tracked skill invocation found"
fi
