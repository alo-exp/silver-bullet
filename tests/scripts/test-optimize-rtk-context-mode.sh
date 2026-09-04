#!/usr/bin/env bash
# Fixture-based tests for optimize-rtk-context-mode.sh and merge helper.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TEST_HOME="$(mktemp -d)"
GLOBAL_BIN="$(mktemp -d)"
GLOBAL_BIN_REAL="$(cd "$GLOBAL_BIN" && pwd -P)"
trap 'rm -rf "$TEST_HOME" "$GLOBAL_BIN"' EXIT

export HOME="$TEST_HOME"
mkdir -p "$TEST_HOME/.cursor" "$TEST_HOME/.codex" "$TEST_HOME/.config/opencode" "$TEST_HOME/.hermes"
printf '#!/usr/bin/env bash\nexit 0\n' >"$GLOBAL_BIN/context-mode"
chmod +x "$GLOBAL_BIN/context-mode"
export PATH="$GLOBAL_BIN:$PATH"
export SB_GLOBAL_CONTEXT_MODE_COMMAND="$GLOBAL_BIN_REAL/context-mode"

echo "=== optimize-rtk-context-mode tests ==="

# 1. Script exists and is executable
if [[ -x "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" ]]; then
  pass "optimize script executable"
else
  fail "optimize script executable"
fi

# 2. Global installer exists
if [[ -x "$REPO_ROOT/scripts/install-recommended-tools-global.sh" ]]; then
  pass "global installer executable"
else
  fail "global installer executable"
fi

# 3. rtk-cm-global lib present
[[ -f "$REPO_ROOT/hooks/lib/rtk-cm-global.sh" ]] && pass "rtk-cm-global.sh present" || fail "rtk-cm-global.sh present"

# 4. Host metadata JSON valid
jq -e '.hosts.claude.status == "supported"' "$REPO_ROOT/scripts/lib/rtk-cm-hosts.json" >/dev/null \
  && pass "rtk-cm-hosts.json valid" || fail "rtk-cm-hosts.json valid"
jq -e '.hosts.goose.status == "unsupported"' "$REPO_ROOT/scripts/lib/rtk-cm-hosts.json" >/dev/null \
  && pass "goose marked unsupported" || fail "goose marked unsupported"
jq -e '.hosts.hermes.status == "partial"' "$REPO_ROOT/scripts/lib/rtk-cm-hosts.json" >/dev/null \
  && pass "hermes marked partial" || fail "hermes marked partial"

# 5. Dry-run cursor completes
if bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host cursor --project-root "$REPO_ROOT" --dry-run --skip-rtk-init --skip-cm-doctor >/dev/null 2>&1; then
  pass "cursor dry-run exits 0"
else
  fail "cursor dry-run exits 0"
fi

# 6. Dry-run all hosts (including goose skip)
all_out="$(bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host all --project-root "$REPO_ROOT" --dry-run --skip-rtk-init --skip-cm-doctor 2>&1 || true)"
if grep -F 'SKIP: goose' <<<"$all_out" >/dev/null; then
  pass "all dry-run skips goose"
else
  fail "all dry-run skips goose"
fi

for host in opencode hermes codex claude; do
  if bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host "$host" --project-root "$REPO_ROOT" --dry-run --skip-rtk-init --skip-cm-doctor >/dev/null 2>&1; then
    pass "${host} dry-run exits 0"
  else
    fail "${host} dry-run exits 0"
  fi
done

# 7. Merge helper adds CM hooks idempotently (cursor)
python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" \
  --host cursor --repo-root "$REPO_ROOT" >/dev/null

if grep -q 'context-mode hook cursor pretooluse' "$TEST_HOME/.cursor/hooks.json" 2>/dev/null; then
  pass "merge adds context-mode pretooluse hook"
else
  fail "merge adds context-mode pretooluse hook"
fi

# Claude must use the same manifest-selected global Context Mode executable as
# the other supported host adapters, even when a native plugin cache exists.
mkdir -p "$TEST_HOME/.claude/plugins/cache/context-mode/context-mode"
printf '{"enabledPlugins":{"context-mode@context-mode":true}}\n' >"$TEST_HOME/.claude/settings.json"
export CLAUDE_DISABLE_MARKER="$TEST_HOME/claude-context-mode-disabled"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "plugin" && "${2:-}" == "disable" ]]; then : >"$CLAUDE_DISABLE_MARKER"; fi\n' >"$GLOBAL_BIN/claude"
chmod +x "$GLOBAL_BIN/claude"
if bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" \
  --host claude --project-root "$REPO_ROOT" --skip-rtk-init --skip-cm-doctor >/dev/null 2>&1; then
  pass "claude optimizer disables native plugin"
else
  fail "claude optimizer disables native plugin"
fi
if [[ -f "$CLAUDE_DISABLE_MARKER" ]] && jq -e --arg command "$GLOBAL_BIN_REAL/context-mode" \
  '.mcpServers["context-mode"].command == $command and .mcpServers["context-mode"].args == []' \
  "$TEST_HOME/.claude.json" >/dev/null; then
  pass "claude optimizer uses shared Context Mode executable"
else
  fail "claude optimizer uses shared Context Mode executable"
fi
python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" \
  --host claude --repo-root "$REPO_ROOT" >/dev/null
if jq -e --arg command "$GLOBAL_BIN_REAL/context-mode" \
  '.mcpServers["context-mode"].command == $command and .mcpServers["context-mode"].args == []' \
  "$TEST_HOME/.claude.json" >/dev/null; then
  pass "claude fallback uses shared global Context Mode executable"
else
  fail "claude fallback uses shared global Context Mode executable"
fi

python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" \
  --host cursor --repo-root "$REPO_ROOT" >/dev/null
count="$(grep -c 'context-mode hook cursor pretooluse' "$TEST_HOME/.cursor/hooks.json" || true)"
[[ "$count" -eq 1 ]] && pass "merge is idempotent (no duplicate pretooluse)" || fail "merge is idempotent (no duplicate pretooluse)"

# Vendor RTK initialization can leave the legacy LeanCTX rewrite hook behind;
# the optimizer must canonicalize that surface back to the shared RTK hook.
printf '#!/usr/bin/env bash\ncase "${1:-}" in\n  gain) [[ "${2:-}" == "--help" ]] && exit 0 ;;\n  --help) printf "rtk test-stub\\n"; exit 0 ;;\n  init) printf '\''{"hooks":{"preToolUse":[{"command":"lean-ctx hook rewrite","matcher":"Shell"}]}}\\n'\'' >"$HOME/.cursor/hooks.json"; exit 0 ;;\nesac\nexit 0\n' >"$GLOBAL_BIN/rtk"
chmod +x "$GLOBAL_BIN/rtk"
printf '{"hooks":{"preToolUse":[{"command":"lean-ctx hook rewrite","matcher":"Shell"}]}}\n' >"$TEST_HOME/.cursor/hooks.json"
if TOOLSTACK_INSTALL_IN_PROGRESS=1 bash "$REPO_ROOT/scripts/optimize-rtk-context-mode.sh" \
  --host cursor --project-root "$REPO_ROOT" --skip-cm-doctor >/dev/null 2>&1; then
  if ! grep -F 'lean-ctx hook rewrite' "$TEST_HOME/.cursor/hooks.json" >/dev/null \
    && grep -F 'rtk hook cursor' "$TEST_HOME/.cursor/hooks.json" >/dev/null; then
    pass "cursor optimizer removes legacy LeanCTX rewrite hook"
  else
    fail "cursor optimizer removes legacy LeanCTX rewrite hook"
  fi
else
  fail "cursor optimizer canonicalizes vendor hook output"
fi

# 8. Allow-list merge
if [[ -f "$TEST_HOME/.cursor/cli-config.json" ]]; then
  allow_count="$(jq '.permissions.allow | length' "$TEST_HOME/.cursor/cli-config.json")"
  [[ "$allow_count" -ge 50 ]] && pass "cli-config allow-list merged ($allow_count entries)" || fail "cli-config allow-list merged"
else
  fail "cli-config created"
fi

# 9. OpenCode merge
python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" --host opencode --repo-root "$REPO_ROOT" >/dev/null
jq -e '.mcp["context-mode"]' "$TEST_HOME/.config/opencode/opencode.json" >/dev/null \
  && pass "opencode MCP merged" || fail "opencode MCP merged"
jq -e '.plugin[]? | select(. == "context-mode")' "$TEST_HOME/.config/opencode/opencode.json" >/dev/null \
  && pass "opencode plugin merged" || fail "opencode plugin merged"

# 10. Hermes partial merge
python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" --host hermes --repo-root "$REPO_ROOT" >/dev/null
grep -q 'context-mode:' "$TEST_HOME/.hermes/config.yaml" \
  && pass "hermes MCP yaml merged" || fail "hermes MCP yaml merged"

# 11. Goose returns unsupported
result="$(python3 "$REPO_ROOT/scripts/lib/merge-token-compression-config.py" --host goose --repo-root "$REPO_ROOT")"
echo "$result" | jq -e '.results[0].status == "unsupported"' >/dev/null \
  && pass "goose merge reports unsupported" || fail "goose merge reports unsupported"

# 12. Extended hooks (sessionStart, afterAgentResponse)
grep -q 'context-mode hook cursor sessionstart' "$TEST_HOME/.cursor/hooks.json" \
  && pass "sessionStart hook merged" || fail "sessionStart hook merged"
grep -q 'context-mode hook cursor afteragentresponse' "$TEST_HOME/.cursor/hooks.json" \
  && pass "afterAgentResponse hook merged" || fail "afterAgentResponse hook merged"

# 13. Verification docs exist
for agent in claude codex cursor opencode goose hermes; do
  doc="$REPO_ROOT/docs/rtk-cm/verification/${agent}-verify-rtk-cm.md"
  [[ -f "$doc" ]] && pass "verification doc ${agent}" || fail "verification doc ${agent}"
done

[[ -f "$REPO_ROOT/docs/rtk-cm/README.md" ]] && pass "rtk-cm README" || fail "rtk-cm README"

# 14. Docs reference optimization script
grep -q 'optimize-rtk-context-mode' "$REPO_ROOT/docs/RTK.md" \
  && pass "RTK.md references optimize script" || fail "RTK.md references optimize script"
grep -q 'optimize-rtk-context-mode' "$REPO_ROOT/docs/CONTEXT-MODE.md" \
  && pass "CONTEXT-MODE.md references optimize script" || fail "CONTEXT-MODE.md references optimize script"
grep -q 'rtk-cm/README' "$REPO_ROOT/docs/RTK.md" \
  && pass "RTK.md links rtk-cm README" || fail "RTK.md links rtk-cm README"

# 15. Allowlist JSON valid
jq -e '.allow | length > 0' "$REPO_ROOT/scripts/lib/cursor-cli-allowlist.json" >/dev/null \
  && pass "cursor-cli-allowlist.json valid" || fail "cursor-cli-allowlist.json valid"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
