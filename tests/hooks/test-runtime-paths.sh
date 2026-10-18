#!/usr/bin/env bash
# hooks/lib/runtime-paths.sh: runtime selection, home roots and state scoping.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib/runtime-paths.sh"
H="$TL_TMP/h"
mkdir -p "$H"

# rp ENV... -- script : source the library in a clean environment and run script
rp() {
  local -a envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" "${envs[@]}" bash -c 'source "$1"; shift; eval "$1"' _ "$LIB" "$1"
}

assert_eq "default runtime is claude" "claude" "$(rp -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "claude home root" "$H/.claude" "$(rp -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "state dir" "$H/.claude/.silver-bullet" "$(rp -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
assert_eq "plugin cache root" "$H/.claude/plugins/cache" "$(rp -- 'printf %s "$SB_RUNTIME_PLUGIN_CACHE_ROOT"')"
assert_eq "Codex env marker" "codex" "$(rp CODEX_THREAD_ID=1 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Codex plugin root" "codex" "$(rp CLAUDE_PLUGIN_ROOT=/x/.codex/y -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Cursor env marker" "cursor" "$(rp CURSOR_PLUGIN_ROOT=/x -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Cursor plugin root" "cursor" "$(rp CLAUDE_PLUGIN_ROOT=/x/.cursor/y -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Pi env marker" "pi" "$(rp PI_CODING_AGENT_DIR=/p -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Pi home root from env" "/p" "$(rp PI_CODING_AGENT_DIR=/p -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "Opencode env marker" "opencode" "$(rp OPENCODE=1 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Opencode pid marker" "opencode" "$(rp OPENCODE_PID=7 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "explicit runtime wins" "cursor" "$(rp SILVER_BULLET_RUNTIME=cursor CODEX_CI=1 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "unknown runtime coerced to claude" "claude" "$(rp SILVER_BULLET_RUNTIME=emacs -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "opencode home root" "$H/.config/opencode" "$(rp SILVER_BULLET_RUNTIME=opencode -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "pi default home root" "$H/.pi/agent" "$(rp SILVER_BULLET_RUNTIME=pi -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "goose home root" "$H/.config/goose" "$(rp SILVER_BULLET_RUNTIME=goose -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "hermes home root" "$H/.hermes" "$(rp SILVER_BULLET_RUNTIME=hermes -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "KAY_HOME relocates the codex root" "/kay/.codex" "$(rp SILVER_BULLET_RUNTIME=codex KAY_HOME=/kay -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "KAY_HOME ignored for claude" "$H/.claude" "$(rp SILVER_BULLET_RUNTIME=claude KAY_HOME=/kay -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "state dir pinned when preserved" "/pinned" "$(rp SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR=/pinned -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
assert_eq "state dir recomputed when not preserved" "$H/.claude/.silver-bullet" "$(rp SB_RUNTIME_STATE_DIR=/pinned -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
assert_eq "codex home helper" "$H/.codex" "$(rp -- 'sb_runtime_codex_home')"
assert_eq "CODEX_HOME overrides the helper" "/ch" "$(rp CODEX_HOME=/ch -- 'sb_runtime_codex_home')"

# explicit runtime selection scopes the state dir under that runtime's home (pre-existing checks)
for runtime in claude codex cursor; do
  assert_eq "explicit $runtime" "${runtime}|${H}/.${runtime}/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME="$runtime" -- 'printf "%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_STATE_DIR"')"
done
assert_eq "explicit codex state dir" "$H/.codex/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME=codex -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
assert_eq "explicit cursor state dir" "$H/.cursor/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME=cursor -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
# runtime inferred from a plugin-cache install path (no runtime markers in the environment)
CACHE_LIB="$H/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/lib"
mkdir -p "$CACHE_LIB"
cp "$LIB" "$CACHE_LIB/runtime-paths.sh"
assert_eq "infers cursor from path" "cursor|${H}/.cursor/.silver-bullet" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf "%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_STATE_DIR"' _ "$CACHE_LIB/runtime-paths.sh")"

# a copy under a .codex tree selects codex on its own
mkdir -p "$TL_TMP/x/.codex/hooks/lib"
cp "$LIB" "$TL_TMP/x/.codex/hooks/lib/runtime-paths.sh"
assert_eq "script path under .codex" "codex" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_TMP/x/.codex/hooks/lib/runtime-paths.sh")"
mkdir -p "$TL_TMP/x/.cursor/hooks/lib" "$TL_TMP/x/.pi/hooks/lib" "$TL_TMP/x/.config/opencode/hooks/lib"
for d in .cursor .pi .config/opencode; do cp "$LIB" "$TL_TMP/x/$d/hooks/lib/runtime-paths.sh"; done
assert_eq "script path under .cursor" "cursor" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_TMP/x/.cursor/hooks/lib/runtime-paths.sh")"
assert_eq "script path under .pi" "pi" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_TMP/x/.pi/hooks/lib/runtime-paths.sh")"
assert_eq "script path under .config/opencode" "opencode" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_TMP/x/.config/opencode/hooks/lib/runtime-paths.sh")"

# ---- state scoping ----------------------------------------------------------
scoped() { rp "${@:1:$#-1}" -- "sb_runtime_path_is_state_scoped \"$(printf '%s' "${!#}")\""; }
if scoped "$H/.claude/.silver-bullet/state"; then tl_pass "state file under the state root"; else tl_fail "state file under the state root"; fi
if scoped "$H/.claude/other/state"; then tl_fail "path outside the state root rejected"; else tl_pass "path outside the state root rejected"; fi
if scoped ""; then tl_fail "empty path rejected"; else tl_pass "empty path rejected"; fi
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="/kay/.silver-bullet:/odd/root::" "/kay/.silver-bullet/state"; then tl_pass "extra state root accepted"; else tl_fail "extra state root accepted"; fi
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="/kay/.silver-bullet/" "/kay/.silver-bullet/state"; then tl_pass "extra state root with trailing slash"; else tl_fail "extra state root with trailing slash"; fi
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="/odd/root" "/odd/root/state"; then tl_fail "extra root not ending in .silver-bullet rejected"; else tl_pass "extra root not ending in .silver-bullet rejected"; fi
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="/kay/.silver-bullet" "/elsewhere/state"; then tl_fail "unrelated path with extra roots rejected"; else tl_pass "unrelated path with extra roots rejected"; fi

# ---- receipt dirs -----------------------------------------------------------
dirs="$(rp SILVER_BULLET_RUNTIME=claude KAY_HOME=/kay PI_CODING_AGENT_DIR=/pi SB_RUNTIME_EXTRA_STATE_ROOTS="/e1/.silver-bullet:/e2::$H/.claude/.silver-bullet" -- 'sb_runtime_skill_receipt_dirs')"
assert_contains "state dir first" "$(sed -n 1p <<<"$dirs")" "$H/.claude/.silver-bullet/skill-invocations"
assert_contains "codex dir listed" "$dirs" "$H/.codex/.silver-bullet/skill-invocations"
assert_contains "kay home dirs listed" "$dirs" "/kay/.cursor/.silver-bullet/skill-invocations"
assert_contains "opencode dir listed" "$dirs" "$H/.config/opencode/.silver-bullet/skill-invocations"
assert_contains "pi dir from env" "$dirs" "/pi/.silver-bullet/skill-invocations"
assert_contains "extra root already ending in .silver-bullet" "$dirs" $'\n/e1/.silver-bullet/skill-invocations'
assert_contains "extra root without the suffix gets it" "$dirs" "/e2/.silver-bullet/skill-invocations"
assert_eq "duplicates removed" "1" "$(grep -cFx "$H/.claude/.silver-bullet/skill-invocations" <<<"$dirs")"
assert_eq "empty home entries skipped (only the state dir remains)" "1" "$(rp HOME= -- 'sb_runtime_skill_receipt_dirs' | wc -l | tr -d ' ')"

tl_results
