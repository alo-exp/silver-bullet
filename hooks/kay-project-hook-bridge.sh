#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

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
if [[ -z "$bridge_home_root" ]]; then
  echo "Unable to resolve Kay bridge home root" >&2
  exit 1
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

# shellcheck source=lib/hook-subproc-timeout.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/hook-subproc-timeout.sh"
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
  } 2>/dev/null >>"$BRIDGE_DEBUG_LOG" || true
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

native_synthetic_tool_name() {
  python3 - "$native_event" "$native_payload" <<'PY'
import json
import sys

native_event = sys.argv[1]
try:
    payload = json.loads(sys.argv[2] or "{}")
except Exception:
    payload = {}

if not isinstance(payload, dict):
    payload = {}

if native_event in {"file.before_write", "file.after_write"}:
    print("Write")
    raise SystemExit(0)

if native_event not in {"tool.before", "tool.after"}:
    print("")
    raise SystemExit(0)

for key in ("tool_name", "tool", "name", "type"):
    value = payload.get(key)
    if value in {"exec_command", "Bash", "Shell", "shell"}:
        print("exec_command" if value == "exec_command" else "Bash")
        raise SystemExit(0)

command = payload.get("command")
if command is None:
    command = payload.get("cmd")
if command is None:
    command = payload.get("argv")
if isinstance(command, list) and command:
    entry = str(command[0])
    if entry in {"exec_command"}:
        print("exec_command")
        raise SystemExit(0)

print("Bash")
PY
}

synthetic_tool_name_for_native() {
  local detected
  detected="$(native_synthetic_tool_name 2>/dev/null || true)"
  if [[ -n "$detected" ]]; then
    printf '%s\n' "$detected"
    return 0
  fi
  case "$1" in
    tool.before|tool.after) printf 'Bash\n' ;;
    file.before_write|file.after_write) printf 'Write\n' ;;
    *) printf '\n' ;;
  esac
}

tool_names_for_hook_matching() {
  local primary="$1"
  case "$native_event" in
    tool.before|tool.after)
      if [[ "$primary" == "exec_command" ]]; then
        printf '%s\n' exec_command Bash
      else
        printf '%s\n' Bash exec_command
      fi
      ;;
    file.before_write|file.after_write)
      printf '%s\n' Write Edit MultiEdit apply_patch
      ;;
  esac
}

# Every path a file.* write touches, one per line. Every path is gated: a
# multi-file write must not hide a protected file behind a harmless first entry.
# Kay's real change schema is not documented in this repo, so unknown shapes are
# gated by the UNION of every path-like value found (keys compared case- and
# underscore-insensitively): top-level path keys, a `changes` list of objects, a
# `changes` object keyed by path, nested rename/move objects and lists of files.
native_file_paths() {
  python3 - "$native_payload" <<'PY'
import json
import sys

try:
    payload = json.loads(sys.argv[1] or "{}")
except Exception:
    payload = {}
if not isinstance(payload, dict):
    payload = {}

PATH_KEYS = {
    "path", "filepath", "newpath", "movepath", "oldpath", "frompath", "topath",
    "destination", "dest", "targetpath", "sourcepath", "file", "filename",
}
seen = []

def norm(key):
    return str(key).lower().replace("_", "").replace("-", "")

def add(path):
    if path and path not in seen:
        seen.append(path)

def collect(value, depth):
    if depth > 8:
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if norm(key) in PATH_KEYS and isinstance(item, str):
                add(item)
            elif isinstance(item, (dict, list)):
                collect(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            collect(item, depth + 1)

changes = payload.get("changes")
if isinstance(changes, dict):
    # keyed by path (the keys are the paths) unless a key is a known field name
    for key, item in changes.items():
        if norm(key) in PATH_KEYS:
            collect({key: item}, 1)
        else:
            add(key)
            collect(item, 1)
else:
    collect(changes, 1)
collect({k: v for k, v in payload.items() if k != "changes"}, 0)
for path in seen:
    print(path)
PY
}

bridge_state_path() {
  printf '%s\n' "${BRIDGE_ROOT}/blocks/${source_call_id}.state"
}

build_synthetic_payload() {
  local hook_event_name="$1"
  local tool_name="$2"
  local file_path_arg="${3:-}"

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

if not isinstance(payload, dict):
    payload = {}

command = payload.get("command")
if command is None:
    command = payload.get("cmd")
if command is None:
    command = payload.get("argv")
if command is None:
    command = []

out = {
    "hook_event_name": hook_event_name,
    "tool_name": tool_name,
    "tool_input": {
        "command": command,
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
      python3 - "$hook_event_name" "$tool_name" "$native_payload" "$file_path_arg" <<'PY'
import json
import sys

hook_event_name = sys.argv[1]
tool_name = sys.argv[2]
file_path = sys.argv[4]

try:
    payload = json.loads(sys.argv[3])
except Exception:
    payload = {}

if not isinstance(payload, dict):
    payload = {}

out = {
    "hook_event_name": hook_event_name,
    "tool_name": tool_name,
    "tool_input": {
        "file_path": file_path,
    },
}

if hook_event_name == "PostToolUse":
    out["tool_response"] = {
        "filePath": file_path,
        "success": bool(payload.get("success", True)),
    }

print(json.dumps(out, separators=(",", ":")))
PY
      ;;
  esac
}

compute_matching_hook_specs() {
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
        budget = hook.get("timeout")
        if isinstance(budget, bool) or not isinstance(budget, (int, float)) or budget <= 0:
            budget = 120
        # Same rule as the Codex adapter: a little below the manifest budget.
        whole = int(budget)
        matched.append({"command": command, "timeout": max(1, whole - max(2, whole // 10))})

print(json.dumps(matched))
PY
}

# Sets MATCHED_JSON for (event, tool). The match does not depend on the path, so
# it is computed once per distinct pair and cached in a variable (not a
# subshell: the cache must survive in this shell). Cost no longer scales with the
# number of paths in a multi-file write.
load_matching_hook_specs() {
  local key
  key="_sb_match_cache_$(printf '%s_%s' "$1" "$2" | tr -c 'A-Za-z0-9' '_')"
  if [[ -z "${!key+x}" ]]; then
    printf -v "$key" '%s' "$(compute_matching_hook_specs "$1" "$2")"
  fi
  MATCHED_JSON="${!key}"
}

parse_hook_block_reason() {
  local hook_stdout="$1"
  local filter out
  # "ask" cannot be answered on Kay, so it is a block (fail closed).
  filter='
    if (.hookSpecificOutput.permissionDecision // "") == "deny" then
      .hookSpecificOutput.permissionDecisionReason // .reason // ""
    elif (.hookSpecificOutput.permissionDecision // "") == "ask" then
      .hookSpecificOutput.permissionDecisionReason // .reason // "Silver Bullet hook requires approval, which this host cannot give."
    elif (.decision // "") == "block" then
      .reason // ""
    else
      ""
    end
  '

  if out="$(printf '%s' "$hook_stdout" | jq -r "$filter" 2>/dev/null)"; then
    printf '%s\n' "$out"
    return 0
  fi
  # Not one JSON document (a banner before the verdict): take the last complete
  # JSON value, i.e. the shortest suffix of the stream that parses. This also
  # handles a pretty-printed multi-line object. Only the last 200 lines are tried.
  local total line_no stop
  total="$(printf '%s\n' "$hook_stdout" | wc -l | tr -d ' ')"
  stop=$((total > 200 ? total - 199 : 1))
  line_no="$total"
  while [[ "$line_no" -ge "$stop" ]]; do
    if out="$(printf '%s\n' "$hook_stdout" | tail -n "+${line_no}" | jq -r "$filter" 2>/dev/null)"; then
      printf '%s\n' "$out"
      return 0
    fi
    line_no=$((line_no - 1))
  done
  return 0
}

run_matching_hooks() {
  local event_name="$1"
  local tool_name="$2"
  local payload_json="$3"
  local matched_json spec command stderr_file stdout_file stdin_file budget status reason
  # seen_commands is declared by run_all_matching_hooks: a command runs once per
  # event even when several tool-name aliases match it.

  load_matching_hook_specs "$event_name" "$tool_name"
  matched_json="$MATCHED_JSON"
  [[ -n "$matched_json" ]] || matched_json='[]'
  bridge_debug "matched_hooks tool=${tool_name} hooks=${matched_json}"

  while IFS= read -r spec; do
    command="$(printf '%s' "$spec" | jq -r '.command')"
    [[ -n "$command" ]] || continue
    if ((${#seen_commands[@]})) && grep -Fqx -- "$command" <<<"$(printf '%s\n' "${seen_commands[@]}")"; then
      continue
    fi
    seen_commands+=("$command")
    stderr_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-stderr.XXXXXX")"
    stdout_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-stdout.XXXXXX")"

    budget="$(printf '%s' "$spec" | jq -r '.timeout // 120')"
    stdin_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-stdin.XXXXXX")"
    printf '%s' "$payload_json" >"$stdin_file"
    # Run under the hook's own budget so a hung hook cannot stall the Kay session.
    if sb_run_hooked_command "$budget" "$stdin_file" "$stdout_file" "$stderr_file" \
      env CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" SB_KAY_HOOK_BRIDGE_INVOKED=1 bash -c "$command"; then
      status=0
    else
      status=$?
    fi
    rm -f -- "$stdin_file"

    reason=""
    if [[ $status -eq 2 ]]; then
      reason="$(tr -d '\r' <"$stderr_file" | sed -n '1p')"
    fi
    if [[ -z "$reason" ]]; then
      reason="$(parse_hook_block_reason "$(cat "$stdout_file")")"
    fi
    if [[ $status -eq 124 && "$event_name" == "PreToolUse" ]]; then
      # No verdict in time: a gating hook that timed out denies (fail closed).
      reason="Silver Bullet hook timed out after ${budget}s and was blocked (fail closed): ${command}"
    fi
    if [[ -z "$reason" && $status -eq 2 ]]; then
      # Exit 2 is the host's blocking error even when the hook said nothing.
      reason="Silver Bullet hook blocked this call (exit 2): ${command}"
    fi
    bridge_debug "hook_command=${command}"
    bridge_debug "hook_status=${status} hook_reason=${reason}"

    rm -f -- "$stderr_file" "$stdout_file"

    if [[ -n "$reason" && -z "${BRIDGE_BLOCK_REASON:-}" ]]; then
      BRIDGE_BLOCK_REASON="$reason"
    fi
  done < <(printf '%s' "$matched_json" | jq -c '.[]' 2>/dev/null || true)
}

run_all_matching_hooks() {
  local event_name="$1"
  local primary_tool_name="$2"
  local payload_json="$3"
  local matcher_tool_name
  local -a seen_commands=()

  while IFS= read -r matcher_tool_name; do
    run_matching_hooks "$event_name" "$matcher_tool_name" "$payload_json"
  done < <(tool_names_for_hook_matching "$primary_tool_name")
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

  grep -qE '(^|[[:space:];(&|])git[[:space:]]+commit([[:space:]]|$)' <<<"$command_str" || return 0
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

# Lock the targets read-only. Locks are SHARED: ${BRIDGE_ROOT}/locks/<key>/ holds
# one lock per path (its original mode, captured only when the path is first
# locked) plus the set of holders (state-file tokens). A second denial that finds
# the path already locked only adds itself as a holder; the path is restored when
# the LAST holder releases, so overlapping denials with different call ids can
# never restore (or record) an already-locked mode as the original. The HOLD record
# is appended to the state file BEFORE the path is changed, so a failure part-way
# (EPERM, a crash) still leaves what is needed to restore. scope "exact" locks
# only the target (its parent only when the target does not exist yet); scope
# "parents" also locks the parent directory of every target (shell commands can
# create files next to a target).
apply_permission_block() {
  local state_path="$1"
  local target_list="$2"
  local scope="${3:-parents}"
  local count

  count="$(python3 - "$target_list" "$state_path" "$scope" "${BRIDGE_ROOT}/locks" <<'PY'
import hashlib
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

targets_path = Path(sys.argv[1])
state_path = Path(sys.argv[2])
scope = sys.argv[3]
lock_root = Path(sys.argv[4])
token = state_path.name
seen = set()
count = 0
can_lock = shutil.which("chflags") is not None
lock_root.mkdir(parents=True, exist_ok=True)

def record(state, kind, key, value):
    state.write(f"{kind}\t{key}\t{value}\n")
    state.flush()
    os.fsync(state.fileno())

def add_record(state, path: Path):
    global count
    if not path.exists():
        return
    path = path.resolve()
    key = str(path)
    if key in seen:
        return
    seen.add(key)
    lock_id = hashlib.sha1(key.encode("utf-8")).hexdigest()[:24]
    lock_dir = lock_root / lock_id
    try:
        record(state, "HOLD", lock_id, key)
        count += 1
        try:
            os.mkdir(lock_dir)
            first = True
        except FileExistsError:
            first = False
        if first:
            mode = stat.S_IMODE(path.stat().st_mode)
            (lock_dir / "path").write_text(key, encoding="utf-8")
            (lock_dir / "mode").write_text(str(mode), encoding="utf-8")
        with open(lock_dir / "holders", "a", encoding="utf-8") as holders:
            holders.write(token + "\n")
        if not first:
            return
        new_mode = mode & ~0o222
        if new_mode != mode:
            os.chmod(path, new_mode)
        if can_lock:
            locked = subprocess.run(
                ["chflags", "uchg", key],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if locked.returncode == 0:
                (lock_dir / "immutable").write_text("uchg", encoding="utf-8")
                record(state, "IMMUTABLE", key, "uchg")
    except OSError:
        return

with open(state_path, "a", encoding="utf-8") as state:
    for raw in targets_path.read_text().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        target = Path(raw)
        if target.exists():
            add_record(state, target)
            if scope != "exact":
                add_record(state, target.parent)
            continue
        add_record(state, target.parent)

print(count)
PY
)"

  [[ "${count:-0}" -gt 0 ]]
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
  if [[ "${SB_KAY_HOOK_BRIDGE_LEGACY_FALLBACK:-1}" == "1" ]]; then
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

  printf '%s\n' "$reason" >&2
  exit 2
}

install_named_command_shim() {
  local state_path="$1"
  local command_name="$2"
  local reason="$3"
  local shim_dir

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

apply_denial_filesystem_block() {
  local state_path="$1"
  local payload_json="$2"
  local reason="$3"
  local targets_file command_str

  touch "$state_path"
  targets_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-targets.XXXXXX")"
  collect_shell_write_targets "$payload_json" | sort -u >"$targets_file"
  bridge_debug "targets=$(tr '\n' '|' <"$targets_file" 2>/dev/null || true)"
  if ! apply_permission_block "$state_path" "$targets_file"; then
    command_str="$(sb_tool_command_string "$payload_json")"
    bridge_debug "permission_block=failed command_str=${command_str}"
    install_command_shim "$state_path" "$command_str" "$reason" || true
  else
    bridge_debug "permission_block=applied state_path=${state_path}"
  fi
  # In an if-condition so a failing shim install cannot trip errexit before the deny is reported.
  if install_mutation_shims "$state_path" "$reason"; then :; fi
  bridge_debug "shim_dir=$(shim_directory_for_call)"
  rm -f -- "$targets_file"
}

apply_file_write_block() {
  local state_path="$1"
  local paths="$2"
  local reason="$3"
  local targets_file

  [[ -n "$paths" ]] || return 0

  touch "$state_path"
  targets_file="$(mktemp "${TMPDIR:-/tmp}/sb-kay-hook-targets.XXXXXX")"
  printf '%s\n' "$paths" >"$targets_file"
  apply_permission_block "$state_path" "$targets_file" exact || true
  # In an if-condition so a failing shim install cannot trip errexit before the deny is reported.
  if install_mutation_shims "$state_path" "$reason"; then :; fi
  rm -f -- "$targets_file"
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

# Release the locks one lock-registry pass at a time. "state FILE": drop this
# state file's token from every lock it holds and restore a path when no holder
# is left. "all": restore every remaining lock to its original mode regardless of
# holders (session boundaries).
release_locks() {
  python3 - "${BRIDGE_ROOT}/locks" "$@" <<'PY'
import os
import shutil
import subprocess
import sys
from pathlib import Path

lock_root = Path(sys.argv[1])
mode_arg = sys.argv[2]

def restore(lock_dir: Path):
    try:
        path = (lock_dir / "path").read_text(encoding="utf-8")
        original = int((lock_dir / "mode").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        shutil.rmtree(lock_dir, ignore_errors=True)
        return
    if (lock_dir / "immutable").exists():
        subprocess.run(["chflags", "nouchg", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    try:
        if os.path.exists(path):
            os.chmod(path, original)
    except OSError:
        pass
    shutil.rmtree(lock_dir, ignore_errors=True)

if mode_arg == "all":
    if lock_root.is_dir():
        for lock_dir in sorted(lock_root.iterdir()):
            restore(lock_dir)
    raise SystemExit(0)

state_path = Path(sys.argv[3])
token = state_path.name
try:
    lines = state_path.read_text(encoding="utf-8").splitlines()
except OSError:
    lines = []
for line in lines:
    fields = line.split("\t")
    if len(fields) < 2 or fields[0] != "HOLD":
        continue
    lock_dir = lock_root / fields[1]
    holders_file = lock_dir / "holders"
    try:
        holders = holders_file.read_text(encoding="utf-8").splitlines()
    except OSError:
        continue
    remaining = [holder for holder in holders if holder != token]
    if remaining:
        holders_file.write_text("".join(h + "\n" for h in remaining), encoding="utf-8")
    else:
        restore(lock_dir)
PY
}

# Undo one state file (shared locks, shim dirs), then delete it.
restore_state_file() {
  local state_path="$1"
  local kind path
  local line

  [[ -f "$state_path" ]] || return 0

  release_locks state "$state_path"
  while IFS= read -r line || [[ -n "$line" ]]; do
    IFS=$'\t' read -r kind path _ <<<"$line"
    if [[ "$kind" == "SHIMDIR" ]]; then
      rm -rf -- "$path"
    fi
  done < "$state_path"

  rm -f -- "$state_path"
}

restore_block_state() {
  restore_state_file "$(bridge_state_path)"
}

# session.start / session.end: a denied call whose tool.after never arrived (a
# crash, a host that skips the after event, a missing call id) must not leave
# the project read-only. Restore every stale state file, newest first (a later
# state can record the already-locked mode of a path an earlier one restores).
run_session_start_hooks() {
  local -a seen_commands=()
  BRIDGE_BLOCK_REASON=""
  run_matching_hooks SessionStart startup '{"hook_event_name":"SessionStart","source":"startup"}'
}

restore_all_stale_blocks() {
  local stale
  while IFS= read -r stale; do
    restore_state_file "$stale"
  done < <(ls -1t "${BRIDGE_ROOT}"/blocks/*.state 2>/dev/null || true)
  # Whatever is still locked (a holder whose state file is gone) goes back to its
  # original mode: session boundaries restore everything regardless of holders.
  release_locks all
  if [[ -d "$ACTIVE_PATH_PREPEND_DIR" && "${ACTIVE_PATH_PREPEND_DIR##*/}" == "active" ]]; then
    rm -rf -- "$ACTIVE_PATH_PREPEND_DIR"
  fi
}

main() {
  local hook_event_name tool_name synthetic_payload state_path file_path
  local -a file_paths=()

  hook_event_name="$(hook_event_name_for_native "$native_event" 2>/dev/null || true)"
  tool_name="$(synthetic_tool_name_for_native "$native_event")"
  [[ -n "$hook_event_name" ]] || exit 0

  # Kay has no Stop/UserPromptSubmit gating (see docs/RUNTIME-COMPATIBILITY.md,
  # "Kay limits"). Session events repair stale denial state; session.start also
  # runs the SessionStart hooks for their side effects (the branch-scoped state
  # reset) and ignores their output and decision.
  case "$native_event" in
    session.start|session.end)
      restore_all_stale_blocks
      if [[ "$native_event" == "session.start" ]]; then
        run_session_start_hooks
      fi
      exit 0
      ;;
  esac

  state_path="$(bridge_state_path)"
  BRIDGE_BLOCK_REASON=""
  BRIDGE_FILE_PATHS=""
  case "$native_event" in
    file.before_write|file.after_write)
      while IFS= read -r file_path; do
        file_paths+=("$file_path")
      done < <(native_file_paths)
      if ((${#file_paths[@]})); then
        BRIDGE_FILE_PATHS="$(printf '%s\n' "${file_paths[@]}")"
      else
        file_paths=("")
        # A write whose payload names no recognisable path cannot be gated: fail closed.
        if [[ "$native_event" == "file.before_write" ]]; then
          BRIDGE_BLOCK_REASON="Silver Bullet found no file path in this write payload (unknown change shape), so it cannot be checked; blocked (fail closed)."
        fi
      fi
      synthetic_payload=""
      for file_path in "${file_paths[@]}"; do
        synthetic_payload="$(build_synthetic_payload "$hook_event_name" "$tool_name" "$file_path")"
        bridge_debug "synthetic_payload=${synthetic_payload}"
        run_all_matching_hooks "$hook_event_name" "$tool_name" "$synthetic_payload"
      done
      ;;
    *)
      synthetic_payload="$(build_synthetic_payload "$hook_event_name" "$tool_name")"
      bridge_debug "synthetic_payload=${synthetic_payload}"
      run_all_matching_hooks "$hook_event_name" "$tool_name" "$synthetic_payload"
      ;;
  esac
  bridge_debug "native_event=${native_event}"
  bridge_debug "native_payload=${native_payload}"

  case "$native_event" in
    tool.before)
      [[ -n "${BRIDGE_BLOCK_REASON:-}" ]] || exit 0
      bridge_debug "block_reason=${BRIDGE_BLOCK_REASON}"
      apply_denial_filesystem_block "$state_path" "$synthetic_payload" "$BRIDGE_BLOCK_REASON"
      bridge_block_denied_tool "$BRIDGE_BLOCK_REASON"
      ;;
    file.before_write)
      [[ -n "${BRIDGE_BLOCK_REASON:-}" ]] || exit 0
      bridge_debug "block_reason=${BRIDGE_BLOCK_REASON}"
      apply_file_write_block "$state_path" "$BRIDGE_FILE_PATHS" "$BRIDGE_BLOCK_REASON"
      bridge_block_denied_tool "$BRIDGE_BLOCK_REASON"
      ;;
    tool.after|file.after_write)
      restore_block_state
      ;;
  esac
}

main "$@"
