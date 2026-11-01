#!/usr/bin/env bash
# hooks/lib/path-canonical.sh: the canonicalisation the guards use to compare tool target
# paths with protected locations (R2-18, R2-35) and runtime-paths.sh uses for state-root
# containment (R2-28, R3-05, R5-01).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib/path-canonical.sh"
# shellcheck source=../../hooks/lib/path-canonical.sh
source "$LIB"

T="$TL_TMP/pc"
mkdir -p "$T/proj/src" "$T/proj/.planning" "$T/elsewhere/deep" "$T/real"
: >"$T/proj/src/app.py"
: >"$T/proj/.planning/ROADMAP.md"
ln -s "$T/proj/src" "$T/proj/lib"
ln -s "$T/elsewhere/deep" "$T/proj/linkdir"
ln -s "$T/proj/src/app.py" "$T/proj/alias.py"
ln -s app.py "$T/proj/src/rel-alias.py"
ln -s "$T/proj/src/not-yet.py" "$T/proj/dangling.py"
ln -s loop "$T/proj/loop"
ln -s "$T/proj" "$T/proj-link"

# ---- host spellings ------------------------------------------------------------
assert_eq "tilde alone" "$HOME" "$(sb_path_from_host '~')"
assert_eq "tilde slash" "$HOME/x/y" "$(sb_path_from_host "~"/x/y)"
assert_eq "other users' tilde untouched" "~bob/x" "$(sb_path_from_host '~bob/x')"
assert_eq "posix path untouched" "/a/b" "$(sb_path_from_host '/a/b')"
assert_eq "drive with backslashes" "/c/proj/src/app.py" "$(sb_path_from_host 'C:\proj\src\app.py')"
assert_eq "drive with forward slashes" "/d/w/x" "$(sb_path_from_host 'd:/w/x')"
assert_eq "bare drive" "/e" "$(sb_path_from_host 'E:')"
assert_eq "long-path prefix" "/c/proj/x" "$(sb_path_from_host '\\?\C:\proj\x')"
assert_eq "UNC share" "//server/share/x" "$(sb_path_from_host '\\server\share\x')"
assert_eq "backslash is a filename byte on POSIX shells" 'src\app.py' "$(OSTYPE=linux-gnu sb_path_from_host 'src\app.py')"
assert_eq "backslash separators on msys" "src/app.py" "$(bash -c 'OSTYPE=msys; source "$1"; sb_path_from_host "$2"' _ "$LIB" 'src\app.py')"
assert_eq "backslash separators on cygwin" "a/b" "$(bash -c 'OSTYPE=cygwin; source "$1"; sb_path_from_host "$2"' _ "$LIB" 'a\b')"
tl_stub cygpath 'printf "/cygdrive/c/proj"'
assert_eq "cygpath translates drive forms when present" "/cygdrive/c/proj" "$(sb_path_from_host 'C:\proj')"
tl_stub cygpath 'exit 1'
assert_eq "failing cygpath falls back to /x/ form" "/c/proj" "$(sb_path_from_host 'C:\proj')"
rm -f "$TL_BIN/cygpath"

# ---- lexical normalisation ------------------------------------------------------
if sb_path_normalize "" >/dev/null; then tl_fail "normalize: empty rejected"; else tl_pass "normalize: empty rejected"; fi
assert_eq "normalize: '.', '//', '..' and trailing slash" "/a/c" "$(sb_path_normalize '/a//./b/../c/')"
assert_eq "normalize: '..' above root stays at root" "/x" "$(sb_path_normalize '/../../x')"
assert_eq "normalize: root" "/" "$(sb_path_normalize '/')"
assert_eq "normalize: relative joined to base" "/base/dir/src/app.py" "$(sb_path_normalize 'src/./app.py' '/base/dir')"
assert_eq "normalize: relative base joined to PWD" "$T/proj/sub/x" "$(cd "$T/proj" && sb_path_normalize 'x' 'sub')"
assert_eq "normalize: no base uses PWD" "$T/proj/x" "$(cd "$T/proj" && sb_path_normalize 'x')"
assert_eq "normalize: relative target under a Windows cwd" "/c/proj/src/app.py" "$(sb_path_normalize 'src\app.py' 'C:\proj')"
assert_eq "normalize: relative backslash target under a POSIX cwd" '/p/src\app.py' "$(sb_path_normalize 'src\app.py' '/p')"
assert_eq "normalize: Windows absolute" "/c/proj/.planning/ROADMAP.md" "$(sb_path_normalize 'C:\proj\.planning\ROADMAP.md')"
assert_eq "normalize: does not touch the filesystem" "$T/proj/linkdir/x" "$(sb_path_normalize "$T/proj/linkdir/./x")"

# ---- physical canonicalisation --------------------------------------------------
assert_eq "canonical: empty prints nothing" "" "$(sb_canonical_path "")"
assert_eq "canonical: tilde expanded" "$HOME/x" "$(sb_canonical_path "~"/x)"
assert_eq "canonical: plain file" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/src/app.py")"
assert_eq "canonical: relative to base" "$T/proj/src/app.py" "$(sb_canonical_path "src/app.py" "$T/proj")"
assert_eq "canonical: relative to PWD" "$T/proj/src/app.py" "$(cd "$T/proj" && sb_canonical_path "src/app.py")"
assert_eq "canonical: '/./' and '//'" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/.//src/./app.py")"
assert_eq "canonical: symlinked directory" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/lib/app.py")"
assert_eq "canonical: symlinked dir then '..' is physical" "$T/elsewhere/x" "$(sb_canonical_path "$T/proj/linkdir/../x")"
assert_eq "canonical: missing component then '..' is lexical" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/nope/../src/app.py")"
assert_eq "canonical: leaf need not exist" "$T/proj/src/new/deeper.py" "$(sb_canonical_path "$T/proj/lib/new/deeper.py")"
assert_eq "canonical: absolute file symlink" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/alias.py")"
assert_eq "canonical: relative file symlink" "$T/proj/src/app.py" "$(sb_canonical_path "$T/proj/src/rel-alias.py")"
assert_eq "canonical: dangling symlink followed" "$T/proj/src/not-yet.py" "$(sb_canonical_path "$T/proj/dangling.py")"
assert_eq "canonical: root" "/" "$(sb_canonical_path "/")"
if sb_canonical_path "$T/proj/loop" >/dev/null; then tl_fail "canonical: symlink loop fails"; else tl_pass "canonical: symlink loop fails"; fi
NORL="$(tl_path_without readlink)"
assert_eq "canonical: python3 reads links without readlink" "$T/proj/src/app.py" "$(PATH="$NORL" bash -c 'source "$1"; sb_canonical_path "$2"' _ "$LIB" "$T/proj/alias.py")"
NORLPY="$(tl_path_without readlink python3)"
assert_eq "canonical: directory links need neither" "$T/proj/src/app.py" "$(PATH="$NORLPY" bash -c 'source "$1"; sb_canonical_path "$2"' _ "$LIB" "$T/proj/lib/app.py")"
if PATH="$NORLPY" bash -c 'source "$1"; sb_canonical_path "$2"' _ "$LIB" "$T/proj/alias.py" >/dev/null; then
  tl_fail "canonical: unreadable file link fails closed"
else
  tl_pass "canonical: unreadable file link fails closed"
fi

# ---- case-insensitive filesystems ----------------------------------------------
# Linux test filesystems are case-sensitive; a case-swapped symlink to the same inode is
# exactly what a case-insensitive filesystem presents, so it exercises the detection.
mkdir -p "$T/ci/Proj/.planning" "$T/cs/Proj" "$T/123/456"
ln -s Proj "$T/ci/pROJ"
ln -s .planning "$T/ci/Proj/.PLANNING"
if sb_path_case_insensitive "$T/ci/Proj/not/there"; then tl_pass "case: detected through the deepest existing ancestor"; else tl_fail "case: detected through the deepest existing ancestor"; fi
if sb_path_case_insensitive "$T/cs/Proj/x"; then tl_fail "case: sensitive filesystem detected"; else tl_pass "case: sensitive filesystem detected"; fi
if sb_path_case_insensitive "$T/123/456"; then tl_fail "case: digits-only components walk up"; else tl_pass "case: digits-only components walk up"; fi
if sb_path_case_insensitive "/"; then tl_fail "case: root is undecidable"; else tl_pass "case: root is undecidable"; fi
if sb_path_case_insensitive ""; then tl_fail "case: empty path"; else tl_pass "case: empty path"; fi
if sb_path_case_insensitive "$T/proj/loop"; then tl_fail "case: loop is undecidable"; else tl_pass "case: loop is undecidable"; fi
assert_eq "fold: ASCII lower-case" "abc/déf-x" "$(sb_path_fold "ABC/déf-X")"
assert_eq "compare key: folded on case-insensitive" "$(sb_path_fold "$T/ci/Proj/.planning/x.md")" "$(sb_path_compare_key "$T/ci/Proj/.planning/X.md")"
assert_eq "compare key: exact on case-sensitive" "$T/cs/Proj/X.md" "$(sb_path_compare_key "$T/cs/Proj/X.md")"
if sb_path_compare_key "" >/dev/null; then tl_fail "compare key: empty"; else tl_pass "compare key: empty"; fi
if sb_path_compare_key "$T/proj/loop" >/dev/null; then tl_fail "compare key: loop"; else tl_pass "compare key: loop"; fi

# ---- containment ----------------------------------------------------------------
within() { # name expected-status target root [base]
  local rc=0
  sb_path_is_within "${@:3}" || rc=$?
  assert_eq "within: $1" "$2" "$rc"
}
within "file below root" 0 "$T/proj/src/app.py" "$T/proj/src"
within "root itself" 0 "$T/proj/src" "$T/proj/src/"
within "sibling with a common prefix" 1 "$T/proj/srcx/app.py" "$T/proj/src"
within "outside" 1 "$T/elsewhere/x" "$T/proj"
within "relative target against payload cwd" 0 "src/app.py" "$T/proj/src" "$T/proj"
within "relative target outside" 1 "../elsewhere/x" "$T/proj" "$T/proj"
within "'/./' and '//'" 0 "$T/proj/.//.planning/./ROADMAP.md" "$T/proj/.planning"
within "'..' back into the root" 0 "$T/proj/src/../.planning/ROADMAP.md" "$T/proj/.planning"
within "symlinked directory into the root" 0 "$T/proj/lib/new.py" "$T/proj/src"
within "symlinked project path vs physical root" 0 "$T/proj-link/.planning/ROADMAP.md" "$T/proj/.planning"
within "physical target vs symlinked root" 0 "$T/proj/.planning/ROADMAP.md" "$T/proj-link/.planning"
within "file symlink into the root" 0 "$T/proj/alias.py" "$T/proj/src"
within "host collapsing '..' lexically" 0 "$T/proj/linkdir/../.planning/ROADMAP.md" "$T/proj/.planning"
within "lexical form through a symlinked prefix" 0 "$T/proj-link/linkdir/../.planning/x" "$T/proj/.planning"
within "lexical forms only (root spelled through a symlink and '..')" 0 "$T/proj/.planning/ROADMAP.md" "$T/proj/linkdir/../.planning"
within "Windows target and cwd" 0 '.planning\ROADMAP.md' "/c/proj/.planning" 'C:\proj'
within "Windows absolute target" 0 'C:\proj\.planning\ROADMAP.md' "/c/proj/.planning"
within "case variant on a case-insensitive filesystem" 0 "$T/ci/pROJ/.PLANNING/ROADMAP.md" "$T/ci/Proj/.planning"
within "case variant of a missing name, insensitive" 0 "$T/ci/Proj/.Planning/new.md" "$T/ci/Proj/.planning"
within "case variant on a case-sensitive filesystem" 1 "$T/cs/PROJ/x" "$T/cs/Proj"
within "everything is below /" 0 "$T/anything" "/"
within "empty target" 1 "" "$T/proj"
within "empty root" 1 "$T/proj" ""
within "loop in the target is undecidable" 2 "$T/proj/loop/x" "$T/proj"
within "loop only in the lexical form is undecidable" 2 "$T/proj/linkdir/../loop/x" "$T/proj"
ln -s rloop "$T/rloop"
within "loop in the root is undecidable" 2 "$T/proj/x" "$T/rloop"

tl_results
