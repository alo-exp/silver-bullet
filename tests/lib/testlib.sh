# shellcheck shell=bash
# Shared helpers for tests/**/test-*.sh.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
#   tl_init                      # sandbox HOME + temp dir, counters, cleanup trap
#   tl_stub jq 'echo stubbed'    # fake command first on PATH
#   tl_run_hook hooks/foo.sh "$(tl_hook_json PreToolUse Bash 'git push')"
#   assert_eq "blocks push" 2 "$TL_STATUS"
#   tl_results                   # prints "Results: N passed, M failed"; non-zero on failure
#
# Every test gets its own HOME, so runtime state (~/.claude, ~/.codex, ...) never
# touches the real home directory. Python user packages stay importable because
# PYTHONUSERBASE is pinned to the real user base before HOME changes.

TL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TL_PASS=0
TL_FAIL=0

# tl_init [runtime]: create the sandbox and recompute SB runtime paths inside it.
tl_init() {
  local runtime="${1:-${SILVER_BULLET_RUNTIME:-claude}}"
  TL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sbtest.XXXXXX")"
  TL_TMP="$(cd "$TL_TMP" && pwd -P)"
  TL_BIN="$TL_TMP/bin"
  mkdir -p "$TL_BIN" "$TL_TMP/home"
  if [[ -z "${PYTHONUSERBASE:-}" ]] && command -v python3 >/dev/null 2>&1; then
    PYTHONUSERBASE="$(python3 -m site --user-base 2>/dev/null || true)"
    export PYTHONUSERBASE
  fi
  export HOME="$TL_TMP/home"
  export PATH="$TL_BIN:$PATH"
  export SILVER_BULLET_RUNTIME="$runtime"
  unset SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME \
    SB_RUNTIME_PRESERVE_STATE_DIR SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE
  # shellcheck source=../../hooks/lib/runtime-paths.sh
  source "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh"
  export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME
  mkdir -p "$SB_RUNTIME_STATE_DIR"
  trap 'tl_cleanup' EXIT
}

tl_cleanup() {
  [[ -n "${TL_TMP:-}" && -d "$TL_TMP" ]] && rm -rf "$TL_TMP"
  return 0
}

tl_pass() { echo "PASS: $1"; TL_PASS=$((TL_PASS + 1)); }
tl_fail() { echo "FAIL: $1"; TL_FAIL=$((TL_FAIL + 1)); }

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then tl_pass "$name"; else tl_fail "$name (expected '$expected', got '$actual')"; fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then tl_pass "$name"; else tl_fail "$name (missing '$needle' in: ${haystack:0:300})"; fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then tl_pass "$name"; else tl_fail "$name (unexpected '$needle' in: ${haystack:0:300})"; fi
}

assert_match() {
  local name="$1" regex="$2" value="$3"
  if [[ "$value" =~ $regex ]]; then tl_pass "$name"; else tl_fail "$name ('$value' does not match /$regex/)"; fi
}

assert_file_exists() {
  if [[ -e "$2" ]]; then tl_pass "$1"; else tl_fail "$1 (missing file $2)"; fi
}

assert_file_absent() {
  if [[ ! -e "$2" ]]; then tl_pass "$1"; else tl_fail "$1 (unexpected file $2)"; fi
}

# tl_run <cmd...>: run a command, capturing stdout/stderr/status in TL_OUT/TL_ERR/TL_STATUS.
tl_run() {
  local out_file="$TL_TMP/.out" err_file="$TL_TMP/.err"
  TL_STATUS=0
  "$@" >"$out_file" 2>"$err_file" </dev/null || TL_STATUS=$?
  TL_OUT="$(cat "$out_file")"
  TL_ERR="$(cat "$err_file")"
}

# tl_run_stdin <input> <cmd...>: like tl_run but feeds <input> on stdin.
tl_run_stdin() {
  local input="$1"
  shift
  local out_file="$TL_TMP/.out" err_file="$TL_TMP/.err"
  TL_STATUS=0
  printf '%s' "$input" | "$@" >"$out_file" 2>"$err_file" || TL_STATUS=$?
  TL_OUT="$(cat "$out_file")"
  TL_ERR="$(cat "$err_file")"
}

# tl_run_hook <hook path relative to repo or absolute> <json>: run a hook with JSON on stdin.
tl_run_hook() {
  local hook="$1" json="$2"
  [[ "$hook" == /* ]] || hook="$TL_REPO_ROOT/$hook"
  tl_run_stdin "$json" bash "$hook"
}

# tl_hook_json <event> <tool> [command-or-path] [extra-json-object]: build hook input.
tl_hook_json() {
  local event="$1" tool="$2" arg="${3:-}" extra="${4:-{\}}"
  local input_key="command"
  case "$tool" in
    Edit|Write|MultiEdit|Read) input_key="file_path" ;;
    Skill) input_key="skill" ;;
  esac
  jq -cn --arg e "$event" --arg t "$tool" --arg k "$input_key" --arg v "$arg" --argjson x "$extra" \
    '{hook_event_name:$e, tool_name:$t, tool_input:({($k):$v} + $x), cwd:env.PWD}'
}

# tl_stub <name> <bash body>: install a fake executable first on PATH.
tl_stub() {
  local name="$1" body="${2:-exit 0}"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$TL_BIN/$name"
  chmod +x "$TL_BIN/$name"
}

# tl_path_without <cmd...>: print a PATH value under which the named commands are absent.
# Every other executable on the current PATH stays reachable through symlinks.
tl_path_without() {
  local dir="$TL_TMP/path-without-$*"
  dir="${dir// /-}"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    local p entry name skip
    local IFS=:
    for p in $PATH; do
      [[ -d "$p" ]] || continue
      for entry in "$p"/*; do
        name="${entry##*/}"
        [[ -x "$entry" && ! -e "$dir/$name" ]] || continue
        skip=0
        local excluded
        for excluded in "$@"; do [[ "$name" == "$excluded" ]] && skip=1; done
        [[ "$skip" -eq 1 ]] || ln -s "$entry" "$dir/$name"
      done
    done
  fi
  printf '%s' "$dir"
}

# tl_git_repo <dir>: initialise a git repo with one commit on branch feature/test.
tl_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config commit.gpgsign false
  : >"$dir/.gitkeep"
  git -C "$dir" add .gitkeep
  git -C "$dir" commit -q -m init
  git -C "$dir" checkout -q -b feature/test
}

tl_results() {
  echo
  echo "Results: ${TL_PASS} passed, ${TL_FAIL} failed"
  [[ "$TL_FAIL" -eq 0 ]]
}
