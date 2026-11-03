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
assert_eq "Cursor env marker no longer selects a runtime" "claude" "$(rp CURSOR_PLUGIN_ROOT=/x -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "a .cursor plugin root no longer selects a runtime" "claude" "$(rp CLAUDE_PLUGIN_ROOT=/x/.cursor/y -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Pi env marker" "pi" "$(rp PI_CODING_AGENT_DIR=/p -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Pi home root from env" "/p" "$(rp PI_CODING_AGENT_DIR=/p -- 'printf %s "$SB_RUNTIME_HOME_ROOT"')"
assert_eq "Opencode env marker" "opencode" "$(rp OPENCODE=1 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "Opencode pid marker" "opencode" "$(rp OPENCODE_PID=7 -- 'printf %s "$SB_RUNTIME_NAME"')"
assert_eq "explicit runtime wins" "claude" "$(rp SILVER_BULLET_RUNTIME=claude CODEX_CI=1 -- 'printf %s "$SB_RUNTIME_NAME"')"
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
for runtime in claude codex; do
  assert_eq "explicit $runtime" "${runtime}|${H}/.${runtime}/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME="$runtime" -- 'printf "%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_STATE_DIR"')"
done
assert_eq "explicit codex state dir" "$H/.codex/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME=codex -- 'printf %s "$SB_RUNTIME_STATE_DIR"')"
assert_eq "a retired cursor runtime is coerced to claude" "claude|$H/.claude/.silver-bullet" "$(rp SILVER_BULLET_RUNTIME=cursor -- 'printf "%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_STATE_DIR"')"
# a copy under a .codex tree selects codex on its own
mkdir -p "$TL_TMP/x/.codex/hooks/lib"
cp "$LIB" "$TL_TMP/x/.codex/hooks/lib/runtime-paths.sh"
assert_eq "script path under .codex" "codex" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; printf %s "$SB_RUNTIME_NAME"' _ "$TL_TMP/x/.codex/hooks/lib/runtime-paths.sh")"
mkdir -p "$TL_TMP/x/.pi/hooks/lib" "$TL_TMP/x/.config/opencode/hooks/lib"
for d in .pi .config/opencode; do cp "$LIB" "$TL_TMP/x/$d/hooks/lib/runtime-paths.sh"; done
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

# ---- canonical containment (R2-28, R3-05, R5-01) ------------------------------
# A string-prefix test let '..', the root itself and symlinked components through.
SR="$H/.claude/.silver-bullet"
mkdir -p "$SR/sub" "$H/outside"
: >"$H/outside/victim"
ln -s "$H/outside" "$SR/escape"
ln -s "$H/outside/victim" "$SR/leaflink"
ln -s "$H/outside/not-yet" "$SR/dangling"
ln -s "$SR/sub" "$SR/inlink"
ln -s "$SR/sub/real" "$SR/inleaf"
for bad in "$SR/../../victim" "$SR/../.silver-bullet-evil/state" "$SR/sub/../../x" \
  "$SR/a/../../../x" "$SR/nonexist/../../x" "$SR/escape/state" "$SR/leaflink" \
  "$SR/dangling/state" "$SR" "$SR/" "$SR/." "$SR/sub/.." "$SR/.." "relative/state" \
  "~"/.claude/.silver-bullet/state "$SR/new"$'\n'"line" "C:\\Users\\x\\.claude\\.silver-bullet\\state"; do
  if scoped "$bad"; then tl_fail "escape rejected: $bad"; else tl_pass "escape rejected: $bad"; fi
done
for good in "$SR/state" "$SR//state" "$SR/./state" "$SR/sub/../state" "$SR/inlink/state" \
  "$SR/state/" "$SR/new/dir/state" "$H//.claude/.silver-bullet/state" "$SR/inleaf"; do
  if scoped "$good"; then tl_pass "honest path accepted: $good"; else tl_fail "honest path accepted: $good"; fi
done
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="/kay/.silver-bullet" "/kay/.silver-bullet/../x"; then tl_fail "extra root escape rejected"; else tl_pass "extra root escape rejected"; fi
if scoped SB_RUNTIME_EXTRA_STATE_ROOTS="relative/.silver-bullet" "/relative/.silver-bullet/x"; then tl_fail "relative extra root ignored"; else tl_pass "relative extra root ignored"; fi

# sb_runtime_state_path: the single safe helper prints a validated canonical path or fails.
sp() { rp "${@:1:$#-1}" -- "sb_runtime_state_path \"$(printf '%s' "${!#}")\" || echo REJECTED"; }
assert_eq "state path: plain" "$SR/state" "$(sp "$SR/state")"
assert_eq "state path: tilde expanded" "$SR/state" "$(sp "~"/.claude/.silver-bullet/state)"
assert_eq "state path: '//', '/./' and trailing slash removed" "$SR/state" "$(sp "$SR//./state/")"
assert_eq "state path: inner '..' resolved" "$SR/state" "$(sp "$SR/sub/../state")"
assert_eq "state path: symlinked parent resolved" "$SR/sub/state" "$(sp "$SR/inlink/state")"
assert_eq "state path: in-root leaf symlink kept as the link" "$SR/inleaf" "$(sp "$SR/inleaf")"
assert_eq "state path: traversal rejected" "REJECTED" "$(sp "$SR/../../victim")"
assert_eq "state path: symlinked parent escaping rejected" "REJECTED" "$(sp "$SR/escape/state")"
assert_eq "state path: leaf symlink escaping rejected" "REJECTED" "$(sp "$SR/leaflink")"
assert_eq "state path: dangling parent symlink rejected" "REJECTED" "$(sp "$SR/dangling/state")"
assert_eq "state path: root itself rejected" "REJECTED" "$(sp "$SR/")"
assert_eq "state path: dot-dot leaf rejected" "REJECTED" "$(sp "$SR/sub/..")"
assert_eq "state path: dot leaf inside the root" "$SR/sub" "$(sp "$SR/sub/.")"
assert_eq "state path: relative rejected" "REJECTED" "$(sp "state")"
assert_eq "state path: empty rejected" "REJECTED" "$(sp "")"
assert_eq "state path: carriage return rejected" "REJECTED" "$(sp "$SR/a"$'\r'"b")"
assert_eq "state path: extra root accepted" "/kay/.silver-bullet/state" "$(sp SB_RUNTIME_EXTRA_STATE_ROOTS=/kay/.silver-bullet "/kay/.silver-bullet/state")"
assert_eq "state path: extra root traversal rejected" "REJECTED" "$(sp SB_RUNTIME_EXTRA_STATE_ROOTS=/kay/.silver-bullet "/kay/.silver-bullet/../.bashrc")"
assert_eq "state path: pinned state dir is not a root" "REJECTED" "$(sp SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR=/pinned "/pinned/state")"
# A runtime home reached through a symlink (dotfiles setups): compare canonical forms.
H2="$TL_TMP/h2"
mkdir -p "$H2/dotfiles/claude"
ln -s "$H2/dotfiles/claude" "$H2/.claude"
assert_eq "state path: symlinked runtime home" "$H2/dotfiles/claude/.silver-bullet/state" "$(env -i PATH="$PATH" HOME="$H2" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; sb_runtime_state_path "$HOME/.claude/.silver-bullet/state"' _ "$LIB")"
if env -i PATH="$PATH" HOME="$H2" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; sb_runtime_path_is_state_scoped "$HOME/.claude/.silver-bullet/../../escape"' _ "$LIB"; then
  tl_fail "symlinked runtime home: traversal rejected"
else
  tl_pass "symlinked runtime home: traversal rejected"
fi
# Symlink loops anywhere in the candidate fail closed.
ln -s loop "$SR/loop"
ln -s selfloop "$SR/selfloop"
assert_eq "state path: loop under a dot-dot leaf rejected" "REJECTED" "$(sp "$SR/loop/..")"
assert_eq "state path: loop in the parent rejected" "REJECTED" "$(sp "$SR/loop/state")"
assert_eq "state path: looping leaf symlink rejected" "REJECTED" "$(sp "$SR/selfloop")"
# Fail closed when the canonicalisation library is not installed next to runtime-paths.sh
# (a symlink farm, so coverage maps the run to the real file).
mkdir -p "$TL_TMP/solo/hooks/lib"
ln -s "$LIB" "$TL_TMP/solo/hooks/lib/runtime-paths.sh"
assert_eq "no path-canonical library: everything rejected" "REJECTED" "$(env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source "$1"; sb_runtime_state_path "$HOME/.claude/.silver-bullet/state" || echo REJECTED' _ "$TL_TMP/solo/hooks/lib/runtime-paths.sh")"
# Sourced by bare name from its own directory: the library is still found.
assert_eq "bare-name source still loads path-canonical.sh" "$SR/state" "$(cd "$TL_REPO_ROOT/hooks/lib" && env -i PATH="$PATH" HOME="$H" BASH_ENV="${BASH_ENV:-}" SB_COV_DIR="${SB_COV_DIR:-}" bash -c 'source runtime-paths.sh; sb_runtime_state_path "$HOME/.claude/.silver-bullet/state"')"

# ---- receipt dirs -----------------------------------------------------------
dirs="$(rp SILVER_BULLET_RUNTIME=claude KAY_HOME=/kay PI_CODING_AGENT_DIR=/pi SB_RUNTIME_EXTRA_STATE_ROOTS="/e1/.silver-bullet:/e2::$H/.claude/.silver-bullet" -- 'sb_runtime_skill_receipt_dirs')"
assert_contains "state dir first" "$(sed -n 1p <<<"$dirs")" "$H/.claude/.silver-bullet/skill-invocations"
assert_contains "codex dir listed" "$dirs" "$H/.codex/.silver-bullet/skill-invocations"
assert_contains "kay home dirs listed" "$dirs" "/kay/.claude/.silver-bullet/skill-invocations"
assert_contains "opencode dir listed" "$dirs" "$H/.config/opencode/.silver-bullet/skill-invocations"
assert_contains "pi dir from env" "$dirs" "/pi/.silver-bullet/skill-invocations"
assert_contains "extra root already ending in .silver-bullet" "$dirs" $'\n/e1/.silver-bullet/skill-invocations'
assert_contains "extra root without the suffix gets it" "$dirs" "/e2/.silver-bullet/skill-invocations"
assert_eq "duplicates removed" "1" "$(grep -cFx "$H/.claude/.silver-bullet/skill-invocations" <<<"$dirs")"
assert_eq "empty home entries skipped (only the state dir remains)" "1" "$(rp HOME= -- 'sb_runtime_skill_receipt_dirs' | wc -l | tr -d ' ')"

tl_results
