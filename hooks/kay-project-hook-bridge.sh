#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"
LIB_DIR="${PLUGIN_ROOT}/hooks/lib"

bridge_home_root="${HOME:-}"
if [[ -z "$bridge_home_root" && -n "${KAY_HOME:-}" ]]; then
  case "$KAY_HOME" in
    */.kay) bridge_home_root="${KAY_HOME%/.kay}" ;;
    *) bridge_home_root="$KAY_HOME" ;;
  esac
fi
if [[ -z "$bridge_home_root" && "$PLUGIN_ROOT" == *"/.codex/"* ]]; then
  bridge_home_root="${PLUGIN_ROOT%%/.codex/*}"
fi
if [[ -n "$bridge_home_root" && -z "${HOME:-}" ]]; then
  export HOME="$bridge_home_root"
fi
BRIDGE_ROOT="${bridge_home_root}/.kay/.silver-bullet/kay-hook-bridge"
PATH_PREPEND_ROOT="${bridge_home_root}/.kay/.silver-bullet/path-prepend"
ACTIVE_PATH_PREPEND_DIR="${PATH_PREPEND_ROOT}/active"

if [[ -n "${PATH:-}" ]]; then
  _sb_bridge_clean_path=""
  IFS=':' read -r -a _sb_bridge_path_parts <<<"$PATH"
  for _sb_bridge_path_part in "${_sb_bridge_path_parts[@]}"; do
    [[ "$_sb_bridge_path_part" == "$ACTIVE_PATH_PREPEND_DIR" ]] && continue
    if [[ -z "$_sb_bridge_clean_path" ]]; then
      _sb_bridge_clean_path="$_sb_bridge_path_part"
    else
      _sb_bridge_clean_path="${_sb_bridge_clean_path}:$_sb_bridge_path_part"
    fi
  done
  PATH="$_sb_bridge_clean_path"
  export PATH
  unset _sb_bridge_clean_path _sb_bridge_path_parts _sb_bridge_path_part
fi

if [[ -f "${LIB_DIR}/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "${LIB_DIR}/runtime-paths.sh"
fi
if [[ -f "${LIB_DIR}/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "${LIB_DIR}/hook-audit.sh"
fi
if [[ -f "${LIB_DIR}/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "${LIB_DIR}/tool-input.sh"
fi

if [[ -z "$bridge_home_root" ]]; then
  echo "Unable to resolve Kay bridge home root" >&2
  exit 1
fi

mkdir -p "${BRIDGE_ROOT}/blocks" "${PATH_PREPEND_ROOT}"

native_event="${CODE_HOOK_EVENT:-}"
native_stdin_payload=""
if [[ ! -t 0 ]]; then
  native_stdin_payload="$(cat)"
fi
if [[ -n "${CODE_HOOK_PAYLOAD:-}" ]]; then
  native_payload="${CODE_HOOK_PAYLOAD}"
elif [[ -n "$native_stdin_payload" ]]; then
  native_payload="$native_stdin_payload"
else
  native_payload='{}'
fi
source_call_id="${CODE_HOOK_SOURCE_CALL_ID:-${CODE_HOOK_CALL_ID:-hook}}"
for _sb_bridge_hook_suffix in \
  _hook_tool_before_1 \
  _hook_tool_after_1 \
  _hook_file_before_write_1 \
  _hook_file_after_write_1; do
  source_call_id="${source_call_id%"$_sb_bridge_hook_suffix"}"
done
unset _sb_bridge_hook_suffix
BRIDGE_DEBUG_LOG=""
if [[ -n "${SB_KAY_HOOK_BRIDGE_DEBUG:-}" ]]; then
  mkdir -p "${BRIDGE_ROOT}/debug"
  BRIDGE_DEBUG_LOG="${BRIDGE_ROOT}/debug/${source_call_id}.log"
fi

bridge_debug() {
  [[ -n "$BRIDGE_DEBUG_LOG" ]] || return 0
  {
    printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1"
  } >>"$BRIDGE_DEBUG_LOG" 2>/dev/null || true
}

hook_event_name_for_native() {
  case "$1" in
    tool.before|file.before_write) printf 'PreToolUse\n' ;;
    tool.after|file.after_write) printf 'PostToolUse\n' ;;
    session.start) printf 'SessionStart\n' ;;
    session.end) printf 'Stop\n' ;;
    *) return 1 ;;
  esac
}

synthetic_tool_name_for_native() {
  case "$1" in
    tool.before|tool.after) printf 'Bash\n' ;;
    file.before_write|file.after_write) printf 'Write\n' ;;
    *) printf '\n' ;;
  esac
}

bridge_state_path() {
  printf '%s\n' "${BRIDGE_ROOT}/blocks/${source_call_id}.state"
}

build_synthetic_payload() {
  local hook_event_name="$1"
  local tool_name="$2"

  case "$native_event" in
    tool.before|tool.after)
      python3 - "$hook_event_name" "$tool_name" "$native_payload" <<'PY'
import json
import sys

hook_event_name = sys.argv[1]
tool_name = sys.argv[2]

try:
    payload = json.loads(sys.argv[3])
except Exception:
    payload = {}

out = {
    "hook_event_name": hook_event_name,
    "tool_name": tool_name,
    "tool_input": {
        "command": payload.get("command", []),
    },
}

if hook_event_name == "PostToolUse":
    out["tool_response"] = {
        "exit_code": payload.get("exit_code"),
        "stdout": payload.get("stdout", ""),
        "stderr": payload.get("stderr", ""),
    }

print(json.dumps(out, separators=(",", ":")))
PY
      ;;
    file.before_write|file.after_write)
      python3 - "$hook_event_name" "$tool_name" "$native_payload" <<'PY'
import json
import sys

hook_event_name = sys.argv[1]
tool_name = sys.argv[2]

try:
    payload = json.loads(sys.argv[3])
except Exception:
    payload = {}

changes = payload.get("changes") or []
first_path = ""
if isinstance(changes, list):
    for change in changes:
        if not isinstance(change, dict):
            continue
        first_path = (
            change.get("path")
            or change.get("filePath")
            or change.get("new_path")
            or change.get("newPath")
            or ""
        )
        if first_path:
            break

out = {
    "hook_event_name": hook_event_name,
    "tool_name": tool_name,
    "tool_input": {
        "file_path": first_path,
    },
}

if hook_event_name == "PostToolUse":
    out["tool_response"] = {
        "filePath": first_path,
        "success": bool(payload.get("success", True)),
    }

print(json.dumps(out, separators=(",", ":")))
PY
      ;;
    *)
      printf '{}\n'
      ;;
  esac
}

matching_hook_specs() {
  local event_name="$1"
  local tool_name="$2"

  python3 - "$HOOKS_JSON" "$event_name" "$tool_name" <<'PY'
import json
import pathlib
import re
import sys

hooks_path = pathlib.Path(sys.argv[1])
event_name = sys.argv[2]
tool_name = sys.argv[3]

if not hooks_path.is_file():
    print("[]")
    raise SystemExit(0)

try:
    data = json.loads(hooks_path.read_text())
except Exception:
    print("[]")
    raise SystemExit(0)

groups = data.get("hooks", {}).get(event_name, [])
matched = []
for group in groups:
    matcher = group.get("matcher", "")
    try:
        is_match = bool(re.fullmatch(matcher, tool_name)) if matcher else False
    except re.error:
        is_match = False
    if not is_match:
        continue
    for hook in group.get("hooks", []):
        command = hook.get("command")
        if not isinstance(command, str) or not command.strip():
            continue
        matched.append({"command": command})

print(json.dumps(matched))
PY
}

parse_hook_block_reason() {
  local hook_stdout="$1"

  printf '%s' "$hook_stdout" | jq -r '
    if (.hookSpecificOutput.permissionDecision // "") == "deny" then
      .hookSpecificOutput.permissionDecisionReason // .reason // ""
    elif (.decision // "") == "block" then
      .reason // ""
    else
      ""
    end
  ' 2>/dev/null || true
}

run_matching_hooks() {
  local event_name="$1"
  local tool_name="$2"
  local payload_json="$3"
  local matched_json spec command stderr_file stdout_file status reason

  matched_json="$(matching_hook_specs "$event_name" "$tool_name")"
  [[ -n "$matched_json" ]] || matched_json='[]'
  bridge_debug "matched_hooks=${matched_json}"

  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    command="$(printf '%s' "$spec" | jq -r '.command')"
    stderr_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-stderr.XXXXXX")"
    stdout_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-stdout.XXXXXX")"

    if printf '%s' "$payload_json" | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash -lc "$command" >"$stdout_file" 2>"$stderr_file"; then
      status=0
    else
      status=$?
    fi

    reason=""
    if [[ $status -eq 2 ]]; then
      reason="$(tr -d '\r' <"$stderr_file" | sed -n '1p')"
    fi
    if [[ -z "$reason" ]]; then
      reason="$(parse_hook_block_reason "$(cat "$stdout_file")")"
    fi
    bridge_debug "hook_command=${command}"
    bridge_debug "hook_status=${status} hook_reason=${reason}"

    rm -f -- "$stderr_file" "$stdout_file"

    if [[ -n "$reason" && -z "${BRIDGE_BLOCK_REASON:-}" ]]; then
      BRIDGE_BLOCK_REASON="$reason"
    fi
  done < <(printf '%s' "$matched_json" | jq -c '.[]' 2>/dev/null || true)
}

collect_shell_write_targets() {
  local payload_json="$1"
  local command_str shell_script_path shell_script_dir shell_script_body
  command_str="$(sb_tool_command_string "$payload_json")"
  [[ -n "$command_str" ]] || return 0

  if declare -f sb_shell_invoked_script_path >/dev/null 2>&1; then
    shell_script_path="$(sb_shell_invoked_script_path "$command_str" "$PWD" 2>/dev/null || true)"
  else
    shell_script_path=""
  fi

  shell_script_dir="$PWD"
  shell_script_body=""
  if [[ -n "$shell_script_path" && -f "$shell_script_path" ]]; then
    shell_script_dir="$(dirname "$shell_script_path")"
    shell_script_body="$(cat "$shell_script_path" 2>/dev/null || true)"
  fi

  if declare -f sb_shell_candidate_write_paths >/dev/null 2>&1; then
    sb_shell_candidate_write_paths "$command_str" "$PWD" 2>/dev/null || true
    if [[ -n "$shell_script_body" ]]; then
      sb_shell_candidate_write_paths "$shell_script_body" "$PWD" 2>/dev/null || true
      sb_shell_candidate_write_paths "$shell_script_body" "$shell_script_dir" 2>/dev/null || true
    fi
  fi

  collect_git_commit_write_targets "$command_str"
}

collect_git_commit_write_targets() {
  local command_str="$1"
  local git_dir=""

  printf '%s' "$command_str" | grep -qE '(^|[[:space:];(&|])git[[:space:]]+commit([[:space:]]|$)' || return 0
  git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || return 0
  case "$git_dir" in
    /*) ;;
    *) git_dir="${PWD}/${git_dir}" ;;
  esac

  for target in \
    "$git_dir" \
    "$git_dir/index" \
    "$git_dir/HEAD" \
    "$git_dir/COMMIT_EDITMSG" \
    "$git_dir/packed-refs" \
    "$git_dir/objects" \
    "$git_dir/refs" \
    "$git_dir/logs"; do
    [[ -e "$target" ]] && printf '%s\n' "$target"
  done

  find "$git_dir/objects" "$git_dir/refs" "$git_dir/logs" \
    -type d -print 2>/dev/null || true
  find "$git_dir/refs" "$git_dir/logs" \
    -type f -print 2>/dev/null || true
}

apply_permission_block() {
  local state_path="$1"
  local target_list="$2"
  local records

  records="$(python3 - "$target_list" <<'PY'
import os
import stat
import subprocess
import sys
from pathlib import Path
import shutil

targets_path = Path(sys.argv[1])
seen = set()
records = []
can_lock = shutil.which("chflags") is not None

def add_record(path: Path):
    if not path.exists():
        return
    path = path.resolve()
    key = str(path)
    if key in seen:
        return
    seen.add(key)
    mode = stat.S_IMODE(path.stat().st_mode)
    new_mode = mode & ~0o222
    if new_mode != mode:
        os.chmod(path, new_mode)
    records.append(("PATH", key, str(mode)))
    if can_lock:
        locked = subprocess.run(
            ["chflags", "uchg", key],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if locked.returncode == 0:
            records.append(("IMMUTABLE", key, "uchg"))

for raw in targets_path.read_text().splitlines():
    raw = raw.strip()
    if not raw:
        continue
    target = Path(raw)
    if target.exists():
        add_record(target)
        add_record(target.parent)
        continue
    add_record(target.parent)

for kind, path, mode in records:
    print(f"{kind}\t{path}\t{mode}")
PY
)"

  [[ -n "$records" ]] || return 1
  printf '%s\n' "$records" >> "$state_path"
  return 0
}

extract_shell_entry_command() {
  local command_str="$1"

  python3 - "$command_str" <<'PY'
import pathlib
import re
import shlex
import sys

command = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
shell_names = {"bash", "sh", "zsh"}

def parse_tokens(raw):
    try:
        return shlex.split(raw, posix=True)
    except Exception:
        return []

def unwrap(raw):
    seen = set()
    current = raw
    while current and current not in seen:
        seen.add(current)
        tokens = parse_tokens(current)
        idx = 0
        if idx < len(tokens) and tokens[idx] == "env":
            idx += 1
        while idx < len(tokens) and assignment_re.match(tokens[idx]):
            idx += 1
        if idx >= len(tokens):
            return ""
        command_name = pathlib.Path(tokens[idx]).name
        args = tokens[idx + 1 :]
        if command_name in shell_names:
            for arg_index, arg in enumerate(args):
                if arg.startswith("-") and "c" in arg[1:] and arg_index + 1 < len(args):
                    current = args[arg_index + 1]
                    break
            else:
                return ""
            continue
        return command_name
    return ""

print(unwrap(command))
PY
}

shim_directory_for_call() {
  if [[ "${SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK:-0}" == "1" ]]; then
    printf '%s\n' "$ACTIVE_PATH_PREPEND_DIR"
    return 0
  fi
  printf '%s\n' "${PATH_PREPEND_ROOT}/${source_call_id}"
}

ensure_shim_dir() {
  local state_path="$1"
  local shim_dir

  shim_dir="$(shim_directory_for_call)"
  if [[ ! -d "$shim_dir" ]]; then
    mkdir -p "$shim_dir"
  fi
  if ! grep -Fqx $'SHIMDIR\t'"${shim_dir}"$'\t0' "$state_path" 2>/dev/null; then
    printf 'SHIMDIR\t%s\t0\n' "$shim_dir" >> "$state_path"
  fi
  printf '%s\n' "$shim_dir"
}

write_reason_shim() {
  local shim_path="$1"
  local reason="$2"

  cat > "$shim_path" <<EOF
#!/bin/bash
printf '%s\n' $(printf '%q' "$reason") >&2
exit 2
EOF
  chmod +x "$shim_path"
}

bridge_block_denied_tool() {
  local reason="$1"

  [[ -n "$reason" ]] || reason="Silver Bullet blocked this tool call."
  printf '%s\n' "$reason" >&2
  exit 2
}

install_named_command_shim() {
  local state_path="$1"
  local command_name="$2"
  local reason="$3"
  local shim_dir

  [[ -n "$command_name" ]] || return 1
  shim_dir="$(ensure_shim_dir "$state_path")"
  write_reason_shim "${shim_dir}/${command_name}" "$reason"
}

install_command_shim() {
  local state_path="$1"
  local command_str="$2"
  local reason="$3"
  local entry_command

  entry_command="$(extract_shell_entry_command "$command_str")"
  case "$entry_command" in
    ""|bash|sh|zsh|env ) return 1 ;;
  esac

  install_named_command_shim "$state_path" "$entry_command" "$reason"
}

install_mutation_shims() {
  local state_path="$1"
  local reason="$2"
  local command_name
  local command_names=(
    chmod
    chflags
    cp
    mv
    rm
    touch
    mkdir
    install
    ln
    tee
    dd
    truncate
    sed
    awk
    perl
    python
    python3
    node
    ruby
    git
    gh
  )

  for command_name in "${command_names[@]}"; do
    install_named_command_shim "$state_path" "$command_name" "$reason"
  done
  return 0
}

restore_block_state() {
  local state_path
  local kind path mode
  local -a state_lines=()
  local line

  state_path="$(bridge_state_path)"
  [[ -f "$state_path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    state_lines+=("$line")
  done < "$state_path"

  for line in "${state_lines[@]}"; do
    IFS=$'\t' read -r kind path mode <<<"$line"
    [[ -n "$kind" ]] || continue
    case "$kind" in
      IMMUTABLE)
        chflags nouchg "$path" >/dev/null 2>&1 || true
        ;;
    esac
  done

  for line in "${state_lines[@]}"; do
    IFS=$'\t' read -r kind path mode <<<"$line"
    [[ -n "$kind" ]] || continue
    case "$kind" in
      PATH)
        python3 - "$path" "$mode" <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
mode = int(sys.argv[2])
if path.exists():
    os.chmod(path, mode)
PY
        ;;
      SHIMDIR)
        rm -rf -- "$path"
        ;;
    esac
  done

  rm -f -- "$state_path"
}

main() {
  local hook_event_name tool_name synthetic_payload state_path targets_file command_str

  hook_event_name="$(hook_event_name_for_native "$native_event" 2>/dev/null || true)"
  tool_name="$(synthetic_tool_name_for_native "$native_event")"
  [[ -n "$hook_event_name" ]] || exit 0

  synthetic_payload="$(build_synthetic_payload "$hook_event_name" "$tool_name")"
  state_path="$(bridge_state_path)"
  bridge_debug "native_event=${native_event}"
  bridge_debug "native_payload=${native_payload}"
  bridge_debug "synthetic_payload=${synthetic_payload}"

  BRIDGE_BLOCK_REASON=""
  run_matching_hooks "$hook_event_name" "$tool_name" "$synthetic_payload"

  case "$native_event" in
    tool.before)
      [[ -n "${BRIDGE_BLOCK_REASON:-}" ]] || exit 0
      bridge_debug "block_reason=${BRIDGE_BLOCK_REASON}"
      if [[ "${SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK:-0}" == "1" ]]; then
        : > "$state_path"
        targets_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-targets.XXXXXX")"
        collect_shell_write_targets "$synthetic_payload" | sort -u > "$targets_file"
        bridge_debug "targets=$(tr '\n' '|' <"$targets_file" 2>/dev/null || true)"
        if ! apply_permission_block "$state_path" "$targets_file"; then
          command_str="$(sb_tool_command_string "$synthetic_payload")"
          bridge_debug "permission_block=failed command_str=${command_str}"
          install_command_shim "$state_path" "$command_str" "$BRIDGE_BLOCK_REASON" || true
        else
          bridge_debug "permission_block=applied state_path=${state_path}"
        fi
        install_mutation_shims "$state_path" "$BRIDGE_BLOCK_REASON" || true
        bridge_debug "shim_dir=$(shim_directory_for_call 2>/dev/null || true)"
        rm -f -- "$targets_file"
      fi
      bridge_block_denied_tool "$BRIDGE_BLOCK_REASON"
      ;;
    file.before_write)
      [[ -n "${BRIDGE_BLOCK_REASON:-}" ]] || exit 0
      bridge_debug "block_reason=${BRIDGE_BLOCK_REASON}"
      bridge_block_denied_tool "$BRIDGE_BLOCK_REASON"
      ;;
    tool.after|file.after_write)
      restore_block_state
      ;;
  esac
}

main "$@"
