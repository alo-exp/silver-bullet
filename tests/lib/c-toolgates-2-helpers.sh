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
  ln -s "$TL_REPO_ROOT/templates" "$root/templates"
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

# tg2_install_jq_stub: jq wrapper that fails when JQ_FAIL is a substring of its argument
# list, so one jq call inside a hook can be made to fail while the others behave normally.
tg2_install_jq_stub() {
  local real
  real="$(command -v jq)"
  tl_stub jq "if [[ -n \"\${JQ_FAIL:-}\" && \"\$*\" == *\"\$JQ_FAIL\"* ]]; then exit 1; fi
exec $real \"\$@\""
}

# tg2_gate_suite <hook> <audit-name> <deny-input> <reason> <target> <trivial:yes|no> <bridge:yes|no>
# Shared prologue assertions for the deny-style PreToolUse gates. The caller defines
# tg2_scenario_block (arrange state so <deny-input> is denied with <reason>) and
# tg2_scenario_off <mode> (disable the gate: optout|suspended).
tg2_gate_suite() {
  local hook="$1" name="$2" input="$3" reason="$4" target="$5" trivial="$6" bridge="$7"
  local post_input saved
  post_input="$(jq -c '.hook_event_name = "PostToolUse"' <<<"$input")"

  tg2_scenario_block
  rm -f "$TG2_AUDIT"
  tg2_run "$hook" "$input"
  assert_denied "$name: baseline is denied" "$reason"
  assert_eq "$name: baseline exits 0" "0" "$TL_STATUS"
  assert_eq "$name: deny is audited" "deny" "$(jq -rs 'last.decision // ""' "$TG2_AUDIT" 2>/dev/null || true)"
  assert_eq "$name: audit hook name" "$name" "$(jq -rs 'last.hook_name // ""' "$TG2_AUDIT" 2>/dev/null || true)"
  assert_eq "$name: audit target" "$target" "$(jq -rs 'last.target // ""' "$TG2_AUDIT" 2>/dev/null || true)"

  tg2_run "$hook" "$post_input"
  assert_eq "$name: non-PreToolUse event blocks with decision=block" "block" "$(tg2_decision)"
  assert_contains "$name: block carries the message" "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message // ""')" "$reason"
  tg2_run "$hook" "$post_input" JQ_FAIL=hook_event_name
  assert_eq "$name: unreadable event name defaults to PreToolUse" "deny" "$(tg2_decision)"

  tg2_run "$hook" "$input" SB_KAY_HOOK_BRIDGE_INVOKED=1
  assert_eq "$name: bridge deny JSON still emitted" "deny" "$(tg2_decision)"
  if [[ "$bridge" == yes ]]; then
    assert_eq "$name: bridge invocation exits 2" "2" "$TL_STATUS"
    assert_contains "$name: bridge invocation prints the reason on stderr" "$TL_ERR" "$reason"
    tg2_run "$hook" "$post_input" SB_KAY_HOOK_BRIDGE_INVOKED=1
    assert_eq "$name: bridge env leaves non-PreToolUse at exit 0" "0" "$TL_STATUS"
  else
    assert_eq "$name: bridge env does not change the exit status" "0" "$TL_STATUS"
  fi

  tg2_run "$hook" ""
  assert_silent_ok "$name: empty stdin allows"
  TG2_STDIN_DIR=1 tg2_run "$hook" ""
  assert_silent_ok "$name: unreadable stdin allows"
  tg2_run "$hook" "not json at all"
  if [[ "${TG2_GARBAGE_DENIES:-}" == yes ]]; then
    assert_denied "$name: unparsable stdin is denied while the gate is armed (fail-closed)" "$reason"
  else
    assert_silent_ok "$name: unparsable stdin allows"
  fi
  TG2_PATH="$(tl_path_without jq)" tg2_run "$hook" "$input"
  assert_silent_ok "$name: missing jq allows (fail-open)"
  tg2_run "$hook" "$input" SB_AGENT_CERT_RUN=1
  assert_silent_ok "$name: cert-run bypass (=1)"
  tg2_run "$hook" "$input" SB_AGENT_CERT_RUN=true
  assert_silent_ok "$name: cert-run bypass (=true)"
  tg2_run "$hook" "$input" SB_AGENT_CERT_RUN=0
  assert_denied "$name: cert-run flag =0 does not bypass" "$reason"

  saved="$(<"$TG2_CFG")"
  printf '{ broken json' >"$TG2_CFG"
  tg2_run "$hook" "$input"
  assert_silent_ok "$name: unparsable project config allows (fail-open)"
  printf '%s' "$saved" >"$TG2_CFG"
  TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$hook" "$input"
  assert_silent_ok "$name: outside any SB project allows"
  rm -f "$TG2_CFG" "$SB_RUNTIME_STATE_DIR/project-root"
  tg2_run "$hook" "$input"
  assert_silent_ok "$name: missing project config allows"
  printf '%s' "$saved" >"$TG2_CFG"
  tg2_scenario_off optout
  tg2_run "$hook" "$input"
  assert_silent_ok "$name: opted-out tool allows"
  printf '%s' "$saved" >"$TG2_CFG"
  tg2_scenario_off suspended
  tg2_run "$hook" "$input"
  assert_silent_ok "$name: suspended enforcement allows"
  printf '%s' "$saved" >"$TG2_CFG"

  if [[ "$trivial" == yes ]]; then
    printf 'x' >"$SB_RUNTIME_STATE_DIR/trivial"
    tg2_run "$hook" "$input"
    assert_silent_ok "$name: trivial marker (default path) allows"
    rm -f "$SB_RUNTIME_STATE_DIR/trivial"
    jq '.state.trivial_file = "~/custom-trivial"' "$TG2_CFG" >"$TG2_CFG.n" && mv "$TG2_CFG.n" "$TG2_CFG"
    tg2_run "$hook" "$input"
    assert_denied "$name: configured trivial path absent still gates" "$reason"
    printf 'x' >"$HOME/custom-trivial"
    tg2_run "$hook" "$input"
    assert_silent_ok "$name: trivial marker (configured ~ path) allows"
    rm -f "$HOME/custom-trivial"
    tg2_run "$hook" "$input" JQ_FAIL=.state.trivial_file
    assert_denied "$name: unreadable trivial_file setting falls back to default" "$reason"
    printf '%s' "$saved" >"$TG2_CFG"
    ln -s "$TL_TMP/trivial-target" "$SB_RUNTIME_STATE_DIR/trivial"
    : >"$TL_TMP/trivial-target"
    tg2_run "$hook" "$input"
    assert_denied "$name: symlinked trivial marker is ignored" "$reason"
    rm -f "$SB_RUNTIME_STATE_DIR/trivial"
  fi

  # library faults
  tg2_farm "walk-$name" "$hook" sb-project-gate.sh project-active.sh
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TG2_PROJ/src" tg2_run "$hook" "$input"
  assert_denied "$name: walk-up fallback finds the config from a subdirectory" "$reason"
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TL_TMP/outside" tg2_run "$hook" "$input"
  assert_silent_ok "$name: walk-up fallback stops at the filesystem root"
  mkdir -p "$TL_TMP/gitonly/sub"
  git -C "$TL_TMP/gitonly" init -q 2>/dev/null
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TL_TMP/gitonly/sub" tg2_run "$hook" "$input"
  assert_silent_ok "$name: walk-up fallback stops at a .git boundary"
  tg2_farm "inactive-$name" "$hook" project-active.sh
  tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }
sb_project_is_initiated() { return 1; }'
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$input"
  assert_silent_ok "$name: uninitiated project allows"
  tg2_farm "noti-$name" "$hook" tool-input.sh
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$input"
  assert_denied "$name: jq fallbacks still gate without tool-input.sh" "$reason"
  tg2_farm "noaudit-$name" "$hook" hook-audit.sh
  rm -f "$TG2_AUDIT"
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$input"
  assert_denied "$name: deny works without hook-audit.sh" "$reason"
  assert_file_absent "$name: nothing audited without hook-audit.sh" "$TG2_AUDIT"
  tg2_farm "nocert-$name" "$hook" cert-bypass.sh
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$input" SB_AGENT_CERT_RUN=1
  assert_denied "$name: without cert-bypass.sh the flag is not honoured" "$reason"
  tg2_farm "nolib-$name" "$hook" -
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$input"
  assert_silent_ok "$name: missing lib dir fails open"
  tg2_scenario_block
}
