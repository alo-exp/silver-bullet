#!/usr/bin/env bash
# test-silver-doctor.sh — silver:doctor skill + sb-doctor.sh contract
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="${REPO_ROOT}/skills/silver-doctor/SKILL.md"
DOCTOR="${REPO_ROOT}/scripts/sb-doctor.sh"
PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  # Fixed-string when needle looks like a flag (BSD grep treats "--fix" as an option).
  if [[ "$needle" == --* ]]; then
    if grep -Fq -- "$needle" "$file"; then
      echo "PASS: $desc"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $desc — missing [$needle] in $file"
      FAIL=$((FAIL + 1))
    fi
  elif grep -qE "$needle" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local desc="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_executable() {
  local desc="$1" file="$2"
  if [[ -x "$file" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — not executable: $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists "silver-doctor skill exists" "$SKILL"
assert_file_exists "sb-doctor.sh exists" "$DOCTOR"
chmod +x "$DOCTOR" 2>/dev/null || true
assert_executable "sb-doctor.sh executable" "$DOCTOR"

assert_contains "documents sb-doctor.sh" "sb-doctor\\.sh" "$SKILL"
assert_contains "documents D1 jq check" "D1" "$SKILL"
assert_contains "documents D13 Claude import" "claude/plugins|D13" "$SKILL"
assert_contains "documents D14 cache bleed" "D14" "$SKILL"
assert_contains "documents --fix flag" "--fix" "$SKILL"
assert_contains "documents --dry-run" "--dry-run" "$SKILL"
assert_contains "documents --deep" "--deep" "$SKILL"
assert_contains "documents D10 reconciler" "D10-graphify" "$SKILL"
assert_contains "sb-doctor has --dry-run" "--dry-run" "$DOCTOR"
assert_contains "sb-doctor has doctor_run_reconciler" "doctor_run_reconciler" "$DOCTOR"
for id in D14 D15 D16; do
  grep -q "${id}" "$DOCTOR" && echo "PASS: sb-doctor.sh references check ${id}" && PASS=$((PASS + 1)) || { echo "FAIL: sb-doctor.sh missing check ${id}"; FAIL=$((FAIL + 1)); }
done
assert_contains "documents zero FAIL for PASS" "zero FAIL" "$SKILL"
assert_contains "documents friction log" "sb-friction-log" "$SKILL"

# Script implements key check IDs
for id in D1 D2 D3 D4 D5 D6 D7 D8 D9 D11 D12 D13; do
  if grep -q "record pass ${id}\|record fail ${id}\|record warn ${id}" "$DOCTOR" 2>/dev/null || grep -q "${id}" "$DOCTOR"; then
    echo "PASS: sb-doctor.sh references check ${id}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: sb-doctor.sh missing check ${id}"
    FAIL=$((FAIL + 1))
  fi
done

# Broken fixture: missing sb_initiated should FAIL D5
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$FIXTURE/.silver-bullet.json"
jq '.sb_initiated = false' "$FIXTURE/.silver-bullet.json" >"${FIXTURE}/.silver-bullet.json.tmp"
mv "${FIXTURE}/.silver-bullet.json.tmp" "$FIXTURE/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$FIXTURE/silver-bullet.md"
mkdir -p "$FIXTURE/docs/workflows" "$FIXTURE/scripts"
cp "$REPO_ROOT/scripts/workflows.sh" "$FIXTURE/scripts/workflows.sh"
chmod +x "$FIXTURE/scripts/workflows.sh"

out="$(bash "$DOCTOR" "$FIXTURE" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'FAIL: D5'; then
  echo "PASS: doctor FAILs D5 when sb_initiated false"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor should FAIL D5 when sb_initiated false"
  FAIL=$((FAIL + 1))
fi

# Host-scoped: Claude runtime must not require Cursor orchestrator rule (D8 N/A)
MOCK_HOME="$(mktemp -d)"
MOCK_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$MOCK_HOME" "$MOCK_PROJ"' EXIT
mkdir -p "$MOCK_HOME/.cursor" "$MOCK_PROJ/docs/workflows" "$MOCK_PROJ/scripts"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$MOCK_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$MOCK_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$MOCK_PROJ/scripts/workflows.sh"
chmod +x "$MOCK_PROJ/scripts/workflows.sh"
# Simulate Cursor hooks present on disk (must not flip Claude host detection)
printf '{"hooks":{"SessionStart":[{"command":"~/.codex/plugins/.codex/plugins/hook.sh"}]}}\n' >"$MOCK_HOME/.cursor/hooks.json"
mkdir -p "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/0.48.7/hooks" \
  "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/0.48.7/agents/claude"
ln -sfn "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/0.48.7" \
  "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/current"
cp "$REPO_ROOT/hooks/hooks.json" "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/0.48.7/hooks/hooks.json"
jq -n --arg v "0.48.7" --arg p "$MOCK_HOME/.codex/plugins/cache/alo-labs/silver-bullet/0.48.7" \
  '{version:2,plugins:{"silver-bullet@alo-labs":[{scope:"user",version:$v,installPath:$p}]}}' \
  >"$MOCK_HOME/.codex/plugins/installed_plugins.json"
printf '{"hooks":{}}\n' >"$MOCK_HOME/.codex/settings.json"

claude_out="$(env HOME="$MOCK_HOME" SILVER_BULLET_RUNTIME=claude bash "$DOCTOR" "$MOCK_PROJ" 2>&1 || true)"
if printf '%s' "$claude_out" | grep -q 'D8.*N/A.*claude'; then
  echo "PASS: D8 N/A on Claude host"
  PASS=$((PASS + 1))
else
  echo "FAIL: D8 should be N/A on Claude host"
  printf '%s\n' "$claude_out" | grep D8 || true
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$claude_out" | grep -q 'FAIL: D8'; then
  echo "FAIL: D8 must not FAIL on Claude host"
  FAIL=$((FAIL + 1))
else
  echo "PASS: D8 does not FAIL on Claude host"
  PASS=$((PASS + 1))
fi
if printf '%s' "$claude_out" | grep -q '\.claude/plugins'; then
  echo "PASS: Claude doctor uses .claude plugin paths"
  PASS=$((PASS + 1))
else
  echo "FAIL: Claude doctor should reference .claude plugin paths in D2/D3"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$claude_out" | grep -q '\.cursor/plugins'; then
  echo "FAIL: Claude doctor must not reference .cursor plugin paths"
  FAIL=$((FAIL + 1))
else
  echo "PASS: Claude doctor avoids .cursor plugin paths"
  PASS=$((PASS + 1))
fi

assert_contains "D8 Cursor-only in doctor script" 'runtime" == "cursor"' "$DOCTOR"
assert_contains "doctor sources runtime-paths" 'runtime-paths\.sh' "$DOCTOR"
assert_contains "D13 host-scoped in doctor script" 'cross-host plugin path contamination' "$DOCTOR"
assert_contains "D20 stack mutex check in doctor" 'D20' "$DOCTOR"

# RED-4: doctor D20 fix primitives clear dirty mutex and scaffold agentmemory export root.
RED4_FIXTURE="$(mktemp -d)"
RED4_STATE="$(mktemp -d)"
export SB_RUNTIME_STATE_DIR="$RED4_STATE"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$RED4_FIXTURE/.silver-bullet.json"
jq '.recommended_tools.leanctx.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = true
  | .optimization_profiles.five_tool_routed = {
      "stack_mode": "parallel_routed",
      "primary_fts": "context_mode",
      "routes": {
        "sb_read": "leanctx",
        "sb_grep": "context_mode",
        "sb_shell": "rtk",
        "sb_slice": "context_mode",
        "sb_webfetch": "context_mode",
        "sb_graph": "graphify",
        "sb_remember": "agentmemory"
      }
    }' "$RED4_FIXTURE/.silver-bullet.json" >"${RED4_FIXTURE}/.silver-bullet.json.tmp"
mv "${RED4_FIXTURE}/.silver-bullet.json.tmp" "$RED4_FIXTURE/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$RED4_FIXTURE/silver-bullet.md"
mkdir -p "$RED4_FIXTURE/docs/workflows" "$RED4_FIXTURE/scripts"
cp "$REPO_ROOT/scripts/workflows.sh" "$RED4_FIXTURE/scripts/workflows.sh"
chmod +x "$RED4_FIXTURE/scripts/workflows.sh"
# shellcheck source=hooks/lib/stack-compression-coordinator.sh
source "$REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"
# shellcheck source=hooks/lib/agentmemory-gate.sh
source "$REPO_ROOT/hooks/lib/agentmemory-gate.sh"
sb_stack_record_double_compression "$RED4_FIXTURE/.silver-bullet.json" "sb_shell" "leanctx" "rtk"
doc_before="$(bash "$DOCTOR" "$RED4_FIXTURE" 2>&1 || true)"
if printf '%s' "$doc_before" | grep -q 'FAIL: D20'; then
  echo "PASS: RED-4 doctor detects dirty mutex (D20 FAIL)"
  PASS=$((PASS + 1))
else
  echo "FAIL: RED-4 doctor should FAIL D20 when mutex dirty"
  FAIL=$((FAIL + 1))
fi
sb_stack_clear_mutex_violations "$RED4_FIXTURE/.silver-bullet.json"
sb_agentmemory_scaffold_export_root "$RED4_FIXTURE" "$RED4_FIXTURE/.silver-bullet.json" || true
if sb_stack_mutual_exclusion_is_clean "$RED4_FIXTURE/.silver-bullet.json"; then
  echo "PASS: RED-4 D20 fix clears dirty mutex"
  PASS=$((PASS + 1))
else
  echo "FAIL: RED-4 D20 fix should clear dirty mutex"
  FAIL=$((FAIL + 1))
fi
if [[ -d "$RED4_FIXTURE/.agentmemory/memory" ]]; then
  echo "PASS: RED-4 D20 fix scaffolds agentmemory export root"
  PASS=$((PASS + 1))
else
  echo "FAIL: RED-4 D20 fix should scaffold .agentmemory/memory"
  FAIL=$((FAIL + 1))
fi
rm -rf "$RED4_FIXTURE" "$RED4_STATE"
unset SB_RUNTIME_STATE_DIR SB_RUNTIME_PRESERVE_STATE_DIR
assert_contains "D21 cursor subagents check in doctor" 'D21' "$DOCTOR"
assert_contains "D21 fix invokes install-cursor-sb-agents" 'install-cursor-sb-agents.sh' "$DOCTOR"
assert_contains "D22 duplicate leanctx MCP check in doctor" 'D22' "$DOCTOR"
assert_contains "install-cursor wires sb-agents" 'install-cursor-sb-agents' "${REPO_ROOT}/scripts/install-cursor.sh"

# D21 — Cursor SB custom subagents (enabled + missing agents → FAIL; probe pass → PASS)
D21_HOME="$(mktemp -d)"
D21_PROJ="$(mktemp -d)"
mkdir -p "$D21_HOME/.cursor" "$D21_PROJ/docs/workflows" "$D21_PROJ/scripts"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$D21_PROJ/.silver-bullet.json"
jq '.sb_initiated = true
  | .cursor_sb_agents.enabled = true
  | .cursor_sb_agents.enabled_by_user = true
  | .cursor_sb_agents.agents_install_scope = "global"
  | .cursor_sb_agents.agents_install_status = "installed"' \
  "$D21_PROJ/.silver-bullet.json" >"${D21_PROJ}/.silver-bullet.json.tmp"
mv "${D21_PROJ}/.silver-bullet.json.tmp" "$D21_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$D21_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$D21_PROJ/scripts/workflows.sh"
chmod +x "$D21_PROJ/scripts/workflows.sh"
printf '{"hooks":{"SessionStart":[{"command":"cursor-hook"}]}}\n' >"$D21_HOME/.cursor/hooks.json"
mkdir -p "$D21_HOME/.config/silver-bullet"
cp "${REPO_ROOT}/tests/fixtures/cursor-models-catalog.json" \
  "$D21_HOME/.config/silver-bullet/cursor-models-catalog.json"
printf '{"agents_install_status":"pending","selected_models":["composer-2.5","grok-4.5"],"effort_levels":["medium","high","xhigh"]}\n' \
  >"$D21_HOME/.config/silver-bullet/cursor-sb-agents.json"
mkdir -p "$D21_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.7/hooks"
ln -sfn "$D21_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.7" \
  "$D21_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/current"
cp "$REPO_ROOT/hooks/hooks.json" "$D21_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.7/hooks/hooks.json"
jq -n --arg v "0.48.7" --arg p "$D21_HOME/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.7" \
  '{version:2,plugins:{"silver-bullet@alo-labs":[{scope:"user",version:$v,installPath:$p}]}}' \
  >"$D21_HOME/.cursor/plugins/installed_plugins.json"

d21_missing="$(env -u SB_RUNTIME_NAME HOME="$D21_HOME" SB_CURSOR_SB_AGENTS_CONFIG="$D21_HOME/.config/silver-bullet/cursor-sb-agents.json" SILVER_BULLET_RUNTIME=cursor bash "$DOCTOR" "$D21_PROJ" 2>&1 || true)"
if printf '%s' "$d21_missing" | grep -q 'FAIL: D21'; then
  echo "PASS: D21 FAIL when enabled agents missing"
  PASS=$((PASS + 1))
else
  echo "FAIL: D21 should FAIL when enabled agents missing"
  FAIL=$((FAIL + 1))
fi

if env HOME="$D21_HOME" \
  SB_CURSOR_SB_AGENTS_OFFLINE=1 \
  SB_CURSOR_MODELS_CATALOG="$D21_HOME/.config/silver-bullet/cursor-models-catalog.json" \
  SB_CURSOR_SB_AGENTS_CONFIG="$D21_HOME/.config/silver-bullet/cursor-sb-agents.json" \
  CSBA_REPO_ROOT="$D21_PROJ" \
  REPO_ROOT="$REPO_ROOT" bash "$REPO_ROOT/scripts/install-cursor-sb-agents.sh" \
  --global --non-interactive >/dev/null 2>&1; then
  d21_ok="$(env -u SB_RUNTIME_NAME HOME="$D21_HOME" SB_CURSOR_SB_AGENTS_CONFIG="$D21_HOME/.config/silver-bullet/cursor-sb-agents.json" SILVER_BULLET_RUNTIME=cursor bash "$DOCTOR" "$D21_PROJ" 2>&1 || true)"
  if printf '%s' "$d21_ok" | grep -q 'PASS: D21'; then
    echo "PASS: D21 PASS after install-cursor-sb-agents"
    PASS=$((PASS + 1))
  else
    echo "FAIL: D21 should PASS after agents installed"
    printf '%s\n' "$d21_ok" | grep D21 || true
    FAIL=$((FAIL + 1))
  fi
else
  echo "WARN: install-cursor-sb-agents skipped in test (catalog/network)"
fi

d21_claude="$(env HOME="$D21_HOME" SILVER_BULLET_RUNTIME=claude bash "$DOCTOR" "$D21_PROJ" 2>&1 || true)"
if printf '%s' "$d21_claude" | grep -q 'D21.*N/A'; then
  echo "PASS: D21 N/A on Claude host"
  PASS=$((PASS + 1))
else
  echo "FAIL: D21 should be N/A on Claude host"
  FAIL=$((FAIL + 1))
fi
rm -rf "$D21_HOME" "$D21_PROJ"


# D10 default-path five-tool coverage contracts
if grep -q "CONTEXT_MODE_PLATFORM" "$SKILL" && grep -q "CONFIGURED ≠ LIVE\|CONFIGURED != LIVE\|configuration, not" "$SKILL"; then
  echo "PASS: skill documents default CM doctor + CONFIGURED vs LIVE"
  PASS=$((PASS + 1))
else
  echo "FAIL: skill missing default CM doctor / CONFIGURED vs LIVE wording"
  FAIL=$((FAIL + 1))
fi
if grep -q "vendor_doctor_failed" "$REPO_ROOT/scripts/lib/recommended-tools/probe-context-mode.sh"; then
  echo "PASS: context-mode probe maps vendor doctor failure on default path"
  PASS=$((PASS + 1))
else
  echo "FAIL: context-mode probe missing vendor_doctor_failed"
  FAIL=$((FAIL + 1))
fi
if grep -q "duplicate_mcp_keys" "$REPO_ROOT/scripts/lib/recommended-tools/probe-leanctx.sh"; then
  echo "PASS: leanctx probe treats duplicate MCP keys as D10 evidence"
  PASS=$((PASS + 1))
else
  echo "FAIL: leanctx probe missing duplicate_mcp_keys"
  FAIL=$((FAIL + 1))
fi

if grep -q "D10-alumnium" "$SKILL" && grep -q "Alumnium" "$SKILL"; then
  echo "PASS: skill documents D10 alumnium coverage"
  PASS=$((PASS + 1))
else
  echo "FAIL: skill missing D10 alumnium coverage"
  FAIL=$((FAIL + 1))
fi
if grep -q "mcp_not_configured" "$REPO_ROOT/scripts/lib/recommended-tools/probe-alumnium.sh" \
  && grep -q "cli_missing" "$REPO_ROOT/scripts/lib/recommended-tools/probe-alumnium.sh" \
  && grep -q "vendor_doctor_failed" "$REPO_ROOT/scripts/lib/recommended-tools/probe-alumnium.sh"; then
  echo "PASS: alumnium probe has CLI/MCP/vendor-doctor D10 evidence"
  PASS=$((PASS + 1))
else
  echo "FAIL: alumnium probe missing CLI/MCP/vendor-doctor evidence"
  FAIL=$((FAIL + 1))
fi

# Live dogfood repo should PASS when environment is healthy (soft — warn only on fail)
if bash "$DOCTOR" "$REPO_ROOT" >/tmp/sb-doctor-live-$$.txt 2>&1; then
  echo "PASS: doctor PASS on live repo"
  PASS=$((PASS + 1))
else
  echo "WARN: doctor did not PASS on live repo (environment-dependent)"
  cat /tmp/sb-doctor-live-$$.txt | tail -20
  # Do not increment FAIL — CI may lack full host plugin state in sandbox
fi
rm -f /tmp/sb-doctor-live-$$.txt

# ── D10-routes: cross_tool "unsupported" is a warning, not a failure ─────────
# rt_host_supported() implements cross-tool convergence for cursor only, so on
# every other host cross_tool is permanently "unsupported" and --fix=host
# provably cannot clear it. Reporting FAIL made granting five-tool consent
# strictly worsen the doctor result while naming an impossible remedy.
UNSUPPORTED_ARM="$(awk '/elif \[\[ "\$cross" == "unsupported" \]\]; then/,/^    else$/' "$DOCTOR")"
# Strip comment lines: the arm's rationale comment legitimately mentions
# --fix=host when explaining why that remedy cannot work, and the assertions
# below are about the emitted `record` line, not the prose.
UNSUPPORTED_CODE="$(printf '%s\n' "$UNSUPPORTED_ARM" | grep -v '^[[:space:]]*#')"

if [[ -n "$UNSUPPORTED_ARM" ]]; then
  echo "PASS: sb-doctor.sh has a dedicated cross_tool=unsupported arm"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-doctor.sh missing cross_tool=unsupported arm"
  FAIL=$((FAIL + 1))
fi

if printf '%s' "$UNSUPPORTED_CODE" | grep -q 'record warn D10-routes'; then
  echo "PASS: cross_tool unsupported records warn (not fail)"
  PASS=$((PASS + 1))
else
  echo "FAIL: cross_tool unsupported does not record warn"
  FAIL=$((FAIL + 1))
fi

if printf '%s' "$UNSUPPORTED_CODE" | grep -q 'record fail'; then
  echo "FAIL: cross_tool unsupported arm still records fail"
  FAIL=$((FAIL + 1))
else
  echo "PASS: cross_tool unsupported arm does not record fail"
  PASS=$((PASS + 1))
fi

if printf '%s' "$UNSUPPORTED_CODE" | grep -Fq -- '--fix=host'; then
  echo "FAIL: cross_tool unsupported still recommends --fix=host"
  FAIL=$((FAIL + 1))
else
  echo "PASS: cross_tool unsupported does not recommend --fix=host"
  PASS=$((PASS + 1))
fi

if printf '%s' "$UNSUPPORTED_CODE" | grep -q 'cursor'; then
  echo "PASS: cross_tool unsupported message names the cursor-only limitation"
  PASS=$((PASS + 1))
else
  echo "FAIL: cross_tool unsupported message omits the platform limitation"
  FAIL=$((FAIL + 1))
fi

# Genuinely repairable drift must still FAIL.
if grep -q 'record fail D10-routes "cross_tool \${cross}' "$DOCTOR"; then
  echo "PASS: repairable cross_tool drift still records fail"
  PASS=$((PASS + 1))
else
  echo "FAIL: repairable cross_tool drift no longer records fail"
  FAIL=$((FAIL + 1))
fi

# rt_host_supported() must NOT have been widened to claim unimplemented support.
RT_COMMON="${REPO_ROOT}/scripts/lib/recommended-tools/common.sh"
if [[ -f "$RT_COMMON" ]]; then
  if awk '/^rt_host_supported\(\)/,/^}/' "$RT_COMMON" | grep -q 'cursor'; then
    echo "PASS: rt_host_supported still gates on cursor"
    PASS=$((PASS + 1))
  else
    echo "FAIL: rt_host_supported no longer gates on cursor"
    FAIL=$((FAIL + 1))
  fi
fi


# ── Report 1 / #256: persist preserves trailing newline ──────────────────────
PERSIST_NL_TMP="$(mktemp -d)"
PERSIST_NL_CFG="${PERSIST_NL_TMP}/.silver-bullet.json"
jq -n '{sb_initiated:true, sb_enforcement_tier:0}' >"$PERSIST_NL_CFG"
# shellcheck source=../../hooks/lib/enforcement-tier-gate.sh
source "${REPO_ROOT}/hooks/lib/enforcement-tier-gate.sh"
sb_enforcement_tier_persist "$PERSIST_NL_CFG" "0"
if [[ "$(tail -c1 "$PERSIST_NL_CFG" | xxd -p)" == "0a" ]]; then
  echo "PASS: sb_enforcement_tier_persist preserves trailing newline"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb_enforcement_tier_persist stripped trailing newline"
  xxd -l 16 -s -16 "$PERSIST_NL_CFG" || true
  FAIL=$((FAIL + 1))
fi
rm -rf "$PERSIST_NL_TMP"

# ── F8 / #257: doctor --dry-run D11 must not dirty .silver-bullet.json ───────
DRY_NL_TMP="$(mktemp -d)"
DRY_NL_CFG="${DRY_NL_TMP}/.silver-bullet.json"
# Use a jq-normalized config that session-start would otherwise rewrite.
jq -n '{
  sb_initiated: true,
  sb_enforcement_tier: 0,
  config_version: "0.0.0"
}' >"$DRY_NL_CFG"
printf '# silver-bullet\n' >"${DRY_NL_TMP}/silver-bullet.md"
DRY_BEFORE="$(cksum "$DRY_NL_CFG")"
bash "$DOCTOR" --dry-run "$DRY_NL_TMP" >/dev/null 2>&1 || true
DRY_AFTER="$(cksum "$DRY_NL_CFG")"
if [[ "$DRY_BEFORE" == "$DRY_AFTER" ]] && [[ "$(tail -c1 "$DRY_NL_CFG" | xxd -p)" == "0a" ]]; then
  echo "PASS: doctor --dry-run leaves .silver-bullet.json byte-identical (D11 smoke)"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor --dry-run dirtied .silver-bullet.json"
  echo "  before=$DRY_BEFORE"
  echo "  after=$DRY_AFTER"
  echo "  eof=$(tail -c1 "$DRY_NL_CFG" | xxd -p)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$DRY_NL_TMP"


echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

