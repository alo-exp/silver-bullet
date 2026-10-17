# shellcheck shell=bash
# Shared helpers for the C-toolgates-2 hook tests (record-* recorders, rtk gate,
# stack compression coordinator/lifecycle, token compression gate). Source after tl_init.
#
#   tg2_init_project            create $TG2_PROJ (git repo + silver-bullet.md), TG2_CFG path
#   tg2_cfg '<json>'            write the project config
#   tg2_run <hook> <stdin> [VAR=val ...]   run a hook from inside the project
#   tg2_farm <name> <hook> [lib basenames to omit | -]   symlink farm for missing-library paths
#   tg2_edit_input / tg2_bash_input / tg2_mcp_input   build hook payloads
#
# tg2_run honours TG2_CWD (working dir), TG2_PROJECT_ROOT (SILVER_BULLET_PROJECT_ROOT),
# TG2_PATH (PATH override) and TG2_REPO (alternate hook tree, e.g. a farm).

TG2_REPO="$TL_REPO_ROOT"

tg2_init_project() {
  TG2_PROJ="$TL_TMP/project"
  TG2_CFG="$TG2_PROJ/.silver-bullet.json"
  TG2_AUDIT="$SB_RUNTIME_STATE_DIR/gate-audit.jsonl"
  mkdir -p "$TG2_PROJ/src" "$TL_TMP/outside"
  git -C "$TG2_PROJ" init -q 2>/dev/null
  printf '# Silver Bullet\n' >"$TG2_PROJ/silver-bullet.md"
  : >"$TG2_PROJ/src/app.js"
  rm -f "$SB_RUNTIME_STATE_DIR/project-root"
  TG2_BASE_PATH="$(tl_path_without graphify agentmemory lean-ctx leanctx context-mode rtk npx npm node curl)"
}

tg2_cfg() { printf '%s' "$1" >"$TG2_CFG"; }

tg2_edit_input() { # [file] [tool] [event]
  jq -cn --arg f "${1:-$TG2_PROJ/src/app.js}" --arg t "${2:-Edit}" --arg e "${3:-PreToolUse}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{file_path:$f, old_string:"a", new_string:"b"}}'
}

tg2_bash_input() { # command [tool] [event] [exit_code]
  jq -cn --arg c "$1" --arg t "${2:-Bash}" --arg e "${3:-PreToolUse}" --argjson x "${4:-0}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{command:$c}, tool_response:{exit_code:$x}}'
}

tg2_mcp_input() { # server tool [tool-name-field] [event]
  jq -cn --arg s "$1" --arg n "$2" --arg t "${3:-CallMcpTool}" --arg e "${4:-PostToolUse}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{server:$s, toolName:$n}}'
}

# tg2_run <hook relative path> <stdin> [VAR=val ...]: sets TL_OUT TL_ERR TL_STATUS.
tg2_run() {
  local hook="$1" input="$2"
  shift 2
  local out="$TL_TMP/.tg2.out" err="$TL_TMP/.tg2.err"
  TL_STATUS=0
  if [[ -z "${TG2_PROJECT_ROOT-$TG2_PROJ}" ]]; then rm -f "$SB_RUNTIME_STATE_DIR/project-root"; fi
  (
    cd "${TG2_CWD:-$TG2_PROJ}"
    if [[ -n "${TG2_STDIN_DIR:-}" ]]; then
      env \
        PATH="${TG2_PATH:-$TL_BIN:$TG2_BASE_PATH}" \
        SILVER_BULLET_PROJECT_ROOT="${TG2_PROJECT_ROOT-$TG2_PROJ}" \
        SILVER_BULLET_HOOK_AUDIT_LOG="$TG2_AUDIT" \
        SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-claude}" \
        "$@" bash "${TG2_REPO}/$hook" <"$TL_TMP"
    else
      printf '%s' "$input" | env \
        PATH="${TG2_PATH:-$TL_BIN:$TG2_BASE_PATH}" \
        SILVER_BULLET_PROJECT_ROOT="${TG2_PROJECT_ROOT-$TG2_PROJ}" \
        SILVER_BULLET_HOOK_AUDIT_LOG="$TG2_AUDIT" \
        SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-claude}" \
        "$@" bash "${TG2_REPO}/$hook"
    fi
  ) >"$out" 2>"$err" || TL_STATUS=$?
  TL_OUT="$(<"$out")"
  TL_ERR="$(<"$err")"
}

tg2_decision() {
  printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecision // .decision // ""' 2>/dev/null || true
}

tg2_reason() {
  printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // .reason // ""' 2>/dev/null || true
}

# assert_silent_ok <name>: exit 0 and no stdout
assert_silent_ok() {
  if [[ "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} err=${TL_ERR:0:200})"; fi
}

assert_denied() { # name [reason substring]
  if [[ "$(tg2_decision)" == "deny" && ( -z "${2:-}" || "$(tg2_reason)" == *"$2"* ) ]]; then
    tl_pass "$1"
  else
    tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:300} err=${TL_ERR:0:200})"
  fi
}

# tg2_farm <name> <hook relative path> [excluded lib basenames... | -]
# Builds $TL_TMP/farm-<name>/{hook, hooks/lib/*} from symlinks to the real files minus the
# excluded libs ("-" drops the whole lib dir) and sets TG2_REPO to the farm root.
tg2_farm() {
  local name="$1" hook="$2" root f ex skip
  shift 2
  root="$TL_TMP/farm-$name"
  rm -rf "$root"
  mkdir -p "$root/hooks/lib"
  ln -s "$TL_REPO_ROOT/$hook" "$root/$hook"
  if [[ "${1:-}" == "-" ]]; then
    rmdir "$root/hooks/lib"
  else
    for f in "$TL_REPO_ROOT"/hooks/lib/*; do
      skip=0
      for ex in "$@"; do [[ "${f##*/}" == "$ex" ]] && skip=1; done
      [[ "$skip" -eq 1 ]] || ln -s "$f" "$root/hooks/lib/${f##*/}"
    done
  fi
  TG2_FARM="$root"
  export TG2_FARM
}

# tg2_farm_stub <lib basename> <body>: replace a farm lib symlink (from the last tg2_farm)
# with a stub file defining the given shell body, to inject faults into a sourced library.
tg2_farm_stub() {
  rm -f "$TG2_FARM/hooks/lib/$1"
  printf '%s\n' "$2" >"$TG2_FARM/hooks/lib/$1"
}
