#!/usr/bin/env bash
# scripts/lib/planning-clarify-path.sh: slugging, path building (date stubbed), newest-doc lookup.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# shellcheck source=../../scripts/lib/planning-clarify-path.sh
source "$TL_REPO_ROOT/scripts/lib/planning-clarify-path.sh"
set +e

rc() { "$@" >/dev/null 2>&1; echo $?; }

# --- plan basename ----------------------------------------------------------------
assert_eq "basename: empty -> 1" 1 "$(rc sb_planning_clarify_plan_basename "")"
assert_eq "basename: no arg -> 1" 1 "$(rc sb_planning_clarify_plan_basename)"
assert_eq "basename: strips .plan.md" feature "$(sb_planning_clarify_plan_basename /a/b/feature.plan.md)"
assert_eq "basename: strips .md" notes "$(sb_planning_clarify_plan_basename notes.md)"
assert_eq "basename: keeps other extension" "x.txt" "$(sb_planning_clarify_plan_basename dir/x.txt)"
assert_eq "basename: bare .md is empty -> 1" 1 "$(rc sb_planning_clarify_plan_basename /a/.md)"

# --- slugify ------------------------------------------------------------------------------
assert_eq "slug: empty -> 1" 1 "$(rc sb_planning_clarify_slugify_topic "")"
assert_eq "slug: normalises" "hello-world-2" "$(sb_planning_clarify_slugify_topic '  Hello,   World!! 2 ')"
assert_eq "slug: only punctuation -> 1" 1 "$(rc sb_planning_clarify_slugify_topic '!!! ???')"

# --- basename segment ---------------------------------------------------------------------------
assert_eq "segment: plan wins" myplan "$(sb_planning_clarify_basename_segment x/myplan.plan.md "Some Topic")"
assert_eq "segment: topic when no plan" some-topic "$(sb_planning_clarify_basename_segment "" "Some Topic")"
assert_eq "segment: invalid plan falls back to topic" some-topic "$(sb_planning_clarify_basename_segment /a/.md "Some Topic")"
assert_eq "segment: nothing -> default" clarify-session "$(sb_planning_clarify_basename_segment)"
assert_eq "segment: invalid plan + invalid topic -> default" clarify-session "$(sb_planning_clarify_basename_segment /a/.md '###')"

# --- timestamps (date stubbed) ---------------------------------------------------------------------------
tl_stub date 'echo "date:$*"'
assert_eq "timestamp format request" "date:-u +%Y%m%dT%H%M%SZ" "$(sb_planning_clarify_timestamp)"
assert_eq "yymmdd format request" "date:-u +%y%m%d" "$(sb_planning_clarify_yymmdd)"
assert_eq "relpath: defaults come from date" ".planning/p-CLARIFY-date:-u +%y%m%d-date:-u +%Y%m%dT%H%M%SZ.md" "$(sb_planning_clarify_output_relpath p.md)"
assert_eq "relpath: explicit stamps" ".planning/p-CLARIFY-260716-20260716T011730Z.md" "$(sb_planning_clarify_output_relpath p.md "" 20260716T011730Z 260716)"
assert_eq "relpath: topic slug" ".planning/my-topic-CLARIFY-260716-T.md" "$(sb_planning_clarify_output_relpath "" "My Topic" T 260716)"
assert_eq "output_path: absolute" "/repo/.planning/clarify-session-CLARIFY-260716-T.md" "$(sb_planning_clarify_output_path /repo "" "" T 260716)"
rm -f "$TL_BIN/date"; hash -r
assert_match "real date format" '^\.planning/p-CLARIFY-[0-9]{6}-[0-9]{8}T[0-9]{6}Z\.md$' "$(sb_planning_clarify_output_relpath p.md)"

# --- filename matcher -----------------------------------------------------------------------------------
assert_eq "matches: valid" 0 "$(rc sb_planning_clarify_filename_matches a-CLARIFY-260716-20260716T011730Z.md)"
assert_eq "matches: bad date" 1 "$(rc sb_planning_clarify_filename_matches a-CLARIFY-26071-20260716T011730Z.md)"
assert_eq "matches: legacy name" 1 "$(rc sb_planning_clarify_filename_matches CLARIFY.md)"

# --- newest clarify doc --------------------------------------------------------------------------------
W="$TL_TMP/w"; mkdir -p "$W"
assert_eq "newest: no .planning -> 1" 1 "$(rc sb_planning_find_newest_clarify_doc "$W")"
mkdir -p "$W/.planning"
assert_eq "newest: empty .planning -> 1" 1 "$(rc sb_planning_find_newest_clarify_doc "$W")"
touch "$W/.planning/other-CLARIFY-x-y.md"          # glob match, wrong pattern
mkdir "$W/.planning/dir-CLARIFY-260101-20260101T000000Z.md"   # directory is skipped
assert_eq "newest: only non-matching candidates -> 1" 1 "$(rc sb_planning_find_newest_clarify_doc "$W")"
echo legacy >"$W/.planning/CLARIFY.md"; touch -d '2020-01-01' "$W/.planning/CLARIFY.md"
assert_eq "newest: legacy only" "$W/.planning/CLARIFY.md" "$(sb_planning_find_newest_clarify_doc "$W")"
A="$W/.planning/a-CLARIFY-260101-20260101T000000Z.md"; B="$W/.planning/b-CLARIFY-260102-20260102T000000Z.md"
touch -d '2021-01-01' "$A"; touch -d '2022-01-01' "$B"
assert_eq "newest: newer pattern file beats legacy" "$B" "$(sb_planning_find_newest_clarify_doc "$W")"
# mtime (not name order) decides: the alphabetically-first file is the newest
touch -d '2024-06-01' "$A"
assert_eq "newest: mtime beats name order" "$A" "$(sb_planning_find_newest_clarify_doc "$W")"
touch -d '2021-01-01' "$A"
touch -d '2023-01-01' "$W/.planning/CLARIFY.md"
assert_eq "newest: newer legacy beats pattern files" "$W/.planning/CLARIFY.md" "$(sb_planning_find_newest_clarify_doc "$W")"
touch -d '2022-01-01' "$W/.planning/CLARIFY.md"
assert_eq "newest: tie prefers pattern file" "$B" "$(sb_planning_find_newest_clarify_doc "$W")"
# stat failing entirely: every mtime reads as 0, ties go to the last glob match
tl_stub stat 'exit 1'; hash -r
assert_eq "newest: stat failure treated as mtime 0" "$B" "$(sb_planning_find_newest_clarify_doc "$W")"
# stat printing garbage is also coerced to 0
tl_stub stat 'echo not-a-number'; hash -r
assert_eq "newest: non-numeric mtime coerced" "$B" "$(sb_planning_find_newest_clarify_doc "$W")"
rm -f "$TL_BIN/stat"; hash -r
rm -f "$W/.planning/CLARIFY.md"
tl_stub stat 'echo not-a-number'; hash -r
assert_eq "newest: non-numeric mtime without legacy doc" "$B" "$(sb_planning_find_newest_clarify_doc "$W")"
rm -f "$TL_BIN/stat"; hash -r

# --- locked decisions ----------------------------------------------------------------------------------------
assert_eq "locked: missing file -> 1" 1 "$(rc sb_planning_clarify_doc_has_locked_decisions "$TL_TMP/none.md")"
echo "Decisions are LOCKED here" >"$TL_TMP/l1.md"
assert_eq "locked: keyword (case-insensitive)" 0 "$(rc sb_planning_clarify_doc_has_locked_decisions "$TL_TMP/l1.md")"
echo "decision_class: A" >"$TL_TMP/l2.md"
assert_eq "locked: decision_class" 0 "$(rc sb_planning_clarify_doc_has_locked_decisions "$TL_TMP/l2.md")"
echo "nothing relevant" >"$TL_TMP/l3.md"
assert_eq "locked: none -> 1" 1 "$(rc sb_planning_clarify_doc_has_locked_decisions "$TL_TMP/l3.md")"

tl_results
