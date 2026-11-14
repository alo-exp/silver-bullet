#!/usr/bin/env bash
# hooks/lib/project-active.sh, sb-project-gate.sh and the record-aware project lookup (hooks/lib/integrity.sh).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
export PYTHONDONTWRITEBYTECODE=1
source "$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh"
source "$TL_REPO_ROOT/hooks/lib/required-skills.sh"

R="$TL_TMP/proj"
mkdir -p "$R/src/deep/er"
git -C "$R" init -q
printf '# SB\n' >"$R/silver-bullet.md"
printf '{"sb_initiated":true}\n' >"$R/.silver-bullet.json"
R="$(cd "$R" && pwd -P)"

# ── sb_project_active / sb_config_marked_initiated ────────────────────────────────────────────
if sb_project_active ""; then tl_fail "empty path is not active"; else tl_pass "an empty config path is not a project"; fi
if sb_project_active "$R/.silver-bullet.json"; then tl_pass "a config that exists is a project"; else tl_fail "a config that exists"; fi
if sb_project_active "$TL_TMP/nowhere/.silver-bullet.json"; then tl_fail "no config, no record"; else tl_pass "no config and no record is not a project"; fi
if sb_project_is_initiated "$R/.silver-bullet.json"; then tl_pass "the old alias agrees"; else tl_fail "alias"; fi
if sb_config_marked_initiated "$R/.silver-bullet.json"; then tl_pass "sb_initiated true is marked"; else tl_fail "marked"; fi
if sb_config_marked_initiated ""; then tl_fail "empty"; else tl_pass "an empty path is not marked"; fi
printf '{"sb_initiated":false}\n' >"$TL_TMP/off.json"
if sb_config_marked_initiated "$TL_TMP/off.json"; then tl_fail "off"; else tl_pass "sb_initiated false is not marked"; fi
if PATH="$(tl_path_without jq)" sb_config_marked_initiated "$R/.silver-bullet.json"; then tl_fail "no jq"; else tl_pass "without jq nothing is marked"; fi
printf 'not json\n' >"$TL_TMP/bad.json"
if sb_config_marked_initiated "$TL_TMP/bad.json"; then tl_fail "bad"; else tl_pass "an unreadable config is not marked"; fi

# a config path that vanished between the lookup and the check: the hook stands down
out="$(cd "$R/src" && bash -c "source '$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh'; sb_find_project_config() { printf '%s' /nonexistent/.silver-bullet.json; }; sb_project_active_or_exit; echo ran")"
assert_eq "a config that is gone by the time it is checked stands the hook down" "" "$out"

# ── the gate-or-exit helpers ──────────────────────────────────────────────────────────────────────
out="$(cd "$R/src" && bash -c "source '$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh'; sb_project_active_or_exit; echo ran")"
assert_eq "inside a project the hook goes on" "ran" "$out"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
out="$(cd "$TL_TMP" && bash -c "source '$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh'; sb_project_active_or_exit; echo ran")"
assert_eq "outside one it exits quietly" "" "$out"
out="$(cd "$R/src" && bash -c "source '$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh'; sb_project_gate_or_exit; echo ran")"
assert_eq "the old alias too" "ran" "$out"

# ── the root cache ────────────────────────────────────────────────────────────────────────────────
if sb_project_root_cache_write ""; then tl_fail "empty root"; else tl_pass "an empty root is not cached"; fi
if sb_project_root_cache_write "$TL_TMP/nowhere"; then tl_fail "no files"; else tl_pass "a root without contract files is not cached"; fi
if SB_RUNTIME_STATE_DIR="" sb_project_root_cache_write "$R"; then tl_pass "no state dir: nothing to write"; else tl_fail "no state dir"; fi
sb_project_root_cache_write "$R/"
assert_eq "a valid root is cached" "$R" "$(cat "$SB_PROJECT_ROOT_CACHE_FILE")"
assert_eq "and read back" "$R" "$(sb_project_root_cache_read)"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
if sb_project_root_cache_read; then tl_fail "no cache"; else tl_pass "no cache file: nothing"; fi
printf '%s\n' "$TL_TMP/nowhere" >"$SB_PROJECT_ROOT_CACHE_FILE"
if sb_project_root_cache_read; then tl_fail "stale cache"; else tl_pass "a cache that points nowhere is ignored"; fi
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
rmdir_target="$TL_TMP/blocked"; : >"$rmdir_target"
(SB_RUNTIME_STATE_DIR="$rmdir_target/sub" sb_project_root_cache_write "$R") || true
tl_pass "an unwritable state directory is tolerated"

# ── lookups: live pair, record-first, cache fallback ───────────────────────────────────────────────
assert_eq "the project config from a subdirectory" "$R/.silver-bullet.json" "$(cd "$R/src/deep/er" && sb_find_project_config)"
assert_eq "its root" "$R" "$(cd "$R/src/deep/er" && sb_find_project_root)"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
if (cd "$TL_TMP" && sb_find_project_root >/dev/null); then tl_fail "outside"; else tl_pass "outside a project there is no root"; fi
assert_eq "the cache answers when the walk finds nothing" "$R/.silver-bullet.json" "$(sb_project_root_cache_write "$R"; cd "$TL_TMP" && sb_find_project_config_from "$TL_TMP")"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"

# a root with a record is a project when its files are gone, and the record wins over a nested pair
source "$TL_REPO_ROOT/hooks/lib/integrity.sh"
export SILVER_BULLET_BRANCH_FILE="$TL_TMP/branch"
sb_integrity_baseline "$R" session
mv "$R/silver-bullet.md" "$TL_TMP/md.away"
mv "$R/.silver-bullet.json" "$TL_TMP/cfg.away"
assert_eq "files gone, record kept: still the project's config path" "$R/.silver-bullet.json" "$(cd "$R/src" && sb_find_project_config_walk_only)"
if sb_project_active "$R/.silver-bullet.json"; then tl_pass "and the project is active"; else tl_fail "active by record"; fi
assert_eq "the activation helper agrees" "$R/.silver-bullet.json" "$(sb_integrity_activation_config "$R/src")"
assert_eq "outside any project it prints nothing" "" "$(sb_integrity_activation_config "$TL_TMP")"
mkdir -p "$R/src/sub"
printf '# SB\n' >"$R/src/sub/silver-bullet.md"
printf '{}\n' >"$R/src/sub/.silver-bullet.json"
assert_eq "a nested pair does not become the root: the nearest record wins" "$R" "$(sb_integrity_root "$R/src/sub")"
(export SILVER_BULLET_PROJECT_ROOT="$R"; assert_eq "an explicit project root with a record wins" "$R" "$(sb_integrity_root "$TL_TMP")")
mv "$TL_TMP/md.away" "$R/silver-bullet.md"
mv "$TL_TMP/cfg.away" "$R/.silver-bullet.json"
(export SILVER_BULLET_PROJECT_ROOT="$R"; assert_eq "an explicit root holding both files is the live lookup's answer" "$R/.silver-bullet.json" "$(sb_integrity_live_config_walk "$TL_TMP")")

# ── the list helpers' empty-name edge ──────────────────────────────────────────────────────────────
if sb_required_skill_is_recorded "a" ""; then tl_fail "empty skill"; else tl_pass "an empty skill name is never recorded"; fi
assert_eq "its line is 0" "0" "$(sb_required_skill_line "a" "" | head -1)"

tl_results
