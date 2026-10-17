#!/usr/bin/env bash
# dev-cycle-check: config validation, shell write detection, PostToolUse invalidation, workflow admission.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

# ── config validation ────────────────────────────────────────────────────────
mkproj cfgpat '.project.src_pattern="lib"'
state ""
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "src_pattern without a leading slash falls back to /src/" "none" "$(decision)"
mkproj cfgpat2 '.project.src_pattern="/"'
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "over-broad src_pattern falls back to /src/" "none" "$(decision)"
mkproj cfgpat3 '.project.src_pattern="/lib/"'
run_dc "$(edit_json "$PROJ/lib/x.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "valid custom src_pattern is honoured" "deny" "$(decision)"
LONG="$(printf 'a%.0s' {1..250})"
mkproj cfgex ".project.src_exclude_pattern=\"$LONG\""
run_dc "$(edit_json "$PROJ/src/app.test.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "over-long exclude pattern falls back to the default" "none" "$(decision)"
mkproj cfgex2 '.project.src_exclude_pattern="a b;c"'
run_dc "$(edit_json "$PROJ/src/app.test.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "unsafe exclude pattern falls back to the default" "none" "$(decision)"
mkproj cfgraw
printf '{ not json' >"$PROJ/.silver-bullet.json"
state inst-a
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "unreadable config falls back to defaults without crashing" "0" "$TL_STATUS"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
RUN_DIR="$NOCFG" run_dc "$(edit_json "$NOCFG/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "no project config: hook still exits cleanly" "0" "$TL_STATUS"
unset RUN_DIR

# ── shell commands ───────────────────────────────────────────────────────────
mkproj shell
state inst-a
dc_cmd 'echo hi'
assert_eq "plain read-only command is ignored" "none" "$(decision)"
dc_cmd 'scripts/silver-bullet invoke-skill silver-plan'
assert_eq "skill adapter invocation is ignored" "none" "$(decision)"
dc_cmd 'echo x > notes/out.txt'
assert_eq "write outside src is ignored" "none" "$(decision)"
dc_cmd 'echo x > src/app.js'
assert_contains "write into src passes the planning gate with an advisory" "$(message)" "Planning verified"
assert_contains "logic write with no composed workflow gets the F-06 advisory" "$(message)" "WORKFLOW ADVISORY"
dc_cmd 'echo x > src/data.json'
assert_contains "non-logic shell write is skipped" "$(message)" "Non-logic file"
dc_cmd 'cp $SRC /src/$DEST'
assert_contains "opaque write mentioning src falls back to scope matching" "$(message)" "Planning verified"
dc_cmd 'cp $SRC /lib/$DEST'
assert_eq "opaque write outside src is ignored" "none" "$(decision)"
dc_cmd 'cp $SRC /src/a.test.js$DEST'
assert_eq "opaque write to an excluded path is ignored" "none" "$(decision)"
dc_cmd 'ls /src/$DIR'
assert_eq "opaque read-only listing is ignored" "none" "$(decision)"
dc_cmd 'git status && echo src/ done'
assert_eq "command without write intent is ignored" "none" "$(decision)"
state ""
dc_cmd 'echo x > src/app.js'
assert_eq "shell write into src is gated without planning" "deny" "$(decision)"

# scripts invoked by the command
state inst-a
printf '#!/usr/bin/env bash\ncat src/app.js\n' >"$PROJ/check.sh"
dc_cmd 'bash check.sh'
assert_eq "read-only script body is ignored" "none" "$(decision)"
printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/gen.sh"
dc_cmd 'bash gen.sh'
assert_contains "script that writes into src is gated" "$(message)" "Planning verified"
printf '#!/usr/bin/env bash\ncp "$1" "$2"\n' >"$PROJ/opaque.sh"
dc_cmd 'bash opaque.sh /src/a'
# Characterisation: write intent is judged from the command text, not from the script body.
assert_eq "opaque script body without write intent in the command is ignored" "none" "$(decision)"
dc_cmd 'bash opaque.sh /src/a > /dev/null && cp x /src/$Y'
assert_contains "command text with opaque write intent is gated" "$(message)" "Planning verified"

# PostToolUse invalidates the fresh-test marker only for real source writes
mkproj post
state inst-a silver-review silver-branch-finish
VT="$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
printf 'v\n' >"$VT"
run_dc "$(edit_json "$PROJ/src/app.js" Write PostToolUse "$BIG_OLD" "$BIG_NEW")"
assert_file_absent "Write PostToolUse invalidates the test marker" "$VT"
printf 'v\n' >"$VT"
run_dc "$(edit_json "$PROJ/src/app.js" Read PostToolUse)"
assert_file_exists "Read PostToolUse keeps the test marker" "$VT"
dc_cmd 'echo x > src/app.js' PostToolUse
assert_file_absent "shell write into src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'cp $A /src/$B' PostToolUse
assert_file_absent "opaque cp into src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'sed -i s/a/b/ $F /src/' PostToolUse
assert_file_absent "opaque sed -i on src invalidates the marker" "$VT"
printf 'v\n' >"$VT"
dc_cmd 'echo x > notes/out.txt' PostToolUse
assert_file_exists "write outside src keeps the marker" "$VT"

# devops shell non-logic handling
mkproj devshell '.project.active_workflow="devops-cycle" | .skills.required_planning_devops=["inst-a"]'
state inst-a
dc_cmd 'echo x > src/notes.md'
assert_contains "devops: markdown shell write is non-logic" "$(message)" "Non-logic file"
dc_cmd 'echo x > src/stack.yaml'
assert_contains "devops: yaml shell write is logic" "$(message)" "Planning verified"

# ── composed workflow admission ──────────────────────────────────────────────
WF=20260101T000000Z-abc123-silver-feature
mkproj adm
state inst-a
mkdir -p "$PROJ/.planning/workflows"
printf '## Flow Log\n| 1 | a | pending |\n' >"$PROJ/.planning/workflows/$WF.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "active workflow without SB_WORKFLOW_ID blocks" "$(message)" "SB_WORKFLOW_ID is unset"
assert_contains "block lists the workflow" "$(message)" "• $WF"
printf '## Flow Log\n| 1 | a | pending |\n' >"$PROJ/.planning/workflows/20260101T000000Z-def456-silver-bugfix.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "block lists every active workflow" "$(message)" "• 20260101T000000Z-def456-silver-bugfix"
rm -f "$PROJ/.planning/workflows/20260101T000000Z-def456-silver-bugfix.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=BAD
assert_contains "malformed id blocks" "$(message)" "invalid format: BAD"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=20260101T000000Z-zzz999-silver-feature
assert_contains "unknown id blocks" "$(message)" "no active workflow file matches"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID="$WF"
assert_contains "matching id admits the edit" "$(message)" "Planning verified"
dc_cmd "export SB_WORKFLOW_ID=$WF; echo x > src/app.js"
assert_contains "id taken from an export assignment" "$(message)" "Planning verified"
dc_cmd "env SB_WORKFLOW_ID=$WF echo x > src/app.js"
assert_contains "id taken from an env prefix" "$(message)" "Planning verified"
dc_cmd "SB_WORKFLOW_ID=BAD-ID echo x > src/app.js"
assert_contains "malformed id in the command blocks" "$(message)" "invalid format"
dc_cmd 'FOO=1 echo x > src/app.js'
assert_contains "no id anywhere in the command blocks" "$(message)" "SB_WORKFLOW_ID is unset"
dc_cmd "echo x > src/app.js" PostToolUse
assert_not_contains "admission is a PreToolUse check" "$(message)" "WORKFLOW ADMISSION"
ln -s "$PROJ/.planning/workflows/$WF.md" "$PROJ/.planning/workflows/20260101T000000Z-lnk123-silver-feature.md"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SB_WORKFLOW_ID=20260101T000000Z-lnk123-silver-feature
assert_contains "symlinked workflow file is not accepted" "$(message)" "no active workflow file matches"


tl_results
