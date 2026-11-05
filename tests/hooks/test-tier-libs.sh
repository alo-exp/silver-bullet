#!/usr/bin/env bash
# hooks/lib/capability-tier.sh and hooks/lib/enforcement-tier-gate.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib"
unset SILVER_BULLET_TEST_HOOK_ENFORCED CODEX_CI CODEX_THREAD_ID CODEX_INTERNAL_ORIGINATOR_OVERRIDE CURSOR_PLUGIN_ROOT CLAUDE_PLUGIN_ROOT

# in <env...> -- run a capability function in a clean subshell
cap() { # env-assignments... -- function args...
  local -a envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  env -u SB_RUNTIME_NAME -u SILVER_BULLET_RUNTIME -u SILVER_BULLET_TEST_HOOK_ENFORCED -u CODEX_CI -u CODEX_THREAD_ID \
    -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE -u CURSOR_PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT "${envs[@]}" \
    bash -c 'source "$1"; shift; "$@"' _ "$LIB/capability-tier.sh" "$@"
}

# ---- runtime name -----------------------------------------------------------
assert_eq "SB_RUNTIME_NAME wins" "cursor" "$(cap SB_RUNTIME_NAME=cursor SILVER_BULLET_RUNTIME=codex -- sb_capability_runtime_name)"
assert_eq "SILVER_BULLET_RUNTIME next" "codex" "$(cap SILVER_BULLET_RUNTIME=codex -- sb_capability_runtime_name)"
assert_eq "Codex env markers" "codex" "$(cap CODEX_THREAD_ID=t -- sb_capability_runtime_name)"
assert_eq "Codex CI marker" "codex" "$(cap CODEX_CI=1 -- sb_capability_runtime_name)"
assert_eq "Cursor plugin root marker" "cursor" "$(cap CURSOR_PLUGIN_ROOT=/x -- sb_capability_runtime_name)"
assert_eq "plugin root under .codex" "codex" "$(cap CLAUDE_PLUGIN_ROOT=/h/.codex/p -- sb_capability_runtime_name)"
assert_eq "plugin root under .cursor" "cursor" "$(cap CLAUDE_PLUGIN_ROOT=/h/.cursor/p -- sb_capability_runtime_name)"
assert_eq "other plugin root falls through to claude" "claude" "$(cap CLAUDE_PLUGIN_ROOT=/h/.claude/p -- sb_capability_runtime_name)"
assert_eq "nothing set: claude" "claude" "$(cap -- sb_capability_runtime_name)"

# ---- hooks present per runtime ----------------------------------------------
H="$TL_TMP/rt"
mkdir -p "$H"
if cap SB_RUNTIME_HOME_ROOT= -- sb_capability_hooks_present ""; then tl_fail "no runtime home: absent"; else tl_pass "no runtime home: absent"; fi
printf 'silver-bullet' >"$H/hooks.json"
if cap SB_RUNTIME_NAME=cursor -- sb_capability_hooks_present "$H"; then tl_pass "cursor hooks.json detected"; else tl_fail "cursor hooks.json detected"; fi
printf 'silver-bullet' >"$H/config.toml"
if cap SB_RUNTIME_NAME=codex -- sb_capability_hooks_present "$H"; then tl_pass "codex config.toml detected"; else tl_fail "codex config.toml detected"; fi
if cap SB_RUNTIME_NAME=claude -- sb_capability_hooks_present "$H"; then tl_fail "claude needs settings.json"; else tl_pass "claude needs settings.json"; fi
printf 'x silver-bullet y' >"$H/settings.json"
if cap SB_RUNTIME_NAME=claude -- sb_capability_hooks_present "$H"; then tl_pass "claude settings.json detected"; else tl_fail "claude settings.json detected"; fi
printf 'nothing' >"$H/settings.json"
if cap SB_RUNTIME_NAME=claude -- sb_capability_hooks_present "$H"; then tl_fail "settings without SB entry"; else tl_pass "settings without SB entry"; fi

# ---- tier names / numbers / banner ------------------------------------------
S="$TL_TMP/state"
mkdir -p "$S"
printf 'silver-bullet' >"$H/settings.json"
assert_eq "test override: hook-enforced" "hook-enforced" "$(cap SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_capability_tier_name)"
assert_eq "hooks present + state dir: hook-enforced" "hook-enforced" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$H" SB_RUNTIME_STATE_DIR="$S" -- sb_capability_tier_name)"
assert_eq "no hooks but state dir: state-tracked" "state-tracked" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$S" -- sb_capability_tier_name)"
assert_eq "nothing: guidance-only" "guidance-only" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$TL_TMP/nostate" -- sb_capability_tier_name)"
assert_eq "tier numbers: 2" "2" "$(cap SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_capability_tier_number)"
assert_eq "tier numbers: 1" "1" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$S" -- sb_capability_tier_number)"
assert_eq "tier numbers: 0" "0" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$TL_TMP/nostate" -- sb_capability_tier_number)"
# live-tested is only reachable through an overriding tier-name probe
assert_eq "live-tested number" "3" "$(env -u SILVER_BULLET_TEST_HOOK_ENFORCED bash -c 'source "$1"; sb_capability_tier_name() { printf live-tested; }; sb_capability_tier_number' _ "$LIB/capability-tier.sh")"
assert_contains "banner tier 2" "$(cap SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_capability_tier_banner)" "tier 2 (hook-enforced)"
assert_contains "banner tier 1" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$S" -- sb_capability_tier_banner)" "tier 1 (state-tracked)"
assert_contains "banner tier 0" "$(cap SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$TL_TMP/nostate" -- sb_capability_tier_banner)" "tier 0 (guidance-only)"

# ---- enforcement tier gate --------------------------------------------------
gate() { # env... -- fn args...
  local -a envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  env -u SB_RUNTIME_NAME -u SILVER_BULLET_RUNTIME -u SILVER_BULLET_TEST_HOOK_ENFORCED -u SB_HOOK_SMOKE "${envs[@]}" \
    bash -c 'source "$1"; shift; "$@"' _ "$LIB/enforcement-tier-gate.sh" "$@"
}
CFG="$TL_TMP/cfg.json"
assert_eq "no config file: 0" "0" "$(gate -- sb_enforcement_tier_read_config "$TL_TMP/absent.json")"
assert_eq "empty path: 0" "0" "$(gate -- sb_enforcement_tier_read_config "")"
assert_eq "no jq: 0" "0" "$(PATH="$(tl_path_without jq)" gate -- sb_enforcement_tier_read_config "$CFG")"
printf '{"sb_enforcement_tier":1}' >"$CFG"
assert_eq "configured tier read" "1" "$(gate -- sb_enforcement_tier_read_config "$CFG")"
printf '{}' >"$CFG"
assert_eq "unset tier reads empty" "" "$(gate -- sb_enforcement_tier_read_config "$CFG")"

assert_eq "probe: hook-enforced -> 2" "2" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_probe)"
assert_eq "probe: state-tracked -> 1" "1" "$(gate SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$S" -- sb_enforcement_tier_probe)"
assert_eq "probe: guidance-only -> 0" "0" "$(gate SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$TL_TMP/nostate" -- sb_enforcement_tier_probe)"

printf '{"sb_enforcement_tier":1}' >"$CFG"
assert_eq "effective is the minimum of configured and probed" "1" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_effective "$CFG")"
printf '{"sb_enforcement_tier":3}' >"$CFG"
assert_eq "configured above probed does not overclaim" "2" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_effective "$CFG")"
printf '{"sb_enforcement_tier":"junk"}' >"$CFG"
assert_eq "invalid configured tier ignored" "2" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_effective "$CFG")"
assert_eq "no config argument: probe only" "2" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_effective)"
if gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_delivery_allowed; then tl_pass "tier 2 allows delivery"; else tl_fail "tier 2 allows delivery"; fi
if gate SB_RUNTIME_NAME=claude SB_RUNTIME_HOME_ROOT="$TL_TMP/none" SB_RUNTIME_STATE_DIR="$S" -- sb_enforcement_tier_delivery_allowed; then tl_fail "tier 1 blocks delivery"; else tl_pass "tier 1 blocks delivery"; fi

assert_eq "a missing config file reads as configured tier 0" "0" "$(gate SILVER_BULLET_TEST_HOOK_ENFORCED=1 -- sb_enforcement_tier_effective "$TL_TMP/absent.json")"

# persist
printf '{"a":1}' >"$CFG"
gate -- sb_enforcement_tier_persist "$CFG" 2
assert_eq "tier persisted" "2" "$(jq -r .sb_enforcement_tier "$CFG")"
assert_eq "other keys preserved" "1" "$(jq -r .a "$CFG")"
assert_file_absent "no temp file left" "$CFG.tmp"
gate SB_HOOK_SMOKE=1 -- sb_enforcement_tier_persist "$CFG" 3
assert_eq "smoke mode does not mutate" "2" "$(jq -r .sb_enforcement_tier "$CFG")"
gate -- sb_enforcement_tier_persist "$TL_TMP/absent.json" 3
assert_file_absent "missing config: nothing created" "$TL_TMP/absent.json"
gate -- sb_enforcement_tier_persist "$CFG" ""
assert_eq "empty tier: no change" "2" "$(jq -r .sb_enforcement_tier "$CFG")"
PATH="$(tl_path_without jq)" gate -- sb_enforcement_tier_persist "$CFG" 0
assert_eq "no jq: no change" "2" "$(jq -r .sb_enforcement_tier "$CFG")"
gate -- sb_enforcement_tier_persist "$CFG" notjson || true
assert_eq "invalid tier value: config untouched" "2" "$(jq -r .sb_enforcement_tier "$CFG")"

# messages
assert_contains "block message names the tier" "$(gate -- sb_enforcement_tier_block_message 1)" "tier 1 (< 2 hook-enforced)"
assert_contains "block message default tier" "$(gate -- sb_enforcement_tier_block_message)" "tier 0"
for t in 0 1 2 3; do
  assert_contains "banner for tier $t" "$(gate -- sb_enforcement_tier_session_banner "$t")" "tier $t"
done
assert_contains "banner default is tier 0" "$(gate -- sb_enforcement_tier_session_banner)" "tier 0"
assert_contains "banner for an unknown tier" "$(gate -- sb_enforcement_tier_session_banner 9)" "tier unknown"

tl_results
