#!/usr/bin/env bash
# site/install-preview-launchagent.sh with launchctl, lsof and sleep stubbed: the real
# LaunchAgents directory, launchd and port 8765 are never touched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# The script derives everything from its own location, so run a copy inside
# <tmp>/repo/site next to the real plist template.
REPO="$TL_TMP/repo"
mkdir -p "$REPO/site"
cp "$TL_REPO_ROOT/site/install-preview-launchagent.sh" "$REPO/site/"
cp "$TL_REPO_ROOT/site/com.alolabs.silver-bullet-site-preview.plist" "$REPO/site/"
INSTALL="$REPO/site/install-preview-launchagent.sh"
DEST="$HOME/Library/LaunchAgents/com.alolabs.silver-bullet-site-preview.plist"
CALLS="$TL_TMP/launchctl.calls"

tl_stub sleep 'exit 0'
# launchctl logs each call; LAUNCHCTL_FAIL names a subcommand that must fail.
tl_stub launchctl "printf '%s\n' \"\$*\" >>$CALLS; [[ \"\$1\" == \"\${LAUNCHCTL_FAIL:-}\" ]] && exit 1; exit 0"
# lsof reports a listener only when LISTEN=1.
tl_stub lsof "echo \"\$*\" >>'$TL_TMP/lsof.args'; [[ \"\${LISTEN:-0}\" == 1 ]] && { echo 4242; exit 0; }; exit 1"

# --- missing template ------------------------------------------------------
mv "$REPO/site/com.alolabs.silver-bullet-site-preview.plist" "$TL_TMP/plist.bak"
tl_run bash "$INSTALL"
assert_eq "missing template exits 1" "1" "$TL_STATUS"
assert_contains "missing template names the file" "$TL_ERR" "Missing template: $REPO/site/com.alolabs.silver-bullet-site-preview.plist"
assert_file_absent "no plist written without template" "$DEST"
assert_file_absent "launchctl untouched without template" "$CALLS"
mv "$TL_TMP/plist.bak" "$REPO/site/com.alolabs.silver-bullet-site-preview.plist"

# --- success ----------------------------------------------------------------
LISTEN=1 tl_run bash "$INSTALL"
assert_eq "install succeeds when the port is listening" "0" "$TL_STATUS"
assert_contains "reports installed plist" "$TL_OUT" "Installed and loaded LaunchAgent: $DEST"
assert_contains "reports preview URL" "$TL_OUT" "Preview URL: http://127.0.0.1:8765/"
assert_contains "points at serve.sh status" "$TL_OUT" "Status: $REPO/site/serve.sh status"
assert_eq "port probe is lsof -iTCP:8765 -sTCP:LISTEN" "-iTCP:8765 -sTCP:LISTEN" "$(head -1 "$TL_TMP/lsof.args")"
assert_file_exists "plist written under HOME" "$DEST"
assert_not_contains "placeholder substituted" "$(cat "$DEST")" "__REPO_ROOT__"
assert_contains "repo root substituted into plist" "$(cat "$DEST")" "<string>$REPO/site/preview-server-daemon.sh</string>"
uid="$(id -u)"
assert_eq "launchctl called bootout, bootstrap, kickstart in order" \
  "bootout gui/$uid $DEST
bootstrap gui/$uid $DEST
kickstart -k gui/$uid/com.alolabs.silver-bullet-site-preview" "$(cat "$CALLS")"

# --- bootout failing (nothing loaded yet) is tolerated ------------------------
: >"$CALLS"
LAUNCHCTL_FAIL=bootout LISTEN=1 tl_run bash "$INSTALL"
assert_eq "failing bootout is ignored" "0" "$TL_STATUS"
assert_contains "bootstrap still ran after failed bootout" "$(cat "$CALLS")" "bootstrap gui/$uid"

# --- bootstrap failing aborts before kickstart ---------------------------------
: >"$CALLS"
LAUNCHCTL_FAIL=bootstrap LISTEN=1 tl_run bash "$INSTALL"
assert_eq "failing bootstrap aborts" "1" "$TL_STATUS"
assert_not_contains "kickstart not reached" "$(cat "$CALLS")" "kickstart"
assert_not_contains "no success message" "$TL_OUT" "Installed and loaded"

# --- loaded but not listening ------------------------------------------------
LISTEN=0 tl_run bash "$INSTALL"
assert_eq "not listening exits 1" "1" "$TL_STATUS"
assert_contains "not listening hints at the log" "$TL_ERR" "port 8765 not listening yet; check $REPO/site/.preview-server.log"
assert_not_contains "no success message when not listening" "$TL_OUT" "Installed and loaded"

tl_results
