# shellcheck shell=bash
# Helpers for the global-toolstack tests (scripts/lib/global-toolstack/*).
# Source after tests/lib/testlib.sh and tl_init.

TS_SRC="$TL_REPO_ROOT/scripts/lib/global-toolstack"

# ts_call <fn> [args...]: run a common.sh function in a fresh bash (HOME is the
# sandbox). Sets TL_OUT / TL_ERR / TL_STATUS. Extra env comes from the caller.
ts_call() {
  tl_run bash -c 'source "$1/common.sh"; shift; "$@"' _ "$TS_SRC" "$@"
}

# ts_write_config <json>: write the toolstack config and point TS_CONFIG at it.
ts_write_config() {
  TS_CONFIG="$HOME/.cursor/toolstack.json"
  mkdir -p "$(dirname "$TS_CONFIG")"
  printf '%s\n' "$1" >"$TS_CONFIG"
  export TS_CONFIG
}

# ts_sb_project <dir> [config-json]: make <dir> look like a Silver Bullet project.
ts_sb_project() {
  mkdir -p "$1"
  printf '%s\n' "${2:-{\}}" >"$1/.silver-bullet.json"
  printf '# sb\n' >"$1/silver-bullet.md"
}
