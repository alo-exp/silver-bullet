#!/usr/bin/env bash
# Contract tests for graphify-am-global-setup.sh — no SB fixture required.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/graphify-am-global-setup.sh"
LIB="${REPO_ROOT}/hooks/lib/graphify-am-global.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== graphify-am-global-setup tests ==="

[[ -f "$SCRIPT" ]] && pass "script exists" || fail "script exists"
chmod +x "$SCRIPT" 2>/dev/null || true
[[ -x "$SCRIPT" ]] && pass "script executable" || fail "script executable"

[[ -f "$LIB" ]] && pass "lib exists" || fail "lib exists"

# shellcheck source=../../hooks/lib/graphify-am-global.sh
source "$LIB"

ga_validate_host claude && pass "host claude valid" || fail "host claude valid"
ga_validate_host codex && pass "host codex valid" || fail "host codex valid"
ga_validate_host opencode && pass "host opencode valid" || fail "host opencode valid"
ga_validate_host goose && pass "host goose valid" || fail "host goose valid"
ga_validate_host hermes && pass "host hermes valid" || fail "host hermes valid"
ga_validate_host cursor && fail "cursor rejected" || pass "cursor rejected (not in global hosts)"

[[ "$(ga_graphify_upstream_platform goose)" == "pi" ]] && pass "goose maps to pi" || fail "goose maps to pi"

pre="$(ga_graphify_pre_commands claude)"
[[ "$pre" == "graphify install" ]] && pass "claude global pre-index" || fail "claude global pre-index: $pre"

post="$(ga_graphify_post_commands claude)"
[[ "$post" == "graphify claude install" ]] && pass "claude global post-index" || fail "claude global post-index: $post"

codex_pre="$(ga_graphify_pre_commands codex)"
printf '%s' "$codex_pre" | grep -q 'graphify install --platform codex' && pass "codex global pre-index" || fail "codex global pre-index"

goose_post="$(ga_graphify_post_commands goose)"
[[ "$goose_post" == "graphify pi install" ]] && pass "goose global post-index" || fail "goose global post-index: $goose_post"

am_claude="$(ga_agentmemory_commands claude)"
[[ "$am_claude" == "agentmemory connect claude-code" ]] && pass "claude agentmemory cmd" || fail "claude agentmemory cmd"

# Help and dry-run (no SB config)
bash "$SCRIPT" --help >/dev/null 2>&1 && pass "--help exits 0" || fail "--help exits 0"

if GA_SKIP_HOST_HOOKS=1 bash "$SCRIPT" --host claude --apply --dry-run >/dev/null 2>&1; then
  pass "dry-run --apply exits 0"
else
  fail "dry-run --apply exits 0"
fi

if ! bash "$SCRIPT" --host invalid --verify 2>/dev/null; then
  pass "invalid host exits non-zero"
else
  fail "invalid host exits non-zero"
fi

# Env merge without SB
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
GA_AGENTMEMORY_HOME="$TMP/amhome" ga_merge_agentmemory_env "/tmp/project"
grep -q 'AGENTMEMORY_INJECT_CONTEXT=true' "$TMP/amhome/.env" && pass "env merge inject_context" || fail "env merge inject_context"
grep -q 'AGENTMEMORY_EXPORT_ROOT=/tmp/project/.agentmemory' "$TMP/amhome/.env" && pass "env absolute export" || fail "env absolute export"

declare -f ga_ensure_gitleaks >/dev/null 2>&1 && pass "ga_ensure_gitleaks defined" || fail "ga_ensure_gitleaks defined"
declare -f ga_gitleaks_path >/dev/null 2>&1 && pass "ga_gitleaks_path defined" || fail "ga_gitleaks_path defined"

if ga_gitleaks_path >/dev/null 2>&1; then
  ga_ensure_gitleaks && pass "ga_ensure_gitleaks when installed"
else
  if GA_GLOBAL_DRY_RUN=1 ga_ensure_gitleaks 2>&1 | grep -q 'DRY-RUN.*gitleaks'; then
    pass "ga_ensure_gitleaks dry-run"
  else
    fail "ga_ensure_gitleaks dry-run"
  fi
fi

# Verification docs exist
for host in claude codex opencode goose hermes; do
  doc="${REPO_ROOT}/docs/graphify-am/verification/${host}-verify-graphify-am.md"
  [[ -f "$doc" ]] && pass "verification doc ${host}" || fail "verification doc ${host}"
  grep -q 'gitleaks' "$doc" && pass "verification doc ${host} gitleaks check" || fail "verification doc ${host} gitleaks check"
done

[[ -f "${REPO_ROOT}/docs/graphify-am/PLATFORM-MATRIX.md" ]] && pass "platform matrix doc" || fail "platform matrix doc"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
