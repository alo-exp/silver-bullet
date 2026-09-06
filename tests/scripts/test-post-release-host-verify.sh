#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if grep -F -- "$needle" >/dev/null <<<"$haystack"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/post-release-host-verify.sh"
UNINSTALL_LIB="$REPO_ROOT/scripts/lib/post-release-uninstall.sh"
STRIP_PY="$REPO_ROOT/scripts/lib/strip-cursor-sb-hooks.py"
REFRESH_SCRIPT="$REPO_ROOT/scripts/post-release-refresh.sh"
RELEASE_SKILL="$REPO_ROOT/skills/silver-create-release/SKILL.md"
GATE_DOC="$REPO_ROOT/docs/internal/pre-release-quality-gate.md"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

verify_body="$(<"$VERIFY_SCRIPT")"
uninstall_body="$(<"$UNINSTALL_LIB")"
refresh_body="$(<"$REFRESH_SCRIPT")"
skill_body="$(<"$RELEASE_SKILL")"
gate_body="$(<"$GATE_DOC")"

echo "--- post-release-host-verify.sh wiring ---"
assert_contains "verify script exists" "post-release-host-verify" "$verify_body"
assert_contains "verify sources uninstall lib" "post-release-uninstall.sh" "$verify_body"
assert_contains "verify sources isolation helper" "pre-release-host-isolation.sh" "$verify_body"
assert_contains "verify writes per-host post-release-verify markers" "marker_dir_for_host" "$verify_body"
assert_contains "verify runs sb-diagnostics smoke" "sb-diagnostics.sh" "$verify_body"
assert_contains "verify runs RC fresh cell" "run-rc-validation-matrix.sh" "$verify_body"
assert_contains "verify supports --host filter" "--host" "$verify_body"
assert_contains "verify supports --version" "--version" "$verify_body"
assert_contains "verify uses RTK_DISABLED" "RTK_DISABLED=1" "$verify_body"

echo "--- post-release-uninstall.sh wiring ---"
assert_contains "uninstall lib defines cursor uninstall" "sb_post_release_uninstall_cursor" "$uninstall_body"
assert_contains "uninstall lib defines codex uninstall" "sb_post_release_uninstall_codex" "$uninstall_body"
assert_contains "uninstall lib defines claude uninstall" "sb_post_release_uninstall_claude" "$uninstall_body"
assert_contains "cursor uninstall strips hooks" "strip-cursor-sb-hooks.py" "$uninstall_body"
assert_contains "codex uninstall purges SB hooks" "purge_legacy_silver_bullet_hooks_from_user_config" "$uninstall_body"

echo "--- strip-cursor-sb-hooks.py ---"
[[ -f "$STRIP_PY" ]] && echo "PASS: strip-cursor-sb-hooks.py exists" && (( PASS++ )) || { echo "FAIL: strip script missing"; (( FAIL++ )) || true; }

echo "--- post-release-refresh.sh delegates ---"
assert_contains "refresh delegates to host verify" "post-release-host-verify.sh" "$refresh_body"

echo "--- silver-create-release SKILL ---"
assert_contains "skill allows post-release-host-verify" "post-release-host-verify.sh" "$skill_body"
assert_contains "skill documents mandatory post-release verify" "Mandatory post-release" "$skill_body"

echo "--- pre-release-quality-gate Stage 5 ---"
assert_contains "gate doc has Stage 5 post-release" "Stage 5" "$gate_body"
assert_contains "gate doc references post-release-host-verify" "post-release-host-verify.sh" "$gate_body"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
