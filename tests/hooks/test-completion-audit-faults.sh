#!/usr/bin/env bash
# completion-audit: fault injection through a staged copy of hooks/ whose libraries are missing,
# partial or refusing (cert-bypass helper absent, tool-input lib absent, required-skills lacking
# the list normaliser, project gate refusing).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"
SKILLS="$TL_TMP/skills"
for s in inst-a inst-b; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done
STATE="$SB_RUNTIME_STATE_DIR/state-test"
QG="$SB_RUNTIME_STATE_DIR/quality-gate-test"
export SILVER_BULLET_STATE_FILE="$STATE" SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1 SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test" SILVER_BULLET_QUALITY_GATE_STATE_FILE="$QG"
printf 'verified\n' >"$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"

stage() {
  STG="$TL_TMP/$1"
  mkdir -p "$STG/templates"
  cp -R "$TL_REPO_ROOT/hooks" "$STG/hooks"
  cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$STG/templates/"
  HOOK="$STG/hooks/completion-audit.sh"
}
rename_fn() { sed -i "s/\\b$2\\b/zz_$2/g" "$1"; }
REAL_HOOK="$HOOK"
unstage() { HOOK="$REAL_HOOK"; }
COMMIT='git commit -m x'
PR='gh pr create --fill'
REL='gh release create v1'

# ── cert-bypass helper absent: the fallback predicate still bypasses ─────────
mkproj c1
stage s1
rename_fn "$STG/hooks/lib/hook-bootstrap.sh" sb_hook_exit_on_cert_run
run_ca PreToolUse "$PR" SB_AGENT_CERT_RUN=1
assert_eq "cert run bypasses via the predicate when the exit helper is missing" "none" "$(decision)"
assert_eq "bypass exits 0" 0 "$TL_STATUS"
run_ca PreToolUse "$COMMIT"
assert_eq "without the cert switch the gate still enforces" "deny" "$(decision)"
unstage

# ── tool-input lib absent: jq fallbacks give the same decisions ──────────────
mkproj c2
state inst-a
stage s2
rm -f "$STG/hooks/lib/tool-input.sh"
run_ca PreToolUse "$COMMIT"
assert_eq "no tool-input lib: planning satisfied is allowed" "allow" "$(decision)"
state ""
run_ca PreToolUse "$COMMIT"
assert_eq "no tool-input lib: missing planning is denied" "deny" "$(decision)"
run_ca PreToolUse 'ls -la'
assert_eq "no tool-input lib: other commands are ignored" "none" "$(decision)"
tl_run_stdin "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"x"}}')" bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "no tool-input lib: non-command tools are ignored" "" "$TL_OUT"
state inst-a inst-b
run_ca PreToolUse "$PR"
assert_eq "no tool-input lib: delivery with all skills is allowed" "allow" "$(decision)"
unstage

# ── required-skills without the list normaliser ──────────────────────────────
stage s3
rename_fn "$STG/hooks/lib/required-skills.sh" sb_required_skills_normalize_configured_list
mkproj c3
state ""
run_ca PreToolUse "$COMMIT"
assert_contains "configured planning list is used as is" "$(message)" "/inst-a"
mkproj c3b 'del(.skills.required_planning)'
state ""
run_ca PreToolUse "$COMMIT"
assert_contains "default planning list applies when none is configured" "$(message)" "/silver-quality-gates"
mkproj c3c
state inst-a
run_ca PreToolUse "$PR"
assert_contains "configured deploy list is used as is" "$(message)" "/inst-b"
mkproj c3d 'del(.skills.required_deploy)'
state inst-a
run_ca PreToolUse "$PR"
assert_contains "default deploy list applies when none is configured" "$(message)" "/silver-execute"
mkproj c3e '.skills.required_release=["inst-b"]'
state inst-a inst-b
run_ca PreToolUse "$REL"
assert_eq "configured release list satisfied: allowed" "allow" "$(decision)"
state inst-a
run_ca PreToolUse "$REL"
assert_contains "configured release list blocks when unmet" "$(message)" "/inst-b"
mkproj c3f
state inst-a inst-b
run_ca PreToolUse "$REL"
assert_contains "default release list applies when none is configured" "$(message)" "silver-create-release"
unstage

# ── project gate refusing ────────────────────────────────────────────────────
stage s4
printf 'sb_project_is_initiated() { return 1; }\n' >>"$STG/hooks/lib/sb-project-gate.sh"
mkproj c4
state ""
run_ca PreToolUse "$COMMIT"
assert_eq "project gate refusing: hook exits quietly" "none" "$(decision)"
assert_eq "exit status 0" 0 "$TL_STATUS"
unstage

tl_results
