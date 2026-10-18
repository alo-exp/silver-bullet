#!/usr/bin/env bash
# scripts/run-visual-qa-pipeline.sh in a temp tree with a stub `node` (no browser, no network).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

T="$TL_TMP/tree"
AUD="$T/.visual-audit/responsive-full"
mkdir -p "$T/scripts" "$AUD"
cp "$TL_REPO_ROOT/scripts/run-visual-qa-pipeline.sh" "$T/scripts/"
tl_git_repo "$T" >/dev/null 2>&1
git -C "$T" checkout -q -b qa/branch 2>/dev/null || true
S="$T/scripts/run-visual-qa-pipeline.sh"
for f in capture-matrix overflow-check style-check golden-strings vision-gate; do : >"$AUD/$f.mjs"; done

# Stub node: behaviour keyed by script basename and env switches. Logs invocations.
cat >"$TL_BIN/node" <<'EOF2'
#!/usr/bin/env bash
script="$(basename "$1")"
echo "$script $*" >>"$NODE_LOG"
case "$script" in
  capture-matrix.mjs) [[ "${FAIL_CAPTURE:-}" == 1 ]] && exit 1; exit 0 ;;
  overflow-check.mjs)
    page="${2:-}"
    if [[ "${FAIL_OVERFLOW:-}" == 1 ]]; then echo "FAIL overflow=12px $page"; exit 1; fi
    if [[ "${FAIL_OVERFLOW:-}" == noinfo ]]; then echo "FAIL weird"; exit 1; fi
    echo "PASS overflow=0px $page"; exit 0 ;;
  style-check.mjs) if [[ "${FAIL_STYLE:-}" == 1 ]]; then echo "l1"; echo "l2"; echo "l3"; echo "l4"; exit 1; fi; exit 0 ;;
  golden-strings.mjs)
    [[ "${FAIL_GOLDEN:-}" == 1 ]] && exit 1
    mkdir -p "$GOLDEN_OUT_DIR"
    echo '{"strings":["a","b","c"]}' >"$GOLDEN_OUT_DIR/home-golden-strings.json"
    echo '{"strings":["a"]}' >"$GOLDEN_OUT_DIR/help-getting-started-golden-strings.json"
    exit 0 ;;
  vision-gate.mjs)
    if [[ "$2" == "--self-test" ]]; then [[ "${FAIL_SELF:-}" == 1 ]] && exit 1; exit 0; fi
    label=""; while [[ $# -gt 0 ]]; do [[ "$1" == --label ]] && label="$2"; shift; done
    [[ "${FAIL_VISION:-}" == "$label" || "${FAIL_VISION:-}" == all ]] && exit 1
    exit 0 ;;
esac
EOF2
chmod +x "$TL_BIN/node"
export NODE_LOG="$TL_TMP/node.log"
export VISUAL_QA_DATE=2026-01-02
unset GEMINI_API_KEY GOOGLE_API_KEY
export SDG_TEST_IMAGE="$TL_TMP/sdg.png"

res() { jq -r "$1" "$T/.visual-audit/proof-test-results-2026-01-02.json"; }
# shellcheck disable=SC2086
run() { : >"$NODE_LOG"; tl_run env "$@" bash "$S" $ARGS; }

AUDIT_OUT="$T/.visual-audit/responsive-full/2026-01-02-pipeline"
step() { res ".steps[]|select(.step==\"$1\")|$2"; }

# 1. full run, no API key: alumnium is a documented SKIP -> PASS_WITH_GAPS
ARGS=""; run
assert_eq "full run ok" 0 "$TL_STATUS"
assert_eq "overall PASS_WITH_GAPS" PASS_WITH_GAPS "$(res .overall)"
assert_eq "branch recorded" qa/branch "$(res .branch)"
assert_eq "outDir relative" ".visual-audit/responsive-full/2026-01-02-pipeline" "$(res .outDir)"
assert_eq "capture detail" ".visual-audit/responsive-full/2026-01-02-pipeline" "$(step capture .detail)"
assert_eq "overflow default pages" "all default pages" "$(step overflow-375 .detail)"
assert_eq "style pass" PASS "$(step style-check .status)"
assert_eq "golden detail" ".visual-audit/responsive-full/2026-01-02-pipeline/golden-strings" "$(step golden-strings .detail)"
assert_eq "self-test PASS" PASS "$(step vision-self-test .status)"
assert_eq "alumnium SKIP" SKIP "$(step alumnium .status)"
assert_eq "no api -> no vision steps" "" "$(step vision-sdg .status)"
assert_eq "SDG golden slug" sdg-control "$(jq -r .slug "$AUDIT_OUT/golden-strings/sdg-control-golden-strings.json")"
assert_contains "Done log" "$TL_OUT" "[visual-qa] Done"
assert_contains "capture ran once" "$(cat "$NODE_LOG")" "capture-matrix.mjs"

# 2. --skip-alumnium: nothing skipped -> PASS; custom SDG golden preserved
echo customized >"$AUDIT_OUT/golden-strings/sdg-control-golden-strings.json"
ARGS="--skip-alumnium --bogus-flag"; run
assert_eq "skip-alumnium ok" 0 "$TL_STATUS"
assert_eq "overall PASS" PASS "$(res .overall)"
assert_eq "SDG golden kept" customized "$(cat "$AUDIT_OUT/golden-strings/sdg-control-golden-strings.json")"
assert_eq "no alumnium step" "" "$(step alumnium .status)"

# 3. API key: SDG + homepage (primary hero) pass
: >"$TL_TMP/sdg.png"; : >"$AUDIT_OUT/home-light-1280px.png"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k
assert_eq "api pass overall" PASS "$(res .overall)"
assert_eq "vision-sdg PASS" PASS "$(step vision-sdg .status)"
assert_eq "vision-homepage PASS" PASS "$(step vision-homepage .status)"
assert_eq "homepage detail is hero path" "$AUDIT_OUT/home-light-1280px.png" "$(step vision-homepage .detail)"
# GOOGLE_API_KEY alone also enables API path; hero fallback #2
rm "$AUDIT_OUT/home-light-1280px.png"; : >"$AUDIT_OUT/home-light-1280px-hero.png"
ARGS="--skip-alumnium"; run GOOGLE_API_KEY=k
assert_eq "hero fallback 2" "$AUDIT_OUT/home-light-1280px-hero.png" "$(step vision-homepage .detail)"
# fallback #3 (post-fix dir)
rm "$AUDIT_OUT/home-light-1280px-hero.png"; mkdir -p "$AUD/2026-06-30-post-fix"; : >"$AUD/2026-06-30-post-fix/home-light-1280px-hero.png"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k
assert_eq "hero fallback 3" "$AUD/2026-06-30-post-fix/home-light-1280px-hero.png" "$(step vision-homepage .detail)"
# no hero at all -> homepage step absent
rm "$AUD/2026-06-30-post-fix/home-light-1280px-hero.png"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k
assert_eq "no hero -> no homepage step" "" "$(step vision-homepage .status)"
assert_eq "sdg still present" PASS "$(step vision-sdg .status)"
# SDG image missing -> no sdg step
rm "$TL_TMP/sdg.png"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k
assert_eq "no sdg image -> no sdg step" "" "$(step vision-sdg .status)"

# 4. vision failures
: >"$TL_TMP/sdg.png"; : >"$AUDIT_OUT/home-light-1280px.png"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k FAIL_VISION=sdg-control
assert_eq "sdg fail" FAIL "$(step vision-sdg .status)"
assert_eq "overall FAIL" FAIL "$(res .overall)"
ARGS="--skip-alumnium"; run GEMINI_API_KEY=k FAIL_VISION=homepage-hero-1280
assert_eq "homepage fail" FAIL "$(step vision-homepage .status)"
assert_eq "homepage fail detail" "homepage vision or grounding failed" "$(step vision-homepage .detail)"
ARGS="--skip-alumnium --skip-vision"; run GEMINI_API_KEY=k
assert_eq "skip-vision: no sdg step" "" "$(step vision-sdg .status)"
assert_eq "skip-vision: self-test still runs" PASS "$(step vision-self-test .status)"

# 5. stage failures
ARGS="--skip-alumnium"; run FAIL_CAPTURE=1
assert_eq "capture fail" FAIL "$(step capture .status)"
assert_eq "capture fail detail" "capture-matrix exit nonzero" "$(step capture .detail)"
ARGS="--skip-alumnium"; run FAIL_OVERFLOW=1
assert_eq "overflow fail" FAIL "$(step overflow-375 .status)"
ARGS="--skip-alumnium"; run FAIL_STYLE=1
assert_eq "style fail" FAIL "$(step style-check .status)"
assert_eq "style fail tail" "l2 l3 l4 " "$(step style-check .detail)"
ARGS="--skip-alumnium"; run FAIL_GOLDEN=1
assert_eq "golden fail" FAIL "$(step golden-strings .status)"
assert_eq "golden fail detail" "extraction error" "$(step golden-strings .detail)"
ARGS="--skip-alumnium"; run FAIL_SELF=1
assert_eq "self-test fail" FAIL "$(step vision-self-test .status)"
ARGS="--skip-alumnium --skip-capture"; run
assert_eq "skip-capture: no capture step" "" "$(step capture .status)"
assert_not_contains "skip-capture: capture-matrix not run" "$(cat "$NODE_LOG")" "capture-matrix.mjs"

# 6. proof-only mode
PROOF="$T/.visual-audit/responsive-full/2026-01-02-pipeline-proof"
ARGS="--proof-only"; run
assert_eq "proof ok" 0 "$TL_STATUS"
assert_eq "proof outDir" ".visual-audit/responsive-full/2026-01-02-pipeline-proof" "$(res .outDir)"
assert_contains "proof capture detail" "$(step capture .detail)" "4 captures"
assert_contains "proof capture env" "$(cat "$NODE_LOG")" "capture-matrix.mjs"
assert_eq "proof overflow home" PASS "$(step overflow-home-375 .status)"
assert_eq "proof overflow home detail" "overflow=0px on /" "$(step overflow-home-375 .detail)"
assert_eq "proof overflow help" PASS "$(step overflow-help-375 .status)"
assert_eq "proof golden detail" "home=3 strings, help-getting-started=1" "$(step golden-strings .detail)"
assert_eq "proof sdg file_attachments skip" SKIP "$(step vision-sdg-file_attachments .status)"
assert_eq "proof delivery extra" task-file_attachments-gemini-3.5-flash "$(step vision-homepage-file_attachments .delivery)"
assert_eq "proof api skip without key" SKIP "$(step vision-api-inline-base64 .status)"
assert_eq "proof alumnium-start" SKIP "$(step alumnium-start .status)"
assert_eq "proof alumnium-check" SKIP "$(step alumnium-check-vision .status)"
assert_eq "proof overall gaps" PASS_WITH_GAPS "$(res .overall)"
ARGS="--proof-only --skip-alumnium"; run GEMINI_API_KEY=k
assert_eq "proof api pass" PASS "$(step vision-api-inline-base64 .status)"
assert_eq "proof: no sdg step" "" "$(step vision-sdg .status)"
ARGS="--proof-only --skip-alumnium"; run GEMINI_API_KEY=k FAIL_VISION=all
assert_eq "proof api fail" FAIL "$(step vision-api-inline-base64 .status)"
ARGS="--proof-only --skip-alumnium --skip-vision"; run
assert_eq "proof skip-vision no api step" "" "$(step vision-api-inline-base64 .status)"
ARGS="--proof-only"; run FAIL_CAPTURE=1 FAIL_OVERFLOW=1
assert_eq "proof capture fail" FAIL "$(step capture .status)"
assert_eq "proof overflow fail detail" "horizontal overflow on /: 12px" "$(step overflow-home-375 .detail)"
ARGS="--proof-only"; run FAIL_OVERFLOW=noinfo
assert_eq "proof overflow unknown px" "horizontal overflow on /help/getting-started/: ?px" "$(step overflow-help-375 .detail)"
# CAPTURE_OUT_DIR override
ARGS="--proof-only"; run CAPTURE_OUT_DIR="$T/custom-out"
assert_eq "custom out dir (under repo -> relative)" "custom-out" "$(res .outDir)"
assert_file_exists "custom out dir created" "$T/custom-out/golden-strings"
assert_file_exists "proof dir created earlier" "$PROOF"

# 7. outside git and default date
T2="$TL_TMP/tree2"
mkdir -p "$T2/scripts" "$T2/.visual-audit/responsive-full"
cp "$S" "$T2/scripts/"
tl_run env -u VISUAL_QA_DATE bash "$T2/scripts/run-visual-qa-pipeline.sh" --skip-alumnium --skip-capture
assert_eq "no-git run ok" 0 "$TL_STATUS"
f2="$(ls "$T2"/.visual-audit/proof-test-results-*.json)"
assert_match "default date in file name" 'proof-test-results-[0-9]{4}-[0-9]{2}-[0-9]{2}\.json$' "$f2"
assert_eq "branch unknown outside git" unknown "$(jq -r .branch "$f2")"

tl_results
