#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME_PATHS="${REPO_ROOT}/hooks/lib/runtime-paths.sh"
PASS=0 FAIL=0
assert_eq() { [[ "$3" == "$2" ]] && { echo "  PASS: $1"; PASS=$((PASS+1)); } || { echo "  FAIL: $1 — expected '$2', got '$3'"; FAIL=$((FAIL+1)); }; }
echo "=== runtime-paths tests ==="
TMP_HOME="$(mktemp -d)"; trap 'rm -rf "$TMP_HOME"' EXIT
for runtime in claude codex cursor; do
  out=$(env -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_PRESERVE_STATE_DIR -u SB_RUNTIME_STATE_DIR SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" bash -c "source '$RUNTIME_PATHS'; printf '%s|%s' \"\$SILVER_BULLET_RUNTIME\" \"\$SB_RUNTIME_STATE_DIR\"")
  assert_eq "explicit $runtime" "${runtime}|${TMP_HOME}/.${runtime}/.silver-bullet" "$out"
done
mkdir -p "$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/lib"
cp "$RUNTIME_PATHS" "$TMP_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/lib/runtime-paths.sh"
out=$(env -u SILVER_BULLET_RUNTIME -u SB_RUNTIME_PRESERVE_STATE_DIR -u SB_RUNTIME_STATE_DIR \
  -u CODEX_CI -u CODEX_THREAD_ID -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE \
  -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT \
  HOME="$TMP_HOME" bash -c 'source "'"$TMP_HOME"'/.cursor/plugins/cache/alo-labs/silver-bullet/0.0.0/hooks/lib/runtime-paths.sh"; printf "%s|%s" "$SILVER_BULLET_RUNTIME" "$SB_RUNTIME_STATE_DIR"')
assert_eq "infers cursor from path" "cursor|${TMP_HOME}/.cursor/.silver-bullet" "$out"
echo; echo "Passed: $PASS"; echo "Failed: $FAIL"; [[ "$FAIL" -eq 0 ]]
