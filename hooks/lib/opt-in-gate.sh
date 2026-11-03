# shellcheck shell=bash
# Shared prelude and classification for the opt-in tool-stack hooks (graphify, agentmemory,
# RTK, Context Mode, LeanCTX, Alumnium, the stack coordinator, the token-compression gate
# and the usage recorders).
#
#   sb_opt_in_hook_begin HOOK TOOL...   read the payload and exit 0 (allow, record nothing)
#       unless the user has a consent record for one of the TOOLs and the working directory
#       is inside an initiated SB project (walk-only discovery: a cached project root from
#       another session never activates a gate here). The consent pre-check runs before any
#       jq or python3 process, so a user who never opted in pays almost nothing.
#       Sets: SB_OPT_IN_HOOK input hook_event config_file project_root tool_name
#   sb_opt_in_emit_block REASON          deny the tool call (PreToolUse) or block (other)
#   sb_opt_in_command_string             the shell command of the payload (string or argv)
#   sb_opt_in_target_paths               every file path the payload edits, one per line
#   sb_opt_in_normalize_path PATH [BASE] absolute path with '.', '..' and symlinked
#       directories (and a symlinked leaf) resolved physically; the leaf need not exist
#   sb_opt_in_path_under PATH DIR        status 0 when normalized PATH is DIR or inside it
#   sb_opt_in_shell_needs_gate TOOL CMD  status 0 when a shell command must pass the gate:
#       a command that delivers (commit, PR, release, or an opaque program word) an install, or that the
#       shared analyzer finds writing a file. TOOL's own setup/retrieval commands and
#       commands proven read-only are exempt; tests, builds and inspections are not gated.
#   sb_opt_in_shell_is_delivery CMD      status 0 when CMD commits, opens/merges a PR, releases, deploys or could
#   sb_opt_in_shell_is_install CMD       status 0 for a machine-wide install or a download piped to a shell
#   sb_opt_in_rtk_unwrap CMD             CMD without a leading RTK_DISABLED=… / rtk prefix

# Hooks and scripts source libraries by absolute path; no `pwd` runs here, so a fault in the
# working-directory lookup cannot break loading.
_sb_opt_in_lib_dir="${BASH_SOURCE[0]%/*}"
# shellcheck source=user-consent.sh
source "${_sb_opt_in_lib_dir}/user-consent.sh"

# Source a sibling library; a missing required one makes the calling hook exit 0 (inert).
_sb_opt_in_source_required() {
  [[ -f "${_sb_opt_in_lib_dir}/${1}" ]] || exit 0
  # shellcheck disable=SC1090
  source "${_sb_opt_in_lib_dir}/${1}"
}

_sb_opt_in_source_optional() {
  # shellcheck disable=SC1090
  [[ ! -f "${_sb_opt_in_lib_dir}/${1}" ]] || source "${_sb_opt_in_lib_dir}/${1}"
  return 0
}

# The shell-command and tool-name helpers; every consumer of this library wants them.
if ! declare -f sb_tool_name >/dev/null 2>&1; then
  _sb_opt_in_source_optional tool-input.sh
fi

sb_opt_in_hook_begin() {
  local hook="${1:-}" tool any=0
  shift
  SB_OPT_IN_HOOK="$hook"
  input="$(cat 2>/dev/null || true)"
  [[ -n "$input" ]] || exit 0
  for tool in "$@"; do
    if sb_consent_store_mentions "$tool"; then
      any=1
      break
    fi
  done
  [[ "$any" == 1 ]] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  # Required libraries: when one is missing the hook cannot tell where it is, so it stays inert.
  _sb_opt_in_source_required runtime-paths.sh
  _sb_opt_in_source_required sb-project-gate.sh
  _sb_opt_in_source_required recommended-tools.sh
  # Optional libraries: without one the gate still decides, minus that facility (no audit
  # record, no certification bypass, no trivial marker, built-in tool-name fallbacks).
  _sb_opt_in_source_optional cert-bypass.sh
  _sb_opt_in_source_optional trivial-bypass.sh
  _sb_opt_in_source_optional hook-audit.sh
  if ! declare -f sb_tool_name >/dev/null 2>&1; then _sb_opt_in_source_optional tool-input.sh; fi
  if ! declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
    sb_tool_is_shell_like() {
      case "${1:-}" in Bash | Shell | shell | exec_command) return 0 ;; esac
      return 1
    }
  fi
  declare -f sb_cert_run_bypass >/dev/null 2>&1 && sb_cert_run_bypass
  config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
  [[ -n "$config_file" ]] || exit 0
  if declare -f sb_project_is_initiated >/dev/null 2>&1; then
    sb_project_is_initiated "$config_file" || exit 0
  fi
  # shellcheck disable=SC2034  # read by the sourcing hook
  project_root="$(dirname "$config_file")"
  # A hook that must hold even for trivial work sets SB_OPT_IN_TRIVIAL_BYPASS=0 before the call.
  if [[ "${SB_OPT_IN_TRIVIAL_BYPASS:-1}" != 0 ]] && declare -f sb_trivial_bypass >/dev/null 2>&1; then
    local trivial_cfg
    trivial_cfg="$(jq -r '.state.trivial_file // "" | strings' "$config_file" 2>/dev/null || true)"
    trivial_cfg="${trivial_cfg/#\~/$HOME}"
    sb_trivial_bypass "${trivial_cfg:-${SB_RUNTIME_STATE_DIR}/trivial}"
  fi
  hook_event="$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse" | strings' 2>/dev/null || true)"
  hook_event="${hook_event:-PreToolUse}"
  tool_name="$(printf '%s' "$input" | jq -r '.tool_name // "" | strings' 2>/dev/null || true)"
}

sb_opt_in_emit_block() {
  local reason="${1:-}" json_reason
  json_reason="$(printf '%s' "$reason" | jq -Rs '.')"
  if declare -f sb_hook_audit_record >/dev/null 2>&1; then
    sb_hook_audit_record "${SB_OPT_IN_HOOK:-opt-in-gate}" "${hook_event:-PreToolUse}" "deny" "$reason" \
      "${file_path:-${command_str:-}}" 2>/dev/null || true
  fi
  if [[ "${hook_event:-PreToolUse}" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    if [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]]; then
      printf '%s\n' "$reason" >&2
      exit 2
    fi
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

# The shell command of the payload: tool_input.command or tool_input.cmd, a string or an
# argv list (shell-quoted with jq's @sh).
sb_opt_in_command_string() {
  printf '%s' "${input:-}" | jq -r '
    (.tool_input // {}) as $t
    | ($t.command // $t.cmd) as $c
    | if ($c | type) == "string" then $c
      elif ($c | type) == "array" then ($c | map(tostring | @sh) | join(" "))
      else "" end' 2>/dev/null || true
}

# sb_opt_in_edit_targets_exempt CHECK: status 0 when the payload names no target or CHECK
# PATH CONFIG accepts every target (an apply_patch touching one exempt file and one source
# file is not exempt). Sets file_path to the first target for the audit record.
sb_opt_in_edit_targets_exempt() {
  local check="${1:-}" path
  file_path=""
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -n "$file_path" ]] || file_path="$path"
    "$check" "$path" "${config_file:-}" || return 1
  done < <(sb_opt_in_target_paths)
  return 0
}

# sb_opt_in_mcp_call: status 0 for an MCP tool call, setting mcp_server, mcp_tool and
# mcp_args. Hosts that name MCP tools mcp__<server>__<tool> are handled by the first case; others send
# CallMcpTool/MCP with the server and tool in tool_input.
sb_opt_in_mcp_call() {
  local rest
  mcp_server=""
  mcp_tool=""
  mcp_args="{}"
  case "${tool_name:-}" in
    mcp__*__*)
      rest="${tool_name#mcp__}"
      mcp_tool="${rest##*__}"
      mcp_server="${rest%__*}"
      mcp_args="$(printf '%s' "${input:-}" | jq -c '.tool_input // {}' 2>/dev/null || printf '{}')"
      ;;
    CallMcpTool | MCP)
      mcp_server="$(printf '%s' "${input:-}" | jq -r '.tool_input.server // .tool_input.mcpServer // "" | strings' 2>/dev/null || true)"
      mcp_tool="$(printf '%s' "${input:-}" | jq -r '.tool_input.toolName // .tool_input.name // "" | strings' 2>/dev/null || true)"
      # shellcheck disable=SC2034  # read by the sourcing hook
      mcp_args="$(printf '%s' "${input:-}" | jq -c '.tool_input.arguments // .tool_input.args // {}' 2>/dev/null || printf '{}')"
      ;;
    *) return 1 ;;
  esac
  [[ -n "$mcp_server" && -n "$mcp_tool" ]]
}

# sb_opt_in_shell_succeeded: status 0 when the PostToolUse payload shows the shell command
# succeeded: an explicit exit code of 0, or, when no exit code is reported, non-empty
# output and no interruption or error flag. A missing exit code is never taken as success.
sb_opt_in_shell_succeeded() {
  [[ "$(printf '%s' "${input:-}" | jq -r '
    (.tool_response // null) as $r
    | if ($r | type) != "object" then "unknown"
      elif (($r.exit_code // $r.exitCode) != null) then
        (if (($r.exit_code // $r.exitCode) | tostring) == "0" then "ok" else "fail" end)
      elif ($r.interrupted == true or $r.is_error == true or $r.isError == true) then "fail"
      elif ((($r.stdout // $r.output // "") | tostring | length) > 0) then "ok"
      else "unknown" end' 2>/dev/null)" == "ok" ]]
}

# sb_opt_in_mcp_succeeded: status 0 unless the MCP result is flagged as an error.
sb_opt_in_mcp_succeeded() {
  ! printf '%s' "${input:-}" | jq -e '(.tool_response // {}) | type == "object" and (.is_error == true or .isError == true)' >/dev/null 2>&1
}

# Every path an Edit/Write/MultiEdit/apply_patch payload targets, one per line.
sb_opt_in_target_paths() {
  local direct
  direct="$(printf '%s' "${input:-}" | jq -r '.tool_input.file_path // .tool_input.path // "" | strings' 2>/dev/null || true)"
  if [[ -n "$direct" ]]; then
    printf '%s\n' "$direct"
    return 0
  fi
  sb_tool_patch_paths "${input:-}" 2>/dev/null || true
}

sb_opt_in_normalize_path() {
  local path="${1:-}" base="${2:-$PWD}" rest part out="" dir leaf probe suffix canon target hops=0
  [[ -n "$path" ]] || return 1
  while :; do
    case "$path" in
      \~/*) path="${HOME}/${path#\~/}" ;;
    esac
    [[ "$path" == /* ]] || path="${base%/}/${path}"
    rest="${path#/}"
    out=""
    while [[ -n "$rest" ]]; do
      part="${rest%%/*}"
      if [[ "$rest" == */* ]]; then rest="${rest#*/}"; else rest=""; fi
      case "$part" in
        "" | .) ;;
        ..) out="${out%/*}" ;;
        *) out="${out}/${part}" ;;
      esac
    done
    [[ -n "$out" ]] || { printf '/'; return 0; }
    dir="${out%/*}"
    leaf="${out##*/}"
    probe="${dir:-/}"
    suffix=""
    while [[ ! -d "$probe" ]]; do
      suffix="/${probe##*/}${suffix}"
      probe="${probe%/*}"
      probe="${probe:-/}"
    done
    canon="$(cd -P -- "$probe" 2>/dev/null && pwd -P)" || canon="$probe"
    out="${canon%/}${suffix}/${leaf}"
    # A symlinked leaf writes through to its target: resolve it (bounded, loops stop).
    if [[ -L "$out" && "$hops" -lt 8 ]] && target="$(readlink -- "$out" 2>/dev/null)" && [[ -n "$target" ]]; then
      hops=$((hops + 1))
      base="${out%/*}"
      path="$target"
      continue
    fi
    printf '%s' "$out"
    return 0
  done
}

# sb_opt_in_path_under PATH DIR: status 0 when PATH (normalized) is DIR (normalized) or
# below it. Component-wise: graphify-out/../src never counts as inside graphify-out.
sb_opt_in_path_under() {
  local path dir
  path="$(sb_opt_in_normalize_path "${1:-}")" || return 1
  dir="$(sb_opt_in_normalize_path "${2:-}")" || return 1
  [[ "$path" == "$dir" || "$path" == "${dir%/}"/* ]]
}

sb_opt_in_rtk_unwrap() {
  local cmd="${1:-}" re='^[[:space:]]*(RTK_DISABLED=[^[:space:]]*[[:space:]]+)?rtk[[:space:]]+(.+)$'
  if [[ "$cmd" =~ $re ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
  else
    printf '%s' "$cmd"
  fi
}

# Collapse runs of whitespace so a copied instruction matches its table entry.
_sb_opt_in_squash() {
  printf '%s' "${1:-}" | tr -s ' \t' '  ' | sed -e 's/^ //' -e 's/ $//'
}

# Status 0 when CMD is one simple command: no ; & | < > backquote, $( or newline anywhere.
_sb_opt_in_simple_command() {
  # shellcheck disable=SC2016  # '$(' is matched literally
  case "${1:-}" in
    *';'* | *'&'* | *'|'* | *'<'* | *'>'* | *'`'* | *'$('* | *$'\n'*) return 1 ;;
  esac
  return 0
}

# The first word of a simple command, with leading NAME=value assignments skipped
# (split on whitespace without pathname expansion).
_sb_opt_in_program() {
  local word
  local -a words
  read -r -a words <<<"${1:-}"
  # ${arr[@]+...}: an empty array is an unbound variable under set -u on Bash < 4.4
  for word in ${words[@]+"${words[@]}"}; do
    [[ "$word" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && continue
    printf '%s' "${word##*/}"
    return 0
  done
  return 1
}

# Status 0 when PROGRAM is a CLI that TOOL owns: running it is the tool's own setup or
# retrieval.
_sb_opt_in_tool_owns_program() {
  case "${1:-}:${2:-}" in
    graphify:graphify | graphify:graphifyy | agentmemory:agentmemory | rtk:rtk \
      | context_mode:context-mode | leanctx:lean-ctx | leanctx:leanctx | alumnium:alumnium)
      return 0
      ;;
  esac
  return 1
}

# Status 0 for a read-only call of the agentmemory REST API on loopback: every option is
# one curl reads with (an allowlist, so no output, config or upload option slips through)
# and every URL is http(s)://localhost:3111/agentmemory/... or 127.0.0.1.
_sb_opt_in_agentmemory_curl() {
  local squashed="${1:-}" word url_seen=0
  local -a words
  read -r -a words <<<"$squashed"
  [[ "${words[0]##*/}" == "curl" ]] || return 1
  for word in "${words[@]:1}"; do
    word="${word#[\"\']}"
    word="${word%[\"\']}"
    case "$word" in
      http://localhost:3111/agentmemory/* | http://127.0.0.1:3111/agentmemory/* \
        | https://localhost:3111/agentmemory/* | https://127.0.0.1:3111/agentmemory/*)
        url_seen=1
        ;;
      *://*) return 1 ;;
      --data | --data-raw | --data-binary | --data-urlencode | --header | --request | --max-time \
        | --json | --silent | --show-error | --fail | --location | --get | --include | --compressed \
        | --data=* | --data-raw=* | --header=* | --request=* | --max-time=* | --json=*)
        ;;
      --*) return 1 ;;
      -*)
        [[ "$word" =~ ^-([sSfLiG]+|[XHdm])$ ]] || return 1
        ;;
    esac
  done
  [[ "$url_seen" == 1 ]]
}

# Status 0 when CMD is one of TOOL's own commands: a simple command running the tool's CLI,
# Silver Bullet's own setup scripts (absolute path into this plugin), the agentmemory REST
# API on loopback, or an exact built-in install/start instruction for the tool.
sb_opt_in_tool_command() {
  local tool="${1:-}" cmd="${2:-}" squashed program line host
  squashed="$(_sb_opt_in_squash "$cmd")"
  [[ -n "$squashed" ]] || return 1
  if _sb_opt_in_simple_command "$squashed"; then
    program="$(_sb_opt_in_program "$squashed" || true)"
    if _sb_opt_in_tool_owns_program "$tool" "$program"; then
      return 0
    fi
    case "$squashed" in
      "bash ${_SB_RT_PLUGIN_ROOT}/scripts/"* | "python3 ${_SB_RT_PLUGIN_ROOT}/scripts/"*)
        [[ "$squashed" != *..* ]] && return 0
        ;;
    esac
    if [[ "$tool" == "agentmemory" ]] && _sb_opt_in_agentmemory_curl "$squashed"; then
      return 0
    fi
  fi
  host="$(sb_runtime_host)"
  while IFS= read -r line; do
    [[ "$(_sb_opt_in_squash "$line")" == "$squashed" ]] && return 0
  done < <(
    sb_recommended_tool_full_install_lines "" "$tool" "$host"
    printf '\n'
    _sb_opt_in_tool_extra_lines "$tool"
  )
  return 1
}

# Remedy commands the deny messages print that are not install lines.
_sb_opt_in_tool_extra_lines() {
  case "${1:-}" in
    agentmemory)
      printf '%s\n' 'nohup agentmemory > ~/.agentmemory/server.log 2>&1 &' \
        'mkdir -p ~/.agentmemory && nohup agentmemory > ~/.agentmemory/server.log 2>&1 &'
      ;;
    rtk) printf '%s\n' 'brew uninstall rtk 2>/dev/null; brew tap rtk-ai/rtk && brew install rtk' ;;
  esac
}

# Shell classification uses the shared analyzer (shell-analysis.sh): one python3 run per
# command, with real tokenizing, so quoting, wrappers, git aliases and variables are seen
# through. _sb_opt_in_classify loads CMD and sets _SB_OPT_IN_{DELIVERY,INSTALL,WRITES,READ_ONLY}
# (1/0). When the analyzer is unavailable (python3 or tool-input.sh missing) every command counts as possible delivery, so a consented gate still gates.
_sb_opt_in_classify() {
  local cmd="${1:-}"
  _SB_OPT_IN_DELIVERY=0 _SB_OPT_IN_INSTALL=0 _SB_OPT_IN_WRITES=0 _SB_OPT_IN_READ_ONLY=0
  # Without the analyzer nothing can be told apart: treat the command as possible delivery.
  declare -f sb_shell_analysis_load >/dev/null 2>&1 || { _SB_OPT_IN_DELIVERY=1; return 0; }
  sb_shell_analysis_load "$cmd" "$PWD"
  [[ "$SB_TI_STATUS" == "ok" ]] || { _SB_OPT_IN_DELIVERY=1; return 0; }
  [[ "$SB_SA_READ_ONLY" == "true" ]] && _SB_OPT_IN_READ_ONLY=1
  [[ -n "$SB_SA_WRITE_PATHS" ]] && _SB_OPT_IN_WRITES=1
  # A commit, PR, release or deploy, or code that could be one (`$G commit`, eval, a download
  # piped into a shell: the analyzer reports those as opaque/unseen).
  case " $SB_SA_ACTIONS $SB_SA_POSSIBLE_ACTIONS " in
    *" commit "* | *" pr_create "* | *" pr_merge "* | *" release_create "* | *" deploy "* | *" unseen "*)
      _SB_OPT_IN_DELIVERY=1 ;;
  esac
  # Machine-wide installs, from the parsed argv of every command.
  jq -e '[.commands[]? | .argv as $a | ($a[0] // "" | split("/") | last) as $p
      | ($a[1:] | map(select(startswith("-") | not))) as $w
      | ($a[1:] | any(. == "-g" or . == "--global")) as $g
      | ($p == "sudo")
        or (($p == "npm" or $p == "pnpm" or $p == "yarn" or $p == "bun")
            and (($g and ($w | any(. == "install" or . == "i" or . == "add"))) or ($w[0:2] == ["global", "add"])))
        or ($p == "brew" and ($w[0] | IN("install", "upgrade", "tap")))
        or (($p == "pipx" or $p == "cargo" or $p == "gem" or $p == "go") and ($w[0] == "install"))
        or ($p == "uv" and ($w[0:2] == ["tool", "install"]))] | any' <<<"$SB_SA_JSON" >/dev/null 2>&1 \
    && _SB_OPT_IN_INSTALL=1
  return 0
}

# Status 0 when CMD commits, opens or merges a PR, creates a release, deploys, or could
# (git merge/cherry-pick/revert/am, `git --no-pager commit`, aliases, `$G commit`, eval).
sb_opt_in_shell_is_delivery() {
  [[ -n "${1:-}" ]] || return 1
  _sb_opt_in_classify "$1"
  [[ "$_SB_OPT_IN_DELIVERY" == 1 ]]
}

# Status 0 when CMD installs software machine-wide (sudo, a global package install, brew,
# pipx/cargo/go/gem/uv tool install).
sb_opt_in_shell_is_install() {
  [[ -n "${1:-}" ]] || return 1
  _sb_opt_in_classify "$1"
  [[ "$_SB_OPT_IN_INSTALL" == 1 ]]
}

# A shell command is gated when it writes files, delivers or installs; ordinary test, build
# and inspection commands (pytest, $PYTHON -m pytest, make test, cargo build, docker ps) are
# never gated.
sb_opt_in_shell_needs_gate() {
  local tool="${1:-}" cmd="${2:-}" unwrapped
  [[ -n "$cmd" ]] || return 1
  unwrapped="$(sb_opt_in_rtk_unwrap "$cmd")"
  if sb_opt_in_tool_command "$tool" "$cmd" || sb_opt_in_tool_command "$tool" "$unwrapped"; then
    return 1
  fi
  _sb_opt_in_classify "$unwrapped"
  [[ "$_SB_OPT_IN_READ_ONLY" == 1 ]] && return 1
  [[ "$_SB_OPT_IN_DELIVERY" == 1 || "$_SB_OPT_IN_INSTALL" == 1 || "$_SB_OPT_IN_WRITES" == 1 ]]
}
