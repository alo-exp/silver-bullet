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
# touches the owned path whatever scope the classifier gave it. Git forms that can rewrite the work tree
# but have no modeled writes count as a write to the whole repository (to the directory for a lone "."):
# checkout/switch of a branch, ".", "-" or with -f/-m/--discard-changes/--pathspec-from-file (not when
# every path follows "--", those are modeled, nor when it only creates a branch), restore
# --pathspec-from-file, read-tree -u/--reset, checkout-index, sparse-checkout (not list), submodule
# update, and anything that sets an alias (-c alias.x=, git config alias.x: an alias can expand to any
# command). `worktree add` counts as a write to its target path. Residual: an alias already present in a
# git config file is not expanded.
if [[ "${SB_TI_STATUS:-}" == "ok" ]]; then
  while IFS= read -r tree_path; do
    [[ "$tree_path" == "REPO" ]] && tree_path="$repo_root"
    # A path that cannot be resolved (symlink loop) is treated as in scope, like sb_agent_delegation_path_in_scope.
    tree_path="$(sb_agent_delegation_normalize_path "$tree_path" "$repo_root" 2>/dev/null)" || { in_scope=true; continue; }
    tree_path="${tree_path%/}"
    if sb_agent_delegation_path_in_scope "$tree_path" "$repo_root"; then
      in_scope=true
    fi
    while IFS= read -r owned; do
      if owned="$(sb_agent_delegation_normalize_path "$owned" "$repo_root" 2>/dev/null)" \
         && [[ "$owned" == "$tree_path" || "$owned" == "$tree_path"/* ]]; then
        in_scope=true
      fi
    done < <(jq -r '.ownership_scope[]? | select(. != "")' "$(sb_agent_delegation_state_file)" 2>/dev/null)
  done < <(printf '%s' "$SB_SA_JSON" | jq -r '
    def under($c): if startswith("/") then . else $c + "/" + . end;
    (.writes[]? | select((.path // "") != "") | .path),
    (.commands[]? | select(.program == "git") | . as $c | .argv as $a
      | ([range(1; $a | length) as $k | select(($a[$k] | startswith("-") | not)
          and ($k == 1 or (["-C", "-c", "--git-dir", "--work-tree", "--namespace"] | index($a[$k - 1]) | not))) | $k][0]) as $i
      | select($i != null)
      | $a[$i] as $sub | $a[$i + 1:] as $r
      | [$r[] | select(startswith("-") | not)] as $pos
      | [$r[] | select(startswith("-"))] as $flags
      | ([range(1; $a | length) as $k | select($a[$k - 1] == "-C") | $a[$k]] | last // "") as $dir
      | ([$flags[] | select(test("^--force$|^--merge$|^--discard-changes$|^-[A-Za-z]*[fm][A-Za-z]*$"))] | length > 0) as $force
      | ([$flags[] | select(test("^-[A-Za-z]*[bBcC]$|^--(orphan|create|force-create)(=.*)?$"))] | length > 0) as $mk
      | ([$flags[] | select(startswith("--pathspec-from-file"))] | length > 0) as $pff
      | any($a[1:$i][]; test("^-?c?alias\\.")) as $aliasc
      | if $aliasc then "REPO"
        elif $sub == "config" then (if any($pos[]; startswith("alias.")) and (any($flags[]; test("^--get|^--list$|^-l$")) | not) then "REPO" else empty end)
        elif ($sub == "checkout" or $sub == "switch") then
          (if $pff then "REPO"
           elif ($r | index("--")) != null then empty
           elif ($pos | length) > (if $mk then 1 else 0 end) or $force or ($r | index("-")) != null then
             (if ($pos | length) > 0 and all($pos[]; . == ".") and ($force | not) and (($r | index("-")) == null)
              then ($dir | if . == "" then $c.cwd else under($c.cwd) end) else "REPO" end)
           else empty end)
        elif $sub == "restore" then (if $pff then "REPO" else empty end)
        elif $sub == "read-tree" then (if any($flags[]; test("^-[A-Za-z]*u[A-Za-z]*$") or . == "--reset") then "REPO" else empty end)
        elif $sub == "checkout-index" then "REPO"
        elif $sub == "sparse-checkout" then (if ($pos[0] // "") != "list" then "REPO" else empty end)
        elif $sub == "submodule" then (if ($pos[0] // "") == "update" then "REPO" else empty end)
        elif $sub == "worktree" and ($pos[0] // "") == "add" then ($pos[1:][] | under($c.cwd))
        else empty end)' 2>/dev/null)
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
