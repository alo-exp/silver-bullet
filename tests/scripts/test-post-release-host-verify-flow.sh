#!/usr/bin/env bash
# scripts/post-release-host-verify.sh in a temp git repo with stub installers, diagnostics,
# uninstall helper and RC matrix. Nothing touches a real host home, gh or the network.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"
REL="$TL_TMP/rel"
tl_git_repo "$REL"
mkdir -p "$REL/scripts/lib" "$REL/hooks/lib"
cp "$R/scripts/post-release-host-verify.sh" "$REL/scripts/"
cp "$R/scripts/lib/pre-release-host-isolation.sh" "$REL/scripts/lib/"
cp "$R/hooks/lib/runtime-paths.sh" "$REL/hooks/lib/"
export LOG="$TL_TMP/calls.log"
V="$REL/scripts/post-release-host-verify.sh"

cat >"$REL/scripts/lib/post-release-uninstall.sh" <<'EOS'
sb_post_release_uninstall_host() {
  echo "uninstall $1" >>"$LOG"
  [[ " ${UNINSTALL_FAIL:-} " == *" $1 "* ]] && return 1
  return 0
}
EOS
for h in cursor codex claude; do
  cat >"$REL/scripts/install-$h.sh" <<EOS
#!/usr/bin/env bash
echo "install $h args=[\$*] from=\$(cd "\$(dirname "\$0")/.." && pwd) rtk=\${RTK_DISABLED:-}" >>"\$LOG"
[[ " \${INSTALL_FAIL:-} " == *" $h "* ]] && exit 1
exit 0
EOS
done
cat >"$REL/scripts/sb-diagnostics.sh" <<'EOS'
#!/usr/bin/env bash
echo "diag rt=$SILVER_BULLET_RUNTIME smoke=${SB_DIAG_SMOKE:-}" >>"$LOG"
[[ " ${DIAG_FAIL:-} " == *" $SILVER_BULLET_RUNTIME "* ]] && exit 1
exit 0
EOS
cat >"$REL/scripts/run-rc-validation-matrix.sh" <<'EOS'
#!/usr/bin/env bash
echo "rc $*" >>"$LOG"
host=""; while [[ $# -gt 0 ]]; do [[ "$1" == --host ]] && host="$2"; shift; done
[[ " ${RC_FAIL:-} " == *" $host "* ]] && exit 1
exit 0
EOS
echo '{"version":"1.0.0"}' >"$REL/package.json"

vrun() { local -a envs=(); while [[ $# -gt 0 && "$1" == *=* ]]; do envs+=("$1"); shift; done
         : >"$LOG"; rm -rf "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude"
         tl_run env -u SB_POST_RELEASE_VERSION "${envs[@]}" bash "$V" "$@"; }
marker() { cat "$HOME/.$1/.silver-bullet/post-release-verify/$1"; }
mfield() { marker "$1" | sed -n "s/^$2=//p"; }

# --- usage / args -------------------------------------------------------------------------------------
vrun -h
assert_eq "help exits 0" 0 "$TL_STATUS"; assert_contains "help text" "$TL_OUT" "Usage: scripts/post-release-host-verify.sh"
vrun --nope
assert_eq "unknown arg -> 2" 2 "$TL_STATUS"; assert_contains "unknown arg msg" "$TL_ERR" "Unknown argument: --nope"; assert_contains "usage on stderr" "$TL_ERR" "Usage:"

# --- version resolution (no tags yet) -----------------------------------------------------------------------------------
git -C "$REL" add -A >/dev/null; git -C "$REL" commit -qm stubs
vrun
assert_eq "no version and no tag -> 1" 1 "$TL_STATUS"; assert_contains "no version msg" "$TL_ERR" "could not resolve release version"

git -C "$REL" tag v1.0.0
# --- happy path, version from git describe, HEAD is the tag ---------------------------------------------------------------
vrun
assert_eq "all hosts pass" 0 "$TL_STATUS"
assert_contains "version from git describe" "$TL_OUT" "Post-release host verify: 3 passed, 0 failed (version v1.0.0)"
assert_contains "cursor result line" "$TL_OUT" "host=cursor uninstall=PASS install=PASS diag=PASS rc=PASS result=PASS"
assert_contains "claude result line" "$TL_OUT" "host=claude uninstall=PASS install=PASS diag=PASS rc=PASS result=PASS"
assert_contains "section header" "$TL_OUT" "[post-release-verify] === codex (v1.0.0) ==="
calls="$(cat "$LOG")"
assert_contains "cursor installs without extra args" "$calls" "install cursor args=[] from=$REL rtk=1"
assert_contains "codex purges legacy skills" "$calls" "install codex args=[--purge-legacy-skills]"
assert_contains "claude purges legacy plugins" "$calls" "install claude args=[--purge-legacy-plugins]"
assert_contains "diagnostics run per host with runtime pinned" "$calls" "diag rt=claude smoke=1"
assert_contains "diag cursor" "$calls" "diag rt=cursor smoke=1"
assert_contains "diag codex" "$calls" "diag rt=codex smoke=1"
assert_contains "rc fresh cell per host" "$calls" "rc --host codex --mode fresh"
for h in cursor codex claude; do
  assert_eq "$h marker status" pass "$(mfield "$h" status)"
  assert_eq "$h marker version" v1.0.0 "$(mfield "$h" version)"
  assert_eq "$h marker detail" fresh-smoke "$(mfield "$h" detail)"
  assert_eq "$h marker host" "$h" "$(mfield "$h" host)"
  assert_match "$h marker timestamp" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(mfield "$h" timestamp)"
done

# --- options -----------------------------------------------------------------------------------------------------------------------
vrun --version v1.0.0 --host claude --public-release
assert_contains "host filter totals" "$TL_OUT" "1 passed, 0 failed"
assert_contains "public-release forwarded (claude)" "$(cat "$LOG")" "install claude args=[--purge-legacy-plugins --public-release]"
assert_not_contains "host filter skips others" "$(cat "$LOG")" "install codex"
vrun --host cursor --public-release
assert_contains "public-release forwarded (cursor, only arg)" "$(cat "$LOG")" "install cursor args=[--public-release]"
vrun SB_POST_RELEASE_VERSION=v1.0.0 --host codex
assert_contains "version from env" "$TL_OUT" "(version v1.0.0)"
vrun --host codex --skip-smoke
assert_eq "skip-smoke ok" 0 "$TL_STATUS"
assert_contains "skip-smoke result line" "$TL_OUT" "host=codex uninstall=PASS install=PASS diag=PASS rc=SKIP result=PASS"
assert_eq "skip-smoke marker detail" skip-rc "$(mfield codex detail)"
assert_not_contains "skip-smoke runs no rc matrix" "$(cat "$LOG")" "rc --host"

# --- failures --------------------------------------------------------------------------------------------------------------------------
vrun UNINSTALL_FAIL=cursor
assert_eq "uninstall failure -> 1" 1 "$TL_STATUS"
assert_contains "uninstall failure line" "$TL_OUT" "host=cursor uninstall=FAIL install=FAIL diag=SKIP rc=SKIP result=FAIL"
assert_eq "uninstall failure marker" fail "$(mfield cursor status)"
assert_eq "uninstall failure detail" uninstall "$(mfield cursor detail)"
assert_not_contains "no install after uninstall failure" "$(grep '^install cursor' "$LOG" || true)" "install cursor"
assert_contains "totals with failure" "$TL_OUT" "2 passed, 1 failed"
vrun DIAG_FAIL=codex --host codex
assert_eq "diag failure -> 1" 1 "$TL_STATUS"
assert_contains "diag failure line" "$TL_OUT" "host=codex uninstall=PASS install=FAIL diag=FAIL rc=SKIP result=FAIL"
assert_eq "diag failure detail" install-or-diagnostics "$(mfield codex detail)"
vrun INSTALL_FAIL=claude --host claude
assert_eq "install exit tolerated when diagnostics pass" 0 "$TL_STATUS"
assert_contains "install warning" "$TL_OUT" "WARN: install script exited 1; diagnostics passed (functional install OK)"
vrun RC_FAIL=claude --host claude
assert_eq "rc failure -> 1" 1 "$TL_STATUS"
assert_contains "rc failure line" "$TL_OUT" "host=claude uninstall=PASS install=PASS diag=PASS rc=FAIL result=FAIL"
assert_eq "rc failure marker" fail "$(mfield claude status)"
assert_eq "rc failure detail" rc-fresh "$(mfield claude detail)"
mv "$REL/scripts/install-cursor.sh" "$TL_TMP/install-cursor.sh.hold"
vrun --host cursor
assert_contains "missing install script reported" "$TL_ERR" "ERROR: missing $REL/scripts/install-cursor.sh"
assert_contains "missing install script tolerated like a failing installer" "$TL_OUT" "WARN: install script exited 1"
mv "$TL_TMP/install-cursor.sh.hold" "$REL/scripts/install-cursor.sh"

# --- install source: tag archive vs working tree ------------------------------------------------------------------------------------------
echo '{"version":"1.1.0"}' >"$REL/package.json"; git -C "$REL" commit -qam "bump to 1.1.0"
vrun --version v1.1.0 --host codex
assert_contains "package.json 'v'+version matches -> repo install" "$(cat "$LOG")" "install codex args=[--purge-legacy-skills] from=$REL"
vrun --version 1.1.0 --host codex
assert_contains "bare version matches package.json -> repo install" "$(cat "$LOG")" "from=$REL"
vrun --version v1.0.0 --host codex
src="$(sed -n 's/^install codex .* from=\(.*\) rtk=.*/\1/p' "$LOG")"
assert_match "older tag -> installed from a temp archive" '/sb-post-release-install\.[A-Za-z0-9]+$' "$src"
assert_file_absent "temp archive removed on exit" "$src"
mv "$REL/package.json" "$TL_TMP/package.json.hold"
vrun --version v1.0.0 --host codex
src="$(sed -n 's/^install codex .* from=\(.*\) rtk=.*/\1/p' "$LOG")"
assert_match "unreadable package.json -> temp archive" '/sb-post-release-install\.' "$src"
mv "$TL_TMP/package.json.hold" "$REL/package.json"
git -C "$REL" tag v1.1.0
vrun --version v1.1.0 --host cursor
assert_contains "HEAD tag equals version -> repo install" "$(cat "$LOG")" "install cursor args=[] from=$REL"
vrun --version v9.9.9 --host cursor
assert_eq "unknown tag cannot be archived (non-zero exit)" nonzero "$([[ $TL_STATUS -ne 0 ]] && echo nonzero || echo zero)"
assert_eq "unknown tag installs nothing" "" "$(grep '^install' "$LOG" || true)"
# runtime-paths library absent from the checkout: still runs
mv "$REL/hooks/lib/runtime-paths.sh" "$TL_TMP/rp.hold"
vrun --version v1.1.0 --host cursor --skip-smoke
assert_eq "works without runtime-paths.sh" 0 "$TL_STATUS"
mv "$TL_TMP/rp.hold" "$REL/hooks/lib/runtime-paths.sh"

tl_results
