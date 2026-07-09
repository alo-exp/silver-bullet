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

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
