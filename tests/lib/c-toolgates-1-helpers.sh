# shellcheck shell=bash
# Shared helpers for the opt-in tool gate hook tests (agentmemory, alumnium,
# context-mode, graphify, leanctx PreToolUse gates). Source after tl_init.
#
#   gh_init_project            create $GH_PROJ (git repo + silver-bullet.md), GH_CFG path
#   gh_cfg '<json>'            write the project config
#   gh_run <hook> <stdin> [VAR=val ...]   run a hook from inside the project
#   gh_edit_input / gh_bash_input         build PreToolUse payloads
#   gh_prelude_suite           assertions for the shared hook prologue

GH_REPO="$TL_REPO_ROOT"

gh_init_project() {
  GH_PROJ="$TL_TMP/project"
  GH_CFG="$GH_PROJ/.silver-bullet.json"
  GH_AUDIT="$SB_RUNTIME_STATE_DIR/gate-audit.jsonl"
  mkdir -p "$GH_PROJ/src" "$GH_PROJ/e2e"
  git -C "$GH_PROJ" init -q 2>/dev/null
  printf '# Silver Bullet\n' >"$GH_PROJ/silver-bullet.md"
  : >"$GH_PROJ/src/app.js"
  : >"$GH_PROJ/e2e/login.spec.ts"
  rm -f "$SB_RUNTIME_STATE_DIR/project-root"
  # PATH without the real tool CLIs: tests re-add stubs where they need them.
  GH_BASE_PATH="$(tl_path_without graphify agentmemory lean-ctx leanctx context-mode rtk npx npm node curl)"
}

gh_cfg() { printf '%s' "$1" >"$GH_CFG"; }

gh_edit_input() { # [file] [tool] [event]
  jq -cn --arg f "${1:-$GH_PROJ/src/app.js}" --arg t "${2:-Edit}" --arg e "${3:-PreToolUse}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{file_path:$f, old_string:"a", new_string:"b"}}'
}

gh_bash_input() { # command [tool] [event]
  jq -cn --arg c "$1" --arg t "${2:-Bash}" --arg e "${3:-PreToolUse}" \
    '{hook_event_name:$e, tool_name:$t, tool_input:{command:$c}}'
}

# gh_run <hook relative path> <stdin> [VAR=val ...]: sets TL_OUT TL_ERR TL_STATUS.
# GH_PATH overrides the PATH the hook sees (default: PATH without real tool CLIs + $TL_BIN).
gh_run() {
  local hook="$1" input="$2"
  shift 2
  local out="$TL_TMP/.gh.out" err="$TL_TMP/.gh.err"
  TL_STATUS=0
  (
    cd "${GH_CWD:-$GH_PROJ}"
    printf '%s' "$input" | env \
      PATH="${GH_PATH:-$TL_BIN:$GH_BASE_PATH}" \
      SILVER_BULLET_PROJECT_ROOT="${GH_PROJECT_ROOT-$GH_PROJ}" \
      SILVER_BULLET_HOOK_AUDIT_LOG="$GH_AUDIT" \
      SILVER_BULLET_RUNTIME=claude \
      "$@" bash "$GH_REPO/$hook"
  ) >"$out" 2>"$err" || TL_STATUS=$?
  TL_OUT="$(<"$out")"
  TL_ERR="$(<"$err")"
}

gh_decision() { # prints permissionDecision or decision from TL_OUT ("" when none)
  printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecision // .decision // ""' 2>/dev/null || true
}

gh_reason() {
  printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // .reason // ""' 2>/dev/null || true
}

# assert_gate_allows <name>: exit 0 and no output after the last gh_run
assert_gate_allows() {
  if [[ "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} err=${TL_ERR:0:200})"; fi
}

# assert_gate_denies <name> [reason-substring]
assert_gate_denies() {
  local name="$1" needle="${2:-}"
  if [[ "$(gh_decision)" == "deny" ]]; then
    if [[ -z "$needle" || "$(gh_reason)" == *"$needle"* ]]; then tl_pass "$name"; else tl_fail "$name (reason lacks '$needle': $(gh_reason | head -3))"; fi
  else
    tl_fail "$name (expected deny; status=$TL_STATUS out=${TL_OUT:0:200} err=${TL_ERR:0:200})"
  fi
}

# gh_prelude_suite <hook> <audit-name> <tool-id> <exempt-path> <exempt-cmd> <edit-path> <block-reason>
# The caller must define gh_scenario_block: arrange state so editing <edit-path> is denied
# with <block-reason> in the message. The suite re-invokes it between variations.
gh_prelude_suite() {
  local hook="$1" name="$2" tool="$3" exempt_path="$4" exempt_cmd="$5" edit_path="$6" reason="$7"
  local edit bashcmd="sed -i s/a/b/ src/app.js"
  edit="$(gh_edit_input "$edit_path")"
  : "$bashcmd"

  gh_scenario_block
  rm -f "$GH_AUDIT"
  gh_run "$hook" "$edit"
  assert_gate_denies "$name: baseline edit is denied" "$reason"
  assert_eq "$name: baseline exit status" "0" "$TL_STATUS"
  assert_eq "$name: deny audited" "deny" "$(jq -rs 'last.decision // ""' "$GH_AUDIT" 2>/dev/null || true)"
  assert_eq "$name: audit hook name" "$name" "$(jq -rs 'last.hook_name // ""' "$GH_AUDIT" 2>/dev/null || true)"
  assert_eq "$name: audit target is the edited path" "$edit_path" "$(jq -rs 'last.target // ""' "$GH_AUDIT" 2>/dev/null || true)"

  # event format variations
  gh_run "$hook" "$(gh_edit_input "$edit_path" Edit PostToolUse)"
  assert_eq "$name: non-PreToolUse event blocks with decision=block" "block" "$(gh_decision)"
  assert_contains "$name: block output carries hookSpecificOutput.message" "$(printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message // ""')" "$reason"
  gh_run "$hook" "$edit" SB_KAY_HOOK_BRIDGE_INVOKED=1
  assert_eq "$name: bridge invocation exits 2" "2" "$TL_STATUS"
  assert_contains "$name: bridge invocation prints reason on stderr" "$TL_ERR" "$reason"
  assert_eq "$name: bridge invocation still emits deny JSON" "deny" "$(gh_decision)"
  gh_run "$hook" "$(gh_edit_input "$edit_path" Edit PostToolUse)" SB_KAY_HOOK_BRIDGE_INVOKED=1
  assert_eq "$name: bridge env does not change non-PreToolUse format" "block" "$(gh_decision)"
  assert_eq "$name: non-PreToolUse stays exit 0" "0" "$TL_STATUS"

  # tool name variations all gate
  for t in Write MultiEdit; do
    gh_run "$hook" "$(gh_edit_input "$edit_path" "$t")"
    assert_gate_denies "$name: $t is gated" "$reason"
  done

  # input / environment variations that must allow
  gh_run "$hook" ""
  assert_gate_allows "$name: empty stdin allows"
  gh_run "$hook" "not json at all"
  assert_gate_allows "$name: unparsable stdin allows"
  local saved_cfg; saved_cfg="$(cat "$GH_CFG")"
  printf '{ broken json' >"$GH_CFG"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: unparsable project config allows (fail-open)"
  printf '%s' "$saved_cfg" >"$GH_CFG"
  GH_PATH="$(tl_path_without jq)" gh_run "$hook" "$edit"
  assert_gate_allows "$name: missing jq allows (fail-open)"
  gh_run "$hook" "$edit" SB_AGENT_CERT_RUN=1
  assert_gate_allows "$name: cert-run bypass (=1)"
  gh_run "$hook" "$edit" SB_AGENT_CERT_RUN=true
  assert_gate_allows "$name: cert-run bypass (=true)"
  gh_run "$hook" "$edit" SB_AGENT_CERT_RUN=0
  assert_gate_denies "$name: cert-run flag =0 does not bypass" "$reason"

  gh_run "$hook" "$(jq -cn --arg e PreToolUse '{hook_event_name:$e, tool_name:"Read", tool_input:{file_path:"/x"}}')"
  assert_gate_allows "$name: Read is not gated"
  gh_run "$hook" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{}}')"
  assert_gate_allows "$name: edit without path or command allows"
  gh_run "$hook" "$(gh_edit_input "$exempt_path")"
  assert_gate_allows "$name: exempt path allows"
  gh_run "$hook" "$(gh_bash_input "$exempt_cmd")"
  assert_gate_allows "$name: exempt command allows"
  gh_run "$hook" "$(gh_bash_input "ls -la")"
  assert_gate_allows "$name: non-writing command allows"
  gh_run "$hook" "$(gh_bash_input "")"
  assert_gate_allows "$name: empty command allows"

  # project / consent / bypass variations
  local saved; saved="$(cat "$GH_CFG")"
  rm -f "$SB_RUNTIME_STATE_DIR/project-root"
  GH_CWD="$TL_TMP/outside" GH_PROJECT_ROOT="" gh_run "$hook" "$edit"
  assert_gate_allows "$name: outside any SB project allows"
  rm -f "$GH_CFG" "$SB_RUNTIME_STATE_DIR/project-root"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: missing project config allows"
  printf '%s' "$saved" >"$GH_CFG"
  jq --arg t "$tool" '.recommended_tools[$t].enabled_by_user = false' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: opted out allows"
  printf '%s' "$saved" >"$GH_CFG"
  jq --arg t "$tool" 'del(.recommended_tools[$t].enabled_by_user)' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: consent pending allows"
  printf '%s' "$saved" >"$GH_CFG"
  jq --arg t "$tool" '.recommended_tools[$t].enforcement_suspended = true' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: enforcement suspended allows"
  printf '%s' "$saved" >"$GH_CFG"

  # trivial bypass: default location and configured (with ~ expansion)
  printf 'x' >"$SB_RUNTIME_STATE_DIR/trivial"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: trivial marker (default path) allows"
  rm -f "$SB_RUNTIME_STATE_DIR/trivial"
  jq '.state.trivial_file = "~/custom-trivial"' "$GH_CFG" >"$GH_CFG.n" && mv "$GH_CFG.n" "$GH_CFG"
  gh_run "$hook" "$edit"
  assert_gate_denies "$name: configured trivial path absent still gates" "$reason"
  printf 'x' >"$HOME/custom-trivial"
  gh_run "$hook" "$edit"
  assert_gate_allows "$name: trivial marker (configured ~ path) allows"
  rm -f "$HOME/custom-trivial"
  rm -f "$SB_RUNTIME_STATE_DIR/trivial"
  ln -s "$TL_TMP/trivial-target" "$SB_RUNTIME_STATE_DIR/trivial"
  printf '%s' "$saved" >"$GH_CFG"
  : >"$TL_TMP/trivial-target"
  gh_run "$hook" "$edit"
  assert_gate_denies "$name: symlinked trivial marker is ignored" "$reason"
  rm -f "$SB_RUNTIME_STATE_DIR/trivial"

  # Shell-like tools gate through the command branch
  gh_run "$hook" "$(gh_bash_input "git commit -m x" Shell)"
  assert_gate_denies "$name: Shell tool with git commit is gated" "$reason"
  gh_run "$hook" "$(gh_bash_input "git commit -m x" exec_command)"
  assert_gate_denies "$name: exec_command with git commit is gated" "$reason"
  gh_run "$hook" "$(gh_bash_input "gh pr create --fill")"
  assert_gate_denies "$name: gh pr create is gated" "$reason"
  gh_run "$hook" "$(gh_bash_input "sed -i s/a/b/ src/app.js")"
  assert_gate_denies "$name: in-place sed is gated" "$reason"
  gh_run "$hook" "$(gh_bash_input "mv a b")"
  assert_gate_denies "$name: mv is gated" "$reason"
  gh_scenario_block
}

# gh_farm <name> <hook relative path> [excluded lib basenames...]
# Builds $TL_TMP/farm-<name>/hooks/{<hook>,lib/*} out of symlinks to the real files,
# minus the excluded libs ("-" excludes the whole lib dir), and points GH_REPO at it so
# gh_run exercises the hook's behavior when a sourced library is unavailable.
gh_farm() {
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
  GH_FARM="$root"
  export GH_FARM
}
