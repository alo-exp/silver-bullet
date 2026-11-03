# shellcheck shell=bash
# Silver Bullet — jq presence gate for enforcement hooks.
#
# Without jq the hooks cannot evaluate their payloads. The policy (R1-29):
#   * outside an SB project (no .silver-bullet.json + silver-bullet.md walking up from $PWD;
#     a stale project-root cache never counts) nothing is ever blocked;
#   * inside one, the way out always stays open: installing jq through a package manager
#     and read-only shell commands are allowed;
#   * delivery gates still block real delivery commands, and the planning / protected-file
#     gates block whatever they cannot evaluate, with a message that says how to recover.
#
# API:
#   sb_jq_missing_message                          recovery text (names "jq is required")
#   sb_jq_enforcement_warn HOOK                    jq missing: visible notice, exit 0
#   sb_jq_enforcement_block HOOK [EMIT_FN] [EVENT] jq missing: block and exit 0. EMIT_FN gets
#                                                  the message; without it a deny/block for
#                                                  EVENT (default PreToolUse) is emitted.
#   sb_jq_enforcement_block_sb_initiated HOOK [EMIT_FN] [PAYLOAD]
#       gate policy: in an SB project block (exit 0) unless the payload is a shell command
#       that installs or probes jq, or is read-only. Returns 0 otherwise. PAYLOAD defaults to
#       stdin, read only when jq is missing inside an SB project and stdin is not a terminal.
#   sb_jq_missing_delivery_gate HOOK [EMIT_FN] PAYLOAD [CLASSIFY_FN]
#       delivery policy: in an SB project block (exit 0) a shell command that CLASSIFY_FN
#       (default: the built-in delivery pattern) classifies as delivery. Returns 0 otherwise.

_sb_jq_gate_dir="${BASH_SOURCE[0]:-$0}"
_sb_jq_gate_dir="${_sb_jq_gate_dir%/*}"
if [[ -f "$_sb_jq_gate_dir/hook-output.sh" ]]; then
  # shellcheck source=hook-output.sh
  source "$_sb_jq_gate_dir/hook-output.sh"
fi

# Installing (or probing for) jq: optional sudo, a few harmless installer env prefixes (never
# PATH, BASH_ENV, LD_PRELOAD and the like), one package manager; only apt refreshes metadata.
_sb_jq_s='[[:space:]]+'
_sb_jq_f='([[:space:]]+-[-A-Za-z0-9=]+)*'
_SB_JQ_REMEDIATION_RE="^[[:space:]]*(sudo${_sb_jq_f}${_sb_jq_s})?((DEBIAN_FRONTEND|NONINTERACTIVE|HOMEBREW_NO_AUTO_UPDATE|HOMEBREW_NO_INSTALL_CLEANUP|HOMEBREW_NO_ENV_HINTS)=[A-Za-z0-9_]*${_sb_jq_s})*((brew|port|choco|scoop|winget|conda|mamba|snap)${_sb_jq_s}install${_sb_jq_f}${_sb_jq_s}(jq|jqlang\\.jq)|(apt|apt-get)${_sb_jq_f}${_sb_jq_s}(install${_sb_jq_f}${_sb_jq_s}jq|update)|(dnf|yum|zypper|microdnf)${_sb_jq_f}${_sb_jq_s}install${_sb_jq_f}${_sb_jq_s}jq|apk${_sb_jq_f}${_sb_jq_s}add${_sb_jq_f}${_sb_jq_s}jq|pacman${_sb_jq_s}-S[A-Za-z]*${_sb_jq_f}${_sb_jq_s}jq|nix-env${_sb_jq_s}-iA${_sb_jq_s}nixpkgs\\.jq|(which|type|command${_sb_jq_s}-v)${_sb_jq_s}jq|jq${_sb_jq_s}--version)${_sb_jq_f}[[:space:]]*$"
# Delivery verbs (fallback when the caller has no classifier of its own).
_SB_JQ_DELIVERY_RE='(^|[^[:alnum:]_-])(git[[:space:]]+(commit|push|write-tree|commit-tree|update-ref|hash-object)|gh[[:space:]]+(pr[[:space:]]+(create|merge)|release[[:space:]]+create)|deploy)([^[:alnum:]_-]|$)'
unset _sb_jq_s _sb_jq_f

sb_jq_missing_message() {
  printf '%s' '🛑 ENFORCEMENT BLOCKED — jq is required for Silver Bullet hooks.

To recover, install jq (allowed while it is missing), check it, then retry:
  macOS:          brew install jq
  Debian/Ubuntu:  sudo apt-get install -y jq
  Fedora/RHEL:    sudo dnf install -y jq
  Alpine:         apk add jq
  check:          jq --version
Re-run /sb:init if this project was set up while jq was missing.

Until then jq installs and (when python3 is available) read-only commands are allowed; delivery (commit, push, PR, merge, deploy, release) and source edits stay blocked.'
}

sb_jq_enforcement_warn() {
  local hook_name="${1:-hook}"
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  local msg="⚠️  ENFORCEMENT INACTIVE — jq not installed (${hook_name}). Install: brew install jq (macOS) / sudo apt-get install -y jq (Linux). Silver Bullet enforcement is disabled until jq is available."
  if declare -f sb_emit_hook_message >/dev/null 2>&1; then
    sb_emit_hook_message "" "$msg"
  else
    printf '{"systemMessage":"ENFORCEMENT INACTIVE - jq not installed. Install jq: brew install jq (macOS) / sudo apt-get install -y jq (Linux)."}'
  fi
  exit 0
}

sb_jq_enforcement_block() {
  local hook_name="${1:-hook}" emit_fn="${2:-}" event="${3:-}" msg
  command -v jq >/dev/null 2>&1 && return 0
  msg="$(sb_jq_missing_message)"
  if [[ -n "$emit_fn" ]] && declare -f "$emit_fn" >/dev/null 2>&1; then
    "$emit_fn" "$msg"
  elif declare -f sb_emit_hook_decision >/dev/null 2>&1; then
    sb_emit_hook_decision "${event:-PreToolUse}" deny "$msg"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq required for Silver Bullet enforcement (%s)"}}' "${hook_name//[^A-Za-z0-9_.-]/}"
  fi
  exit 0
}

# _sb_jq_in_sb_project: an SB project encloses $PWD (walk only; no root cache).
_sb_jq_in_sb_project() {
  local gate_lib="$_sb_jq_gate_dir/sb-project-gate.sh"
  if ! declare -f sb_find_project_config_walk_only >/dev/null 2>&1; then
    [[ -f "$gate_lib" ]] || return 1
    # shellcheck source=sb-project-gate.sh
    source "$gate_lib"
  fi
  [[ -n "$(sb_find_project_config_walk_only 2>/dev/null || true)" ]]
}

# _sb_jq_payload_field PAYLOAD tool_name|hook_event_name|command: read a payload field
# without jq (python3, else a sed extraction that leaves JSON escapes in place).
_sb_jq_payload_field() {
  local payload="${1:-}" field="$2" re
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -c '
import json, shlex, sys
try:
    d = json.loads(sys.stdin.read() or "{}")
except Exception:
    raise SystemExit(0)
if not isinstance(d, dict):
    raise SystemExit(0)
if sys.argv[1] == "command":
    ti = d.get("tool_input") if isinstance(d.get("tool_input"), dict) else {}
    v = ti.get("command", ti.get("cmd"))
    if isinstance(v, list):
        v = " ".join(shlex.quote(str(p)) for p in v)
else:
    v = d.get(sys.argv[1])
sys.stdout.write(v if isinstance(v, str) else "")
' "$field" 2>/dev/null
    return 0
  fi
  [[ "$field" != command ]] || field='command|cmd'
  re='.*"('"$field"')"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*'
  printf '%s' "$payload" | sed -nE "s/$re/\\2/p" | sed -n '1p'
}

_sb_jq_shell_tool() {
  case "${1:-}" in
    Bash | Shell | shell | exec_command) return 0 ;;
  esac
  return 1
}

# _sb_jq_allowed_without_jq CMD: every segment installs/probes jq, or CMD is read-only.
_sb_jq_allowed_without_jq() {
  local cmd="${1:-}" segs seg any=0 nl=$'\n' and_op='&&' or_op='||' semi=';'
  [[ -n "$cmd" ]] || return 1
  if declare -f sb_shell_command_looks_read_only >/dev/null 2>&1 && sb_shell_command_looks_read_only "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  # No outer quotes: Bash <= 4.2 keeps the quotes of a quoted replacement inside "${...}".
  segs=${cmd//"$and_op"/"$nl"}
  segs=${segs//"$or_op"/"$nl"}
  segs=${segs//"$semi"/"$nl"}
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
    [[ "$seg" =~ $_SB_JQ_REMEDIATION_RE ]] || return 1
    any=1
  done <<<"$segs"
  [[ "$any" == 1 ]]
}

sb_jq_enforcement_block_sb_initiated() {
  local hook_name="${1:-hook}" emit_fn="${2:-}" payload=""
  command -v jq >/dev/null 2>&1 && return 0
  _sb_jq_in_sb_project || return 0
  if [[ $# -ge 3 ]]; then
    payload="$3"
  elif [[ ! -t 0 ]]; then
    payload="$(cat)"
  fi
  if _sb_jq_shell_tool "$(_sb_jq_payload_field "$payload" tool_name)" &&
    _sb_jq_allowed_without_jq "$(_sb_jq_payload_field "$payload" command)"; then
    return 0
  fi
  sb_jq_enforcement_block "$hook_name" "$emit_fn" "$(_sb_jq_payload_field "$payload" hook_event_name)"
}

sb_jq_missing_delivery_gate() {
  local hook_name="${1:-hook}" emit_fn="${2:-}" payload="${3:-}" classify_fn="${4:-}" cmd
  command -v jq >/dev/null 2>&1 && return 0
  _sb_jq_in_sb_project || return 0
  _sb_jq_shell_tool "$(_sb_jq_payload_field "$payload" tool_name)" || return 0
  cmd="$(_sb_jq_payload_field "$payload" command)"
  if [[ -n "$classify_fn" ]] && declare -f "$classify_fn" >/dev/null 2>&1; then
    "$classify_fn" "$cmd" || return 0
  else
    [[ "${cmd%%$'\n'*}" =~ $_SB_JQ_DELIVERY_RE ]] || return 0
  fi
  sb_jq_enforcement_block "$hook_name" "$emit_fn" "$(_sb_jq_payload_field "$payload" hook_event_name)"
}
