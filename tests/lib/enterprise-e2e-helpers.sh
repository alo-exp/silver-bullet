# shellcheck shell=bash
# Helpers shared by the enterprise E2E harness tests (package F-enterprise-1).
# Source after testlib.sh and tl_init.

# e2e_call LIB [ENV-ARG ...] -- FUNCTION [ARGS ...]
# Run FUNCTION from the sourced LIB in a fresh bash. ENV-ARGs are passed to
# env(1) (-u VAR first, then VAR=value; at least one is required). The result lands in TL_OUT/TL_ERR/TL_STATUS.
e2e_call() {
  local lib="$1"
  shift
  local envs=()
  while [[ "${1:-}" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  tl_run env ${envs[@]+"${envs[@]}"} bash -c 'source "$1"; shift; "$@"' _ "$lib" "$@"
}

# e2e_script SCRIPT-BODY [ENV-ARG ...]
# Run a bash snippet (with errexit/nounset/pipefail on) in a fresh bash; ENV-ARGs
# as for e2e_call (pass E2E_CALL=1 when there is nothing else).
e2e_script() {
  local body="$1"
  shift
  tl_run env "$@" bash -c "set -euo pipefail; $body"
}

# e2e_git_app DIR: a test-app git repo on branch main with one commit.
e2e_git_app() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "e2e@test"
  git -C "$dir" config user.name "E2E"
  git -C "$dir" config commit.gpgsign false
  printf 'seed\n' >"$dir/seed.txt"
  git -C "$dir" add seed.txt
  git -C "$dir" commit -q -m "seed"
}

# e2e_commit DIR FILE MESSAGE: add a commit touching FILE (path relative to DIR).
e2e_commit() {
  local dir="$1" file="$2" msg="$3"
  mkdir -p "$(dirname "$dir/$file")"
  printf '%s\n' "$msg" >>"$dir/$file"
  git -C "$dir" add "$file"
  git -C "$dir" commit -q -m "$msg"
}
