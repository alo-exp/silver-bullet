#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

_bridge_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _bridge_lib=""
if [[ -f "${_bridge_lib}/rtk-compat.sh" ]]; then
  # shellcheck source=lib/rtk-compat.sh
  source "${_bridge_lib}/rtk-compat.sh"
fi
export SILVER_BULLET_HOOK_EXEC=1

cursor_event="${1:-}"
shift || true

if [[ -z "$cursor_event" || "$#" -eq 0 ]]; then
  exit 2
fi

# region agent log
# Temporary ff97da instrumentation: snapshot discovery state without changing hook output.
if [[ "$cursor_event" == "sessionStart" || "$cursor_event" == "beforeSubmitPrompt" ]]; then
  _debug_log="/Users/shafqat/projects/silver-bullet/repo/.cursor/debug-ff97da.log"
  _debug_lines=0
  [[ -f "$_debug_log" ]] && _debug_lines="$(wc -l <"$_debug_log" 2>/dev/null || printf '0')"
  if [[ "$_debug_lines" -lt 10 ]]; then
    _debug_local="$HOME/.cursor/plugins/local/silver-bullet"
    _debug_local_type="missing"
    [[ -L "$_debug_local" ]] && _debug_local_type="symlink"
    [[ -d "$_debug_local" ]] && _debug_local_type="directory"
    _debug_local_realpath="$(cd "$_debug_local" 2>/dev/null && pwd -P || true)"
    _debug_manifest="$_debug_local/.cursor-plugin/plugin.json"
    _debug_manifest_present=0
    [[ -f "$_debug_manifest" ]] && _debug_manifest_present=1
    _debug_manifest_version="$(jq -r '.version // empty' "$_debug_manifest" 2>/dev/null || true)"
    _debug_manifest_commands="$(jq -c '.commands // null' "$_debug_manifest" 2>/dev/null || printf 'null')"
    _debug_manifest_commands_dir="$_debug_local/commands"
    _debug_root_commands_dir="$_debug_local/commands"
    _debug_count_files() {
      local dir="$1" count=0 file
      for file in "$dir"/*; do
        [[ -f "$file" ]] || continue
        count=$((count + 1))
      done
      printf '%s' "$count"
    }
    _debug_representative_files() {
      local dir="$1" file count=0
      for file in "$dir"/*; do
        [[ -f "$file" ]] || continue
        printf '%s\n' "$(basename "$file")"
        count=$((count + 1))
        [[ "$count" -ge 5 ]] && break
      done | jq -Rsc 'split("\n") | map(select(length > 0))'
    }
    _debug_command_filename_colon_count() {
      local dir="$1" count=0 file
      for file in "$dir"/*.md; do
        [[ -f "$file" ]] || continue
        case "$(basename "$file")" in
          *:*) count=$((count + 1)) ;;
        esac
      done
      printf '%s' "$count"
    }
    _debug_manifest_commands_count="$(_debug_count_files "$_debug_manifest_commands_dir")"
    _debug_manifest_commands_representative="$(_debug_representative_files "$_debug_manifest_commands_dir")"
    _debug_root_commands_count="$(_debug_count_files "$_debug_root_commands_dir")"
    _debug_root_commands_representative="$(_debug_representative_files "$_debug_root_commands_dir")"
    _debug_local_command_filename_colon_count="$(_debug_command_filename_colon_count "$_debug_root_commands_dir")"
    _debug_registry="$HOME/.cursor/plugins/installed_plugins.json"
    _debug_registry_keys="$(jq -c '.plugins["silver-bullet@alo-labs"][0] // {} | keys' "$_debug_registry" 2>/dev/null || printf '[]')"
    _debug_registry_version="$(jq -r '.plugins["silver-bullet@alo-labs"][0].version // empty' "$_debug_registry" 2>/dev/null || true)"
    _debug_registry_enabled="$(jq -c '.plugins["silver-bullet@alo-labs"][0].enabled // null' "$_debug_registry" 2>/dev/null || printf 'null')"
    _debug_registry_install_path="$(jq -r '.plugins["silver-bullet@alo-labs"][0].installPath // empty' "$_debug_registry" 2>/dev/null || true)"
    _debug_registry_git_path="$(jq -r '.plugins["silver-bullet@alo-labs"][0].gitPath // empty' "$_debug_registry" 2>/dev/null || true)"
    _debug_cache_root="$HOME/.cursor/plugins/cache/alo-labs/silver-bullet"
    _debug_cache_path="${_debug_cache_root}/${_debug_registry_version}"
    _debug_cache_present=0
    [[ -d "$_debug_cache_path" ]] && _debug_cache_present=1
    _debug_cache_actual_version="$(cd "$_debug_registry_install_path" 2>/dev/null && basename "$(pwd -P)" || true)"
    _debug_cache_command_filename_colon_count="$(_debug_command_filename_colon_count "$_debug_registry_install_path/commands")"
    _debug_marketplace_enablement_record_exists=0
    if jq -e '.plugins["silver-bullet@alo-labs"][0].enabled == true' "$_debug_registry" >/dev/null 2>&1; then
      _debug_marketplace_enablement_record_exists=1
    fi
    _debug_marketplace_path="$_debug_registry_git_path/.cursor-plugin/marketplace.json"
    [[ -f "$_debug_marketplace_path" ]] || _debug_marketplace_path="/Users/shafqat/projects/silver-bullet/repo/.cursor-plugin/marketplace.json"
    _debug_marketplace_version="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version // empty' "$_debug_marketplace_path" 2>/dev/null || true)"
    _debug_marketplace_sha="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .source.sha // empty' "$_debug_marketplace_path" 2>/dev/null || true)"
    _debug_marketplace_manifest_version="$(jq -r '.metadata.version // empty' "$_debug_marketplace_path" 2>/dev/null || true)"
    _debug_latest_plugin_log=""
    for _debug_candidate in "$HOME/Library/Application Support/Cursor/logs"/*/*/exthost/anysphere.cursor-agent-exec/"Cursor Plugins"*.log; do
      [[ -f "$_debug_candidate" ]] || continue
      [[ -z "$_debug_latest_plugin_log" || "$_debug_candidate" -nt "$_debug_latest_plugin_log" ]] && _debug_latest_plugin_log="$_debug_candidate"
    done
    _debug_latest_plugin_log_mtime="$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$_debug_latest_plugin_log" 2>/dev/null || true)"
    _debug_plugin_log_silver_matches=0
    _debug_plugin_log_command_matches=0
    _debug_plugin_log_local_loader_matches=0
    _debug_plugin_log_enabled_matches=0
    if [[ -n "$_debug_latest_plugin_log" && -f "$_debug_latest_plugin_log" ]]; then
      _debug_plugin_log_silver_matches="$(rg -i -c 'silver-bullet|silver bullet' "$_debug_latest_plugin_log" 2>/dev/null || printf '0')"
      _debug_plugin_log_command_matches="$(rg -i -c 'command|slash|chat' "$_debug_latest_plugin_log" 2>/dev/null || printf '0')"
      _debug_plugin_log_local_loader_matches="$(rg -i -c 'loadUserLocalPlugin|local plugin' "$_debug_latest_plugin_log" 2>/dev/null || printf '0')"
      _debug_plugin_log_enabled_matches="$(rg -i -c 'listEnabledPlugins|enabled plugin' "$_debug_latest_plugin_log" 2>/dev/null || printf '0')"
    fi
    _debug_append_snapshot() {
      local hypothesis="$1" message="$2" data="$3"
      jq -nc \
        --arg sessionId "ff97da" \
        --arg runId "repro" \
        --arg hypothesisId "$hypothesis" \
        --arg location "${BASH_SOURCE[0]}:debug-plugin-discovery" \
        --arg message "$message" \
        --argjson data "$data" \
        '{sessionId:$sessionId,runId:$runId,hypothesisId:$hypothesisId,location:$location,message:$message,data:$data,timestamp:(now|todateiso8601)}' >>"$_debug_log"
    }
    _debug_append_snapshot A "Cache and local command surfaces" "$(jq -nc \
      --arg localType "$_debug_local_type" \
      --arg localRealpath "$_debug_local_realpath" \
      --arg registryInstallPath "$_debug_registry_install_path" \
      --arg cacheActualVersion "$_debug_cache_actual_version" \
      --argjson cachePresent "$_debug_cache_present" \
      --argjson localCommandCount "$_debug_root_commands_count" \
      --argjson localColonCount "$_debug_local_command_filename_colon_count" \
      --argjson cacheColonCount "$_debug_cache_command_filename_colon_count" \
      '{localType:$localType,localRealpath:$localRealpath,registryInstallPath:$registryInstallPath,cacheActualVersion:$cacheActualVersion,cachePresent:$cachePresent,localCommandCount:$localCommandCount,localColonCount:$localColonCount,cacheColonCount:$cacheColonCount}')"
    _debug_append_snapshot B "Plugin manifest command registration contract" "$(jq -nc \
      --arg manifestPath "$_debug_manifest" \
      --arg manifestVersion "$_debug_manifest_version" \
      --argjson manifestPresent "$_debug_manifest_present" \
      --argjson manifestCommands "$_debug_manifest_commands" \
      --arg manifestCommandsDir "$_debug_manifest_commands_dir" \
      --argjson manifestCommandsCount "$_debug_manifest_commands_count" \
      '{manifestPath:$manifestPath,manifestVersion:$manifestVersion,manifestPresent:$manifestPresent,commands:$manifestCommands,commandsDir:$manifestCommandsDir,commandsCount:$manifestCommandsCount}')"
    _debug_append_snapshot C "Persisted plugin enablement and source identity" "$(jq -nc \
      --arg registryVersion "$_debug_registry_version" \
      --argjson registryEnabled "$_debug_registry_enabled" \
      --arg registryGitPath "$_debug_registry_git_path" \
      --argjson marketplaceEnablementRecordExists "$_debug_marketplace_enablement_record_exists" \
      --arg marketplaceVersion "$_debug_marketplace_version" \
      --arg marketplaceSha "$_debug_marketplace_sha" \
      '{registryVersion:$registryVersion,registryEnabled:$registryEnabled,registryGitPath:$registryGitPath,marketplaceEnablementRecordExists:$marketplaceEnablementRecordExists,marketplaceVersion:$marketplaceVersion,marketplaceSha:$marketplaceSha}')"
    _debug_append_snapshot D "Cursor plugin host log evidence" "$(jq -nc \
      --arg latestPluginLogPath "$_debug_latest_plugin_log" \
      --arg latestPluginLogMtime "$_debug_latest_plugin_log_mtime" \
      --argjson silverMatches "$_debug_plugin_log_silver_matches" \
      --argjson commandMatches "$_debug_plugin_log_command_matches" \
      --argjson localLoaderMatches "$_debug_plugin_log_local_loader_matches" \
      --argjson enabledMatches "$_debug_plugin_log_enabled_matches" \
      '{latestPluginLogPath:$latestPluginLogPath,latestPluginLogMtime:$latestPluginLogMtime,silverMatches:$silverMatches,commandMatches:$commandMatches,localLoaderMatches:$localLoaderMatches,enabledMatches:$enabledMatches}')"
    _debug_append_snapshot E "Hook lifecycle event reached" "$(jq -nc \
      --arg event "$cursor_event" \
      --argjson argvCount "$#" \
      '{event:$event,argvCount:$argvCount}')"
    for _debug_hypothesis in A B C D E; do
      _debug_record="$(jq -nc \
        --arg sessionId "ff97da" \
        --arg runId "pre-fix" \
        --arg hypothesisId "$_debug_hypothesis" \
        --arg location "${BASH_SOURCE[0]}:debug-plugin-discovery" \
        --arg message "Cursor plugin discovery snapshot" \
        --arg event "$cursor_event" \
        --arg localPath "$_debug_local" \
        --arg localType "$_debug_local_type" \
        --arg localRealpath "$_debug_local_realpath" \
        --arg manifestPath "$_debug_manifest" \
        --arg manifestVersion "$_debug_manifest_version" \
        --argjson manifestCommands "$_debug_manifest_commands" \
        --argjson manifestPresent "$_debug_manifest_present" \
        --arg manifestCommandsDir "$_debug_manifest_commands_dir" \
        --argjson manifestCommandsCount "$_debug_manifest_commands_count" \
        --argjson manifestCommandsRepresentative "$_debug_manifest_commands_representative" \
        --arg rootCommandsDir "$_debug_root_commands_dir" \
        --argjson rootCommandsCount "$_debug_root_commands_count" \
        --argjson rootCommandsRepresentative "$_debug_root_commands_representative" \
        --arg registryPath "$_debug_registry" \
        --argjson registryEntryKeys "$_debug_registry_keys" \
        --arg registryVersion "$_debug_registry_version" \
        --argjson registryEnabled "$_debug_registry_enabled" \
        --arg registryInstallPath "$_debug_registry_install_path" \
        --arg registryGitPath "$_debug_registry_git_path" \
        --arg cacheRoot "$_debug_cache_root" \
        --arg cacheActualVersion "$_debug_cache_actual_version" \
        --argjson cachePresent "$_debug_cache_present" \
        --argjson localCommandFilenameColonCount "$_debug_local_command_filename_colon_count" \
        --argjson cacheCommandFilenameColonCount "$_debug_cache_command_filename_colon_count" \
        --argjson marketplaceEnablementRecordExists "$_debug_marketplace_enablement_record_exists" \
        --arg marketplacePath "$_debug_marketplace_path" \
        --arg marketplaceVersion "$_debug_marketplace_version" \
        --arg marketplaceSha "$_debug_marketplace_sha" \
        --arg marketplaceManifestVersion "$_debug_marketplace_manifest_version" \
        --arg latestPluginLogPath "$_debug_latest_plugin_log" \
        --arg latestPluginLogMtime "$_debug_latest_plugin_log_mtime" \
        '{sessionId:$sessionId,runId:$runId,hypothesisId:$hypothesisId,location:$location,message:$message,fixAttempt:true,data:{event:$event,localPlugin:{path:$localPath,type:$localType,realpath:$localRealpath},manifest:{present:$manifestPresent,path:$manifestPath,version:$manifestVersion,commands:$manifestCommands,commandsDir:$manifestCommandsDir,commandsCount:$manifestCommandsCount,representative:$manifestCommandsRepresentative},rootCommands:{dir:$rootCommandsDir,count:$rootCommandsCount,representative:$rootCommandsRepresentative},registry:{path:$registryPath,entryKeys:$registryEntryKeys,version:$registryVersion,enabled:$registryEnabled,installPath:$registryInstallPath,gitPath:$registryGitPath},cache:{root:$cacheRoot,present:$cachePresent,actualVersion:$cacheActualVersion,commandFilenameColonCount:$cacheCommandFilenameColonCount},commandFilenameColonCount:$localCommandFilenameColonCount,marketplaceEnablementRecordExists:$marketplaceEnablementRecordExists,marketplace:{path:$marketplacePath,manifestVersion:$marketplaceManifestVersion,pluginVersion:$marketplaceVersion,sha:$marketplaceSha},latestCursorPluginLog:{path:$latestPluginLogPath,mtime:$latestPluginLogMtime}},timestamp:(now|todateiso8601)}')"
      printf '%s\n' "$_debug_record" >>"$_debug_log"
    done
  fi
fi
# endregion

input_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-in.XXXXXX")"
stdout_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-out.XXXXXX")"
stderr_file="$(mktemp "${TMPDIR:-/tmp}/sb-cursor-err.XXXXXX")"

cleanup() {
  rm -f -- "$input_file" "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

cat >"$input_file"

python3 - "$cursor_event" "$input_file" <<'PY' >"${input_file}.sb"
import json
import shlex
import sys
from pathlib import Path

cursor_event = sys.argv[1]
raw = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8") or "{}")

EVENT_MAP = {
    "sessionStart": "SessionStart",
    "preToolUse": "PreToolUse",
    "postToolUse": "PostToolUse",
    "postToolUseFailure": "PostToolUse",
    "stop": "Stop",
    "subagentStart": "SubagentStart",
    "subagentStop": "SubagentStop",
    "beforeSubmitPrompt": "UserPromptSubmit",
    "beforeShellExecution": "PreToolUse",
    "afterShellExecution": "PostToolUse",
}

TOOL_MAP = {
    "Shell": "Bash",
    "shell": "Bash",
    "exec_command": "Bash",
}

sb_event = EVENT_MAP.get(cursor_event, cursor_event)
out = {"hook_event_name": sb_event}

if cursor_event == "beforeSubmitPrompt":
    out["prompt"] = raw.get("prompt") or raw.get("user_message") or raw.get("text") or ""
elif cursor_event in {"beforeShellExecution", "afterShellExecution"}:
    command = raw.get("command") or raw.get("cmd") or ""
    if isinstance(command, list):
        command = " ".join(shlex.quote(str(part)) for part in command)
    out["tool_name"] = "Bash"
    out["tool_input"] = {"command": command}
    if cursor_event == "afterShellExecution":
        out["tool_response"] = {
            "exit_code": raw.get("exit_code", raw.get("exitCode", 0)),
            "stdout": raw.get("stdout", ""),
            "stderr": raw.get("stderr", ""),
        }
elif cursor_event == "sessionStart":
    out["source"] = raw.get("source") or raw.get("sessionSource") or "startup"
elif cursor_event == "subagentStart":
    out["subagent_type"] = raw.get("subagent_type") or raw.get("subagentType") or ""
    out["prompt"] = raw.get("prompt") or raw.get("user_message") or raw.get("text") or ""
else:
    tool_name = raw.get("tool_name") or raw.get("toolName") or raw.get("tool") or ""
    out["tool_name"] = TOOL_MAP.get(tool_name, tool_name)
    tool_input = raw.get("tool_input") or raw.get("toolInput") or raw.get("input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}
    out["tool_input"] = tool_input
    tool_response = raw.get("tool_response") or raw.get("toolResponse") or raw.get("response")
    if isinstance(tool_response, dict):
        out["tool_response"] = tool_response

Path(sys.argv[2] + ".sb").write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
PY

rc=0
if ! "$@" <"${input_file}.sb" >"$stdout_file" 2>"$stderr_file"; then
  rc=$?
fi
rm -f -- "${input_file}.sb"

python3 - "$cursor_event" "$stdout_file" <<'PY'
import json
import sys
from pathlib import Path

cursor_event = sys.argv[1]
text = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")
trimmed = text.strip()
if not trimmed or trimmed[0] not in "{[":
    sys.stdout.write(text)
    raise SystemExit(0)
try:
    payload = json.loads(text)
except Exception:
    sys.stdout.write(text)
    raise SystemExit(0)
if not isinstance(payload, dict):
    sys.stdout.write(text)
    raise SystemExit(0)

out = {}
if payload.get("decision") == "block":
    reason = payload.get("reason") or "Silver Bullet blocked completion."
    if cursor_event in {"stop", "subagentStop"}:
        out["followup_message"] = reason if isinstance(reason, str) else str(reason)
    else:
        out["permission"] = "deny"
        out["agent_message"] = reason if isinstance(reason, str) else str(reason)
        out["user_message"] = out["agent_message"]
    sys.stdout.write(json.dumps(out, separators=(",", ":")))
    raise SystemExit(0)

hook_specific = payload.get("hookSpecificOutput")
if isinstance(hook_specific, dict):
    message = hook_specific.get("message")
    additional = hook_specific.get("additionalContext")
    decision = hook_specific.get("permissionDecision")
    reason = hook_specific.get("permissionDecisionReason")
    if decision == "deny":
        out["permission"] = "deny"
        if reason is not None:
            text_reason = reason if isinstance(reason, str) else json.dumps(reason, separators=(",", ":"))
            out["agent_message"] = text_reason
            out["user_message"] = text_reason
    if additional is not None and cursor_event in {"postToolUse", "sessionStart", "beforeSubmitPrompt", "subagentStart"}:
        out["additional_context"] = additional if isinstance(additional, str) else str(additional)
    elif message is not None:
        if cursor_event in {"postToolUse", "sessionStart", "beforeSubmitPrompt", "subagentStart"}:
            out["additional_context"] = message if isinstance(message, str) else str(message)
        elif cursor_event in {"stop", "subagentStop"}:
            out["followup_message"] = message if isinstance(message, str) else str(message)
        elif cursor_event in {"beforeShellExecution", "preToolUse", "beforeMCPExecution"}:
            out["agent_message"] = message if isinstance(message, str) else str(message)

if out:
    sys.stdout.write(json.dumps(out, separators=(",", ":")))
else:
    sys.stdout.write(text)
PY

cat "$stderr_file" >&2
exit "$rc"
