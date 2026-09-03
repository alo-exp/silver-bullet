#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0 FAIL=0
TMP_HOME="$(mktemp -d)"; TMP_PROJECT="$(mktemp -d)"; trap 'rm -rf "$TMP_HOME" "$TMP_PROJECT"' EXIT
mkdir -p "$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0"
rsync -a "$REPO_ROOT/hooks/" "$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/"
echo '# SB' > "$TMP_PROJECT/silver-bullet.md"
cat > "$TMP_PROJECT/.silver-bullet.json" <<EOF
{"project":{"active_workflow":"full-dev-cycle"},"skills":{"required_planning":["silver-quality-gates"],"required_deploy":["silver-quality-gates"]},"state":{"state_file":"$TMP_HOME/.cursor/.silver-bullet/state"}}
EOF
git -C "$TMP_PROJECT" init -q
git -C "$TMP_PROJECT" config user.email "sb-test@example.com"
git -C "$TMP_PROJECT" config user.name "SB Test"
git -C "$TMP_PROJECT" add . && git -C "$TMP_PROJECT" commit -q -m init
out=$(env -u SILVER_BULLET_RUNTIME -u CODEX_CI -u CODEX_THREAD_ID \
  -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT \
  HOME="$TMP_HOME" bash -c 'source "$HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/lib/runtime-paths.sh"; printf "%s" "$SILVER_BULLET_RUNTIME"')
[[ "$out" == cursor ]] && { echo "  PASS: infers cursor"; PASS=$((PASS+1)); } || { echo "  FAIL: runtime $out"; FAIL=$((FAIL+1)); }
(
  cd "$TMP_PROJECT"
  printf '%s' '{"hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"}}' | \
    env -u SILVER_BULLET_RUNTIME -u CODEX_CI -u CODEX_THREAD_ID \
    -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT \
    HOME="$TMP_HOME" SILVER_BULLET_STATE_FILE="$TMP_HOME/.cursor/.silver-bullet/state" \
    bash "$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/record-skill.sh" >/dev/null
)
grep -Fqx silver-quality-gates "$TMP_HOME/.cursor/.silver-bullet/state" && { echo "  PASS: record-skill"; PASS=$((PASS+1)); } || { echo "  FAIL: record-skill"; FAIL=$((FAIL+1)); }
echo; echo "Passed: $PASS"; echo "Failed: $FAIL"; [[ "$FAIL" -eq 0 ]]
