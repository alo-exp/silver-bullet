#!/usr/bin/env bash
# shellcheck disable=SC2034  # the SB_* variables are outputs, read by the hooks that source this file
# Shell-command and hook-payload analysis for Silver Bullet gates (load once per hook, then query).
#
#   sb_tool_input_load "$input" [base-dir]   # the hook payload JSON; call once, in the hook's
#                                            # main shell (not inside $(...)), right after input=$(cat)
#   sb_shell_analysis_load "$cmd" [base-dir] # or any shell command (a script body, a git alias)
#
# Each load runs hooks/lib/tool-input/shell_analysis.py once with the input on stdin (no
# argv size limit) and never fails. It sets:
#
#   SB_TI_STATUS      ok | empty | parse_failed | helper_unavailable
#   SB_TI_ERROR       why, when SB_TI_STATUS is not ok
#   SB_TI_TOOL_NAME   SB_TI_TOOL_KIND (shell|mcp|patch|edit|other)
#   SB_TI_COMMAND     SB_TI_FILE_PATH  SB_TI_PATCH_PATHS (one per line)
#   SB_SA_ACTIONS     space-separated: commit push pr_create pr_merge release_create deploy remote_write
#   SB_SA_TIER        none | intermediate (commit, push) | completion (everything else)
#   SB_SA_POSSIBLE_ACTIONS / SB_SA_POSSIBLE_TIER / SB_SA_COULD_BE_DELIVERY
#                     actions an opaque part could perform, judged from its visible arguments
#                     (`$G commit -m x` -> commit; `$PYTHON -m pytest` -> none)
#   SB_SA_OPAQUE (true|false), SB_SA_OPAQUE_REASONS (one per line)
#   SB_SA_READ_ONLY (strict allowlist), SB_SA_READ_ONLY_LEGACY (also plain test runners)
#   SB_SA_WRITE_PATHS (one per line), SB_SA_SKILL_ADAPTER, SB_SA_RTK_UNWRAPPED,
#   SB_SA_INVOKED_SCRIPT, SB_SA_LEGACY_FIRST_LINE
#   SB_SA_JSON        the whole analysis; its schema is documented in shell_analysis.py
#
# Fail closed in core gates on SB_TI_STATUS=parse_failed|helper_unavailable (shell tools),
# using sb_shell_analysis_helper_message for the second. The legacy accessors in
# tool-input.sh reuse a load of the same payload or command when the hook made one;
# without a prior load each accessor starts python3 itself (completion-audit's
# classifier loads once; other gates adopt sb_tool_input_load as they are reworked).
#
# SB_SA_POSSIBLE_ACTIONS may contain `unseen`: code that runs but cannot be read (see the
# schema in shell_analysis.py). It makes SB_SA_POSSIBLE_TIER completion, so gates that use
# sb_shell_analysis_effective_tier hold it at the strictest floor.

_sb_sa_helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tool-input/analyze.py"

_sb_sa_reset() {
  SB_TI_STATUS="helper_unavailable"
  SB_TI_ERROR="${1:-}"
  SB_TI_TOOL_NAME="" SB_TI_TOOL_KIND="" SB_TI_COMMAND="" SB_TI_FILE_PATH="" SB_TI_PATCH_PATHS=""
  SB_SA_ACTIONS="" SB_SA_TIER="none" SB_SA_POSSIBLE_ACTIONS="" SB_SA_POSSIBLE_TIER="none"
  SB_SA_COULD_BE_DELIVERY="false" SB_SA_OPAQUE="false" SB_SA_OPAQUE_REASONS=""
  SB_SA_READ_ONLY="false" SB_SA_READ_ONLY_LEGACY="false" SB_SA_WRITE_PATHS="" SB_SA_SKILL_ADAPTER="false"
  SB_SA_RTK_UNWRAPPED="" SB_SA_INVOKED_SCRIPT="" SB_SA_LEGACY_FIRST_LINE="" SB_SA_JSON="{}"
  _SB_SA_LOADED=0
}

# _sb_sa_run MODE INPUT [BASE]: run the helper and read its NUL-separated key/value records.
_sb_sa_run() {
  local mode="$1" input="$2" base="${3:-$PWD}" key value complete=0
  _sb_sa_reset "python3 is not installed or not on PATH"
  command -v python3 >/dev/null 2>&1 || return 0
  while IFS= read -r -d '' key && IFS= read -r -d '' value; do
    case "$key" in
      status) SB_TI_STATUS="$value" ;;
      error) SB_TI_ERROR="$value" ;;
      tool_name) SB_TI_TOOL_NAME="$value" ;;
      tool_kind) SB_TI_TOOL_KIND="$value" ;;
      command) SB_TI_COMMAND="$value" ;;
      file_path) SB_TI_FILE_PATH="$value" ;;
      patch_paths) SB_TI_PATCH_PATHS="$value" ;;
      actions) SB_SA_ACTIONS="$value" ;;
      tier) SB_SA_TIER="$value" ;;
      possible_actions) SB_SA_POSSIBLE_ACTIONS="$value" ;;
      possible_tier) SB_SA_POSSIBLE_TIER="$value" ;;
      could_be_delivery) SB_SA_COULD_BE_DELIVERY="$value" ;;
      opaque) SB_SA_OPAQUE="$value" ;;
      opaque_reasons) SB_SA_OPAQUE_REASONS="$value" ;;
      read_only) SB_SA_READ_ONLY="$value" ;;
      read_only_legacy) SB_SA_READ_ONLY_LEGACY="$value" ;;
      write_paths) SB_SA_WRITE_PATHS="$value" ;;
      skill_adapter) SB_SA_SKILL_ADAPTER="$value" ;;
      rtk_unwrapped) SB_SA_RTK_UNWRAPPED="$value" ;;
      invoked_script) SB_SA_INVOKED_SCRIPT="$value" ;;
      legacy_first_line) SB_SA_LEGACY_FIRST_LINE="$value" ;;
      base_dir) _SB_SA_LOADED_BASE="$value" ;;
      json) SB_SA_JSON="$value" ;;
      __end__) complete=1 ;;
    esac
  done < <(printf '%s' "$input" | python3 "$_sb_sa_helper" "$mode" --base-dir "$base" 2>/dev/null)
  if [[ "$complete" -ne 1 ]]; then
    _sb_sa_reset "the python3 helper failed: $_sb_sa_helper"
    return 0
  fi
  _SB_SA_LOADED=1
}

sb_tool_input_load() {
  _sb_sa_run load-payload "${1:-}" "${2:-}"
  _SB_TI_LOADED_PAYLOAD="${1:-}"
  _SB_SA_LOADED_COMMAND="$SB_TI_COMMAND"
}

sb_shell_analysis_load() {
  _sb_sa_run load-command "${1:-}" "${2:-}"
  _SB_TI_LOADED_PAYLOAD=""
  _SB_SA_LOADED_COMMAND="${1:-}"
}

# _sb_sa_loaded_payload PAYLOAD / _sb_sa_loaded_command COMMAND [BASE]: true when the last
# successful load analysed exactly this input (so the legacy accessors can reuse it).
_sb_sa_loaded_payload() {
  [[ "${_SB_SA_LOADED:-0}" -eq 1 && -n "${_SB_TI_LOADED_PAYLOAD:-}" && "$1" == "$_SB_TI_LOADED_PAYLOAD" ]]
}

_sb_sa_loaded_command() {
  [[ "${_SB_SA_LOADED:-0}" -eq 1 && "$1" == "${_SB_SA_LOADED_COMMAND:-}" ]] || return 1
  [[ $# -lt 2 || "$2" == "${_SB_SA_LOADED_BASE:-}" ]]
}

sb_tool_input_ok() {
  [[ "${SB_TI_STATUS:-}" == "ok" ]]
}

sb_shell_analysis_helper_message() {
  printf '🛑 Silver Bullet cannot inspect this tool call: %s.\n\npython3 is a required prerequisite. Install it (macOS: xcode-select --install or brew install python; Debian/Ubuntu: apt install python3), make sure python3 is on the PATH the agent host gives hooks, then retry.' \
    "${SB_TI_ERROR:-the python3 helper is unavailable}"
}

# sb_shell_analysis_has_action ACTION: the analysed input performs ACTION.
sb_shell_analysis_has_action() {
  [[ " ${SB_SA_ACTIONS:-} " == *" $1 "* ]]
}

# sb_shell_analysis_may_deliver ACTION: performs ACTION, or an opaque part could.
sb_shell_analysis_may_deliver() {
  sb_shell_analysis_has_action "$1" || [[ " ${SB_SA_POSSIBLE_ACTIONS:-} " == *" $1 "* ]]
}

# sb_shell_analysis_effective_tier: the higher of SB_SA_TIER and SB_SA_POSSIBLE_TIER.
sb_shell_analysis_effective_tier() {
  case "${SB_SA_TIER:-none} ${SB_SA_POSSIBLE_TIER:-none}" in
    *completion*) printf 'completion' ;;
    *intermediate*) printf 'intermediate' ;;
    *) printf 'none' ;;
  esac
}

# sb_shell_analysis_invokes NAME [ARG...]: some command runs program NAME (or an interpreter
# running script NAME, NAME.ext) with ARG... as its first arguments. Needs jq.
sb_shell_analysis_invokes() {
  local name="$1"
  shift
  printf '%s' "${SB_SA_JSON:-}" | jq -e --arg name "$name" '
    def base: split("/") | last;
    ($ARGS.positional) as $want
    | [.commands[]?.argv
       | if (.[0] | base) == $name then .[1:]
         elif (.[0] | base | test("^(node|nodejs|python[0-9.]*|bash|sh|zsh|ruby|perl|deno|bun)$"))
              and length > 1 and ((.[1] | base) == $name or (.[1] | base | sub("\\.[A-Za-z0-9]+$"; "")) == $name)
         then .[2:]
         else null end
       | select(. != null and .[0:($want | length)] == $want)]
    | length > 0' --args "$@" >/dev/null 2>&1
}
