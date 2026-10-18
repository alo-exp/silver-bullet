# shellcheck shell=bash
# Helpers shared by the enterprise E2E harness tests (package F-enterprise-1).
# Source after testlib.sh and tl_init.

# _e2e_split_env ARG...: env(1) wants its -u options before the assignments, so sort
# them (an unset always applies first). Result in E2E_ENV_ARGS.
_e2e_split_env() {
  local opts=() assigns=()
  while (($#)); do
    if [[ "$1" == "-u" ]]; then
      opts+=(-u "$2")
      shift 2
    else
      assigns+=("$1")
      shift
    fi
  done
  E2E_ENV_ARGS=(${opts[@]+"${opts[@]}"} ${assigns[@]+"${assigns[@]}"})
}

# e2e_call LIB [ENV-ARG ...] -- FUNCTION [ARGS ...]
# Run FUNCTION from the sourced LIB in a fresh bash. ENV-ARGs are passed to
# env(1) (-u VAR or VAR=value, any order). The result lands in TL_OUT/TL_ERR/TL_STATUS.
e2e_call() {
  local lib="$1"
  shift
  local envs=()
  while [[ "${1:-}" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  _e2e_split_env ${envs[@]+"${envs[@]}"}
  tl_run env ${E2E_ENV_ARGS[@]+"${E2E_ENV_ARGS[@]}"} bash -c 'source "$1"; shift; "$@"' _ "$lib" "$@"
}

# e2e_script SCRIPT-BODY [ENV-ARG ...]
# Run a bash snippet (with errexit/nounset/pipefail on) in a fresh bash; ENV-ARGs
# as for e2e_call (pass E2E_CALL=1 when there is nothing else).
e2e_script() {
  local body="$1"
  shift
  _e2e_split_env "$@"
  tl_run env ${E2E_ENV_ARGS[@]+"${E2E_ENV_ARGS[@]}"} bash -c "set -euo pipefail; $body"
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

# e2e_stage_scripts STAGE: build STAGE/scripts as a real directory of symlinks to the repo's
# scripts/ (and the same one level down for scripts/lib and scripts/enterprise-e2e), so a script
# that derives SB_ROOT from its own location resolves to STAGE while the code under test is the
# real file (coverage follows the symlinks). Individual files are then replaced with
# e2e_stage_override.
e2e_stage_scripts() {
  local stage="$1" f d
  mkdir -p "$stage/scripts"
  for f in "$TL_REPO_ROOT"/scripts/*; do
    ln -s "$f" "$stage/scripts/$(basename "$f")"
  done
  for d in lib enterprise-e2e; do
    rm -f "$stage/scripts/$d"
    mkdir -p "$stage/scripts/$d"
    for f in "$TL_REPO_ROOT/scripts/$d"/*; do
      ln -s "$f" "$stage/scripts/$d/$(basename "$f")"
    done
  done
}

# e2e_stage_override STAGE REL-PATH BODY: replace a staged script with a stub holding BODY.
e2e_stage_override() {
  local stage="$1" rel="$2" body="$3"
  rm -f "$stage/$rel"
  mkdir -p "$(dirname "$stage/$rel")"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$stage/$rel"
  chmod +x "$stage/$rel"
}

# e2e_mk_ledger FILE ROW:STATUS...: a workflow-matrix ledger with the required columns.
e2e_mk_ledger() {
  local f="$1" spec
  shift
  mkdir -p "$(dirname "$f")"
  {
    echo "| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |"
    echo "|---|---------|-----------|--------------------|------------------------|"
    for spec in "$@"; do
      echo "| ${spec%%:*} | wf-${spec%%:*} | ${spec#*:} | q | m |"
    done
    echo "**Pass count: x**"
  } >"$f"
}

# e2e_all_pass_specs N: prints "1:Pass" ... "N:Pass" one per line.
e2e_all_pass_specs() {
  local n
  for ((n = 1; n <= $1; n++)); do
    echo "$n:Pass"
  done
}
