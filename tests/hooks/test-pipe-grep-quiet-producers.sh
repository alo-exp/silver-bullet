#!/usr/bin/env bash
# Behavioural guard for `producer | grep -q` under pipefail.
#
# grep -q exits at the first match; a producer that is still writing gets SIGPIPE
# (or EPIPE) and, under `set -o pipefail`, the pipeline reports "no match" even
# though it matched. Every stub below prints the matching line FIRST, then about
# 200 KB, so the old pipeline form fails deterministically. The sources must read
# the producer through `grep ... < <(producer)` instead.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# A stub body: the match line first, then roughly 200 KB of filler lines.
big() { printf 'echo %q; yes xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | head -c 200000' "$1"; }

# Run one function from a sourced lib in a fresh pipefail shell.
lib_fn() { # <lib> <fn> [args...]
  local lib="$1"; shift
  bash -c 'set -euo pipefail; source "$1"; shift; "$@"' _ "$TL_REPO_ROOT/$lib" "$@"
}
yes_t() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then tl_fail "$n"; else tl_pass "$n"; fi; }

# --- rtk-gate.sh:48 and optimize-rtk-context-mode.sh:98 (--help | head -5 | grep) ---
tl_stub rtk "[[ \"\${1:-}\" == gain ]] && exit 0
$(big 'rust type kit')"
RTK="$TL_BIN/rtk"
yes_t "rtk-gate: wrong rtk binary detected despite long --help" lib_fn hooks/lib/rtk-gate.sh sb_rtk_is_wrong_binary "$RTK"

opt_fn() {
  bash -c 'set -euo pipefail
    source "$1"
    eval "$(sed -n "/^rtk_binary_ok()/,/^}/p" "$2")"
    rtk_binary_ok' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh" "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh"
}
no_t "optimize-rtk: wrong rtk binary rejected despite long --help" opt_fn

# --- stack-optimizer.sh:65 and graphify-am-global.sh:364 (graphify hook status | grep) ---
tl_stub graphify "[[ \"\${1:-}\" == hook ]] || exit 0
$(big 'hooks installed')"
EMPTY_REPO="$TL_TMP/norepo"; mkdir -p "$EMPTY_REPO"
yes_t "stack-optimizer: graphify hooks detected despite long status" lib_fn hooks/lib/stack-optimizer.sh sb_stack_graphify_hooks_installed "$EMPTY_REPO"
yes_t "graphify-am-global: graphify hooks detected despite long status" lib_fn hooks/lib/graphify-am-global.sh ga_graphify_hooks_installed

# --- global-toolstack/common.sh:456 (agentmemory status | grep) ---
tl_stub curl 'exit 1'
tl_stub agentmemory "$(big 'Health: healthy')"
yes_t "toolstack: agentmemory healthy despite long status" lib_fn scripts/lib/global-toolstack/common.sh ts_agentmemory_server_healthy

# --- uat-gate.sh:74/81 (grep | grep -qv on a large UAT file) ---
uat_case() { # <result> <rows>
  local proj="$TL_TMP/uat-$1"; mkdir -p "$proj/.planning"
  printf '{"sb_initiated": true}\n' >"$proj/.silver-bullet.json"
  printf '# Silver Bullet\n' >"$proj/silver-bullet.md"
  { printf 'spec-version: 1.0\n| ID | Criterion | Result |\n|----|----|----|\n'
    for ((i = 1; i <= 20000; i++)); do printf '| %d | criterion number %d | %s |\n' "$i" "$i" "$1"; done
  } >"$proj/.planning/UAT.md"
  (cd "$proj" && printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-release"}}' |
    SILVER_BULLET_TEST_HOOK_ENFORCED=1 bash "$TL_REPO_ROOT/hooks/uat-gate.sh" 2>/dev/null)
}
assert_contains "uat-gate blocks a large UAT with FAIL rows" "$(uat_case FAIL)" "UAT GATE"
assert_contains "uat-gate blocks a large UAT with NOT-RUN rows" "$(uat_case NOT-RUN)" "UAT GATE"

# --- context-mode-gate.sh:164 (grep -rl | grep -q . with many matching files) ---
RULES="$TL_TMP/cm/.cursor/rules"; mkdir -p "$RULES"
for ((i = 1; i <= 5000; i++)); do
  printf 'context-mode\n' >"$RULES/rule-with-a-reasonably-long-descriptive-file-name-$i.mdc"
done
yes_t "context-mode: cursor rule found among many matching files" lib_fn hooks/lib/context-mode-gate.sh sb_context_mode_cursor_rule_present "$TL_TMP/cm"

tl_results
