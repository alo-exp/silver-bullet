#!/usr/bin/env bash
# scripts/install-omniroute-launchagent.sh with stubbed omniroute/node/lsof/
# launchctl/pkill and a sandboxed HOME: plist contents, binary resolution,
# port-in-use refusal, bootstrap order and the health-check timeout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

SCRIPT="$TL_REPO_ROOT/scripts/install-omniroute-launchagent.sh"
LOG="$TL_TMP/calls.log"
CFG="$TL_TMP/cfg"
mkdir -p "$CFG" "$TL_TMP/real-bin"
PLIST="$HOME/Library/LaunchAgents/com.omniroute.server.plist"

# Real binary behind the omniroute command; PATH entry is a symlink to it.
printf '#!/usr/bin/env bash\necho "omniroute $*" >>"%s"\n[[ "$1" == health && -f "%s/unhealthy" ]] && exit 1\n[[ "$1" == stop && -f "%s/ctl-fails" ]] && exit 1\nexit 0\n' "$LOG" "$CFG" "$CFG" >"$TL_TMP/real-bin/omniroute.mjs"
chmod +x "$TL_TMP/real-bin/omniroute.mjs"
ln -s "$TL_TMP/real-bin/omniroute.mjs" "$TL_BIN/omniroute"
tl_stub node 'exit 0'
tl_stub pkill 'echo "pkill $*" >>"'"$LOG"'"; exit 1'
tl_stub lsof '[[ -f "'"$CFG"'/port-busy" ]]'
tl_stub launchctl '
echo "launchctl $*" >>"'"$LOG"'"
[[ "$1" == print && ! -f "'"$CFG"'/loaded" ]] && exit 1
[[ ( "$1" == bootout || "$1" == enable ) && -f "'"$CFG"'/ctl-fails" ]] && exit 1
exit 0'

# No real waiting: an exported function shadows sleep and advances SECONDS so
# the 30 s health deadline elapses immediately.
ORIG_BASH_ENV="${BASH_ENV:-}"
BASH_ENV="$TL_TMP/bashenv.sh"
{
  [[ -n "$ORIG_BASH_ENV" ]] && printf '. %q\n' "$ORIG_BASH_ENV"
  printf '%s\n' 'sleep() { SECONDS=$((SECONDS + 31)); }' 'export -f sleep'
} >"$BASH_ENV"
export BASH_ENV

run() { : >"$LOG"; tl_run bash "$SCRIPT"; }

# ---- missing prerequisites
tl_run env PATH="$(tl_path_without omniroute)" bash "$SCRIPT"
assert_eq "omniroute missing exits 1" 1 "$TL_STATUS"
assert_contains "omniroute missing message" "$TL_ERR" "omniroute not found on PATH"
tl_run env PATH="$(tl_path_without node)" bash "$SCRIPT"
assert_eq "node missing exits 1" 1 "$TL_STATUS"
assert_contains "node missing message" "$TL_ERR" "node not found on PATH"

# ---- healthy install
run
assert_eq "healthy install exits 0" 0 "$TL_STATUS"
assert_contains "success banner names the plist" "$TL_OUT" "OmniRoute LaunchAgent installed: $PLIST"
assert_contains "banner shows the default port" "$TL_OUT" "port:   20128"
assert_file_exists "plist written" "$PLIST"
PL="$(<"$PLIST")"
assert_contains "plist label" "$PL" "<string>com.omniroute.server</string>"
assert_contains "plist runs the resolved symlink target" "$PL" "<string>$TL_TMP/real-bin/omniroute.mjs</string>"
assert_contains "plist uses the node on PATH" "$PL" "<string>$TL_BIN/node</string>"
assert_contains "plist port" "$PL" "<string>20128</string>"
assert_contains "plist log file under data dir" "$PL" "<string>$HOME/.omniroute/server.log</string>"
assert_file_exists "data dir created" "$HOME/.omniroute"
CALLS="$(<"$LOG")"
assert_contains "foreign instance stopped" "$CALLS" "omniroute stop"
assert_contains "serve processes killed" "$CALLS" "pkill -f omniroute.*serve"
assert_contains "launchd bootstrap" "$CALLS" "launchctl bootstrap gui/$(id -u) $PLIST"
assert_contains "launchd kickstart" "$CALLS" "launchctl kickstart -k gui/$(id -u)/com.omniroute.server"
assert_not_contains "no bootout when not loaded" "$CALLS" "bootout"

# ---- custom port, already loaded job is booted out first
touch "$CFG/loaded"
tl_run env OMNIROUTE_PORT=3999 bash "$SCRIPT"
assert_eq "custom port install exits 0" 0 "$TL_STATUS"
assert_contains "custom port in plist" "$(<"$PLIST")" "<string>3999</string>"
assert_contains "loaded job booted out first" "$(<"$LOG")" "launchctl bootout gui/$(id -u) $PLIST"
rm -f "$CFG/loaded"

# ---- tolerated failures: omniroute stop, launchctl bootout and enable
touch "$CFG/loaded" "$CFG/ctl-fails"
run
assert_eq "failing stop/bootout/enable do not abort the install" 0 "$TL_STATUS"
assert_contains "bootout was attempted" "$(<"$LOG")" "launchctl bootout"
assert_contains "enable was attempted" "$(<"$LOG")" "launchctl enable gui/$(id -u)/com.omniroute.server"
assert_contains "bootstrap still ran" "$(<"$LOG")" "launchctl bootstrap"
rm -f "$CFG/loaded" "$CFG/ctl-fails"

# ---- port still in use after stop
touch "$CFG/port-busy"
run
assert_eq "busy port exits 1" 1 "$TL_STATUS"
assert_contains "busy port message" "$TL_ERR" "port 20128 still in use after stop"
assert_not_contains "no bootstrap when port busy" "$(<"$LOG")" "bootstrap"
rm -f "$CFG/port-busy"

# ---- health never passes
touch "$CFG/unhealthy"
run
assert_eq "unhealthy server exits 1" 1 "$TL_STATUS"
assert_contains "unhealthy message" "$TL_ERR" "omniroute health did not pass within 30s"
rm -f "$CFG/unhealthy"

# ---- binary resolution fallbacks when readlink -f / realpath are unavailable
REAL_READLINK="$(command -v readlink)"
tl_stub readlink '[[ "$1" == "-f" ]] && exit 1; exec '"$REAL_READLINK"' "$@"'
tl_stub realpath 'exit 1'
run
assert_eq "absolute link target resolved without readlink -f" 0 "$TL_STATUS"
assert_contains "plist keeps absolute target" "$(<"$PLIST")" "<string>$TL_TMP/real-bin/omniroute.mjs</string>"
rm -f "$TL_BIN/omniroute"
ln -s "../real-bin/omniroute.mjs" "$TL_TMP/real-bin/rel-omniroute"
mkdir -p "$TL_TMP/rel-bin"
ln -s "../real-bin/omniroute.mjs" "$TL_TMP/rel-bin/omniroute"
tl_run env PATH="$TL_TMP/rel-bin:$PATH" bash "$SCRIPT"
assert_eq "relative link target resolved" 0 "$TL_STATUS"
assert_contains "plist holds the link-relative target" "$(<"$PLIST")" "<string>$TL_TMP/rel-bin/../real-bin/omniroute.mjs</string>"
rm -f "$TL_BIN/readlink" "$TL_BIN/realpath"

# ---- a regular (non-symlink) executable is used as is
rm -rf "$TL_TMP/rel-bin"
mkdir -p "$TL_TMP/plain-bin"
cp "$TL_TMP/real-bin/omniroute.mjs" "$TL_TMP/plain-bin/omniroute"
tl_run env PATH="$TL_TMP/plain-bin:$PATH" bash "$SCRIPT"
assert_eq "plain executable install exits 0" 0 "$TL_STATUS"
assert_contains "plist uses the plain path" "$(<"$PLIST")" "<string>$TL_TMP/plain-bin/omniroute</string>"

tl_results
