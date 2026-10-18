#!/usr/bin/env bash
# site/preview-server-daemon.sh: python3 discovery order, host/port defaults and
# overrides, and the exit-127 failure. python3 is always a recording stub, so no
# server is started and no port is bound.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

DAEMON="$TL_REPO_ROOT/site/preview-server-daemon.sh"

# A stub interpreter that records its working directory and arguments.
mk_py() {
  local path="$1" tag="$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\nprintf "%%s|%%s|%%s\\n" %q "$PWD" "$*" >%q\n' "$tag" "$TL_TMP/py.out" >"$path"
  chmod +x "$path"
}
no_py_path="$(tl_path_without python3)"

# Candidate 1: $PYTHON3 wins over everything.
mk_py "$TL_TMP/custom/py" explicit
mk_py "$TL_BIN/python3" onpath
rm -f "$TL_TMP/py.out"
PYTHON3="$TL_TMP/custom/py" tl_run bash "$DAEMON"
assert_eq "PYTHON3 override runs" "0" "$TL_STATUS"
assert_eq "PYTHON3 override beats PATH python3, serves 127.0.0.1:8765 from the site dir" \
  "explicit|$TL_REPO_ROOT/site|-m http.server 8765 --bind 127.0.0.1" "$(cat "$TL_TMP/py.out")"

# Candidate 2: python3 on PATH when PYTHON3 is unset or not executable.
rm -f "$TL_TMP/py.out"
PYTHON3="$TL_TMP/does-not-exist" tl_run bash "$DAEMON"
assert_eq "falls back to PATH python3" "onpath" "$(cut -d'|' -f1 "$TL_TMP/py.out")"

# Host and port come from PREVIEW_HOST / PREVIEW_PORT.
PREVIEW_HOST=0.0.0.0 PREVIEW_PORT=9999 tl_run bash "$DAEMON"
assert_eq "host and port overrides" "-m http.server 9999 --bind 0.0.0.0" "$(cut -d'|' -f3 "$TL_TMP/py.out")"

# Candidates 3-5 are absolute paths (homebrew, /usr/local, /usr/bin). A copy with those
# literals pointed into the sandbox (same line layout) lets each be reached without
# touching the real filesystem.
stage_copy() {
  local dir="$1" hb="$2" ul="$3" ub="$4"
  mkdir -p "$dir"
  sed -e "s#/opt/homebrew/bin/python3#$hb#" -e "s#/usr/local/bin/python3#$ul#" -e "s#/usr/bin/python3#$ub#" \
    "$DAEMON" >"$dir/preview-server-daemon.sh"
  chmod +x "$dir/preview-server-daemon.sh"
}
HB="$TL_TMP/abs/homebrew/python3"; UL="$TL_TMP/abs/usrlocal/python3"; UB="$TL_TMP/abs/usrbin/python3"
stage_copy "$TL_TMP/copy/site" "$HB" "$UL" "$UB"
COPY="$TL_TMP/copy/site/preview-server-daemon.sh"

mk_py "$UB" usrbin
rm -f "$TL_TMP/py.out"
PATH="$no_py_path" tl_run bash "$COPY"
assert_eq "last candidate is used when nothing else exists" "usrbin" "$(cut -d'|' -f1 "$TL_TMP/py.out")"
mk_py "$UL" usrlocal
PATH="$no_py_path" tl_run bash "$COPY"
assert_eq "/usr/local candidate beats the last one" "usrlocal" "$(cut -d'|' -f1 "$TL_TMP/py.out")"
mk_py "$HB" homebrew
PATH="$no_py_path" tl_run bash "$COPY"
assert_eq "homebrew candidate comes first of the absolute paths" "homebrew" "$(cut -d'|' -f1 "$TL_TMP/py.out")"

# No interpreter anywhere: exit 127 with a hint, nothing executed.
rm -f "$HB" "$UL" "$UB" "$TL_TMP/py.out"
PATH="$no_py_path" tl_run bash "$COPY"
assert_eq "no python3 exits 127" "127" "$TL_STATUS"
assert_contains "no python3 message names PYTHON3" "$TL_ERR" "python3 not found"
assert_contains "no python3 message names PYTHON3 override" "$TL_ERR" "set PYTHON3"
assert_file_absent "no interpreter was run" "$TL_TMP/py.out"

tl_results
