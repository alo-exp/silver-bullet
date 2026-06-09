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

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
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
  local receipt_dir="${SB_RUNTIME_STATE_DIR}/skill-invocations"
  local cwd_real now max_age receipt

  if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    canonical_skill="$(sb_skill_canonical_name "$raw_skill")"
  fi

  [[ -d "$receipt_dir" && ! -L "$receipt_dir" ]] || return 1
  cwd_real="$(python3 -c 'import pathlib; print(pathlib.Path.cwd().resolve())' 2>/dev/null || printf '%s' "$PWD")"
  now="$(date +%s)"
  max_age="${SILVER_BULLET_INVOKE_SKILL_RECEIPT_MAX_AGE_SECONDS:-300}"

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
      # canonical hyphenated marker (e.g. silver-init, gsd-discuss-phase).
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
# GSD command phases (tracked as gsd-* markers for compliance visibility)
# Prefer the canonical tracked list from the packaged config template so
# bootstrap skills like silver:init are still recorded before a project-level
# .silver-bullet.json exists. Fall back to a small hardcoded list only if the
# template cannot be read for some reason.
DEFAULT_TRACKED=""
if [[ -n "${_repo_dir:-}" && -f "${_repo_dir}/templates/silver-bullet.config.json.default" ]]; then
  DEFAULT_TRACKED=$(jq -r '(.skills.all_tracked // []) | join(" ")' "${_repo_dir}/templates/silver-bullet.config.json.default" 2>/dev/null || true)
fi
if [[ -z "$DEFAULT_TRACKED" ]]; then
  DEFAULT_TRACKED="silver-quality-gates silver-blast-radius devops-quality-gates devops-skill-router design-system ux-copy architecture system-design gsd-code-review code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release silver-ensure-docs silver-forensics silver-init silver-add silver-remove silver-rem silver-scan gsd-scan verify-tests verification-before-completion test-driven-development tech-debt accessibility-review incident-response modularity reusability scalability security reliability usability testability extensibility gsd-new-project gsd-new-milestone gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work gsd-ship gsd-debug gsd-ui-phase gsd-ui-review gsd-secure-phase"
fi

tracked_list="$DEFAULT_TRACKED"
if [[ -n "$config_file" ]]; then
  custom_tracked=$(jq -r '(.skills.all_tracked // []) | join(" ")' "$config_file")
  if [[ -n "$custom_tracked" ]]; then
    # Project configs may be partial, especially older scaffolds or live-test
    # workspaces generated by an agent. Treat custom tracked skills as additive
    # to the packaged defaults so core SB/GSD route markers remain recordable.
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
    # Fallback for older layouts: GSD keeps a gsd- prefix, other namespaces strip.
    if printf '%s' "$skill" | grep -qE '^gsd:'; then
      skill=$(printf '%s' "$skill" | sed 's/^gsd:/gsd-/')
    else
      while printf '%s' "$skill" | grep -qE '^[a-zA-Z0-9_-]+:'; do
        skill=$(printf '%s' "$skill" | sed 's/^[a-zA-Z0-9_-]*://')
      done
    fi
  fi

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
    if ! grep -qx "$skill" "$loaded_file" 2>/dev/null; then
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
  if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
    printf '%s\n' "$skill" >> "$STATE_FILE"
    recorded_any=true
  fi
done

if [[ ${#completed_skills_to_mark[@]} -gt 0 ]] && declare -F sb_session_ledger_mark_completed >/dev/null 2>&1; then
  for skill in "${completed_skills_to_mark[@]}"; do
    sb_session_ledger_mark_completed "$skill" || true
  done
fi

if [[ "$recorded_any" == true ]]; then
  printf '{"hookSpecificOutput":{"message":"✅ Skill recorded"}}'
else
  # No tracked skills inferred from this hook invocation.
  printf '{"hookSpecificOutput":{"message":"ℹ️ No completed tracked skill invocation found"}}'
fi
