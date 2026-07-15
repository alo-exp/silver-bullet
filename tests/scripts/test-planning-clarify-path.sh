#!/usr/bin/env bash
# Tests for /silver:clarify output path naming (plan-scoped + timestamped).
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/planning-clarify-path.sh
source "${REPO_ROOT}/scripts/lib/planning-clarify-path.sh"

base="$(sb_planning_clarify_plan_basename '/tmp/multi_ai_deep_research_b3d9881b.plan.md')"
[[ "$base" == "multi_ai_deep_research_b3d9881b" ]] && pass "plan basename strips .plan.md" || fail "plan basename got $base"

rel="$(sb_planning_clarify_output_relpath '/tmp/foo.plan.md' '' '20260716T011730Z' '260716')"
[[ "$rel" == ".planning/foo-CLARIFY-260716-20260716T011730Z.md" ]] && pass "relpath uses plan basename + date + timestamp" || fail "relpath got $rel"

abs="$(sb_planning_clarify_output_path "$REPO_ROOT" '/tmp/multi_ai_deep_research_b3d9881b.plan.md' '' '20260716T011730Z' '260716')"
[[ "$abs" == "${REPO_ROOT}/.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260716-20260716T011730Z.md" ]] && pass "absolute path resolves under repo" || fail "abs got $abs"

topic_base="$(sb_planning_clarify_basename_segment '' 'Multi AI Deep Research')"
[[ "$topic_base" == "multi-ai-deep-research" ]] && pass "topic slug fallback" || fail "topic slug got $topic_base"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/.planning"
printf 'legacy\n' >"$FIXTURE/.planning/CLARIFY.md"
sleep 1
printf 'locked decision\ndecision_class: locked\n' >"$FIXTURE/.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260716-20260716T011730Z.md"
found="$(sb_planning_find_newest_clarify_doc "$FIXTURE")"
[[ "$(basename "$found")" == "multi_ai_deep_research_b3d9881b-CLARIFY-260716-20260716T011730Z.md" ]] && pass "find newest prefers timestamped clarify doc" || fail "found $found"

if sb_planning_clarify_doc_has_locked_decisions "$found"; then
  pass "locked decision detector"
else
  fail "locked decision detector"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
