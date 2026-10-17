# shellcheck shell=bash
# shellcheck disable=SC2034  # TL_* are outputs read by the sourcing tests
# Shared helpers for the D-gates coverage tests (source after testlib.sh + tl_init).

# dg_project DIR [CONFIG_JSON]: SB project root (git dir, config, silver-bullet.md).
dg_project() {
  local dir="$1" cfg="${2:-}"
  [[ -n "$cfg" ]] || cfg='{"sb_initiated":true}'
  mkdir -p "$dir/.git"
  printf '%s\n' "$cfg" >"$dir/.silver-bullet.json"
  printf '# silver bullet\n' >"$dir/silver-bullet.md"
}

# dg_run DIR HOOK JSON [VAR=VALUE...]: run a hook with cwd=DIR and extra env.
dg_run() {
  local dir="$1" hook="$2" json="$3"
  shift 3
  [[ "$hook" == /* ]] || hook="$TL_REPO_ROOT/$hook"
  TL_STATUS=0
  printf '%s' "$json" | (cd "$dir" && env "$@" bash "$hook") >"$TL_TMP/.out" 2>"$TL_TMP/.err" || TL_STATUS=$?
  TL_OUT="$(cat "$TL_TMP/.out")"
  TL_ERR="$(cat "$TL_TMP/.err")"
}

# dg_run_nolib HOOK JSON: run a hook with `cd` failing, so its lib-dir lookup falls back to "".
dg_run_nolib() {
  local hook="$1" json="$2"
  [[ "$hook" == /* ]] || hook="$TL_REPO_ROOT/$hook"
  TL_STATUS=0
  printf '%s' "$json" | bash -c 'cd() { return 1; }; export -f cd; exec bash "$0"' "$hook" \
    >"$TL_TMP/.out" 2>"$TL_TMP/.err" || TL_STATUS=$?
  TL_OUT="$(cat "$TL_TMP/.out")"
  TL_ERR="$(cat "$TL_TMP/.err")"
}

# dg_run_nojq DIR HOOK JSON [VAR=VALUE...]: run a hook with jq absent from PATH.
dg_run_nojq() {
  local dir="$1" hook="$2" json="$3"
  shift 3
  dg_run "$dir" "$hook" "$json" PATH="$(tl_path_without jq)" "$@"
}

# dg_run_closed_stdin DIR HOOK [VAR=VALUE...]: run a hook whose `cat` fails, so reading the
# hook payload fails (a closed stdin cannot be used: bash reuses fd 0 and cat would block).
dg_run_closed_stdin() {
  local dir="$1" hook="$2"
  shift 2
  mkdir -p "$TL_TMP/failcat"
  printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/failcat/cat"
  chmod +x "$TL_TMP/failcat/cat"
  dg_run "$dir" "$hook" "" PATH="$TL_TMP/failcat:$PATH" "$@"
}

# dg_run_gate_missing DIR HOOK JSON [VAR=VALUE...]: run a hook as if project-active.sh were
# unavailable. Pre-defining sb_project_active makes sb-project-gate.sh skip sourcing it, so
# sb_project_gate_or_exit is a missing command (status 127) inside the hook.
dg_run_gate_missing() {
  local dir="$1" hook="$2" json="$3"
  shift 3
  [[ "$hook" == /* ]] || hook="$TL_REPO_ROOT/$hook"
  TL_STATUS=0
  printf '%s' "$json" | (cd "$dir" && env "$@" bash -c 'sb_project_active() { return 0; }; export -f sb_project_active; exec bash "$0"' "$hook") \
    >"$TL_TMP/.out" 2>"$TL_TMP/.err" || TL_STATUS=$?
  TL_OUT="$(cat "$TL_TMP/.out")"
  TL_ERR="$(cat "$TL_TMP/.err")"
}

# dg_stub_real NAME MATCH: install a stub NAME that fails when its arguments contain MATCH
# and otherwise runs the real command.
dg_stub_real() {
  local name="$1" match="$2" real
  real="$(command -v "$name")"
  tl_stub "$name" "if [[ \"\$*\" == *${match}* ]]; then exit 1; fi; exec ${real} \"\$@\""
}

# dg_run_nolib_in DIR HOOK JSON [VAR=VALUE...]: like dg_run_nolib but with cwd=DIR.
dg_run_nolib_in() {
  local dir="$1" hook="$2" json="$3"
  shift 3
  [[ "$hook" == /* ]] || hook="$TL_REPO_ROOT/$hook"
  TL_STATUS=0
  printf '%s' "$json" | (cd "$dir" && env "$@" bash -c 'cd() { return 1; }; export -f cd; exec bash "$0"' "$hook") \
    >"$TL_TMP/.out" 2>"$TL_TMP/.err" || TL_STATUS=$?
  TL_OUT="$(cat "$TL_TMP/.out")"
  TL_ERR="$(cat "$TL_TMP/.err")"
}
