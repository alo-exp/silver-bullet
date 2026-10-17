#!/usr/bin/env bash
# hooks/lib/completion-audit/{classify,state-helpers,change-class,gates}.sh unit tests.
# The libs are sourced into small bash -c drivers so each function is exercised directly.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

CA="$TL_REPO_ROOT/hooks/lib/completion-audit"
LIBDIR="$TL_REPO_ROOT/hooks/lib"

# drive <lib> <code>: source a lib (plus workflow-utils/required-skills helpers) and run code.
drive() {
  local lib="$1" code="$2"
  tl_run bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2"; eval "$3"' _ "$LIBDIR" "$CA/$lib" "$code"
}

# ── classify.sh: skill-adapter detection ─────────────────────────────────────
adapter() { drive classify.sh "shell_payload_is_sb_skill_adapter_invocation \"\$1\"" ; }
check_adapter() {
  local name="$1" want="$2" payload="$3"
  tl_run bash -c 'source "$1"; shell_payload_is_sb_skill_adapter_invocation "$2"' _ "$CA/classify.sh" "$payload"
  assert_eq "adapter: $name" "$want" "$TL_STATUS"
}
check_adapter "relative script + invoke-skill" 0 "scripts/silver-bullet invoke-skill silver-plan"
check_adapter "absolute script path" 0 "/opt/x/scripts/silver-bullet invoke-skill silver-plan"
check_adapter "env prefix and assignment" 0 "env A=1 B=2 scripts/silver-bullet invoke-skill x"
check_adapter "empty payload" 1 ""
check_adapter "multi-line payload" 1 $'scripts/silver-bullet invoke-skill x\nrm -rf /'
check_adapter "chained with semicolon" 1 "scripts/silver-bullet invoke-skill x; rm y"
check_adapter "piped" 1 "scripts/silver-bullet invoke-skill x | cat"
check_adapter "redirected" 1 "scripts/silver-bullet invoke-skill x > out"
check_adapter "unbalanced quote" 1 "scripts/silver-bullet invoke-skill 'x"
check_adapter "script only, no subcommand" 1 "scripts/silver-bullet"
check_adapter "env assignments only" 1 "env A=1"
check_adapter "different program" 1 "scripts/other invoke-skill x"
check_adapter "different subcommand" 1 "scripts/silver-bullet status x"
check_adapter "whitespace only" 1 "   "

# ── classify.sh: workflow id extraction ──────────────────────────────────────
wid() { tl_run bash -c 'source "$1"; workflow_id_from_shell_assignment "$2"' _ "$CA/classify.sh" "$1"; }
wid 'export SB_WORKFLOW_ID=20260101T000000Z-abc123-silver-feature; gh pr create'
assert_eq "export form id" "20260101T000000Z-abc123-silver-feature" "$TL_OUT"
wid '  export SB_WORKFLOW_ID=abc ; gh pr create'
assert_eq "export form tolerates leading space" "abc" "$TL_OUT"
wid 'env SB_WORKFLOW_ID=wf1 gh pr create'
assert_eq "env prefix form id" "wf1" "$TL_OUT"
wid 'SB_WORKFLOW_ID=wf2 gh pr create'
assert_eq "bare assignment form id" "wf2" "$TL_OUT"
wid 'FOO=1 SB_WORKFLOW_ID=wf3 gh pr create'
assert_eq "assignment after another var" "wf3" "$TL_OUT"
wid 'gh pr create'
assert_eq "no assignment: status 1" 1 "$TL_STATUS"
wid 'export OTHER=1; gh pr create'
assert_eq "other export: status 1" 1 "$TL_STATUS"
wid $'gh pr create\nSB_WORKFLOW_ID=second-line x'
assert_eq "only the first line is considered" 1 "$TL_STATUS"

# ── classify.sh: command classification ──────────────────────────────────────
classify() {
  tl_run bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$1/tool-input.sh"; source "$2"; ca_classify_command "$3"; rc=$?; echo "rc=$rc inter=$is_intermediate comp=$is_completion"' _ "$LIBDIR" "$CA/classify.sh" "$1"
}
for c in 'git commit -m x' 'git push origin x' 'git write-tree' 'git commit-tree abc -m x' 'git hash-object -w f' 'git update-ref refs/heads/x abc'; do
  classify "$c"
  assert_contains "intermediate: $c" "$TL_OUT" "rc=0 inter=true comp=false"
done
for c in 'gh pr create --fill' 'gh pr merge 1' 'make Deploy' 'gh release create v1'; do
  classify "$c"
  assert_contains "completion: $c" "$TL_OUT" "rc=0 inter=false comp=true"
done
for c in 'git status' 'git hash-object f' 'git update-ref refs/tags/x abc' 'ls' 'echo deployment'; do
  classify "$c"
  assert_contains "not gated: $c" "$TL_OUT" "rc=1 inter=false comp=false"
done
classify 'scripts/silver-bullet invoke-skill git-commit-helper'
assert_contains "skill adapter invocation is not gated" "$TL_OUT" "rc=1"
classify 'RTK_DISABLED=1 rtk git commit -m x'
assert_contains "rtk wrapper is unwrapped before classifying" "$TL_OUT" "inter=true"
tl_run bash -c 'source "$1"; ca_classify_command "git commit -m x"; echo "inter=$is_intermediate"' _ "$CA/classify.sh"
assert_contains "classifies without the rtk unwrap helper" "$TL_OUT" "inter=true"

# ── state-helpers.sh ────────────────────────────────────────────────────────
STATE=$'silver-plan\nsilver-review\nsilver-plan-extra'
tl_run bash -c 'source "$1"; state_contents="$2"; has_skill silver-plan; echo "has=$?"; has_skill silver-pla; echo "partial=$?"; echo "line=$(skill_line silver-review)"; echo "absent=$(skill_line nope)"' _ "$CA/state-helpers.sh" "$STATE"
assert_contains "fallback has_skill matches whole line" "$TL_OUT" "has=0"
assert_contains "fallback has_skill rejects substrings" "$TL_OUT" "partial=1"
assert_contains "fallback skill_line gives 1-based line" "$TL_OUT" "line=2"
assert_contains "fallback skill_line is 0 when absent" "$TL_OUT" "absent=0"
tl_run bash -c 'source "$1/required-skills.sh"; source "$2"; state_contents="$3"; has_skill silver-plan; echo "has=$?"; echo "line=$(skill_line silver-review)"' _ "$LIBDIR" "$CA/state-helpers.sh" "$STATE"
assert_contains "required-skills-backed has_skill" "$TL_OUT" "has=0"
assert_contains "required-skills-backed skill_line" "$TL_OUT" "line=2"

# ── change-class.sh ─────────────────────────────────────────────────────────
cls() { tl_run bash -c 'source "$1"; ca_classify_path "$2" "${3:-/src/}"' _ "$CA/change-class.sh" "$@"; }
check_cls() { cls "$2" "${3:-/src/}"; assert_eq "classify path $1: $2" "$1" "$TL_OUT"; }
check_cls release package.json
check_cls release plugins/silver-bullet/x.json
check_cls release scripts/pre-release-gate.sh
check_cls release .claude-plugin/plugin.json
check_cls release docs/CHANGELOG.md
check_cls release plugins/foo/CHANGELOG.md
check_cls site site/index.html
check_cls config .silver-bullet.json
check_cls config hooks/hooks.json
check_cls config .cursor/hooks.json
check_cls other .mcp.json
check_cls config mcp.json
check_cls config templates/silver-bullet.config.json.default
check_cls src app/src/main.py
check_cls src hooks/foo.sh
check_cls src skills/x/SKILL.md
check_cls src app/lib/custom/a.py '/lib/custom/'
check_cls docs docs/guide.md
check_cls docs README.md
check_cls docs AGENTS.md
check_cls docs silver-bullet.md
check_cls other random.txt
tl_run bash -c 'dcc_matches_src_scope() { [[ "$1" == vendor/* ]]; }; source "$1"; ca_classify_path vendor/x.js; ca_classify_path docs/a.md' _ "$CA/change-class.sh"
assert_eq "dcc_matches_src_scope hook decides src, else falls through" "srcdocs" "$TL_OUT"

# git fixtures
GITROOT="$TL_TMP/repo"
tl_git_repo "$GITROOT"
git -C "$GITROOT" checkout -q -b topic
collect() { tl_run bash -c 'source "$1"; ca_collect_changed_paths "$2"' _ "$CA/change-class.sh" "$1"; }
detect() {
  tl_run bash -c 'source "$1"; cmd_first_line="$4"; ca_detect_change_class "$2" "$3"; echo "$ca_change_class"' _ "$CA/change-class.sh" "$1" "${2:-}" "${3:-}"
}

NOGIT="$TL_TMP/nogit"; mkdir -p "$NOGIT"
collect "$NOGIT"
assert_eq "non-git dir: no paths" "" "$TL_OUT"
assert_eq "non-git dir: succeeds" 0 "$TL_STATUS"
collect "$GITROOT"
assert_eq "clean tree: no paths" "" "$TL_OUT"
detect "$GITROOT"
assert_eq "no changes: mixed" "mixed" "$TL_OUT"

mkdir -p "$GITROOT/docs"
echo a >"$GITROOT/docs/a.md"
git -C "$GITROOT" add docs/a.md
git -C "$GITROOT" commit -q -m docs
echo b >"$GITROOT/docs/b.md"
git -C "$GITROOT" add docs/b.md
echo c >"$GITROOT/.gitkeep"
collect "$GITROOT"
assert_eq "committed + staged + unstaged paths unioned" ".gitkeep
docs/a.md
docs/b.md" "$TL_OUT"
detect "$GITROOT"
assert_eq "docs plus other file: mixed" "mixed" "$TL_OUT"
git -C "$GITROOT" checkout -q -- .gitkeep
detect "$GITROOT"
assert_eq "docs only: docs" "docs" "$TL_OUT"

# master as base branch
git -C "$GITROOT" branch -m main master
collect "$GITROOT"
assert_contains "master used as merge base" "$TL_OUT" "docs/a.md"
git -C "$GITROOT" branch -m master main

cfg="$TL_TMP/cfg.json"
printf '{"project":{"src_pattern":"/lib/"}}' >"$cfg"
mkdir -p "$GITROOT/lib"; echo x >"$GITROOT/lib/m.py"; git -C "$GITROOT" add lib/m.py
detect "$GITROOT" "$cfg"
assert_eq "configured src_pattern: src plus docs is mixed" "mixed" "$TL_OUT"
printf '{"project":{"src_pattern":"not a/valid pattern("}}' >"$cfg"
detect "$GITROOT" "$cfg"
assert_eq "invalid src_pattern falls back to /src/" "mixed" "$TL_OUT"
tl_stub jq 'exit 1'
detect "$GITROOT" "$cfg"
assert_eq "failing jq falls back to /src/" "mixed" "$TL_OUT"
rm -f "$TL_BIN/jq"

# every class from a dedicated repo
class_for() { # class_for <relpath>... -> class
  local r="$TL_TMP/cls-$RANDOM"
  tl_git_repo "$r"; git -C "$r" checkout -q -b t
  local f
  for f in "$@"; do mkdir -p "$r/$(dirname "$f")"; echo x >"$r/$f"; git -C "$r" add "$f"; done
  detect "$r"
}
class_for pkg/src/app.py;                        assert_eq "src only" "src" "$TL_OUT"
class_for pkg/src/app.py docs/x.md;              assert_eq "src plus docs" "mixed" "$TL_OUT"
class_for package.json pkg/src/app.py;           assert_eq "release wins" "release" "$TL_OUT"
class_for random.txt;                        assert_eq "other only" "mixed" "$TL_OUT"
class_for site/a.html;                       assert_eq "site only" "site" "$TL_OUT"
class_for .silver-bullet.json;               assert_eq "config only" "config" "$TL_OUT"
class_for docs/x.md site/a.html;             assert_eq "docs plus site" "docs" "$TL_OUT"
class_for docs/x.md .silver-bullet.json;     assert_eq "docs plus config" "docs" "$TL_OUT"
class_for site/a.html .silver-bullet.json;   assert_eq "site plus config" "docs" "$TL_OUT"

detect "$GITROOT" "" "gh release create v1"
assert_eq "release command forces release class" "release" "$TL_OUT"

# subsetting and floor application
tl_run bash -c 'source "$1"; ca_subset_skills_for_light_class "silver-plan tdd silver-ship other documentation"' _ "$CA/change-class.sh"
assert_eq "light class keeps the allowlist only" "silver-plan silver-ship documentation" "$TL_OUT"
tl_run bash -c 'source "$1"; ca_subset_skills_for_light_class ""' _ "$CA/change-class.sh"
assert_eq "empty skill list stays empty" "" "$TL_OUT"

floor() { # floor <relpath> -> "class|required_skills"
  local r="$TL_TMP/fl-$RANDOM"
  tl_git_repo "$r"; git -C "$r" checkout -q -b t
  mkdir -p "$r/$(dirname "$1")"; echo x >"$r/$1"; git -C "$r" add "$1"
  tl_run bash -c 'source "$1"; required_skills="silver-plan test-driven-development silver-ship"; ca_apply_change_class_floor "$2" ""; echo "$ca_change_class|$required_skills"' _ "$CA/change-class.sh" "$r"
}
floor docs/a.md;  assert_eq "docs class subsets required skills" "docs|silver-plan silver-ship" "$TL_OUT"
floor pkg/src/a.py;   assert_eq "src class keeps the full list" "src|silver-plan test-driven-development silver-ship" "$TL_OUT"
floor package.json; assert_eq "release class keeps the full list" "release|silver-plan test-driven-development silver-ship" "$TL_OUT"
tl_run bash -c 'source "$1"; ca_detect_change_class() { ca_change_class=bogus; }; required_skills="a b"; ca_apply_change_class_floor "$2" ""; echo "$ca_change_class|$required_skills"' _ "$CA/change-class.sh" "$TL_TMP"
assert_eq "unknown class is treated as mixed" "mixed|a b" "$TL_OUT"

# ── gates.sh: workflow strict gate ───────────────────────────────────────────
wfroot="$TL_TMP/wf"; mkdir -p "$wfroot/.planning/workflows"
gate() { # gate <env assignments...> -> runs run_workflow_strict_gate in a clean shell
  tl_run env "$@" bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2/classify.sh"; source "$2/gates.sh"; emit_block() { echo "BLOCK: $1"; }; cmd="${GATE_CMD:-gh pr create}"; run_workflow_strict_gate "$3"; echo "fell-through"' _ "$LIBDIR" "$CA" "$wfroot"
}
gate X=1
assert_eq "no workflow files: falls through" "fell-through" "$TL_OUT"
rm -rf "$wfroot/.planning/workflows"
gate X=1
assert_eq "no workflow dir: falls through" "fell-through" "$TL_OUT"
mkdir -p "$wfroot/.planning/workflows"
mkdir "$wfroot/.planning/workflows/subdir.md"
gate X=1
assert_eq "directory named *.md is not an active workflow" "fell-through" "$TL_OUT"
rmdir "$wfroot/.planning/workflows/subdir.md"

WF=20260101T000000Z-abc123-silver-feature
printf '## Flow Log\n| 1 | a | complete |\n| 2 | b | pending |\n' >"$wfroot/.planning/workflows/$WF.md"
printf '## Flow Log\n| 1 | a | pending |\n' >"$wfroot/.planning/workflows/20260101T000000Z-def456-silver-bugfix.md"
gate X=1
assert_contains "no id: gate blocks" "$TL_OUT" "SB_WORKFLOW_ID is not set"
assert_contains "no id: active workflows are listed" "$TL_OUT" "• $WF"
assert_contains "no id: every active workflow is listed" "$TL_OUT" "• 20260101T000000Z-def456-silver-bugfix"
rm -f "$wfroot/.planning/workflows/20260101T000000Z-def456-silver-bugfix.md"
assert_eq "no id: block path exits 0" 0 "$TL_STATUS"
assert_not_contains "no id: does not fall through" "$TL_OUT" "fell-through"
gate SB_WORKFLOW_ID=BAD_ID
assert_contains "invalid id format is blocked" "$TL_OUT" "invalid format: BAD_ID"
gate SB_WORKFLOW_ID=20260101T000000Z-zzz999-missing
assert_contains "unknown workflow file is blocked" "$TL_OUT" "No active workflow file matches"
gate SB_WORKFLOW_ID=$WF
assert_contains "incomplete flows are blocked" "$TL_OUT" "1 of 2 flows complete"
gate X=1 "GATE_CMD=export SB_WORKFLOW_ID=$WF; gh pr create"
assert_contains "id from the command's export assignment" "$TL_OUT" "1 of 2 flows complete"
printf '## Flow Log\n| 1 | a | complete |\n| 2 | b | skipped |\n' >"$wfroot/.planning/workflows/$WF.md"
gate SB_WORKFLOW_ID=$WF
assert_eq "all flows complete: falls through" "fell-through" "$TL_OUT"
printf '## Flow Log\nno flow rows here\n' >"$wfroot/.planning/workflows/$WF.md"
gate SB_WORKFLOW_ID=$WF
assert_contains "workflow without Flow Log rows is blocked" "$TL_OUT" "has no Flow Log rows"
printf '## Flow Log\n| 1 | a | pending |\n| 2 | b | pending |\n' >"$wfroot/.planning/workflows/$WF.md"
gate SB_WORKFLOW_ID=$WF
assert_contains "zero complete flows is blocked, not skipped" "$TL_OUT" "0 of 2 flows complete"
ln -sf "$wfroot/.planning/workflows/$WF.md" "$wfroot/.planning/workflows/20260101T000000Z-lnk123-symlinked.md"
gate SB_WORKFLOW_ID=20260101T000000Z-lnk123-symlinked
assert_contains "symlinked workflow file is rejected" "$TL_OUT" "No active workflow file matches"

# ── gates.sh: mtime helper and doc-key resolution ────────────────────────────
mt="$TL_TMP/mt.txt"; echo x >"$mt"; touch -d '2026-01-02 03:04:05 UTC' "$mt"
drive gates.sh "_mtime_epoch '$mt'"
assert_eq "linux mtime via stat --format" "$(date -u -d '2026-01-02 03:04:05' +%s)" "$TL_OUT"
drive gates.sh "_mtime_epoch '$TL_TMP/does-not-exist'"
assert_eq "missing file mtime is 0" "0" "$TL_OUT"
tl_stub uname 'echo Darwin'
tl_stub stat '[[ "$1" == "-f" && "$2" == "%m" ]] && echo 1234 || exit 1'
drive gates.sh "_mtime_epoch '$mt'"
assert_eq "darwin mtime via stat -f %m" "1234" "$TL_OUT"
tl_stub stat 'echo not-a-number'
drive gates.sh "_mtime_epoch '$mt'"
assert_eq "non-numeric stat output becomes 0" "0" "$TL_OUT"
rm -f "$TL_BIN/uname" "$TL_BIN/stat"

docroot="$TL_TMP/docs-repo"; mkdir -p "$docroot/docs/knowledge" "$docroot/docs/learnings"
echo k >"$docroot/docs/knowledge/2026-03.md"; touch -d '2026-03-01 00:00:00 UTC' "$docroot/docs/knowledge/2026-03.md"
echo k >"$docroot/docs/knowledge/2026-03-extra.md"; touch -d '2026-03-02 00:00:00 UTC' "$docroot/docs/knowledge/2026-03-extra.md"
echo k >"$docroot/docs/knowledge/2026-04.md"
ln -s "$docroot/docs/knowledge/2026-03.md" "$docroot/docs/knowledge/2026-03-link.md"
echo l >"$docroot/docs/learnings/2026-03.md"; touch -d '2026-03-05 00:00:00 UTC' "$docroot/docs/learnings/2026-03.md"
echo c >"$docroot/docs/CHANGELOG.md"; touch -d '2026-03-06 00:00:00 UTC' "$docroot/docs/CHANGELOG.md"
ln -s "$docroot/docs/CHANGELOG.md" "$docroot/docs/LINK.md"
resolve() { drive gates.sh "resolve_doc_key_state '$docroot' 2026-03 '$1'; echo \"\$DOC_KEY_LABEL|\$DOC_KEY_EXISTS|\$DOC_KEY_MTIME\""; }
resolve docs/knowledge/YYYY-MM.md
assert_eq "knowledge key: newest monthly file" "docs/knowledge/2026-03*.md|1|$(date -u -d 2026-03-02 +%s)" "$TL_OUT"
resolve docs/learnings/YYYY-MM.md
assert_eq "learnings key: monthly file" "docs/learnings/2026-03*.md|1|$(date -u -d 2026-03-05 +%s)" "$TL_OUT"
drive gates.sh "resolve_doc_key_state '$docroot' 2026-09 docs/knowledge/YYYY-MM.md; echo \"\$DOC_KEY_EXISTS|\$DOC_KEY_MTIME\""
assert_eq "knowledge key: no file for month" "0|0" "$TL_OUT"
drive gates.sh "resolve_doc_key_state '$docroot' 2026-09 docs/learnings/YYYY-MM.md; echo \"\$DOC_KEY_EXISTS|\$DOC_KEY_MTIME\""
assert_eq "learnings key: no file for month" "0|0" "$TL_OUT"
resolve docs/CHANGELOG.md
assert_eq "plain key: file exists" "docs/CHANGELOG.md|1|$(date -u -d 2026-03-06 +%s)" "$TL_OUT"
resolve docs/LINK.md
assert_eq "plain key: symlink does not count" "docs/LINK.md|0|0" "$TL_OUT"
resolve docs/missing.md
assert_eq "plain key: missing file" "docs/missing.md|0|0" "$TL_OUT"

# ── gates.sh: checklist key builder ──────────────────────────────────────────
mkdir -p "$docroot/docs/guides"
echo g >"$docroot/docs/guides/a.md"; : >"$docroot/docs/guides/.gitkeep"; : >"$docroot/docs/.gitkeep"
echo r >"$docroot/README.md"; echo c >"$docroot/CHANGELOG.md"
drive gates.sh "build_doc_scheme_checklist_keys '$docroot'; printf '%s\n' \"\${DOC_SCHEME_CHECKLIST_KEYS[@]}\""
assert_eq "checklist keys: wildcards, docs files, root docs; monthly/.gitkeep/symlink/dupes dropped" "docs/CHANGELOG.md
docs/knowledge/YYYY-MM.md
docs/learnings/YYYY-MM.md
docs/guides/a.md
README.md
CHANGELOG.md" "$TL_OUT"
bare="$TL_TMP/bare-repo"; mkdir -p "$bare/docs"
ln -s "$docroot/README.md" "$bare/README.md"
drive gates.sh "build_doc_scheme_checklist_keys '$bare'; printf '%s\n' \"\${DOC_SCHEME_CHECKLIST_KEYS[@]}\""
assert_eq "checklist keys: symlinked root docs are skipped" "docs/CHANGELOG.md
docs/knowledge/YYYY-MM.md
docs/learnings/YYYY-MM.md" "$TL_OUT"
nodocs="$TL_TMP/nodocs"; mkdir -p "$nodocs"
drive gates.sh "build_doc_scheme_checklist_keys '$nodocs'; printf '%s\n' \"\${#DOC_SCHEME_CHECKLIST_KEYS[@]}\""
assert_eq "checklist keys: no docs dir keeps the mandatory three" "3" "$TL_OUT"

# ── change-class.sh: git failure fallbacks ───────────────────────────────────
NOBASE="$TL_TMP/nobase"; mkdir -p "$NOBASE"
git -C "$NOBASE" init -q -b trunk
git -C "$NOBASE" config user.email t@example.com; git -C "$NOBASE" config user.name T; git -C "$NOBASE" config commit.gpgsign false
echo a >"$NOBASE/a.txt"; git -C "$NOBASE" add a.txt; git -C "$NOBASE" commit -q -m init
echo b >"$NOBASE/b.txt"
collect "$NOBASE"
assert_eq "no main/master branch: only working-tree changes (none tracked)" "" "$TL_OUT"
echo c >>"$NOBASE/a.txt"
collect "$NOBASE"
assert_eq "no main/master branch: unstaged change reported" "a.txt" "$TL_OUT"

# External git stubs (a shell-function stub would interleave its own trace lines with the lib's).
REAL_GIT="$(command -v git)"
tl_stub git 'for a in "$@"; do [[ "$a" == diff ]] && exit 1; done; exec "$GIT_REAL" "$@"'
export GIT_REAL="$REAL_GIT"
collect "$GITROOT"
assert_eq "all git diffs failing: no paths" "" "$TL_OUT"
assert_eq "all git diffs failing: still success" 0 "$TL_STATUS"
rm -f "$TL_BIN/git"

tl_run bash -c 'source "$1"; ca_collect_changed_paths() { printf "docs/a.md\n\ndocs/b.md\n"; }; cmd_first_line=""; ca_detect_change_class "$2" ""; echo "$ca_change_class"' _ "$CA/change-class.sh" "$GITROOT"
assert_eq "blank lines in the path list are skipped" "docs" "$TL_OUT"

# ── gates.sh: darwin stat failure, enforcement tier helper, project gate ─────
tl_stub uname 'echo Darwin'
tl_stub stat 'exit 1'
drive gates.sh "_mtime_epoch '$mt'"
assert_eq "darwin stat failure becomes mtime 0" "0" "$TL_OUT"
rm -f "$TL_BIN/uname" "$TL_BIN/stat"

mkdir -p "$TL_TMP/learn-only/docs/learnings"
echo l >"$TL_TMP/learn-only/docs/learnings/2026-03.md"
ln -s "$TL_TMP/learn-only/docs/learnings/2026-03.md" "$TL_TMP/learn-only/docs/learnings/2026-03-link.md"
drive gates.sh "resolve_doc_key_state '$TL_TMP/learn-only' 2026-03 docs/learnings/YYYY-MM.md; echo \"\$DOC_KEY_EXISTS\""
assert_eq "learnings key ignores symlinked monthly files" "1" "$TL_OUT"

tier() { # tier <config path or empty> [pre-code]
  tl_run env "${@:3}" bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$1"; emit_block() { echo "BLOCK: $1"; }; config_file="$3"; eval "$4"; run_enforcement_tier_delivery_gate; echo "returned"' _ "$LIBDIR" "$CA" "$1" "${2:-:}"
}
tier "" 
assert_eq "no config: tier gate is a no-op" "returned" "$TL_OUT"
tier "$TL_TMP/missing-config.json"
assert_eq "missing config file: tier gate is a no-op" "returned" "$TL_OUT"
echo '{}' >"$TL_TMP/tier-cfg.json"
tier "$TL_TMP/tier-cfg.json" ':' SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
assert_eq "skip switch disables the tier gate" "returned" "$TL_OUT"
tier "$TL_TMP/tier-cfg.json" 'sb_enforcement_tier_delivery_allowed() { return 0; }'
assert_eq "tier allowing delivery: gate returns" "returned" "$TL_OUT"
tier "$TL_TMP/tier-cfg.json" 'sb_enforcement_tier_delivery_allowed() { return 1; }; sb_enforcement_tier_effective() { echo 1; }; sb_enforcement_tier_block_message() { echo "tier-msg-$1"; }'
assert_contains "tier denying delivery: blocks with the tier message" "$TL_OUT" "BLOCK: tier-msg-1"
assert_not_contains "tier denial exits instead of returning" "$TL_OUT" "returned"

# ── gates.sh: evidence schema strictness resolution ──────────────────────────
evid() { # evid <config json> [env...]
  printf '%s' "$1" >"$TL_TMP/ev-cfg.json"
  tl_run env "${@:2}" bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$1"; config_file="$3"; run_evidence_schema_delivery_gate "$4"; echo "strict=$SILVER_BULLET_EVIDENCE_SCHEMA_STRICT"' _ "$LIBDIR" "$CA" "$TL_TMP/ev-cfg.json" "$TL_TMP"
}
evid '{}'
assert_contains "default is strict" "$TL_OUT" "strict=1"
evid '{"hooks":{"evidence_schema":{"strict":"false"}}}'
assert_contains "config can relax strictness" "$TL_OUT" "strict=0"
evid '{"hooks":{"evidence_schema":{"strict":"yes"}}}'
assert_contains "'yes' counts as strict" "$TL_OUT" "strict=1"
evid '{}' SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=off
assert_contains "env override wins and unknown values are non-strict" "$TL_OUT" "strict=0"
evid '{}' SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=true
assert_contains "env 'true' is strict" "$TL_OUT" "strict=1"
tl_run env -u SILVER_BULLET_EVIDENCE_SCHEMA_STRICT bash -c 'source "$1/required-skills.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$3"; config_file=""; run_evidence_schema_delivery_gate "$4"; echo "strict=$SILVER_BULLET_EVIDENCE_SCHEMA_STRICT"' _ "$LIBDIR" "$CA" "$TL_TMP/no-such-dir" "$TL_TMP"
assert_contains "no config at all: strict by default" "$TL_OUT" "strict=1"
evid 'not json'
assert_contains "unreadable config falls back to strict" "$TL_OUT" "strict=1"
mkdir -p "$TL_TMP/no-ep-lib"
printf '{"hooks":{"evidence_schema":{"strict":"false"}}}' >"$TL_TMP/ev-cfg.json"
tl_run env -u SILVER_BULLET_EVIDENCE_SCHEMA_STRICT bash -c 'source "$1/required-skills.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$3"; config_file="$4"; run_evidence_schema_delivery_gate "$5"; echo "strict=$SILVER_BULLET_EVIDENCE_SCHEMA_STRICT"' _ "$LIBDIR" "$CA" "$TL_TMP/no-ep-lib" "$TL_TMP/ev-cfg.json" "$TL_TMP"
assert_contains "without the enterprise-policy lib the config is read directly" "$TL_OUT" "strict=0"
printf 'not json' >"$TL_TMP/ev-cfg.json"
tl_run env -u SILVER_BULLET_EVIDENCE_SCHEMA_STRICT bash -c 'source "$1/required-skills.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$3"; config_file="$4"; run_evidence_schema_delivery_gate "$5"; echo "strict=$SILVER_BULLET_EVIDENCE_SCHEMA_STRICT"' _ "$LIBDIR" "$CA" "$TL_TMP/no-ep-lib" "$TL_TMP/ev-cfg.json" "$TL_TMP"
assert_contains "no enterprise lib and unreadable config: strict" "$TL_OUT" "strict=1"

# ── remaining fallbacks: junk stat output, blank find lines, whitespace-only path list ──
tl_stub stat 'echo junk'
drive gates.sh "_mtime_epoch '$mt'"
assert_eq "non-numeric stat output becomes mtime 0 (linux branch)" "0" "$TL_OUT"
rm -f "$TL_BIN/stat"

REAL_FIND="$(command -v find)"
tl_stub find 'printf "\ndocs/x.md\n"'
drive gates.sh "build_doc_scheme_checklist_keys '$docroot'; printf '%s\n' \"\${DOC_SCHEME_CHECKLIST_KEYS[@]}\""
assert_contains "blank lines from find are skipped" "$TL_OUT" "docs/x.md"
assert_not_contains "no empty key is recorded" "$TL_OUT"$'\n' $'\n\n'
rm -f "$TL_BIN/find"
: "$REAL_FIND"

tl_run bash -c 'source "$1"; ca_collect_changed_paths() { printf " \n"; }; cmd_first_line=""; ca_detect_change_class "$2" ""; echo "$ca_change_class"' _ "$CA/change-class.sh" "$GITROOT"
assert_eq "whitespace-only path entries classify as mixed" "mixed" "$TL_OUT"

# jq succeeding for the enterprise check and failing for the gate's own read
REAL_JQ="$(command -v jq)"
export REAL_JQ
tl_stub jq 'if [[ "$*" == *evidence_schema.strict* ]]; then n=$(cat "$TL_TMP/jqcount" 2>/dev/null || echo 0); echo $((n+1)) >"$TL_TMP/jqcount"; if [[ "$n" -eq 0 ]]; then echo false; exit 0; fi; exit 1; fi; exec "$REAL_JQ" "$@"'
export TL_TMP
rm -f "$TL_TMP/jqcount"
evid '{}'
assert_contains "failing jq re-read after a non-strict profile answer defaults to strict" "$TL_OUT" "strict=1"
rm -f "$TL_BIN/jq"

# project gate refusing inside the enforcement-tier helper
mkdir -p "$TL_TMP/refuse-lib"
printf 'sb_project_is_initiated() { return 1; }\n' >"$TL_TMP/refuse-lib/sb-project-gate.sh"
tl_run bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$3"; config_file="$4"; emit_block() { echo "BLOCK: $1"; }; run_enforcement_tier_delivery_gate; echo "returned"' _ "$LIBDIR" "$CA" "$TL_TMP/refuse-lib" "$TL_TMP/tier-cfg.json"
assert_eq "uninitiated project: tier gate is a no-op" "returned" "$TL_OUT"

tl_results
