# shellcheck shell=bash
# Helpers for the global-toolstack tests (scripts/lib/global-toolstack/*).
# Source after tests/lib/testlib.sh and tl_init.

TS_SRC="$TL_REPO_ROOT/scripts/lib/global-toolstack"

# ts_call <fn> [args...]: run a common.sh function in a fresh bash with cwd=$HOME
# (the sandbox, so the repo's own SB markers are not discovered). Sets TL_OUT / TL_ERR / TL_STATUS. Extra env comes from the caller.
ts_call() {
  tl_run bash -c 'cd "$HOME"; source "$1/common.sh"; shift; "$@"' _ "$TS_SRC" "$@"
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

# ts_stage_deployed <dir>: lay the toolstack scripts out like ~/.cursor/hooks/toolstack
# (scripts next to a lib/ directory that holds common.sh), as the gates expect.
ts_stage_deployed() {
  local d="$1" f
  mkdir -p "$d/lib"
  for f in "$TS_SRC"/*.sh; do
    cp "$f" "$d/"
  done
  mv "$d/common.sh" "$d/lib/common.sh"
}

# ts_gate <script-basename> <json> [cwd]: run a staged gate with the payload on stdin.
# Requires TS_STAGE to point at the staged directory.
ts_gate() {
  local script="$1" json="$2" cwd="${3:-$PWD}"
  tl_run_stdin "$json" bash -c 'cd "$1" && exec bash "$2"' _ "$cwd" "$TS_STAGE/$script"
}

# ts_payload <tool> <file_path> <command> [event]: build a hook payload.
ts_payload() {
  jq -cn --arg t "$1" --arg f "$2" --arg c "$3" --arg e "${4:-}" \
    '{tool_name:$t, tool_input:({} + (if $f != "" then {file_path:$f} else {} end) + (if $c != "" then {command:$c} else {} end))}
     + (if $e != "" then {hook_event_name:$e} else {} end)'
}
