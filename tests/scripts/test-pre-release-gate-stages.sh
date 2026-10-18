#!/usr/bin/env bash
# scripts/pre-release-gate.sh in a temp tree whose stage scripts are stubs that log their environment.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

T="$TL_TMP/tree"
mkdir -p "$T/scripts" "$T/tests/scripts"
cp "$TL_REPO_ROOT/scripts/pre-release-gate.sh" "$T/scripts/"
LOG="$TL_TMP/stages.log"
mk_stub() { # path label
  cat >"$1" <<EOS
#!/usr/bin/env bash
echo "$2 PRE=\${SB_FIVE_TOOL_PRERELEASE:-unset} LIVE=\${SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE:-unset}" >>"$LOG"
[[ "\${FAIL_STAGE:-}" == "$2" ]] && exit 1
exit 0
EOS
  chmod +x "$1"
}
mk_stub "$T/tests/scripts/test-site-content-freshness.sh" content
mk_stub "$T/tests/scripts/test-site-doc-freshness.sh" doc
mk_stub "$T/tests/scripts/test-five-tool-prerelease-cursor.sh" fivetool
mk_stub "$T/tests/run-all-tests.sh" fullsuite
mk_stub "$T/scripts/run-rc-validation-matrix.sh" rcmatrix
G="$T/scripts/pre-release-gate.sh"
run() { : >"$LOG"; tl_run env "$@" bash "$G"; }

# bypass
run SB_SKIP_PRE_RELEASE_GATE=1
assert_eq "bypass exits 0" 0 "$TL_STATUS"
assert_contains "bypass notice" "$TL_ERR" "SB_SKIP_PRE_RELEASE_GATE=1 — pre-release gate skipped"
assert_eq "bypass runs nothing" "" "$(cat "$LOG")"

# all green, leanctx not opted in
echo '{"recommended_tools":{"leanctx":{"enabled_by_user":false}}}' >"$T/.silver-bullet.json"
run SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=leak
assert_eq "all stages pass" 0 "$TL_STATUS"
assert_eq "stage order" "content doc fivetool fullsuite rcmatrix" "$(awk '{printf "%s%s", (NR>1?" ":""), $1}' "$LOG")"
assert_contains "banner" "$TL_OUT" "PRE-RELEASE GATE — CI green + site freshness required"
assert_contains "offline notice" "$TL_OUT" "leanctx not opted in — offline wiring + bundle only"
assert_contains "site ok" "$TL_OUT" "✓ Site freshness tests passed."
assert_contains "five-tool ok" "$TL_OUT" "✓ Five-tool pre-release gate passed."
assert_contains "suite ok" "$TL_OUT" "✓ Pre-release gate passed — local CI-equivalent suite is green."
assert_contains "matrix ok" "$TL_OUT" "✓ RC validation matrix passed."
assert_contains "five-tool stage sees prerelease flag, live unset" "$(grep '^fivetool' "$LOG")" "PRE=1 LIVE=unset"
assert_contains "full suite does not inherit selectors" "$(grep '^fullsuite' "$LOG")" "PRE=unset LIVE=unset"

# leanctx opted in -> live required for the five-tool stage only
echo '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}' >"$T/.silver-bullet.json"
run
assert_contains "live required notice" "$TL_OUT" "leanctx opted in — live delegate scenarios required"
assert_contains "five-tool stage sees live flag" "$(grep '^fivetool' "$LOG")" "PRE=1 LIVE=1"
assert_contains "full suite still clean" "$(grep '^fullsuite' "$LOG")" "PRE=unset LIVE=unset"

# missing config / unparseable config -> treated as not opted in
rm "$T/.silver-bullet.json"
run
assert_contains "no config -> offline" "$TL_OUT" "leanctx not opted in"
echo '{bad' >"$T/.silver-bullet.json"
run
assert_contains "bad config -> offline" "$TL_OUT" "leanctx not opted in"

# each stage failing stops the gate with its own message
chk_fail() { # stage message last-stage-expected
  run FAIL_STAGE="$1"
  assert_eq "$1 failure -> exit 1" 1 "$TL_STATUS"
  assert_contains "$1 failure message" "$TL_ERR" "$2"
  assert_eq "$1 failure stops later stages" "$3" "$(awk '{printf "%s%s", (NR>1?" ":""), $1}' "$LOG")"
}
chk_fail content "site content freshness test failed" "content"
chk_fail doc "site doc freshness test failed" "content doc"
chk_fail fivetool "five-tool stack pre-release gate failed" "content doc fivetool"
assert_contains "five-tool hint" "$TL_ERR" "docs/testing/FIVE-TOOL-PRERELEASE.md"
chk_fail fullsuite "fix failing tests before bump/tag/release" "content doc fivetool fullsuite"
chk_fail rcmatrix "RC validation matrix failed" "content doc fivetool fullsuite rcmatrix"
assert_contains "rc matrix bypass hint" "$TL_ERR" "bypass: SB_SKIP_RC_MATRIX=1"

tl_results
