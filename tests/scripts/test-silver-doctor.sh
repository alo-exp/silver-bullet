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

# D13 must only flag plugin paths belonging to a different supported host.
run_d13_host_path_case() {
  local current_host="$1" path_host="$2" expected="${3:-pass}"
  local d13_tmp d13_home d13_proj manifest plugin_path d13_out first_d13
  d13_tmp="$(mktemp -d)"
  d13_home="${d13_tmp}/home"
  d13_proj="${d13_tmp}/project"
  mkdir -p "$d13_home" "$d13_proj/docs/workflows" "$d13_proj/scripts"
  cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$d13_proj/.silver-bullet.json"
  cp "$REPO_ROOT/silver-bullet.md" "$d13_proj/silver-bullet.md"
  cp "$REPO_ROOT/scripts/workflows.sh" "$d13_proj/scripts/workflows.sh"
  chmod +x "$d13_proj/scripts/workflows.sh"

  plugin_path="${d13_home}/.${path_host}/plugins/alo-labs/silver-bullet"
  case "$current_host" in
    claude)
      manifest="${d13_home}/.claude/settings.json"
      mkdir -p "$(dirname "$manifest")"
      printf '{"pluginPath":"%s"}\n' "$plugin_path" >"$manifest"
      ;;
    codex)
      manifest="${d13_home}/.codex/config.toml"
      mkdir -p "$(dirname "$manifest")"
      printf 'plugin_path = "%s"\n' "$plugin_path" >"$manifest"
      ;;
    cursor)
      manifest="${d13_home}/.cursor/hooks.json"
      mkdir -p "$(dirname "$manifest")"
      printf '{"hooks":{"SessionStart":[{"command":"%s/hook.sh"}]}}\n' "$plugin_path" >"$manifest"
      ;;
  esac

  d13_out="$(env HOME="$d13_home" SILVER_BULLET_RUNTIME="$current_host" \
    RT_SKIP_VENDOR_DOCTOR=1 bash "$DOCTOR" "$d13_proj" 2>&1 || true)"
  first_d13="$(printf '%s\n' "$d13_out" | grep -m1 'D13' || true)"
  if [[ "$expected" == "pass" ]] && printf '%s' "$first_d13" | grep -q 'PASS: D13'; then
    echo "PASS: D13 ignores ${current_host} plugin path"
    PASS=$((PASS + 1))
  elif [[ "$expected" == "fail" ]] && printf '%s' "$first_d13" | grep -q 'FAIL: D13'; then
    echo "PASS: D13 flags ${path_host} plugin path on ${current_host}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: D13 ${current_host}/${path_host} expected ${expected}: ${first_d13}"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$d13_tmp"
}

for d13_current_host in claude codex cursor; do
  for d13_path_host in claude codex cursor; do
    if [[ "$d13_current_host" == "$d13_path_host" ]]; then
      run_d13_host_path_case "$d13_current_host" "$d13_path_host" pass
    else
      run_d13_host_path_case "$d13_current_host" "$d13_path_host" fail
    fi
  done
done

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
if grep -q 'source "${RT_LIB}/probe-alumnium.sh"' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh" \
  && grep -q 'rt_run_component alumnium' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh"; then
  echo "PASS: live reconciler sources and runs alumnium D10 probe"
  PASS=$((PASS + 1))
else
  echo "FAIL: live reconciler missing probe-alumnium.sh / rt_run_component alumnium"
  FAIL=$((FAIL + 1))
fi
if grep -q 'doctor_record_reconciler_d10' "$DOCTOR" && ! grep -q 'lib/sb-doctor/checks.sh' "$DOCTOR"; then
  echo "PASS: sb-doctor D10 uses reconciler (not checks.sh consent loop)"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-doctor D10 must use reconciler, not checks.sh"
  FAIL=$((FAIL + 1))
fi

# Live D10-alumnium via sb-doctor.sh (install + MCP wiring, not consent-only)
ALU_HOME="$(mktemp -d)"
ALU_PROJ="$(mktemp -d)"
ALU_BIN="$(mktemp -d)"
mkdir -p "$ALU_HOME/.cursor" "$ALU_PROJ/docs/workflows" "$ALU_PROJ/scripts"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$ALU_PROJ/.silver-bullet.json"
jq '.sb_initiated = true' "$ALU_PROJ/.silver-bullet.json" >"${ALU_PROJ}/.silver-bullet.json.tmp"
mv "${ALU_PROJ}/.silver-bullet.json.tmp" "$ALU_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$ALU_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$ALU_PROJ/scripts/workflows.sh"
chmod +x "$ALU_PROJ/scripts/workflows.sh"
printf '{"mcpServers":{}}\n' >"$ALU_HOME/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"$ALU_HOME/.cursor/hooks.json"

alu_run_doctor() {
  env -u SB_RUNTIME_NAME HOME="$ALU_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${ALU_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
    bash "$DOCTOR" "$ALU_PROJ" 2>&1 || true
}

alu_na_out="$(alu_run_doctor)"
if printf '%s' "$alu_na_out" | grep -qE 'PASS: D10-alumnium — alumnium (pending|disabled)'; then
  echo "PASS: live D10-alumnium PASS N/A when not opted in"
  PASS=$((PASS + 1))
else
  echo "FAIL: live D10-alumnium PASS N/A when not opted in"
  printf '%s\n' "$alu_na_out" | grep 'D10-alumnium' || true
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$alu_na_out" | grep -qE 'FAIL: D10-alumnium'; then
  echo "FAIL: live D10-alumnium must not FAIL the default/not-opted-in tree"
  FAIL=$((FAIL + 1))
else
  echo "PASS: live D10-alumnium does not FAIL when not opted in"
  PASS=$((PASS + 1))
fi

jq '.recommended_tools.alumnium.enabled_by_user = true' \
  "$ALU_PROJ/.silver-bullet.json" >"${ALU_PROJ}/.silver-bullet.json.tmp"
mv "${ALU_PROJ}/.silver-bullet.json.tmp" "$ALU_PROJ/.silver-bullet.json"
alu_cli_out="$(alu_run_doctor)"
if printf '%s' "$alu_cli_out" | grep -qE 'FAIL: D10-alumnium'; then
  echo "PASS: live D10-alumnium FAILs when opted in and CLI missing"
  PASS=$((PASS + 1))
else
  echo "FAIL: live D10-alumnium FAILs when opted in and CLI missing"
  printf '%s\n' "$alu_cli_out" | grep 'D10-alumnium' || true
  FAIL=$((FAIL + 1))
fi

printf '#!/usr/bin/env bash\nexit 0\n' >"${ALU_BIN}/alumnium"
chmod +x "${ALU_BIN}/alumnium"
alu_mcp_out="$(alu_run_doctor)"
if printf '%s' "$alu_mcp_out" | grep -qE 'FAIL: D10-alumnium'; then
  echo "PASS: live D10-alumnium FAILs when MCP server missing"
  PASS=$((PASS + 1))
else
  echo "FAIL: live D10-alumnium FAILs when MCP server missing"
  printf '%s\n' "$alu_mcp_out" | grep 'D10-alumnium' || true
  FAIL=$((FAIL + 1))
fi
rm -rf "$ALU_HOME" "$ALU_PROJ" "$ALU_BIN"

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

# --- Wave 1: search_cli canary + --fix swallow honesty ---
PROBE_SC="$REPO_ROOT/scripts/lib/recommended-tools/probe-search_cli.sh"
assert_file_exists "probe-search_cli.sh exists" "$PROBE_SC"
if grep -q 'search config show' "$PROBE_SC" 2>/dev/null; then
  echo "FAIL: probe-search_cli.sh must not dump search config show"
  FAIL=$((FAIL + 1))
else
  echo "PASS: probe-search_cli.sh must not dump search config show"
  PASS=$((PASS + 1))
fi
if grep -q 'D10-search_cli' "$SKILL" && grep -q 'docs_pin' "$SKILL" && grep -q 'search_cli' "$SKILL"; then
  echo "PASS: skill D10 F4 row documents search_cli"
  PASS=$((PASS + 1))
else
  echo "FAIL: skill D10 F4 row documents search_cli"
  FAIL=$((FAIL + 1))
fi
if grep -q 'planned WS7, not D10 Graphify' "$SKILL"; then
  echo "PASS: skill Omni footnote is planned WS7 not D10 Graphify"
  PASS=$((PASS + 1))
else
  echo "FAIL: skill Omni footnote is planned WS7 not D10 Graphify"
  FAIL=$((FAIL + 1))
fi
if awk '/search_cli/{f=1} f && /Health/{print; exit}' "$SKILL" | grep -q 'command -v'; then
  echo "FAIL: search_cli Health must not claim command -v alone"
  FAIL=$((FAIL + 1))
else
  echo "PASS: search_cli Health must not claim command -v alone"
  PASS=$((PASS + 1))
fi
if grep -q 'source "${RT_LIB}/probe-search_cli.sh"' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh" \
  && grep -q 'rt_run_component search_cli' "$REPO_ROOT/scripts/reconcile-recommended-tools.sh"; then
  echo "PASS: live reconciler sources and runs search_cli"
  PASS=$((PASS + 1))
else
  echo "FAIL: live reconciler sources and runs search_cli"
  FAIL=$((FAIL + 1))
fi

# Swallow anti-pattern: apply must not discard stderr then mark applied
if grep -n 'doctor_run_reconciler apply' "$DOCTOR" | grep -q .; then
  apply_ctx="$(awk '/doctor_apply_fixes\(\)/,/^run_doctor_checks/{print}' "$DOCTOR")"
  if printf '%s' "$apply_ctx" | grep -q '2>/dev/null || true' \
    && printf '%s' "$apply_ctx" | grep -q 'DOCTOR_FIX_APPLIED=1'; then
    echo "FAIL: doctor_apply_fixes must not swallow reconciler JSON then mark applied"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: doctor_apply_fixes must not swallow reconciler JSON then mark applied"
    PASS=$((PASS + 1))
  fi
else
  echo "FAIL: doctor_apply_fixes must invoke reconciler apply"
  FAIL=$((FAIL + 1))
fi
if grep -q '\[\[ "$DOCTOR_FIX_APPLIED" -eq 1 \]\] && return 0' "$DOCTOR"; then
  echo "FAIL: doctor_apply_fixes must not early-return on DOCTOR_FIX_APPLIED"
  FAIL=$((FAIL + 1))
else
  echo "PASS: doctor_apply_fixes must not early-return on DOCTOR_FIX_APPLIED"
  PASS=$((PASS + 1))
fi

# Live D10-search_cli via sb-doctor.sh
SC_HOME="$(mktemp -d)"
SC_PROJ="$(mktemp -d)"
SC_BIN="$(mktemp -d)"
mkdir -p "$SC_HOME/.cursor" "$SC_PROJ/docs/workflows" "$SC_PROJ/scripts"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$SC_PROJ/.silver-bullet.json"
jq '.sb_initiated = true' "$SC_PROJ/.silver-bullet.json" >"${SC_PROJ}/.silver-bullet.json.tmp"
mv "${SC_PROJ}/.silver-bullet.json.tmp" "$SC_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$SC_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$SC_PROJ/scripts/workflows.sh"
chmod +x "$SC_PROJ/scripts/workflows.sh"
printf '{"mcpServers":{}}\n' >"$SC_HOME/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"$SC_HOME/.cursor/hooks.json"

sc_run_doctor() {
  local extra_env="${1:-}"
  # shellcheck disable=SC2086
  env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 $extra_env \
    bash "$DOCTOR" "$SC_PROJ" 2>&1 || true
}

sc_na_out="$(sc_run_doctor)"
if printf '%s' "$sc_na_out" | grep -qE 'PASS: D10-search_cli — search_cli (pending|disabled)'; then
  echo "PASS: live D10-search_cli PASS N/A when not opted in"
  PASS=$((PASS + 1))
else
  echo "FAIL: live D10-search_cli PASS N/A when not opted in"
  printf '%s\n' "$sc_na_out" | grep 'D10-search_cli' || true
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$sc_na_out" | grep -qE 'FAIL: D10-search_cli'; then
  echo "FAIL: live D10-search_cli must not FAIL the default/not-opted-in tree"
  FAIL=$((FAIL + 1))
else
  echo "PASS: live D10-search_cli does not FAIL when not opted in"
  PASS=$((PASS + 1))
fi

jq '.recommended_tools.search_cli.enabled_by_user = true' \
  "$SC_PROJ/.silver-bullet.json" >"${SC_PROJ}/.silver-bullet.json.tmp"
mv "${SC_PROJ}/.silver-bullet.json.tmp" "$SC_PROJ/.silver-bullet.json"

for sc_rt in cursor claude codex; do
  sc_cli_out="$(
    env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME="$sc_rt" \
      PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
      bash "$DOCTOR" "$SC_PROJ" 2>&1 || true
  )"
  if printf '%s' "$sc_cli_out" | grep -qE 'FAIL: D10-search_cli'; then
    echo "PASS: live D10-search_cli FAILs when opted in and CLI missing (${sc_rt})"
    PASS=$((PASS + 1))
  else
    echo "FAIL: live D10-search_cli FAILs when opted in and CLI missing (${sc_rt})"
    printf '%s\n' "$sc_cli_out" | grep 'D10-search_cli' || true
    FAIL=$((FAIL + 1))
  fi
done

# WARN-only tree exits zero; FAIL tree exits nonzero
cat >"${SC_BIN}/search" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "search 0.9.0"; exit 0; fi
if [[ "${1:-}" == "config" && "${2:-}" == "check" ]]; then echo "providers: none"; exit 0; fi
exit 0
EOF
chmod +x "${SC_BIN}/search"
sc_warn_rc=0
env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
  PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
  bash "$DOCTOR" "$SC_PROJ" >/tmp/sb-doctor-sc-warn-$$.txt 2>&1 || sc_warn_rc=$?
if grep -qE 'WARN: D10-search_cli' /tmp/sb-doctor-sc-warn-$$.txt \
  && ! grep -qE 'FAIL: D10-search_cli' /tmp/sb-doctor-sc-warn-$$.txt; then
  echo "PASS: WARN-only search_cli D10 is WARN not FAIL"
  PASS=$((PASS + 1))
else
  echo "FAIL: WARN-only search_cli D10 is WARN not FAIL (rc=$sc_warn_rc)"
  grep 'D10-search_cli' /tmp/sb-doctor-sc-warn-$$.txt || true
  FAIL=$((FAIL + 1))
fi
rm -f "${SC_BIN}/search"
sc_fail_rc=0
env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
  PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
  bash "$DOCTOR" "$SC_PROJ" >/tmp/sb-doctor-sc-fail-$$.txt 2>&1 || sc_fail_rc=$?
if grep -qE 'FAIL: D10-search_cli' /tmp/sb-doctor-sc-fail-$$.txt && [[ "$sc_fail_rc" -ne 0 ]]; then
  echo "PASS: FAIL search_cli tree exits nonzero"
  PASS=$((PASS + 1))
else
  echo "FAIL: FAIL search_cli tree exits nonzero (rc=$sc_fail_rc)"
  grep 'D10-search_cli' /tmp/sb-doctor-sc-fail-$$.txt || true
  FAIL=$((FAIL + 1))
fi

# Empty / malformed / failed apply JSON must not mark applied
SC_FAKE="$SC_BIN/fake-reconcile.sh"
cat >"$SC_FAKE" <<'EOF'
#!/usr/bin/env bash
echo "reconciler-stderr-kept" >&2
exit 1
EOF
chmod +x "$SC_FAKE"
sc_empty_out="$(
  env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
    SB_DOCTOR_RECONCILER="$SC_FAKE" SB_DOCTOR_FORMAT=json SB_DOCTOR_ASSUME_YES=1 \
    bash "$DOCTOR" --fix=packages "$SC_PROJ" 2>/tmp/sb-doctor-sc-empty-err-$$.txt || true
)"
sc_empty_err="$(cat /tmp/sb-doctor-sc-empty-err-$$.txt 2>/dev/null || true)"
if printf '%s' "$sc_empty_out" | jq -e '.fix_applied == false' >/dev/null 2>&1 \
  && printf '%s' "$sc_empty_err" | grep -q 'reconciler-stderr-kept'; then
  echo "PASS: empty/failed apply JSON does not mark DOCTOR_FIX_APPLIED"
  PASS=$((PASS + 1))
else
  echo "FAIL: empty/failed apply JSON does not mark DOCTOR_FIX_APPLIED"
  printf '%s\n' "$sc_empty_out" | head -c 400; echo
  printf '%s\n' "$sc_empty_err" | head -c 400; echo
  FAIL=$((FAIL + 1))
fi

cat >"$SC_FAKE" <<'EOF'
#!/usr/bin/env bash
echo 'not-json'
exit 0
EOF
sc_mal_out="$(
  env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
    SB_DOCTOR_RECONCILER="$SC_FAKE" SB_DOCTOR_FORMAT=json SB_DOCTOR_ASSUME_YES=1 \
    bash "$DOCTOR" --fix=packages "$SC_PROJ" 2>/dev/null || true
)"
if printf '%s' "$sc_mal_out" | jq -e '.fix_applied == false' >/dev/null 2>&1; then
  echo "PASS: malformed apply JSON does not mark DOCTOR_FIX_APPLIED"
  PASS=$((PASS + 1))
else
  echo "FAIL: malformed apply JSON does not mark DOCTOR_FIX_APPLIED"
  printf '%s\n' "$sc_mal_out" | head -c 400; echo
  FAIL=$((FAIL + 1))
fi

# --dry-run / plan writes nothing
SC_CFG_BEFORE="$(cksum "$SC_PROJ/.silver-bullet.json")"
env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
  PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 \
  bash "$DOCTOR" --dry-run "$SC_PROJ" >/dev/null 2>&1 || true
SC_CFG_AFTER="$(cksum "$SC_PROJ/.silver-bullet.json")"
if [[ "$SC_CFG_BEFORE" == "$SC_CFG_AFTER" ]]; then
  echo "PASS: doctor --dry-run writes nothing for search_cli fixture"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor --dry-run writes nothing for search_cli fixture"
  FAIL=$((FAIL + 1))
fi

# Confirmation unobtainable: no writes when confirm-class packages mutation planned
SC_STAMP="$SC_HOME/brew.stamp"
rm -f "$SC_STAMP"
cat >"${SC_BIN}/brew" <<EOF
#!/usr/bin/env bash
echo invoked >> "$SC_STAMP"
exit 0
EOF
chmod +x "${SC_BIN}/brew"
unset SB_DOCTOR_ASSUME_YES
sc_confirm_rc=0
env -u SB_RUNTIME_NAME -u SB_DOCTOR_ASSUME_YES HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
  PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_FORMAT=json \
  bash "$DOCTOR" --fix=packages "$SC_PROJ" >/tmp/sb-doctor-sc-confirm-$$.txt 2>&1 || sc_confirm_rc=$?
if [[ "$sc_confirm_rc" -ne 0 ]] && [[ ! -f "$SC_STAMP" ]]; then
  echo "PASS: confirmation unobtainable blocks packages --fix writes"
  PASS=$((PASS + 1))
else
  echo "FAIL: confirmation unobtainable blocks packages --fix writes (rc=$sc_confirm_rc stamp=$([[ -f $SC_STAMP ]] && echo yes || echo no))"
  FAIL=$((FAIL + 1))
fi

# JSON stdout parseable
sc_json_out="$(
  env -u SB_RUNTIME_NAME HOME="$SC_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${SC_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_FORMAT=json \
    bash "$DOCTOR" --dry-run "$SC_PROJ" 2>/dev/null || true
)"
if printf '%s' "$sc_json_out" | jq -e '.schema' >/dev/null 2>&1; then
  echo "PASS: SB_DOCTOR_FORMAT=json stdout is parseable"
  PASS=$((PASS + 1))
else
  echo "FAIL: SB_DOCTOR_FORMAT=json stdout is parseable"
  FAIL=$((FAIL + 1))
fi

# Secrets must not appear in stdout/stderr/JSON
if printf '%s\n%s\n' "$sc_json_out" "$sc_na_out" | grep -qiE 'sk-live|api[_-]?key|BRAVE_API'; then
  echo "FAIL: doctor output must not contain secrets"
  FAIL=$((FAIL + 1))
else
  echo "PASS: doctor output must not contain secrets"
  PASS=$((PASS + 1))
fi

rm -rf "$SC_HOME" "$SC_PROJ" "$SC_BIN"
rm -f /tmp/sb-doctor-sc-warn-$$.txt /tmp/sb-doctor-sc-fail-$$.txt \
  /tmp/sb-doctor-sc-empty-err-$$.txt /tmp/sb-doctor-sc-confirm-$$.txt

echo

# --- Wave 2: D10 honesty + --fix proof + alias + stale split ---

# Full F4 coverage table
for tool in graphify agentmemory rtk context_mode leanctx alumnium search_cli cross_tool; do
  if grep -q "$tool" "$SKILL" && grep -q 'docs_pin' "$SKILL"; then
    echo "PASS: skill F4 mentions $tool and docs_pin"
    PASS=$((PASS + 1))
  else
    echo "FAIL: skill F4 mentions $tool and docs_pin"
    FAIL=$((FAIL + 1))
  fi
done
if grep -qE 'D10-routes' "$SKILL" && grep -q 'no_five_tool_consent' "$SKILL"; then
  echo "PASS: skill D10-routes documents no_five_tool_consent as PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL: skill D10-routes documents no_five_tool_consent as PASS"
  FAIL=$((FAIL + 1))
fi
if grep -q 'planned WS7, not D10 Graphify' "$SKILL" && ! grep -qE '^\| *omni' "$SKILL"; then
  echo "PASS: Omni is footnote not F4 row"
  PASS=$((PASS + 1))
else
  echo "FAIL: Omni is footnote not F4 row"
  FAIL=$((FAIL + 1))
fi

# /sb:doctor alias
SB_DOC_CMD="${REPO_ROOT}/plugins/silver-bullet/commands/sb-doctor.md"
SILVER_DOC_CMD="${REPO_ROOT}/plugins/silver-bullet/commands/silver-doctor.md"
assert_file_exists "sb-doctor command stub exists" "$SB_DOC_CMD"
assert_file_exists "silver-doctor command stub exists" "$SILVER_DOC_CMD"
assert_contains "SKILL documents /sb:doctor" "/sb:doctor" "$SKILL"
assert_contains "SKILL documents /silver:doctor" "/silver:doctor" "$SKILL"
assert_contains "sb-doctor stub forwards to sb-doctor.sh" "sb-doctor\\.sh" "$SB_DOC_CMD"
assert_contains "silver-doctor stub forwards to sb-doctor.sh" "sb-doctor\\.sh" "$SILVER_DOC_CMD"
assert_contains "sb-doctor stub documents --fix" "--fix" "$SB_DOC_CMD"
assert_contains "sb-doctor stub documents --dry-run" "--dry-run" "$SB_DOC_CMD"
assert_contains "silver-doctor stub documents --fix" "--fix" "$SILVER_DOC_CMD"
assert_contains "silver-doctor stub documents --dry-run" "--dry-run" "$SILVER_DOC_CMD"

# Stale split deleted
if [[ ! -f "$REPO_ROOT/scripts/lib/sb-doctor/checks.sh" ]] \
  && [[ ! -f "$REPO_ROOT/scripts/lib/sb-doctor/fix.sh" ]]; then
  echo "PASS: stale checks.sh and fix.sh deleted"
  PASS=$((PASS + 1))
else
  echo "FAIL: stale checks.sh and fix.sh deleted"
  FAIL=$((FAIL + 1))
fi
if [[ ! -f "$REPO_ROOT/scripts/lib/sb-doctor/core.sh" ]] \
  && [[ ! -f "$REPO_ROOT/scripts/lib/sb-doctor/summary.sh" ]]; then
  echo "PASS: stale core.sh and summary.sh deleted with split"
  PASS=$((PASS + 1))
else
  echo "FAIL: stale core.sh and summary.sh deleted with split"
  FAIL=$((FAIL + 1))
fi
if ! grep -Fq '[[ "$fixed" -eq 1 ]] && break' "$DOCTOR"; then
  echo "PASS: doctor_apply_fixes has no first-match break"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor_apply_fixes has no first-match break"
  FAIL=$((FAIL + 1))
fi
if grep -q 'D4|D13|D14|D16|D18|D19|D21' "$DOCTOR" && grep -q 'local' "$DOCTOR"; then
  echo "PASS: --fix=local fences host check ids"
  PASS=$((PASS + 1))
else
  echo "FAIL: --fix=local fences host check ids"
  FAIL=$((FAIL + 1))
fi

# Repair-dispatch: advertised --fix scopes are wired
if grep -q 'doctor_reconciler_scope\|DOCTOR_FIX_SCOPE' "$DOCTOR" \
  && grep -q 'rt_repair_search_cli' "$REPO_ROOT/scripts/lib/recommended-tools/probe-search_cli.sh"; then
  echo "PASS: repair-dispatch wires packages search_cli and doctor scopes"
  PASS=$((PASS + 1))
else
  echo "FAIL: repair-dispatch wires packages search_cli and doctor scopes"
  FAIL=$((FAIL + 1))
fi

# Advisory mapping includes skill_package_skew
if grep -q 'skill_package_skew' "$DOCTOR"; then
  echo "PASS: doctor maps skill_package_skew as advisory WARN"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor maps skill_package_skew as advisory WARN"
  FAIL=$((FAIL + 1))
fi

# unknown_key → WARN + nonzero
if grep -q 'unknown_key' "$DOCTOR" && grep -q 'DOCTOR_UNKNOWN_KEY' "$DOCTOR"; then
  echo "PASS: doctor records unknown_key WARN with nonzero exit"
  PASS=$((PASS + 1))
else
  echo "FAIL: doctor records unknown_key WARN with nonzero exit"
  FAIL=$((FAIL + 1))
fi

# Stale-loop canary: opted-in missing CLI stays FAIL (consent-only would PASS)
CANARY_HOME="$(mktemp -d)"
CANARY_PROJ="$(mktemp -d)"
mkdir -p "$CANARY_HOME/.cursor" "$CANARY_PROJ/scripts" "$CANARY_PROJ/docs/workflows"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$CANARY_PROJ/.silver-bullet.json"
jq '.sb_initiated = true
  | .recommended_tools.graphify.enabled_by_user = true
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = false
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .recommended_tools.alumnium.enabled_by_user = false
  | .recommended_tools.search_cli.enabled_by_user = false' \
  "$CANARY_PROJ/.silver-bullet.json" >"${CANARY_PROJ}/.silver-bullet.json.tmp"
mv "${CANARY_PROJ}/.silver-bullet.json.tmp" "$CANARY_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$CANARY_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$CANARY_PROJ/scripts/workflows.sh"
chmod +x "$CANARY_PROJ/scripts/workflows.sh"
printf '{"mcpServers":{}}\n' >"$CANARY_HOME/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[]}}\n' >"$CANARY_HOME/.cursor/hooks.json"
canary_out="$(
  env -u SB_RUNTIME_NAME HOME="$CANARY_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="/usr/bin:/bin" RT_SKIP_VENDOR_DOCTOR=1 \
    bash "$DOCTOR" "$CANARY_PROJ" 2>&1 || true
)"
if printf '%s' "$canary_out" | grep -qE 'FAIL: D10-graphify' \
  && ! printf '%s' "$canary_out" | grep -qE 'PASS: D10-graphify — graphify enabled \(enforcement active\)'; then
  echo "PASS: stale-loop canary (opted-in missing CLI) stays non-green"
  PASS=$((PASS + 1))
else
  echo "FAIL: stale-loop canary (opted-in missing CLI) stays non-green"
  printf '%s\n' "$canary_out" | grep 'D10-graphify' || true
  FAIL=$((FAIL + 1))
fi
rm -rf "$CANARY_HOME" "$CANARY_PROJ"

# Five-tool --fix fixture: RTK missing hook → --fix=host → hook present; second apply idempotent
FIX_HOME="$(mktemp -d)"
FIX_PROJ="$(mktemp -d)"
FIX_BIN="$(mktemp -d)"
mkdir -p "$FIX_HOME/.cursor" "$FIX_HOME/.silver-bullet" "$FIX_PROJ/scripts" "$FIX_PROJ/docs/workflows"
cp "$REPO_ROOT/templates/silver-bullet.config.json.default" "$FIX_PROJ/.silver-bullet.json"
jq '.sb_initiated = true
  | .recommended_tools.graphify.enabled_by_user = false
  | .recommended_tools.agentmemory.enabled_by_user = false
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = false
  | .recommended_tools.leanctx.enabled_by_user = false
  | .recommended_tools.alumnium.enabled_by_user = false
  | .recommended_tools.search_cli.enabled_by_user = false' \
  "$FIX_PROJ/.silver-bullet.json" >"${FIX_PROJ}/.silver-bullet.json.tmp"
mv "${FIX_PROJ}/.silver-bullet.json.tmp" "$FIX_PROJ/.silver-bullet.json"
cp "$REPO_ROOT/silver-bullet.md" "$FIX_PROJ/silver-bullet.md"
cp "$REPO_ROOT/scripts/workflows.sh" "$FIX_PROJ/scripts/workflows.sh"
chmod +x "$FIX_PROJ/scripts/workflows.sh"
printf '{"mcpServers":{}}\n' >"$FIX_HOME/.cursor/mcp.json"
printf '{"hooks":{"preToolUse":[{"command":"silver-bullet/cursor-hook-bridge.sh","matcher":"Shell"}]}}\n' >"$FIX_HOME/.cursor/hooks.json"
cat >"${FIX_BIN}/rtk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  gain) exit 0 ;;
  --version) echo "rtk 0.42.0"; exit 0 ;;
  doctor) exit 2 ;;
  init) exit 0 ;;
  hook) exit 0 ;;
  --help) echo "rtk hook helper"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${FIX_BIN}/rtk"
# Mock reconciler: apply writes the RTK hook; verify/plan echo fixture JSON.
FIX_RECON="$FIX_HOME/mock-reconcile.sh"
cat >"$FIX_RECON" <<EOF
#!/usr/bin/env bash
set -euo pipefail
mode="verify"
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --mode) mode="\$2"; shift 2 ;;
    --mode=*) mode="\${1#--mode=}"; shift ;;
    *) shift ;;
  esac
done
hooks="$FIX_HOME/.cursor/hooks.json"
if [[ "\$mode" == "apply" ]]; then
  printf '%s\\n' '{"hooks":{"preToolUse":[{"command":"rtk hook cursor","matcher":"Shell"}]}}' >"\$hooks"
fi
if grep -q 'rtk hook cursor' "\$hooks" 2>/dev/null; then
  cat <<'JSON'
{"schema":"1.0.0","ok":true,"mode":"apply","components":[{"component":"rtk","consent":"enabled","canonical_state":"ready","activation_status":"full","repairable":false,"evidence":[]}]}
JSON
else
  cat <<'JSON'
{"schema":"1.0.0","ok":true,"mode":"verify","components":[{"component":"rtk","consent":"enabled","canonical_state":"repairable","activation_status":"partial","repairable":true,"evidence":["shell_hook_missing"]}]}
JSON
fi
EOF
chmod +x "$FIX_RECON"
fix_out1="$(
  env -u SB_RUNTIME_NAME HOME="$FIX_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${FIX_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_ASSUME_YES=1 \
    SB_DOCTOR_RECONCILER="$FIX_RECON" SB_DOCTOR_FORMAT=json \
    SB_DOCTOR_STUB_HOST_INSTALL="${FIX_HOME}/host-install.stamp" \
    bash "$DOCTOR" --fix=host "$FIX_PROJ" 2>/dev/null || true
)"
if grep -q 'rtk hook cursor' "$FIX_HOME/.cursor/hooks.json" \
  && printf '%s' "$fix_out1" | jq -e '.fix_applied == true' >/dev/null 2>&1; then
  echo "PASS: five-tool --fix=host writes missing RTK hook and fix_applied"
  PASS=$((PASS + 1))
else
  echo "FAIL: five-tool --fix=host writes missing RTK hook and fix_applied"
  FAIL=$((FAIL + 1))
fi
hooks_before="$(cksum "$FIX_HOME/.cursor/hooks.json")"
fix_out2="$(
  env -u SB_RUNTIME_NAME HOME="$FIX_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${FIX_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_ASSUME_YES=1 \
    SB_DOCTOR_RECONCILER="$FIX_RECON" SB_DOCTOR_FORMAT=json \
    SB_DOCTOR_STUB_HOST_INSTALL="${FIX_HOME}/host-install.stamp" \
    bash "$DOCTOR" --fix=host "$FIX_PROJ" 2>/dev/null || true
)"
hooks_after="$(cksum "$FIX_HOME/.cursor/hooks.json")"
if [[ "$hooks_before" == "$hooks_after" ]]; then
  echo "PASS: five-tool second --fix=host is idempotent"
  PASS=$((PASS + 1))
else
  echo "FAIL: five-tool second --fix=host is idempotent"
  FAIL=$((FAIL + 1))
fi

# --fix=local must not run D4 (hooks stay missing SB bridge); D20 mutex still cleared
FIX_RECON_NOWWRITE="$FIX_HOME/mock-reconcile-nowrite.sh"
cat >"$FIX_RECON_NOWWRITE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"schema":"1.0.0","ok":true,"mode":"apply","components":[]}
JSON
EOF
chmod +x "$FIX_RECON_NOWWRITE"
printf '{"hooks":{"preToolUse":[{"command":"other-hook","matcher":"Shell"}]}}\n' \
  >"$FIX_HOME/.cursor/hooks.json"
hooks_local_before="$(cksum "$FIX_HOME/.cursor/hooks.json")"
mkdir -p "$FIX_HOME/.cursor/.silver-bullet"
printf '{"violations":[{"route":"sb_shell"}]}\n' >"$FIX_HOME/.cursor/.silver-bullet/stack-compression-mutex"
jq '.recommended_tools.leanctx.enabled_by_user = true
  | .recommended_tools.rtk.enabled_by_user = true
  | .recommended_tools.context_mode.enabled_by_user = true' \
  "$FIX_PROJ/.silver-bullet.json" >"${FIX_PROJ}/.silver-bullet.json.tmp"
mv "${FIX_PROJ}/.silver-bullet.json.tmp" "$FIX_PROJ/.silver-bullet.json"
local_out="$(
  env -u SB_RUNTIME_NAME HOME="$FIX_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${FIX_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_ASSUME_YES=1 \
    SB_DOCTOR_RECONCILER="$FIX_RECON_NOWWRITE" \
    SB_DOCTOR_STUB_HOST_INSTALL="${FIX_HOME}/host-install-local.stamp" \
    bash "$DOCTOR" --fix=local "$FIX_PROJ" 2>/dev/null || true
)"
hooks_local_after="$(cksum "$FIX_HOME/.cursor/hooks.json")"
if [[ "$hooks_local_before" == "$hooks_local_after" ]]; then
  echo "PASS: --fix=local does not mutate host D4 hooks"
  PASS=$((PASS + 1))
else
  echo "FAIL: --fix=local does not mutate host D4 hooks"
  FAIL=$((FAIL + 1))
fi
mutex_file="$FIX_HOME/.cursor/.silver-bullet/stack-compression-mutex"
if [[ ! -f "$mutex_file" ]] || [[ "$(jq -r '.violations | length' "$mutex_file" 2>/dev/null || echo 1)" == "0" ]]; then
  echo "PASS: --fix=local still clears D20 mutex"
  PASS=$((PASS + 1))
else
  echo "FAIL: --fix=local still clears D20 mutex"
  FAIL=$((FAIL + 1))
fi

# --fix=all: two in-scope (D4 + D20) converge without break
printf '{"hooks":{"preToolUse":[{"command":"other-hook","matcher":"Shell"}]}}\n' \
  >"$FIX_HOME/.cursor/hooks.json"
printf '{"violations":[{"route":"sb_shell"}]}\n' >"$FIX_HOME/.cursor/.silver-bullet/stack-compression-mutex"
FIX_STAMP="$FIX_HOME/host-install.stamp"
rm -f "$FIX_STAMP"
all_out="$(
  env -u SB_RUNTIME_NAME HOME="$FIX_HOME" SILVER_BULLET_RUNTIME=cursor \
    PATH="${FIX_BIN}:${PATH}" RT_SKIP_VENDOR_DOCTOR=1 SB_DOCTOR_ASSUME_YES=1 \
    SB_DOCTOR_RECONCILER="$FIX_RECON_NOWWRITE" SB_DOCTOR_FORMAT=json \
    SB_DOCTOR_STUB_HOST_INSTALL="$FIX_STAMP" \
    bash "$DOCTOR" --fix=all "$FIX_PROJ" 2>/dev/null || true
)"
mutex_all_file="$FIX_HOME/.cursor/.silver-bullet/stack-compression-mutex"
mutex_all_clean=0
[[ ! -f "$mutex_all_file" ]] && mutex_all_clean=1
[[ -f "$mutex_all_file" && "$(jq -r '.violations | length' "$mutex_all_file" 2>/dev/null || echo 1)" == "0" ]] && mutex_all_clean=1
if [[ "$mutex_all_clean" -eq 1 ]] \
  && grep -qx D4 "$FIX_STAMP" 2>/dev/null \
  && printf '%s' "$all_out" | jq -e '.fix_applied == true' >/dev/null 2>&1; then
  echo "PASS: --fix=all ordered pass sets DOCTOR_FIX_APPLIED and clears D20"
  PASS=$((PASS + 1))
else
  echo "FAIL: --fix=all ordered pass sets DOCTOR_FIX_APPLIED and clears D20"
  FAIL=$((FAIL + 1))
fi
rm -rf "$FIX_HOME" "$FIX_PROJ" "$FIX_BIN"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
