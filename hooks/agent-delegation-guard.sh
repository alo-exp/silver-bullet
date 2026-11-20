#!/usr/bin/env bash
# PreToolUse — active delegation guard: block Claude/Codex parent edits; advise Cursor parent.
set -euo pipefail
trap 'exit 0' ERR

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh agent-delegation-state.sh hook-audit.sh cert-bypass.sh tool-input.sh; do
  # shellcheck disable=SC1090
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done
# shellcheck source=hooks/agent-delegation-progress-surface.sh
[[ -f "$(dirname "${BASH_SOURCE[0]}")/agent-delegation-progress-surface.sh" ]] && \
  source "$(dirname "${BASH_SOURCE[0]}")/agent-delegation-progress-surface.sh"

_sb_adg_have_jq=false
command -v jq >/dev/null 2>&1 && _sb_adg_have_jq=true

sb_adg_hook_field() {
  local json="$1" field="$2" default="${3:-}"
  if [[ "$_sb_adg_have_jq" == true ]]; then
    printf '%s' "$json" | jq -r ".$field // \"$default\"" 2>/dev/null || printf '%s' "$default"
    return 0
  fi
  case "$field" in
    hook_event_name) grep -q '"hook_event_name"[[:space:]]*:[[:space:]]*"PreToolUse"' <<<"$json" && printf 'PreToolUse' || printf '%s' "$default" ;;
    tool_name) printf '%s' "$json" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/' || printf '%s' "$default" ;;
  esac
}

_workspace_config=""
if declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
  _workspace_config="$(sb_find_project_config_walk_only 2>/dev/null || true)"
fi
[[ -n "$_workspace_config" ]] || exit 0

sb_agent_delegation_v2_enabled || exit 0
sb_agent_delegation_is_active || exit 0

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi

hook_event="$(sb_adg_hook_field "$input" 'hook_event_name' 'PreToolUse')"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_adg_hook_field "$input" 'tool_name' '')"
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|exec_command|Shell) ;;
  *) exit 0 ;;
esac

# Without jq the guard cannot read the payload's paths: it stays inert (documented fail-open;
# session-start already warns that jq is missing).
[[ "$_sb_adg_have_jq" == true ]] || exit 0

repo_root="$(dirname "$_workspace_config")"

# Every path the call would write: tool_input.file_path/path, the files named inside an
# apply_patch body (Codex sends them only there), and for shell tools the paths the shared
# classifier finds (redirections, tee, sed -i, ...). Any one inside the delegated scope denies (R4-17).
target_paths=""
if declare -f sb_tool_input_load >/dev/null 2>&1; then
  sb_tool_input_load "$input" "$PWD"
  if [[ "$SB_TI_STATUS" == "ok" ]]; then
    target_paths="$(printf '%s\n%s\n%s' "$SB_TI_FILE_PATH" "$SB_TI_PATCH_PATHS" "$SB_SA_WRITE_PATHS")"
  fi
fi
target_paths="$(printf '%s\n%s' "$target_paths" "$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)")"

in_scope=false
# A write whose path is a directory holding an owned path (git reset --hard, git restore ., git apply, ...)
# touches the owned path whatever scope the classifier gave it. `git checkout|switch <branch|.>` has no
# modeled writes (it may be a path or a branch), so it counts as a write to the whole repository, or to
# the directory for a lone ".", unless it names paths after "--" (those are modeled) or only creates a branch.
if [[ "${SB_TI_STATUS:-}" == "ok" ]]; then
  while IFS= read -r tree_path; do
    [[ "$tree_path" == "REPO" ]] && tree_path="$repo_root"
    tree_path="$(sb_agent_delegation_normalize_path "$tree_path" "$repo_root" 2>/dev/null || printf '%s' "$tree_path")"
    tree_path="${tree_path%/}"
    while IFS= read -r owned; do
      if owned="$(sb_agent_delegation_normalize_path "$owned" "$repo_root" 2>/dev/null)" \
         && [[ "$owned" == "$tree_path" || "$owned" == "$tree_path"/* ]]; then
        in_scope=true
      fi
    done < <(jq -r '.ownership_scope[]? | select(. != "")' "$(sb_agent_delegation_state_file)" 2>/dev/null)
  done < <(printf '%s' "$SB_SA_JSON" | jq -r '
    (.writes[]? | select((.path // "") != "") | .path),
    (.commands[]? | select(.program == "git") | . as $c | .argv as $a
      | ([range(1; $a | length) as $k | select(($a[$k] | startswith("-") | not)
          and ($k == 1 or (["-C", "-c", "--git-dir", "--work-tree", "--namespace"] | index($a[$k - 1]) | not))) | $k][0]) as $i
      | select($i != null and ($a[$i] == "checkout" or $a[$i] == "switch"))
      | $a[$i + 1:] as $r
      | select(($r | index("--")) == null)
      | [$r[] | select(startswith("-") | not)] as $pos
      | ([$r[] | select(test("^-[A-Za-z]*[bBcC]$|^--(orphan|create|force-create)(=.*)?$"))] | length > 0) as $mk
      | select(($pos | length) > (if $mk then 1 else 0 end))
      | ([range(1; $a | length) as $k | select($a[$k - 1] == "-C") | $a[$k]] | last // "") as $dir
      | if all($pos[]; . == ".") then ($dir | if . == "" then $c.cwd elif startswith("/") then . else $c.cwd + "/" + . end) else "REPO" end)' 2>/dev/null)
fi
while IFS= read -r target_path; do
  [[ -n "$target_path" ]] || continue
  if sb_agent_delegation_path_in_scope "$target_path" "$repo_root"; then
    in_scope=true
    break
  fi
done <<<"$target_paths"
[[ "$in_scope" == true ]] || exit 0

tier="$(sb_agent_delegation_parent_host_tier)"
progress="$(sb_agent_delegation_progress_surface 2>/dev/null || true)"
reason="Active external-agent delegation — parent must supervise, not edit scoped ownership paths. See AF-AGENT-DELEGATE."

if [[ "$tier" == "block" ]]; then
  if command -v jq >/dev/null 2>&1; then
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
    if declare -f sb_hook_audit_record >/dev/null 2>&1; then
      sb_hook_audit_record "agent-delegation-guard" "PreToolUse" "deny" "$reason" ""
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    exit 0
  fi
  printf '%s\n' "$reason" >&2
  exit 2
fi

# Cursor: advise via additional_context
if command -v jq >/dev/null 2>&1; then
  ctx=$(printf '%s\n%s' "$reason" "$progress" | jq -Rs '.')
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "agent-delegation-guard" "PreToolUse" "advise" "$reason" ""
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":%s}}' "$ctx"
fi
exit 0
