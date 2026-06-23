#!/usr/bin/env bash
# Regression tests for Kay project hook bridge (KAY-01).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="${REPO_ROOT}/hooks/kay-project-hook-bridge.sh"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — expected [$expected], got [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_deny_reason() {
  local label="$1" haystack="$2"
  if printf '%s' "$haystack" | grep -qE 'Planning incomplete|HARD STOP|ORCHESTRATOR PARENT|forbidden|blocked'; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — expected a planning/parent denial reason"
    echo "  output: $(printf '%s' "$haystack" | head -c 400)"
    FAIL=$((FAIL + 1))
  fi
}

capture_digest() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || echo ""
}

run_bridge() {
  local work_dir="$1" event="$2" call_id="$3" payload="$4"
  local home_root="$5"
  local plugin_root="$6"
  local status=0
  local output

  output="$(
    cd "$work_dir" && \
      HOME="$home_root" \
      KAY_HOME="$home_root" \
      SILVER_BULLET_RUNTIME=codex \
      SILVER_BULLET_STATE_FILE="${home_root}/.codex/.silver-bullet/state" \
      CLAUDE_PLUGIN_ROOT="$plugin_root" \
      CODE_HOOK_EVENT="$event" \
      CODE_HOOK_SOURCE_CALL_ID="$call_id" \
      CODE_HOOK_PAYLOAD="$payload" \
      bash "$BRIDGE" </dev/null 2>&1
  )" || status=$?
  printf '%s\n' "$status"
  printf '%s' "$output"
}

TMP="$(mktemp -d)"
cleanup_tmp() {
  if [[ -d "$TMP" ]]; then
    chflags -R nouchg "$TMP" 2>/dev/null || true
    chmod -R u+w "$TMP" 2>/dev/null || true
    rm -rf "$TMP"
  fi
}
trap cleanup_tmp EXIT

WORK="$TMP/workspace"
HOME_ROOT="$TMP/kay-home"
PLUGIN_ROOT="$REPO_ROOT"
TARGET="$WORK/src/routes/todos.js"
STATE_DIR="${HOME_ROOT}/.codex/.silver-bullet"
ACTIVE_SHIM="${HOME_ROOT}/.kay/.silver-bullet/path-prepend/active"

mkdir -p "$(dirname "$TARGET")" "$STATE_DIR" "$ACTIVE_SHIM"
cat > "$TARGET" <<'EOF'
export const todos = [];
EOF
cat > "$WORK/.silver-bullet.json" <<EOF
{
  "sb_initiated": true,
  "project": {
    "name": "kay-bridge-test",
    "src_pattern": "/src/",
    "active_workflow": "full-dev-cycle"
  },
  "skills": {
    "required_planning": ["silver-quality-gates"]
  },
  "state": {
    "state_file": "${STATE_DIR}/state"
  }
}
EOF
printf '# Kay bridge test\n' >"$WORK/silver-bullet.md"
git -C "$WORK" init -q
git -C "$WORK" config user.email "bridge@test"
git -C "$WORK" config user.name "Bridge Test"
git -C "$WORK" add -A
git -C "$WORK" commit -q -m "baseline"
: >"${STATE_DIR}/state"

# KAY-01 probe: exec_command-style payload (Kay native) must deny before planning.
probe_command='bash -lc "printf '"'"'\n// kay bridge regression probe\n'"'"' >> src/routes/todos.js"'
exec_payload="$(jq -nc --arg cmd "$probe_command" '{tool_name:"exec_command",command:["bash","-lc",$cmd]}')"
digest_before="$(capture_digest "$TARGET")"
status_and_output="$(run_bridge "$WORK" "tool.before" "kay01-exec-probe" "$exec_payload" "$HOME_ROOT" "$PLUGIN_ROOT")"
bridge_status="${status_and_output%%$'\n'*}"
bridge_output="${status_and_output#*$'\n'}"
assert_eq "exec_command tool.before returns native deny status" "2" "$bridge_status"
assert_deny_reason "exec_command tool.before surfaces planning denial" "$bridge_output"
digest_after="$(capture_digest "$TARGET")"
assert_eq "exec_command tool.before keeps target unchanged" "$digest_before" "$digest_after"

# file.before_write path must also deny direct writes.
file_payload="$(jq -nc --arg path "$TARGET" '{changes:[{path:$path}]}')"
digest_before="$(capture_digest "$TARGET")"
status_and_output="$(run_bridge "$WORK" "file.before_write" "kay01-file-probe" "$file_payload" "$HOME_ROOT" "$PLUGIN_ROOT")"
bridge_status="${status_and_output%%$'\n'*}"
bridge_output="${status_and_output#*$'\n'}"
assert_eq "file.before_write returns native deny status" "2" "$bridge_status"
assert_deny_reason "file.before_write surfaces planning denial" "$bridge_output"
digest_after="$(capture_digest "$TARGET")"
assert_eq "file.before_write keeps target unchanged" "$digest_before" "$digest_after"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
