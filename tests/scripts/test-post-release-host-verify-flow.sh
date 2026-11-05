#!/usr/bin/env bash
# scripts/post-release-host-verify.sh in a temp git repo with stub installers, diagnostics,
# uninstall helper and RC matrix. Nothing touches a real host home, gh or the network.
# Every host is installed, diagnosed and smoke-tested from a checkout of the release tag,
# never from the working tree (R13-06).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"
REL="$TL_TMP/rel"
tl_git_repo "$REL"
mkdir -p "$REL/scripts/lib" "$REL/hooks/lib" "$TL_TMP/tmpdir"
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
# Each stub records the tree it runs from and the code that tree carries.
for h in cursor codex claude; do
  cat >"$REL/scripts/install-$h.sh" <<EOS
#!/usr/bin/env bash
root="\$(cd "\$(dirname "\$0")/.." && pwd)"
echo "install $h args=[\$*] from=\$root code=\$(cat "\$root/code.txt") rtk=\${RTK_DISABLED:-}" >>"\$LOG"
[[ " \${INSTALL_FAIL:-} " == *" $h "* ]] && exit 1
exit 0
EOS
done
cat >"$REL/scripts/sb-diagnostics.sh" <<'EOS'
#!/usr/bin/env bash
echo "diag rt=$SILVER_BULLET_RUNTIME smoke=${SB_DIAG_SMOKE:-} from=$(cd "$(dirname "$0")/.." && pwd)" >>"$LOG"
[[ " ${DIAG_FAIL:-} " == *" $SILVER_BULLET_RUNTIME "* ]] && exit 1
exit 0
EOS
cat >"$REL/scripts/run-rc-validation-matrix.sh" <<'EOS'
#!/usr/bin/env bash
echo "rc $* from=$(cd "$(dirname "$0")/.." && pwd)" >>"$LOG"
host=""; while [[ $# -gt 0 ]]; do [[ "$1" == --host ]] && host="$2"; shift; done
[[ " ${RC_FAIL:-} " == *" $host "* ]] && exit 1
exit 0
EOS
echo '{"version":"1.0.0"}' >"$REL/package.json"
echo released >"$REL/code.txt"

vrun() { local -a envs=(); while [[ $# -gt 0 && "$1" == *=* ]]; do envs+=("$1"); shift; done
         : >"$LOG"; rm -rf "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude"
         tl_run env -u SB_POST_RELEASE_VERSION TMPDIR="$TL_TMP/tmpdir" "${envs[@]}" bash "$V" "$@"; }
marker() { cat "$HOME/.$1/.silver-bullet/post-release-verify/$1"; }
mfield() { marker "$1" | sed -n "s/^$2=//p"; }
# install_src HOST: the tree the host's installer ran from in the last run.
install_src() { sed -n "s/^install $1 .* from=\\(.*\\) code=.*/\\1/p" "$LOG"; }
TAG_TREE_RE='/tmpdir/sb-post-release-install\.[A-Za-z0-9]+/silver-bullet$'

# --- usage / args -------------------------------------------------------------------------------------
vrun -h
assert_eq "help exits 0" 0 "$TL_STATUS"; assert_contains "help text" "$TL_OUT" "Usage: scripts/post-release-host-verify.sh"
assert_contains "help names the tag as the install source" "$TL_OUT" "Fresh install from a checkout of the release tag"
vrun --nope
assert_eq "unknown arg -> 2" 2 "$TL_STATUS"; assert_contains "unknown arg msg" "$TL_ERR" "Unknown argument: --nope"; assert_contains "usage on stderr" "$TL_ERR" "Usage:"

vrun --version v1.0.0 --host bogus
assert_eq "unknown host is a usage error" 2 "$TL_STATUS"
assert_contains "unknown host message" "$TL_ERR" "Unknown host: bogus"
assert_contains "unknown host shows usage" "$TL_ERR" "Usage:"
assert_eq "unknown host runs nothing" "" "$(cat "$LOG")"

# --- version resolution (no tags yet) -----------------------------------------------------------------------------------
git -C "$REL" add -A >/dev/null; git -C "$REL" commit -qm stubs
vrun
assert_eq "no version and no tag -> 1" 1 "$TL_STATUS"; assert_contains "no version msg" "$TL_ERR" "could not resolve release version"

git -C "$REL" tag v1.0.0
# --- happy path, version from git describe ---------------------------------------------------------------
vrun
assert_eq "all hosts pass" 0 "$TL_STATUS"
assert_contains "version from git describe" "$TL_OUT" "Post-release host verify: 3 passed, 0 failed (version v1.0.0)"
assert_contains "cursor result line" "$TL_OUT" "host=cursor uninstall=PASS install=PASS diag=PASS rc=PASS result=PASS"
assert_contains "claude result line" "$TL_OUT" "host=claude uninstall=PASS install=PASS diag=PASS rc=PASS result=PASS"
assert_contains "section header" "$TL_OUT" "[post-release-verify] === codex (v1.0.0) ==="
calls="$(cat "$LOG")"
assert_match "cursor installs from a checkout of the tag" "$TAG_TREE_RE" "$(install_src cursor)"
assert_contains "cursor installs without extra args" "$calls" "install cursor args=[] from=$(install_src cursor) code=released rtk=1"
assert_contains "codex purges legacy skills" "$calls" "install codex args=[--purge-legacy-skills]"
assert_contains "claude purges legacy plugins" "$calls" "install claude args=[--purge-legacy-plugins]"
assert_contains "diagnostics run per host with runtime pinned" "$calls" "diag rt=claude smoke=1"
assert_contains "diag cursor" "$calls" "diag rt=cursor smoke=1"
assert_contains "diag codex" "$calls" "diag rt=codex smoke=1"
assert_contains "diagnostics run from the tag checkout" "$calls" "diag rt=codex smoke=1 from=$(install_src codex)"
assert_contains "rc fresh cell per host, from the tag checkout" "$calls" "rc --host codex --mode fresh from=$(install_src codex)"
for h in cursor codex claude; do
  assert_eq "$h marker status" pass "$(mfield "$h" status)"
  assert_eq "$h marker version" v1.0.0 "$(mfield "$h" version)"
  assert_eq "$h marker detail" fresh-smoke "$(mfield "$h" detail)"
  assert_eq "$h marker host" "$h" "$(mfield "$h" host)"
  assert_eq "$h marker records the tagged commit" "$(git -C "$REL" rev-parse 'v1.0.0^{commit}')" "$(mfield "$h" commit)"
  assert_match "$h marker timestamp" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(mfield "$h" timestamp)"
done
assert_eq "tag checkout removed on exit" "" "$(ls -A "$TL_TMP/tmpdir")"

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

# The tag that is verified lacks an installer: reported, then handled like a failing installer.
git -C "$REL" rm -q scripts/install-cursor.sh
git -C "$REL" commit -qm "drop the cursor installer"
git -C "$REL" tag v1.0.1
vrun --version v1.0.1 --host cursor
assert_contains "missing install script reported" "$TL_ERR" "ERROR: missing "
assert_contains "missing install script named" "$TL_ERR" "/silver-bullet/scripts/install-cursor.sh"
assert_contains "missing install script tolerated like a failing installer" "$TL_OUT" "WARN: install script exited 1"
git -C "$REL" revert --no-edit HEAD >/dev/null

# --- install source: always the tag, never the working tree (R13-06) ------------------------------------------------------------------
echo '{"version":"1.1.0"}' >"$REL/package.json"
echo "unreleased change" >"$REL/code.txt"
git -C "$REL" commit -qam "post-release work, package.json still says 1.1.0"
echo "uncommitted edit" >"$REL/code.txt"

vrun --version v1.0.0 --host codex
assert_eq "older tag verified" 0 "$TL_STATUS"
assert_match "older tag: installed from a checkout of the tag" "$TAG_TREE_RE" "$(install_src codex)"
assert_contains "older tag: the tag's code is installed" "$(cat "$LOG")" "code=released"

# package.json says 1.1.0 but v1.1.0 was never tagged: nothing is installed from the working tree.
vrun --version v1.1.0 --host codex
assert_eq "untagged version refused" 1 "$TL_STATUS"
assert_contains "untagged version explained" "$TL_ERR" "release tag v1.1.0 not found in $REL"
assert_eq "untagged version installs nothing" "" "$(grep '^install' "$LOG" || true)"
vrun --version 1.1.0 --host codex
assert_eq "bare untagged version refused" 1 "$TL_STATUS"

# HEAD is the tag but the working tree carries an uncommitted edit: the tag is installed.
git -C "$REL" tag v1.1.0
vrun --version 1.1.0 --host cursor
assert_eq "tag at HEAD verified" 0 "$TL_STATUS"
assert_match "tag at HEAD: installed from a checkout of the tag" "$TAG_TREE_RE" "$(install_src cursor)"
assert_contains "tag at HEAD: committed tag content, not the uncommitted edit" "$(cat "$LOG")" "code=unreleased change"
assert_not_contains "uncommitted edit never installed" "$(cat "$LOG")" "uncommitted edit"
assert_eq "bare version recorded as the tag" v1.1.0 "$(mfield cursor version)"
assert_eq "working tree left as it was" "uncommitted edit" "$(<"$REL/code.txt")"

vrun --version v9.9.9 --host cursor
assert_eq "unknown tag refused" 1 "$TL_STATUS"
assert_contains "unknown tag explained" "$TL_ERR" "release tag v9.9.9 not found"
assert_eq "unknown tag installs nothing" "" "$(grep '^install' "$LOG" || true)"

# A failing checkout of the tag leaves no temporary directory behind.
REAL_GIT="$(command -v git)"
tl_stub git "if [[ \" \$* \" == *' clone '* ]]; then echo 'clone refused' >&2; exit 1; fi; exec '$REAL_GIT' \"\$@\""
hash -r
vrun --version v1.0.0 --host codex
assert_eq "failed tag checkout -> non-zero" nonzero "$([[ $TL_STATUS -ne 0 ]] && echo nonzero || echo zero)"
assert_eq "failed tag checkout installs nothing" "" "$(grep '^install' "$LOG" || true)"
assert_eq "failed tag checkout leaves no temporary directory" "" "$(ls -A "$TL_TMP/tmpdir")"
rm -f "$TL_BIN/git"; hash -r

# runtime-paths library absent from the checkout: still runs
mv "$REL/hooks/lib/runtime-paths.sh" "$TL_TMP/rp.hold"
vrun --version v1.1.0 --host cursor --skip-smoke
assert_eq "works without runtime-paths.sh" 0 "$TL_STATUS"
mv "$TL_TMP/rp.hold" "$REL/hooks/lib/runtime-paths.sh"

tl_results
