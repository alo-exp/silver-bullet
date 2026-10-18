#!/usr/bin/env bash
# Wrapper-style scripts: rfl-assert-advance, post-release-refresh,
# sb-migrate-orchestrator-parent, run-apo-authoring-compliance,
# dogfood-orchestrator-parent-surface. Each runs from a temp copy of the tree.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"

# --- rfl-assert-advance.sh -------------------------------------------------
T="$TL_TMP/rfl"
mkdir -p "$T/scripts"
cp "$R/scripts/rfl-assert-advance.sh" "$T/scripts/"
cat >"$T/scripts/review-fix-ladder.py" <<'EOF'
import sys
print("ARGS:" + "|".join(sys.argv[1:]))
sys.exit(3)
EOF
tl_run bash "$T/scripts/rfl-assert-advance.sh" --run abc
assert_eq "rfl wrapper propagates resolver exit code" 3 "$TL_STATUS"
assert_contains "rfl wrapper passes flag then args" "$TL_OUT" "ARGS:--assert-rfl-advance|--run|abc"

# --- post-release-refresh.sh ----------------------------------------------
tl_run env SB_POST_RELEASE_VERIFY_SCRIPT="$TL_TMP/nope.sh" bash "$R/scripts/post-release-refresh.sh"
assert_eq "refresh fails when verify script missing" 1 "$TL_STATUS"
assert_contains "refresh names the missing script" "$TL_ERR" "post-release verify script missing at $TL_TMP/nope.sh"

printf '#!/usr/bin/env bash\necho "VERIFY:$*"; exit 4\n' >"$TL_TMP/verify.sh"
tl_run env SB_POST_RELEASE_VERIFY_SCRIPT="$TL_TMP/verify.sh" bash "$R/scripts/post-release-refresh.sh" --x y
assert_eq "refresh exec propagates exit" 4 "$TL_STATUS"
assert_contains "refresh announces delegation" "$TL_OUT" "[post-release-refresh] Delegating"
assert_contains "refresh forwards args" "$TL_OUT" "VERIFY:--x y"

# --- sb-migrate-orchestrator-parent.sh --------------------------------------
PL="$TL_TMP/plugin"
mkdir -p "$PL/templates/orchestrator-workers" "$PL/scripts/lib/install-cursor/templates/cursor-rules"
echo worker >"$PL/templates/orchestrator-workers/w.md"
echo rule >"$PL/scripts/lib/install-cursor/templates/cursor-rules/silver-orchestrator.mdc"

P="$TL_TMP/proj"
mkdir -p "$P/.git" "$P/sub/deeper"
echo '{"a":1}' >"$P/.silver-bullet.json"
echo md >"$P/silver-bullet.md"
tl_run env PLUGIN_ROOT="$PL" bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$P/sub/deeper"
assert_eq "migrate parent ok" 0 "$TL_STATUS"
assert_contains "reports prior mode absent" "$TL_OUT" "Set orchestrator_mode=parent (was: absent)"
assert_eq "config rewritten" '{"a":1,"orchestrator_mode":"parent"}' "$(jq -c . "$P/.silver-bullet.json")"
assert_eq "worker templates copied" worker "$(cat "$P/.silver-bullet/orchestrator-workers/w.md")"
assert_eq "cursor rule copied" rule "$(cat "$P/.cursor/rules/silver-orchestrator.mdc")"
assert_contains "mentions templates" "$TL_OUT" "Copied worker templates"
assert_contains "mentions rule" "$TL_OUT" "Refreshed .cursor/rules/silver-orchestrator.mdc"
assert_contains "completion line" "$TL_OUT" "Migration complete for $P"
# second run reports old mode
tl_run env PLUGIN_ROOT="$PL" bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$P"
assert_contains "reports prior mode parent" "$TL_OUT" "(was: parent)"

# no templates in plugin root -> skip copies
PL2="$TL_TMP/plugin-empty"
mkdir -p "$PL2"
P2="$TL_TMP/proj2"
mkdir -p "$P2"
echo '{}' >"$P2/.silver-bullet.json"
echo md >"$P2/silver-bullet.md"
tl_run env PLUGIN_ROOT="$PL2" bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$P2"
assert_eq "migrate without templates ok" 0 "$TL_STATUS"
assert_not_contains "no template copy message" "$TL_OUT" "Copied worker templates"
assert_not_contains "no rule refresh message" "$TL_OUT" "Refreshed .cursor"
assert_file_absent "no rule file" "$P2/.cursor/rules/silver-orchestrator.mdc"

# no project found: stops at a .git dir
P3="$TL_TMP/nop"
mkdir -p "$P3/.git"
tl_run bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$P3"
assert_eq "no project -> exit 1" 1 "$TL_STATUS"
assert_contains "no project message" "$TL_ERR" "No SB project found"
# walking up to / without .git
mkdir -p "$TL_TMP/nogit/x"
tl_run bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$TL_TMP/nogit/x"
assert_eq "no project, no git -> exit 1" 1 "$TL_STATUS"

# jq missing
NOJQ="$(tl_path_without jq)"
tl_run env PATH="$NOJQ" PLUGIN_ROOT="$PL" bash "$R/scripts/sb-migrate-orchestrator-parent.sh" "$P"
assert_eq "jq missing -> exit 1" 1 "$TL_STATUS"
assert_contains "jq required message" "$TL_ERR" "jq required"

# --- run-apo-authoring-compliance.sh ---------------------------------------
A="$TL_TMP/apo"
mkdir -p "$A/scripts" "$A/tests/scripts"
cp "$R/scripts/run-apo-authoring-compliance.sh" "$A/scripts/"
printf '#!/usr/bin/env bash\necho "stub generator $*"\n' >"$A/scripts/generate-apo-artifacts.py"
# python3 on the stub path runs the .py; make it valid Python
printf 'import sys\nprint("gen", sys.argv[1:])\n' >"$A/scripts/generate-apo-artifacts.py"
while read -r t; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$A/tests/scripts/$t"
done < <(grep -o 'bash tests/scripts/[^"]*' "$R/scripts/run-apo-authoring-compliance.sh" | sed 's#bash tests/scripts/##')
tl_run bash "$A/scripts/run-apo-authoring-compliance.sh"
assert_eq "apo all pass -> exit 0" 0 "$TL_STATUS"
assert_contains "apo summary pass" "$TL_OUT" "PASS: 26 / 26"
assert_contains "apo summary fail zero" "$TL_OUT" "FAIL: 0 / 26"
assert_contains "apo ran generator check" "$TL_OUT" "gen ['--check']"

printf '#!/usr/bin/env bash\nexit 1\n' >"$A/tests/scripts/test-router-coverage.sh"
rm "$A/tests/scripts/test-triple-alignment.sh"   # missing test file also fails
tl_run bash "$A/scripts/run-apo-authoring-compliance.sh"
assert_eq "apo failure -> exit 1" 1 "$TL_STATUS"
assert_contains "apo counts failures" "$TL_OUT" "FAIL: 2 / 26"
assert_contains "apo lists failed check" "$TL_OUT" "  - router-coverage"
assert_contains "apo lists missing check" "$TL_OUT" "  - triple-alignment"
assert_contains "apo failure on stderr" "$TL_ERR" "FAILED: router-coverage"

# --- dogfood-orchestrator-parent-surface.sh ---------------------------------
D="$TL_TMP/dog"
mkdir -p "$D/scripts" "$D/hooks" "$D/tests/hooks"
cp "$R/scripts/dogfood-orchestrator-parent-surface.sh" "$D/scripts/"
printf '#!/usr/bin/env bash\necho "MIGRATE:$1"\n' >"$D/scripts/sb-migrate-orchestrator-parent.sh"
# record-skill stub only records half of the skills, so the script's fallback append is exercised
cat >"$D/hooks/record-skill.sh" <<'EOF'
#!/usr/bin/env bash
s="$(jq -r .tool_input.skill)"
case "$s" in silver-plan|tdd) ;; *) echo "$s" >>"$SILVER_BULLET_STATE_FILE" ;; esac
EOF
for t in orchestrator-parent-guard orchestrator-directive orchestrator-worker-handoff outcomes-check; do
  printf '#!/usr/bin/env bash\necho "stub %s"\necho "Results: 1 passed, 0 failed"\n' "$t" >"$D/tests/hooks/test-$t.sh"
done
APP="$TL_TMP/app"
mkdir -p "$APP/.planning/phases/08-v5-full-surface" "$APP/.planning/workflows/.archive"
touch "$APP/.planning/phases/08-v5-full-surface/PLAN.md" "$APP/.planning/phases/08-v5-full-surface/REVIEW.md" "$APP/.planning/orchestrator-composition-log.jsonl"
tl_stub npm 'echo "tests 5 passed"'
STATE_DIR="$TL_TMP/dogstate"
tl_run env SB_RUNTIME_STATE_DIR="$STATE_DIR" bash "$D/scripts/dogfood-orchestrator-parent-surface.sh" "$APP" testhost
assert_eq "dogfood ok" 0 "$TL_STATUS"
assert_contains "dogfood label" "$TL_OUT" "=== Orchestrator parent surface dogfood (testhost) ==="
assert_contains "dogfood migrate arg" "$TL_OUT" "MIGRATE:$APP"
assert_contains "dogfood skills count" "$TL_OUT" "PASS: lifecycle skills recorded (15 lines)"
assert_contains "dogfood fallback appended skill" "$(cat "$STATE_DIR/state")" "silver-plan"
assert_contains "dogfood npm line" "$TL_OUT" "PASS: enterprise-grade-test-app npm test (tests 5 passed)"
assert_contains "dogfood artifact present" "$TL_OUT" "PASS: artifact .planning/phases/08-v5-full-surface/PLAN.md"
assert_contains "dogfood artifact missing" "$TL_OUT" "FAIL: missing .planning/phases/08-v5-full-surface/VERIFICATION.md"
assert_contains "dogfood archive present" "$TL_OUT" "PASS: workflow archive present"
assert_contains "dogfood complete" "$TL_OUT" "=== testhost surface dogfood complete ==="
assert_eq "dogfood outcomes cleared" '{"prompts":{}}' "$(cat "$STATE_DIR/outcomes-session.json")"
assert_contains "dogfood test tails" "$TL_OUT" "Results: 1 passed, 0 failed"

rmdir "$APP/.planning/workflows/.archive"
tl_run env SB_RUNTIME_STATE_DIR="$STATE_DIR" SILVER_BULLET_STATE_FILE="$STATE_DIR/alt-state" bash "$D/scripts/dogfood-orchestrator-parent-surface.sh" "$APP"
assert_contains "dogfood archive missing" "$TL_OUT" "FAIL: workflow archive missing"
assert_contains "dogfood default label" "$TL_OUT" "(cursor)"
assert_file_exists "dogfood honours SILVER_BULLET_STATE_FILE" "$STATE_DIR/alt-state"

tl_results
