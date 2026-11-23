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
assert_eq "record and registry gone, marker kept: still the root" "$P1" "$(sb_integrity_record_root "$P1/src")"
assert_eq "the marker anchors the logical ancestors too" "$P1" "$(cd "$TL_TMP" && sb_integrity_record_root "$P1/src/../src")"
rm -f "$SB_RUNTIME_STATE_DIR"/root-*
assert_eq "all three anchors gone: no anchor (the documented residual)" "" "$(sb_integrity_record_root "$P1/src")"
_sb_iv_cksum_var "$P1"
ln -s "$TL_TMP/marker-target" "$SB_RUNTIME_STATE_DIR/root-$_SB_IV_SUM"
sb_integrity_register_root "$P1"
assert_eq "a symlink at the marker's name is never written through" "no" "$([[ -e "$TL_TMP/marker-target" ]] && echo yes || echo no)"
rm -f "$SB_RUNTIME_STATE_DIR/root-$_SB_IV_SUM"
: >"$REG"
# a plain registry line (no inode) is read too
printf '%s\n' "$P1" >"$REG"
assert_eq "a plain registry line names the root" "$P1" "$(sb_integrity_record_root "$P1/src")"
# a renamed root is found by its inode; a stale entry (path gone, inode nowhere) is ignored
rm -f "$REG"; sb_integrity_register_root "$P1"
mv "$P1" "$RT/p1-moved"
assert_eq "renamed root: recognised by its inode" "$RT/p1-moved" "$(sb_integrity_record_root "$RT/p1-moved/src")"
assert_eq "an unrelated directory is no root beside the stale entry" "" "$(sb_integrity_record_root "$RT/p2/src")"
# a different directory placed at the registered path is that root as far as the path goes (the line is only removed by retirement)
mkdir -p "$RT/p1/src"
assert_eq "a different directory at a registered path stays strict (by design, until the line is retired)" "$RT/p1" "$(sb_integrity_record_root "$RT/p1/src")"
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
# the single-directory identity drops an unknown birth time in every spelling, and 'no identity' keys by the path
for spelling in "1:2:0" "1:2:?" "1:2:-"; do
  printf '#!/bin/bash\ncase "$1" in --version) exit 0 ;; *) echo "%s" ;; esac\n' "$spelling" >"$STUB/stat"
  assert_eq "identity from '$spelling' is device:inode" "1:2" "$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_dir_id /tmp' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
done
printf '#!/bin/bash\nexit 1\n' >"$STUB/stat"
assert_eq "no identity: the root key is the path" "p:/x/y" "$(PATH="$STUB:$PATH" bash -c 'source "$1"; _sb_iv_root_key /x/y' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
NOID="$TL_TMP/noid-root"; mkdir -p "$NOID/src"
sb_integrity_baseline "$R" session
_sb_iv_cksum_var "p:$NOID"; : >"$SB_RUNTIME_STATE_DIR/integrity-$_SB_IV_SUM.rec"
assert_eq "no identity: a record named by the path still anchors the root" "$NOID" "$(PATH="$STUB:$PATH" bash -c 'source "$1"; sb_integrity_record_root "$2"' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$NOID/src")"
rm -f "$SB_RUNTIME_STATE_DIR/integrity-$_SB_IV_SUM.rec"
# unregistering a root drops the lines of its identity under other paths too
rm -f "$REG"
mkdir -p "$TL_TMP/twin-a" "$TL_TMP/other-b"
TID="$(_sb_iv_dir_id "$TL_TMP/twin-a")"
printf '%s\t%s\n%s\t%s\n%s\t%s\n' "$TL_TMP/old-name" "$TID" "$TL_TMP/other-b" "$(_sb_iv_dir_id "$TL_TMP/other-b")" "$TL_TMP/twin-a" "$TID" >"$REG"
sb_integrity_unregister_root "$TL_TMP/twin-a"
assert_eq "a renamed root loses its old-path line as well" "no" "$([[ "$(<"$REG")" == *old-name* ]] && echo yes || echo no)"
assert_eq "and keeps unrelated roots" "yes" "$([[ "$(<"$REG")" == *other-b* ]] && echo yes || echo no)"
# pruning: blank lines, plain lines, live lines, a path that holds another directory, a renamed twin, the cap
mkdir -p "$TL_TMP/pr-live" "$TL_TMP/pr-other"
LID="$(_sb_iv_dir_id "$TL_TMP/pr-live")"
printf '\n%s\n%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s\n' "$TL_TMP/pr-plain" "$TL_TMP/pr-live" "$LID" "$TL_TMP/pr-other" "9:9" "$TL_TMP/pr-gone-twin" "$LID" "$TL_TMP/pr-gone-alone" "8:8:8" >"$REG"
sb_integrity_prune_registry
pr="$(<"$REG")"
assert_eq "prune keeps a plain line" "yes" "$([[ "$pr" == *pr-plain* ]] && echo yes || echo no)"
assert_eq "prune keeps a live line" "yes" "$([[ "$pr" == *$'\n'"$TL_TMP/pr-live"* || "$pr" == "$TL_TMP/pr-live"* ]] && echo yes || echo no)"
assert_eq "prune keeps a dev:ino line whose path now holds another directory (the path stays registered)" "yes" "$([[ "$pr" == *pr-other* ]] && echo yes || echo no)"
mkdir -p "$TL_TMP/pr-bt"
printf '%s\t%s\n' "$TL_TMP/pr-bt" "9:9:5" >"$REG"
sb_integrity_prune_registry
assert_eq "prune keeps a line with a birth time whose path holds another directory" "yes" "$([[ "$(<"$REG")" == *pr-bt* ]] && echo yes || echo no)"
# a directory that vanishes between listing and identity: no unbound read, the line is kept or dropped on its own
printf '%s\t%s\n%s\t%s\n' "$TL_TMP/pr-bt" "9:9:5" "$TL_TMP/pr-live" "$LID" >"$REG"
RACE="$TL_TMP/racestub"; mkdir -p "$RACE"
printf '#!/bin/bash\ncase "$1" in --version) exit 0 ;; *) shift; shift; for d in "$@"; do case "$d" in *pr-bt) rmdir "$d" 2>/dev/null; echo "1:1:1" ;; *) echo "$(/usr/bin/stat -c %%d:%%i:%%W "$d")" ;; esac; done ;; esac\n' >"$RACE/stat"; chmod +x "$RACE/stat"
PATH="$RACE:$PATH" bash -c 'set -u; source "$1"; sb_integrity_prune_registry' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh"
assert_eq "a directory vanishing mid-prune does not abort (set -u)" "0" "$?"
assert_eq "and the line of the live directory survives" "yes" "$([[ "$(<"$REG")" == *pr-live* ]] && echo yes || echo no)"
printf '%s\t%s\n' "$TL_TMP/pr-other" "9:9" >"$REG"
assert_eq "prune drops the old name of a root that lives on" "no" "$([[ "$pr" == *pr-gone-twin* ]] && echo yes || echo no)"
assert_eq "prune keeps a gone path whose identity is nowhere else" "yes" "$([[ "$pr" == *pr-gone-alone* ]] && echo yes || echo no)"
rm -f "$REG"; sb_integrity_prune_registry
assert_eq "pruning without a registry is a no-op" "no" "$([[ -e "$REG" ]] && echo yes || echo no)"
: >"$REG"
for n in $(seq 1 230); do printf '%s\t%s\n' "$TL_TMP/cap$n" "8:$n:1" >>"$REG"; done
sb_integrity_prune_registry
assert_eq "the cap keeps at most 200 lines" "ok" "$([[ "$(grep -c . "$REG")" -le 200 ]] && echo ok || echo big)"
assert_eq "the cap keeps the newest" "yes" "$([[ "$(<"$REG")" == *cap230* ]] && echo yes || echo no)"
rm -f "$REG"
# concurrent writers: parallel registrations and prunes keep every root anchored, every worker exits 0, nothing
# hangs, and no two workers are ever inside a rewrite at once. Each worker records its own exit status in a file
# (an EXIT trap), so a death is seen without relying on `wait` (Bash 5.2 answers 127, "not a child of this shell",
# for a job it has already reaped). `date` is slowed a little inside the workers: it runs between a holder's
# mkdir and its claim, the window a loaded machine stretches. The rewrite is wrapped in a probe that takes a
# second, independent mkdir mutex; a second holder inside the rewrite is a violation, whatever the timing luck.
rm -f "$REG"; rm -rf "$REG.lock"
CC="$TL_TMP/conc"; rm -rf "$CC"; mkdir -p "$CC/probe-parent"
CW="$TL_TMP/conc-worker.sh"
cat >"$CW" <<'CWEOF'
set -euo pipefail
source "$1"
CC="$2"; w="$3"; rounds="$4"
status="$CC/status.$w"
trap 'printf "%s\n" "$?" >"$status"' EXIT
date() { sleep "0.0$((RANDOM % 4))"; command date "$@"; }
eval "_probed_register$(declare -f _sb_iv_register_unlocked | sed '1s/^_sb_iv_register_unlocked//')"
eval "_probed_prune$(declare -f _sb_iv_prune_unlocked | sed '1s/^_sb_iv_prune_unlocked//')"
_probe_enter() { if ! mkdir "$CC/probe" 2>/dev/null; then : >"$CC/violation.$w"; fi; sleep 0.01; }
_probe_leave() { rmdir "$CC/probe" 2>/dev/null || :; }
_sb_iv_register_unlocked() { if [[ -n "${2:-}" ]]; then _probe_enter; fi; _probed_register "$@"; if [[ -n "${2:-}" ]]; then _probe_leave; fi; }
_sb_iv_prune_unlocked() { _probe_enter; _probed_prune "$@"; _probe_leave; }
for n in $(seq 1 "$rounds"); do
  mkdir -p "$CC/w$w-r$n"
  sb_integrity_register_root "$CC/w$w-r$n"
  if [[ $((n % 3)) -eq 0 ]]; then sb_integrity_prune_registry; fi
done
CWEOF
WP=()
for w in 1 2 3 4 5 6 7 8; do
  bash "$CW" "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$CC" "$w" 6 &
  WP+=($!)
done
for pid in "${WP[@]}"; do wait "$pid" || :; done
spins=0
while [[ $(find "$CC" -maxdepth 1 -name 'status.*' | grep -c .) -lt 8 && $spins -lt 600 ]]; do sleep 0.1; spins=$((spins + 1)); done
bad=0
for w in 1 2 3 4 5 6 7 8; do if [[ "$(cat "$CC/status.$w" 2>/dev/null)" != 0 ]]; then bad=$((bad + 1)); fi; done
assert_eq "no parallel worker died" "0" "$bad"
assert_eq "no two workers were inside a registry rewrite at once" "0" "$(find "$CC" -maxdepth 1 -name 'violation.*' | grep -c . || true)"
anchored=0
for w in 1 2 3 4 5 6 7 8; do for n in 1 2 3 4 5 6; do if [[ "$(sb_integrity_record_root "$CC/w$w-r$n")" == "$CC/w$w-r$n" ]]; then anchored=$((anchored + 1)); fi; done; done
assert_eq "48 parallel registrations: every root is anchored (line, marker or record)" "48" "$anchored"
assert_eq "the lock is released" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
assert_eq "no temporary file is left behind" "0" "$(find "$SB_RUNTIME_STATE_DIR" -maxdepth 1 -name 'baselined-roots.*' | grep -c . || true)"
# with the lock obtainable (no contention) every line survives, prunes in between included
rm -f "$REG"
for n in $(seq 1 30); do
  mkdir -p "$CC/seq$n"
  sb_integrity_register_root "$CC/seq$n"
  if [[ $((n % 10)) -eq 0 ]]; then sb_integrity_prune_registry; fi
done
assert_eq "30 sequential registrations with prunes in between: all 30 lines" "30" "$(grep -c "$CC/seq" "$REG")"
# a lock whose owner is dead is taken over (the first protocol's pid file and the claim file alike); a lock with
# no claim yet is a holder between its mkdir and its claim: never taken over young, taken over once a minute old
mkdir "$REG.lock"; printf '%s' 999999 >"$REG.lock/pid"
sb_integrity_register_root "$CC/after-dead-owner"
assert_eq "a lock whose owner is dead is taken over" "yes" "$([[ "$(<"$REG")" == *after-dead-owner* ]] && echo yes || echo no)"
assert_eq "and is released again" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
mkdir "$REG.lock"; printf '%s %s\n' 999999 "$(date +%s)" >"$REG.lock/claim.999999.12"
sb_integrity_register_root "$CC/after-dead-claim"
assert_eq "a claim of a dead process is taken over too" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
assert_eq "and its registration landed" "yes" "$([[ "$(<"$REG")" == *after-dead-claim* ]] && echo yes || echo no)"
mkdir "$REG.lock"
SECONDS=0
sb_integrity_register_root "$CC/after-pidless-lock"
assert_eq "a young lock with no claim yet is not taken over (its holder is between mkdir and claim)" "yes" "$([[ -d "$REG.lock" ]] && echo yes || echo no)"
assert_eq "its wait is bounded" "ok" "$([[ $SECONDS -le 20 ]] && echo ok || echo slow)"
assert_eq "and the registration still landed (one append)" "yes" "$([[ "$(<"$REG")" == *after-pidless-lock* ]] && echo yes || echo no)"
touch -t 200001010000 "$REG.lock"
sb_integrity_register_root "$CC/after-aged-lock"
assert_eq "a lock with no claim that is a minute old is taken over" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
# a foreign (non-claim) file in the lock directory keeps the lock held (documented in KNOWN-LIMITS.md): the rewrite is
# skipped, the registration still lands, and removing the directory recovers
mkdir "$REG.lock"; printf '999999 1\n' >"$REG.lock/foreign.txt"
sb_integrity_register_root "$CC/under-foreign-file-lock"
assert_eq "a foreign file keeps the lock held (never removed)" "yes" "$([[ -f "$REG.lock/foreign.txt" ]] && echo yes || echo no)"
assert_eq "and the registration still landed" "yes" "$([[ "$(<"$REG")" == *under-foreign-file-lock* ]] && echo yes || echo no)"
rm -rf "$REG.lock"
sb_integrity_register_root "$CC/after-recovery"
assert_eq "removing the lock directory recovers: the next registration takes and releases the lock" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
# a lock path that is a symlink is never entered: give up at once, nothing behind the link is touched
mkdir "$CC/linked-lock"; printf x >"$CC/linked-lock/claim.999999.1"; ln -s "$CC/linked-lock" "$REG.lock"
SECONDS=0
sb_integrity_register_root "$CC/under-symlinked-lock"
assert_eq "a symlinked lock is left alone" "yes" "$([[ -L "$REG.lock" && -f "$CC/linked-lock/claim.999999.1" ]] && echo yes || echo no)"
assert_eq "without waiting for it" "ok" "$([[ $SECONDS -le 2 ]] && echo ok || echo slow)"
assert_eq "the registration still landed" "yes" "$([[ "$(<"$REG")" == *under-symlinked-lock* ]] && echo yes || echo no)"
rm -f "$REG.lock"
# a lock released between a failed mkdir and the look at its path is retaken, not given up (the rewrite would be
# skipped for the whole session): the first mkdir fails as if another holder had the lock, which is gone by the next look
cp "$REG" "$TL_TMP/reg.before-rel"; rm -f "$REG"; mkdir -p "$CC/rel-a" "$CC/rel-b"
sb_integrity_register_root "$CC/rel-a"; sb_integrity_register_root "$CC/rel-b"
export MKDIR_FLAG="$TL_TMP/mkdir-once" MKDIR_LOCK="$REG.lock"; rm -f "$MKDIR_FLAG"
tl_stub mkdir 'if [ "${1:-}" = "$MKDIR_LOCK" ] && [ ! -e "$MKDIR_FLAG" ]; then : >"$MKDIR_FLAG"; exit 1; fi; exec "$(command -v -p mkdir)" "$@"'; hash -r
sb_integrity_unregister_root "$CC/rel-a"
rm -f "$TL_BIN/mkdir"; hash -r
assert_eq "the first mkdir really failed (the stub ran)" "yes" "$([[ -e "$MKDIR_FLAG" ]] && echo yes || echo no)"
assert_eq "a lock released in that instant is retaken: the unregister is not skipped" "no" "$([[ "$(<"$REG")" == *rel-a* ]] && echo yes || echo no)"
assert_eq "and the other line stays" "yes" "$([[ "$(<"$REG")" == *rel-b* ]] && echo yes || echo no)"
assert_eq "and the lock is released again" "no" "$([[ -e "$REG.lock" ]] && echo yes || echo no)"
# a lock path that is a plain file is never replaced or waited for: give up at once, rewrite skipped
: >"$REG.lock"; SECONDS=0
sb_integrity_unregister_root "$CC/rel-b"
assert_eq "a plain file at the lock path: the rewrite is skipped" "yes" "$([[ "$(<"$REG")" == *rel-b* ]] && echo yes || echo no)"
assert_eq "without waiting for it" "ok" "$([[ $SECONDS -le 2 ]] && echo ok || echo slow)"
assert_eq "and the file is left alone" "yes" "$([[ -f "$REG.lock" ]] && echo yes || echo no)"
rm -f "$REG.lock"
cp "$TL_TMP/reg.before-rel" "$REG"
# a live owner is never robbed: the rewrite is skipped, the registration still lands (one append)
sleep 30 &
LIVE=$!
mkdir "$REG.lock"; printf '%s %s\n' "$LIVE" "$(date +%s)" >"$REG.lock/pid"
printf '%s\t%s\n' "$CC/stale-a" "8:8:8" >>"$REG"
SECONDS=0
sb_integrity_prune_registry
sb_integrity_unregister_root "$CC/after-pidless-lock"
sb_integrity_register_root "$CC/under-live-lock"
assert_eq "a held lock is bounded: three writers returned within the wait" "ok" "$([[ $SECONDS -le 20 ]] && echo ok || echo slow)"
assert_eq "a live owner's lock is not taken over" "yes" "$([[ -d "$REG.lock" ]] && echo yes || echo no)"
assert_eq "its rewrites (unregister) were skipped" "yes" "$([[ "$(<"$REG")" == *after-pidless-lock* ]] && echo yes || echo no)"
assert_eq "but the registration was appended without the lock" "yes" "$([[ "$(<"$REG")" == *under-live-lock* ]] && echo yes || echo no)"
# ... but a lock older than 30 s is taken over even when its owner's PID is alive (a reused PID)
rm -rf "$REG.lock"; mkdir "$REG.lock"; printf '%s %s\n' "$LIVE" 1 >"$REG.lock/claim.$LIVE.5"
sb_integrity_unregister_root "$CC/after-pidless-lock"
assert_eq "a lock older than 30 s is taken over although its owner is alive" "no" "$([[ "$(<"$REG")" == *after-pidless-lock* ]] && echo yes || echo no)"
kill "$LIVE" 2>/dev/null; wait "$LIVE" 2>/dev/null || true
rm -rf "$REG.lock"
# a state directory that cannot hold a lock: give up at once, no hang, no failure
SECONDS=0
out="$(SB_RUNTIME_STATE_DIR="$TL_TMP/no-such-state-dir" bash -c 'set -u; source "$1"; sb_integrity_prune_registry; sb_integrity_unregister_root /x; sb_integrity_register_root /x; echo done' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh")"
assert_eq "a missing state directory: the writers return at once" "done" "$out"
assert_eq "and quickly" "ok" "$([[ $SECONDS -le 3 ]] && echo ok || echo slow)"
# the claim protocol, piece by piece (a lock directory standing alone)
LK="$TL_TMP/lk"; rm -rf "$LK"; mkdir "$LK"
stale_of() { if _sb_iv_claim_stale "$1"; then echo stale; else echo live; fi; }
printf '%s %s\n' 999999 "$(date +%s)" >"$LK/claim.999999.1"
assert_eq "a claim of a dead process is stale" "stale" "$(stale_of "$LK/claim.999999.1")"
printf '%s %s\n' "$$" "$(date +%s)" >"$LK/claim.$$.1"
assert_eq "a young claim of a live process is not stale" "live" "$(stale_of "$LK/claim.$$.1")"
printf '%s %s\n' "$$" 1 >"$LK/claim.$$.2"
assert_eq "a claim older than 30 s is stale although its process lives (PID reuse)" "stale" "$(stale_of "$LK/claim.$$.2")"
printf '%s %s\n' "$$" "not-a-time" >"$LK/claim.$$.3"
assert_eq "a live claim whose time is unreadable is not stale" "live" "$(stale_of "$LK/claim.$$.3")"
: >"$LK/claim.$$.4"
assert_eq "a claim being written (no pid yet) is not stale" "live" "$(stale_of "$LK/claim.$$.4")"
touch -t 200001010000 "$LK/claim.$$.4"
assert_eq "but one that never got its pid in a minute is" "stale" "$(stale_of "$LK/claim.$$.4")"
assert_eq "a claim that is gone is not stale (nothing to take over)" "live" "$(stale_of "$LK/claim.$$.gone")"
rm -f "$LK"/claim.*
# reclaim: only stale claim-named regular files are removed; anything else keeps the lock held
printf '%s %s\n' 999999 "$(date +%s)" >"$LK/claim.999999.1"
printf '999999 1\n' >"$LK/keep.txt"
ln -s "$LK/keep.txt" "$LK/claim.999999.2"
if _sb_iv_lock_reclaim "$LK"; then r=gone; else r=held; fi
assert_eq "reclaim leaves a lock with a foreign file or a linked claim held" "held" "$r"
assert_eq "it removed the stale claim file only" "yes" "$([[ ! -e "$LK/claim.999999.1" && -f "$LK/keep.txt" && -L "$LK/claim.999999.2" ]] && echo yes || echo no)"
rm -f "$LK/keep.txt" "$LK/claim.999999.2"
printf '%s %s\n' 999999 "$(date +%s)" >"$LK/claim.999999.3"
if _sb_iv_lock_reclaim "$LK"; then r=gone; else r=held; fi
assert_eq "reclaim removes a lock whose claims are all stale" "gone" "$r"
assert_eq "directory and all" "no" "$([[ -e "$LK" ]] && echo yes || echo no)"
mkdir "$LK"
if _sb_iv_lock_reclaim "$LK"; then r=gone; else r=held; fi
assert_eq "reclaim leaves a young lock with no claim to its holder" "held" "$r"
# two holders cannot both win: a claim that lands between this holder's mkdir and its own claim makes it lose
out="$(bash -c 'set -u; source "$1"; lock="$2"; date() { printf "%s %s\n" "$$" 1 >"$lock/claim.$$.1"; command date "$@"; }; if _sb_iv_lock_claim "$lock"; then echo won; else echo lost; fi; ls "$lock"' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$LK" | tr '\n' ' ')"
assert_eq "a foreign claim in the directory makes this holder lose, and it removes only its own claim" "lost claim.$$.1 " "$(printf '%s' "$out" | sed "s/claim\.[0-9]*\.1 /claim.$$.1 /;s/^lost claim\.[0-9]*\.1/lost claim.$$.1/")"
rm -rf "$LK"; mkdir "$LK"
out="$(bash -c 'set -u; source "$1"; if _sb_iv_lock_claim "$2"; then echo won; else echo lost; fi' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$LK")"
assert_eq "alone in the directory, a holder wins" "won" "$out"
rm -rf "$LK"
out="$(bash -c 'set -u; source "$1"; if _sb_iv_lock_claim "$2"; then echo won; else echo lost; fi' _ "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$LK")"
assert_eq "a claim that cannot be written (no lock directory) loses without error" "lost" "$out"
# unlock removes only a lock that still holds our claim
UNL="$TL_TMP/unlock.sh"
cat >"$UNL" <<'UEOF'
set -eu
source "$1"
export SB_RUNTIME_STATE_DIR="$2"; rm -rf "$SB_RUNTIME_STATE_DIR"; mkdir -p "$SB_RUNTIME_STATE_DIR"
lock="$(_sb_iv_registry_file).lock"
_sb_iv_reg_lock
mine="$_SB_IV_LOCK_CLAIM"
# our claim is taken over and a new owner holds the lock
rm -rf "$lock"; mkdir "$lock"; printf '%s %s\n' "$$" "$(date +%s)" >"$lock/claim.$$.77"
_sb_iv_reg_unlock
if [[ -f "$lock/claim.$$.77" ]]; then echo kept; else echo robbed; fi
rm -rf "$lock"
_sb_iv_reg_lock
_sb_iv_reg_unlock
if [[ -e "$lock" ]]; then echo left; else echo released; fi
_sb_iv_reg_lock
mine="$_SB_IV_LOCK_CLAIM"; printf x >"$lock/foreign"
_sb_iv_reg_unlock
if [[ -d "$lock" && ! -e "$mine" && -f "$lock/foreign" ]]; then echo own-claim-only; else echo wrong; fi
_sb_iv_reg_unlock
echo twice
UEOF
out="$(bash "$UNL" "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$TL_TMP/unlock-state" 2>&1 | tr '\n' ' ')" || true
assert_eq "unlock leaves a lock whose claim was taken over to its new owner, releases its own, and is idempotent" "kept released own-claim-only twice " "$out"
# a failing rename of the rewritten registry must not end a set -e caller (prune, unregister and the cap)
MVF="$TL_TMP/mvfail.sh"
cat >"$MVF" <<'MEOF'
set -euo pipefail
source "$1"
export SB_RUNTIME_STATE_DIR="$2"; rm -rf "$SB_RUNTIME_STATE_DIR"; mkdir -p "$SB_RUNTIME_STATE_DIR"
mv() { return 1; }
REG="$(_sb_iv_registry_file)"
printf '%s\t%s\n' /a 1:1:1 /b 1:2:1 >"$REG"
sb_integrity_prune_registry; echo prune
sb_integrity_unregister_root /a; echo unregister
for n in $(seq 1 205); do printf '/cap%s\t8:%s:1\n' "$n" "$n"; done >"$REG"
sb_integrity_register_root /new; echo cap
ls "$SB_RUNTIME_STATE_DIR" | grep -c 'baselined-roots\.' || :
MEOF
out="$(bash "$MVF" "$TL_REPO_ROOT/hooks/lib/integrity-anchor.sh" "$TL_TMP/mvfail-state" 2>&1 | tr '\n' ' ')" || true
assert_eq "a failing rename ends no caller, leaves no temporary file" "prune unregister cap 0 " "$out"
rm -f "$REG"
# a relative directory is judged from the working directory
sb_integrity_register_root "$P2"
assert_eq "a relative directory resolves against the working directory" "$P2" "$(cd "$P2" && sb_integrity_record_root src)"
sb_integrity_unregister_root "$P2"
# markers: written with the identity, removed by identity and by path, pruned by the twin rule only
rm -f "$SB_RUNTIME_STATE_DIR"/root-*; rm -f "$REG"
MK="$TL_TMP/mk"; mkdir -p "$MK/a" "$MK/b"
sb_integrity_register_root "$MK/a"; sb_integrity_register_root "$MK/b"
assert_eq "a marker is written per registered path" "2" "$(ls "$SB_RUNTIME_STATE_DIR"/root-* | wc -l | tr -d ' ')"
mv "$MK/a" "$MK/a2"; sb_integrity_register_root "$MK/a2"
sb_integrity_prune_registry
assert_eq "the twin rule drops the old-name marker of a renamed root" "2" "$(ls "$SB_RUNTIME_STATE_DIR"/root-* | wc -l | tr -d ' ')"
mkdir "$MK/a"
assert_eq "a different directory at the old path is not held once the old marker is gone" "" "$(sb_integrity_record_root "$MK/a")"
rm -rf "$MK/b"; mkdir "$MK/b"
assert_eq "a marker whose path holds another directory stays (the path stays held)" "$MK/b" "$(sb_integrity_record_root "$MK/b")"
sb_integrity_prune_registry
assert_eq "and survives the prune" "$MK/b" "$(sb_integrity_record_root "$MK/b")"
sb_integrity_unregister_root "$MK/a2"
assert_eq "unregistering removes the marker" "" "$(sb_integrity_record_root "$MK/a2")"
assert_eq "and only that root's" "$MK/b" "$(sb_integrity_record_root "$MK/b")"
printf 'not-a-marker-with-tabs' >"$SB_RUNTIME_STATE_DIR/root-1"
sb_integrity_prune_registry
sb_integrity_unregister_root "$MK/b"
rm -f "$SB_RUNTIME_STATE_DIR"/root-* "$REG"
# a marker anchors through the LOGICAL spelling too: the registered path is a symlink now, the registry and the record are gone
rm -f "$SB_RUNTIME_STATE_DIR"/root-* "$REG" "$SB_RUNTIME_STATE_DIR"/integrity-*
LM="$TL_TMP/lm"; mkdir -p "$LM/root/src" "$LM/elsewhere/src"
LMR="$(cd "$LM/root" && pwd -P)"
sb_integrity_register_root "$LMR"
rm -f "$REG" "$SB_RUNTIME_STATE_DIR"/integrity-*
mv "$LM/root" "$LM/root.o"; ln -s "$LM/elsewhere" "$LM/root"
assert_eq "a symlink at a marked path is still the marked root (logical spelling)" "$LMR" "$(sb_integrity_record_root "$LM/root/src")"
rm -f "$SB_RUNTIME_STATE_DIR"/root-*
# ancestors in one pass: the CRC of every ancestor equals the cksum of that string
for str in "/" "/a" "/a/b" "/a/b/c" "/a b/c d/e" "$P2" "$P2/src/deep/er" "/héllo/ü/x" "$(printf '/seg%s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)"; do
  _sb_iv_cksum_ancestors "$str"
  want=""; d="$str"
  while true; do
    want+="$(printf '%s' "$d" | cksum | cut -d' ' -f1) "
    [[ "$d" != "/" ]] || break
    d="${d%/*}"; [[ -n "$d" ]] || d="/"
  done
  assert_eq "ancestor sums of '${str:0:24}' equal the cksum of each ancestor" "$want" "${_SB_IV_ASUM[*]} "
done
# markers hold a path: a second path with the SAME CRC is no anchor, never displaces the first one's marker, and the
# first one stays anchored (two colliding names are built at run time by a birthday search over same-length paths)
rm -f "$SB_RUNTIME_STATE_DIR"/root-* "$REG" "$SB_RUNTIME_STATE_DIR"/integrity-*
CP="$(python3 - "$TL_TMP/col" <<'PYE'
import random, sys
def table():
    out = []
    for i in range(256):
        c = i << 24
        for _ in range(8):
            c = ((c << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if c & 0x80000000 else (c << 1) & 0xFFFFFFFF
        out.append(c)
    return out
T = table()
def cksum(data):
    crc = 0
    for b in data:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ T[((crc >> 24) ^ b) & 0xFF]
    n = len(data)
    while n:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ T[((crc >> 24) ^ n) & 0xFF]
        n >>= 8
    return ~crc & 0xFFFFFFFF
base = sys.argv[1]
seen = {}
rng = random.Random(7)  # fixed seed: the same two paths every run (a change of the last four bytes alone never collides)
while True:
    name = "".join(rng.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(8))
    path = "%s/%s" % (base, name)
    key = cksum(path.encode())
    if key in seen and seen[key] != path:
        print(seen[key] + "\n" + path)
        break
    seen[key] = path
PYE
)"
CA="${CP%%$'\n'*}"; CB="${CP##*$'\n'}"
assert_eq "the search found two different paths" "yes" "$([[ -n "$CA" && -n "$CB" && "$CA" != "$CB" ]] && echo yes || echo no)"
assert_eq "and they have the same cksum" "$(printf '%s' "$CA" | cksum | cut -d' ' -f1)" "$(printf '%s' "$CB" | cksum | cut -d' ' -f1)"
mkdir -p "$CA/src" "$CB/src"
sb_integrity_register_root "$CA"
: >"$REG"; rm -f "$SB_RUNTIME_STATE_DIR"/integrity-*
assert_eq "collision: the marked path is still found" "$CA" "$(sb_integrity_record_root "$CA/src")"
assert_eq "collision: the other path is no false anchor" "" "$(sb_integrity_record_root "$CB/src")"
sb_integrity_register_root "$CB"
assert_eq "collision: registering the second path leaves the first one's marker alone" "1" "$(ls "$SB_RUNTIME_STATE_DIR"/root-* | wc -l | tr -d ' ')"
assert_eq "collision: the marker still names the first path" "$CA" "$(cut -f1 "$SB_RUNTIME_STATE_DIR"/root-*)"
sb_integrity_unregister_root "$CB"
assert_eq "collision: retiring the second path leaves the first one's marker" "$CA" "$(sb_integrity_record_root "$CA/src")"
printf 'garbage without a tab' >"$SB_RUNTIME_STATE_DIR/root-$(printf '%s' "$CA" | cksum | cut -d' ' -f1)"
assert_eq "a damaged marker (no stored path) anchors nothing" "" "$(sb_integrity_record_root "$CA/src")"
sb_integrity_register_root "$CA"
assert_eq "a damaged marker is rewritten by the next registration" "$CA" "$(cut -f1 "$SB_RUNTIME_STATE_DIR"/root-*)"
rm -f "$SB_RUNTIME_STATE_DIR"/root-* "$REG" "$SB_RUNTIME_STATE_DIR"/integrity-*
# the record name is the POSIX cksum of the root
for str in "" "a" "$P2" "héllo/ü" "$(head -c 200 /dev/urandom | base64 -w0)"; do
  assert_eq "bash cksum matches cksum(1) for '${str:0:20}'" "$(printf '%s' "$str" | cksum | cut -d' ' -f1)" "$(_sb_iv_cksum "$str")"
done

# ── the list helpers' empty-name edge ──────────────────────────────────────────────────────────────
if sb_required_skill_is_recorded "a" ""; then tl_fail "empty skill"; else tl_pass "an empty skill name is never recorded"; fi
assert_eq "its line is 0" "0" "$(sb_required_skill_line "a" "" | head -1)"

tl_results
