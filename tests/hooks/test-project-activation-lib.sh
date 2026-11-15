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

# ── the registry of baselined roots ────────────────────────────────────────────────────────────────────
REG="$SB_RUNTIME_STATE_DIR/baselined-roots"
mkdir -p "$TL_TMP/plain/a/b"
assert_eq "no registry entry, no contract file: no project, the walk ends at the filesystem root" "" "$(sb_integrity_root "$TL_TMP/plain/a/b")"
assert_eq "a path not created yet is judged by its nearest existing ancestor" "" "$(sb_integrity_root "$TL_TMP/plain/a/new/deeper")"
sb_integrity_register_root "$TL_TMP/plain/a"
sb_integrity_register_root "$TL_TMP/plain/a"
assert_eq "registering twice lists the root once" "1" "$(grep -cF -- "$TL_TMP/plain/a"$'\t' "$REG")"
assert_eq "a registered root anchors a deeper path" "$TL_TMP/plain/a" "$(sb_integrity_root "$TL_TMP/plain/a/b")"
assert_eq "and a directory that does not exist yet beneath it" "$TL_TMP/plain/a" "$(sb_integrity_root "$TL_TMP/plain/a/new/deeper")"
sb_integrity_unregister_root "$TL_TMP/plain/a"
assert_eq "an unregistered root anchors nothing again" "" "$(sb_integrity_root "$TL_TMP/plain/a/b")"
sb_integrity_unregister_root "$TL_TMP/never-listed"
mv "$REG" "$REG.away"
sb_integrity_unregister_root "$TL_TMP/plain/a"
assert_eq "unregistering without a registry is a no-op" "no" "$([[ -e "$REG" ]] && echo yes || echo no)"
ln -s /nonexistent "$REG"
sb_integrity_register_root "$TL_TMP/plain/a"
sb_integrity_unregister_root "$TL_TMP/plain/a"
assert_eq "a symlinked registry is never written through" "no" "$([[ -e /nonexistent ]] && echo yes || echo no)"
rm -f "$REG"
mkdir "$REG"
sb_integrity_register_root "$TL_TMP/plain/a"
assert_eq "a registry that cannot be written is left alone (no failure)" "dir" "$([[ -d "$REG" ]] && echo dir || echo other)"
rmdir "$REG"
# an install whose registry is gone still finds a root by its record
sb_integrity_baseline "$R" session
rm -f "$REG"
assert_eq "without a registry the record still names the root" "$R" "$(sb_integrity_record_root "$R/src")"
assert_eq "and a directory without either is no root" "" "$(sb_integrity_record_root "$TL_TMP/plain")"
mv "$REG.away" "$REG"

# ── a root is registered OR has a record; the inode follows a renamed root ─────────────────────────
RT="$TL_TMP/reg-matrix"; mkdir -p "$RT"
rec_only() { sb_integrity_baseline "$1" session; }
mkdir -p "$RT/p1/src" "$RT/p2/src" "$RT/p3/src"
for q in p1 p2 p3; do printf '# SB\n' >"$RT/$q/silver-bullet.md"; printf '{"sb_initiated":true}\n' >"$RT/$q/.silver-bullet.json"; done
P1="$(cd "$RT/p1" && pwd -P)"
rm -f "$SB_RUNTIME_STATE_DIR"/integrity-*; rm -f "$REG"
sb_integrity_baseline "$P1" session
assert_eq "registered and recorded: the root" "$P1" "$(sb_integrity_root "$P1/src")"
: >"$REG"
assert_eq "registry emptied, record kept: still the root" "$P1" "$(sb_integrity_root "$P1/src")"
printf '/somewhere/else\t1:2\n' >"$REG"
assert_eq "registry replaced, record kept: still the root" "$P1" "$(sb_integrity_root "$P1/src")"
rm -f "$REG"
assert_eq "registry deleted, record kept: still the root" "$P1" "$(sb_integrity_record_root "$P1/src")"
sb_integrity_register_root "$P1"
rm -f "$SB_RUNTIME_STATE_DIR"/integrity-*
assert_eq "record deleted, registry kept: still the root" "$P1" "$(sb_integrity_record_root "$P1/src")"
: >"$REG"
assert_eq "both gone: no anchor (the documented residual)" "" "$(sb_integrity_record_root "$P1/src")"
# a plain registry line (no inode) is read too
printf '%s\n' "$P1" >"$REG"
assert_eq "a plain registry line names the root" "$P1" "$(sb_integrity_record_root "$P1/src")"
# a renamed root is found by its inode; a stale entry (path gone, inode nowhere) is ignored
rm -f "$REG"; sb_integrity_register_root "$P1"
mv "$P1" "$RT/p1-moved"
assert_eq "renamed root: recognised by its inode" "$RT/p1-moved" "$(sb_integrity_record_root "$RT/p1-moved/src")"
assert_eq "an unrelated directory is no root beside the stale entry" "" "$(sb_integrity_record_root "$RT/p2/src")"
# a different project later placed at the old path (the moved one is still alive, so the inode differs) is not that root
mkdir -p "$RT/p1/src"
assert_eq "a different directory at the old path: not the registered root" "" "$(sb_integrity_record_root "$RT/p1/src")"
rm -rf "$RT/p1" "$RT/p1-moved"
assert_eq "the project is gone: the stale entry anchors nothing and blocks nothing" "" "$(sb_integrity_record_root "$RT/p2/src")"
# registered twice, nested roots, a symlinked path
P2="$(cd "$RT/p2" && pwd -P)"
rm -f "$REG"; sb_integrity_register_root "$P2"; sb_integrity_register_root "$P2"
assert_eq "registered twice: one root" "$P2" "$(sb_integrity_record_root "$P2/src")"
mkdir -p "$P2/inner/src"
sb_integrity_register_root "$P2/inner"
assert_eq "nested roots: the nearest wins" "$P2/inner" "$(sb_integrity_record_root "$P2/inner/src")"
assert_eq "nested roots: the outer one still holds its other paths" "$P2" "$(sb_integrity_record_root "$P2/src")"
ln -s "$P2" "$RT/link"
assert_eq "a symlinked path resolves to the registered root" "$P2" "$(sb_integrity_record_root "$RT/link/src")"
sb_integrity_unregister_root "$P2"
assert_eq "retirement drops every line of a root" "0" "$(grep -cF -- "$P2"$'\t' "$REG" || true)"
# identities: line-aligned whatever stat does, birth time normalised, BSD stat as the fallback
IDD="$TL_TMP/ids"; mkdir -p "$IDD/a" "$IDD/b"
out="$(_sb_iv_dir_ids "$IDD/a" "$IDD/nonexistent" "$IDD/b")"
assert_eq "one identity per argument, '-' where stat failed, aligned" "3" "$(grep -c . <<<"$out")"
assert_eq "the failed middle argument is '-'" "-" "$(sed -n 2p <<<"$out")"
assert_eq "the arguments around it keep their own identity" "$(_sb_iv_dir_id "$IDD/b")" "$(sed -n 3p <<<"$out")"
STUB="$TL_TMP/statstub"; mkdir -p "$STUB"
printf '#!/bin/bash\nexit 1\n' >"$STUB/stat"; chmod +x "$STUB/stat"
out="$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_dir_ids /tmp /' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
assert_eq "stat failing outright: every identity is '-'" "-|-" "$(tr '\n' '|' <<<"$out" | sed 's/|$//')"
printf '#!/bin/bash\ncase "$1" in --version) exit 1 ;; -f) shift; shift; for d in "$@"; do echo "7:$(basename "$d" | tr -dc 0-9):0"; done ;; *) exit 1 ;; esac\n' >"$STUB/stat"
mkdir -p "$TL_TMP/d11" "$TL_TMP/d22"
out="$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_dir_ids "$2" "$3"' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$TL_TMP/d11" "$TL_TMP/d22")"
assert_eq "BSD stat is the fallback; a zero birth time is dropped" "7:11|7:22" "$(tr '\n' '|' <<<"$out" | sed 's/|$//')"
printf '#!/bin/bash\ncase "$1" in --version) exit 0 ;; *) echo "3:4:?"; echo "garbage" ;; esac\n' >"$STUB/stat"
out="$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_dir_ids /tmp /' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
assert_eq "an unknown birth time is dropped, garbage is '-'" "3:4|-" "$(tr '\n' '|' <<<"$out" | sed 's/|$//')"
# a root without an identity falls back to the path for its record name
printf '#!/bin/bash\nexit 1\n' >"$STUB/stat"
assert_eq "no identity: the record is keyed by the path" "$(_sb_iv_cksum "p:/nowhere/x")" "$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_cksum_var "$(_sb_iv_root_key /nowhere/x)"; printf "%s" "$_SB_IV_SUM"' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
# the record name is the POSIX cksum of the root
for str in "" "a" "$P2" "héllo/ü" "$(head -c 200 /dev/urandom | base64 -w0)"; do
  assert_eq "bash cksum matches cksum(1) for '${str:0:20}'" "$(printf '%s' "$str" | cksum | cut -d' ' -f1)" "$(_sb_iv_cksum "$str")"
done

# ── the list helpers' empty-name edge ──────────────────────────────────────────────────────────────
if sb_required_skill_is_recorded "a" ""; then tl_fail "empty skill"; else tl_pass "an empty skill name is never recorded"; fi
assert_eq "its line is 0" "0" "$(sb_required_skill_line "a" "" | head -1)"

tl_results
