#!/usr/bin/env bash
# Branch tests for scripts/sb-diagnostics.sh. The script runs from a staged repo whose
# hooks/lib helpers are stubs driven by STUB_* environment variables, so every check
# (consent, CLI presence, health, platform wiring, scores, Cursor install identity)
# can be forced to each outcome. Real-library behaviour is covered by
# test-sb-diagnostics-reallibs.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"
unset CI SB_DIAG_SMOKE SB_DIAG_FORMAT

ST="$TL_TMP/stage"
mkdir -p "$ST/scripts" "$ST/hooks/lib"
cp "$TL_REPO_ROOT/scripts/sb-diagnostics.sh" "$ST/scripts/"
cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$ST/hooks/lib/"
printf '{"version":"9.9.9"}\n' >"$ST/package.json"
printf '{}\n' >"$ST/.silver-bullet.json"
D="$ST/scripts/sb-diagnostics.sh"

# ---- stub libraries ----
defn() { printf '[[ " ${STUB_UNDEF:-} " == *" %s "* ]] || %s() { %s; }\n' "$1" "$1" "$2"; }
flag() { printf '[[ "${%s:-%s}" == 1 ]]' "$1" "${2:-0}"; }
{
  defn sb_recommended_tool_consent 'local v="STUB_CONSENT_$2"; printf "%s" "${!v:-pending}"'
  defn sb_recommended_tool_enforcement_suspended 'local v="STUB_SUSP_$2"; [[ "${!v:-0}" == 1 ]]'
} >"$ST/hooks/lib/recommended-tools.sh"
{
  defn sb_graphify_abs_graph_path 'printf "%s" "${STUB_GRAPH_PATH:-$1/graphify-out/graph.json}"'
  defn sb_runtime_host 'printf "%s" "${SB_RUNTIME_NAME:-claude}"'
  defn sb_graphify_platform_artifact_path 'printf "%s/.gf-%s" "$1" "$2"'
  defn sb_graphify_platform_artifact_present "$(flag STUB_GF_PLAT)"
} >"$ST/hooks/lib/graphify-gate.sh"
{
  defn sb_agentmemory_server_healthy "$(flag STUB_AM_HEALTH)"
  defn sb_agentmemory_export_exists "$(flag STUB_AM_EXPORT)"
  defn sb_agentmemory_platform_artifact_path 'printf "%s/.am-%s" "$1" "$2"'
  defn sb_agentmemory_platform_artifact_present "$(flag STUB_AM_PLAT)"
} >"$ST/hooks/lib/agentmemory-gate.sh"
{
  defn sb_rtk_cli_path '[[ -n "${STUB_RTK_PATH:-}" ]] && printf "%s" "$STUB_RTK_PATH"'
  defn sb_rtk_cli_available "$(flag STUB_RTK_AVAIL)"
  defn sb_rtk_version_ok "$(flag STUB_RTK_VER)"
  defn sb_rtk_platform_hook_present "$(flag STUB_RTK_HOOK)"
} >"$ST/hooks/lib/rtk-gate.sh"
{
  defn sb_context_mode_cli_available "$(flag STUB_CM_AVAIL)"
  defn sb_context_mode_node_ok "$(flag STUB_CM_NODE 1)"
  defn sb_context_mode_platform_artifact_present "$(flag STUB_CM_MCP)"
  defn sb_context_mode_instruction_fragment_present "$(flag STUB_CM_FRAG)"
} >"$ST/hooks/lib/context-mode-gate.sh"
{
  defn sb_optimization_score 'export SB_STACK_SCORE="${STUB_SCORE:-100}" SB_STACK_SCORE_FAILS="${STUB_FAILS:-0}"; printf "%s" "${STUB_SCORE:-100}"'
  defn sb_stack_graphify_hooks_installed "$(flag STUB_GF_HOOKS)"
  defn sb_stack_server_persistence_ok "$(flag STUB_PERSIST)"
  defn sb_stack_bridge_running "$(flag STUB_BRIDGE)"
  defn sb_stack_gitleaks_required "$(flag STUB_GL_REQ)"
  defn sb_stack_gitleaks_path 'printf "%s" "${STUB_GL_PATH:-}"'
  defn sb_stack_graph_has_agentmemory_refs "$(flag STUB_SYN)"
} >"$ST/hooks/lib/stack-optimizer.sh"

gf_on()  { hr_bin graphify; }
gf_off() { hr_nobin graphify; rm -f "$HOME/.local/bin/graphify"; }
am_on()  { hr_bin agentmemory; }
am_off() { hr_nobin agentmemory; }
# run_diag VAR=val ...: run the staged script with the given environment
run_diag() { tl_run env "$@" bash "$D"; }

# ---------- baseline: nothing configured ----------
run_diag SILVER_BULLET_RUNTIME=claude
assert_eq "baseline exits 0" "0" "$TL_STATUS"
assert_contains "jq passes" "$TL_OUT" "PASS: jq — installed (jq-"
assert_contains "no hook config warns" "$TL_OUT" "WARN: hooks — no SB hook config in Claude settings.json"
assert_contains "graphify warns when pending" "$TL_OUT" "WARN: graphify — not on PATH — tier-1 code intelligence unavailable (consent: pending)"
assert_contains "agentmemory warns when pending" "$TL_OUT" "WARN: agentmemory — not on PATH — session capture unavailable (consent: pending)"
assert_contains "rtk warns when pending" "$TL_OUT" "WARN: rtk — not on PATH (consent: pending)"
assert_contains "context-mode warns when pending" "$TL_OUT" "WARN: context-mode — not installed (consent: pending)"
assert_contains "version unknown" "$TL_OUT" "PASS: package-version — unknown"
assert_contains "state tier without hooks" "$TL_OUT" "PASS: runtime-capability-tier — state-tracked (claude; see docs/RUNTIME-COMPATIBILITY.md)"
assert_contains "state root present" "$TL_OUT" "PASS: state-root — $HOME/.claude/.silver-bullet"
assert_contains "summary line" "$TL_OUT" "Results: 4 passed, 0 failed, 5 warnings"

# ---------- runtime hook detection and capability tiers ----------
mkdir -p "$HOME/.claude"; echo '{"hooks":"silver-bullet"}' >"$HOME/.claude/settings.json"
run_diag SILVER_BULLET_RUNTIME=claude
assert_contains "claude hooks referenced" "$TL_OUT" "PASS: hooks — Silver Bullet hooks referenced in $HOME/.claude/settings.json"
assert_contains "hook-enforced tier" "$TL_OUT" "PASS: runtime-capability-tier — hook-enforced (claude"
echo '{}' >"$HOME/.claude/settings.json"
run_diag SILVER_BULLET_RUNTIME=claude
assert_contains "settings without silver-bullet warns" "$TL_OUT" "WARN: hooks — no SB hook config in Claude settings.json"

mkdir -p "$HOME/.codex/.silver-bullet"
run_diag SILVER_BULLET_RUNTIME=codex
assert_contains "codex without config warns" "$TL_OUT" "WARN: hooks — no SB hook config in Codex config.toml"
assert_contains "codex state-tracked" "$TL_OUT" "PASS: runtime-capability-tier — state-tracked (codex"
echo 'hooks = "silver-bullet"' >"$HOME/.codex/config.toml"
run_diag SILVER_BULLET_RUNTIME=codex
assert_contains "codex hooks referenced" "$TL_OUT" "PASS: hooks — Silver Bullet hooks referenced in $HOME/.codex/config.toml"
assert_contains "codex hook-enforced" "$TL_OUT" "PASS: runtime-capability-tier — hook-enforced (codex"

mkdir -p "$HOME/.cursor/.silver-bullet"
run_diag SILVER_BULLET_RUNTIME=cursor
assert_contains "cursor without hooks.json warns" "$TL_OUT" "WARN: hooks — no SB hook config in Cursor hooks.json"
echo '{"silver-bullet":1}' >"$HOME/.cursor/hooks.json"
run_diag SILVER_BULLET_RUNTIME=cursor
assert_contains "cursor hooks referenced" "$TL_OUT" "PASS: hooks — Silver Bullet hooks referenced in $HOME/.cursor/hooks.json"

# no state dir at all: guidance-only
run_diag SILVER_BULLET_RUNTIME=goose
assert_contains "guidance-only tier" "$TL_OUT" "PASS: runtime-capability-tier — guidance-only (goose"
assert_contains "state root missing warns" "$TL_OUT" "WARN: state-root — $HOME/.config/goose/.silver-bullet not found yet"

# runtime-paths.sh missing: the codex home is assumed and the state dir derived from it
mv "$ST/hooks/lib/runtime-paths.sh" "$ST/hooks/lib/runtime-paths.off"
mkdir -p "$HOME/.codex/.silver-bullet"
tl_run env -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_NAME -u SILVER_BULLET_RUNTIME bash "$D"
assert_contains "no runtime-paths: claude fallback hooks check" "$TL_OUT" "WARN: hooks — no SB hook config in Claude settings.json"
assert_contains "no runtime-paths: state root under .codex" "$TL_OUT" "PASS: state-root — $HOME/.codex/.silver-bullet"
assert_contains "no runtime-paths: runtime unknown" "$TL_OUT" "state-tracked (unknown;"
mv "$ST/hooks/lib/runtime-paths.off" "$ST/hooks/lib/runtime-paths.sh"

# ---------- graphify ----------
C='SILVER_BULLET_RUNTIME=claude'
gf_on
run_diag $C
assert_contains "graphify CLI pending consent" "$TL_OUT" "PASS: graphify-cli — CLI available (consent: pending)"
run_diag $C STUB_CONSENT_graphify=enabled STUB_SUSP_graphify=1
assert_contains "graphify suspended with CLI" "$TL_OUT" "PASS: graphify-cli — CLI available (consent: enabled)"

mkdir -p "$ST/graphify-out"
run_diag $C STUB_CONSENT_graphify=enabled
assert_contains "graphify opted in" "$TL_OUT" "PASS: graphify-cli — CLI available (opted in)"
assert_contains "graphify index missing fails" "$TL_OUT" "FAIL: graphify-index — index missing — run: graphify update . --no-cluster"
assert_eq "graphify index failure exits 1" "1" "$TL_STATUS"
assert_contains "graphify platform missing warns" "$TL_OUT" "WARN: graphify-platform — platform artifact missing for claude"
echo '{}' >"$ST/graphify-out/graph.json"
run_diag $C STUB_CONSENT_graphify=enabled STUB_GF_PLAT=1
assert_contains "graphify index present (relative path)" "$TL_OUT" "PASS: graphify-index — index present at graphify-out/graph.json"
assert_contains "graphify platform present" "$TL_OUT" "PASS: graphify-platform — platform artifact present (.gf-claude, host=claude)"
rm -f "$ST/graphify-out/graph.json"; echo '{}' >"$TL_TMP/real-graph.json"; ln -s "$TL_TMP/real-graph.json" "$ST/graphify-out/graph.json"
run_diag $C STUB_CONSENT_graphify=enabled
assert_contains "symlinked graph is not an index" "$TL_OUT" "FAIL: graphify-index"
rm -f "$ST/graphify-out/graph.json"; echo '{}' >"$ST/custom-graph.json"
run_diag $C STUB_CONSENT_graphify=enabled STUB_GRAPH_PATH="$ST/custom-graph.json"
assert_contains "configured graph path honoured" "$TL_OUT" "PASS: graphify-index — index present at custom-graph.json"
echo '{}' >"$ST/graphify-out/graph.json"
run_diag $C STUB_CONSENT_graphify=enabled STUB_UNDEF="sb_graphify_abs_graph_path sb_graphify_platform_artifact_present"
assert_contains "default graph path without the helper" "$TL_OUT" "PASS: graphify-index — index present at graphify-out/graph.json"
assert_not_contains "no platform check without the helper" "$TL_OUT" "graphify-platform"
run_diag $C STUB_CONSENT_graphify=enabled STUB_UNDEF="sb_runtime_host"
assert_not_contains "no platform check without sb_runtime_host" "$TL_OUT" "graphify-platform"
run_diag $C STUB_CONSENT_graphify=enabled STUB_UNDEF="sb_recommended_tool_consent sb_recommended_tool_enforcement_suspended"
assert_contains "consent defaults to pending without the helper" "$TL_OUT" "PASS: graphify-cli — CLI available (consent: pending)"
gf_off
run_diag $C STUB_CONSENT_graphify=enabled STUB_SUSP_graphify=1
assert_contains "graphify install failed" "$TL_OUT" "WARN: graphify — opted in but install failed — enforcement suspended"
run_diag $C STUB_CONSENT_graphify=enabled
assert_contains "graphify missing but opted in" "$TL_OUT" "FAIL: graphify-cli — not on PATH — user opted in; install: uv tool install graphifyy"
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/graphify"; chmod +x "$HOME/.local/bin/graphify"
run_diag $C
assert_contains "graphify found in ~/.local/bin" "$TL_OUT" "PASS: graphify-cli — CLI available (consent: pending)"
gf_off

# ---------- agentmemory ----------
am_on
run_diag $C
assert_contains "agentmemory CLI pending consent" "$TL_OUT" "PASS: agentmemory-cli — CLI available (consent: pending)"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_SUSP_agentmemory=1
assert_contains "agentmemory suspended with CLI" "$TL_OUT" "PASS: agentmemory-cli — CLI available (consent: enabled)"
run_diag $C STUB_CONSENT_agentmemory=enabled
assert_contains "agentmemory opted in" "$TL_OUT" "PASS: agentmemory-cli — CLI available (opted in)"
assert_contains "agentmemory server unhealthy" "$TL_OUT" "FAIL: agentmemory-server — server not healthy"
assert_contains "agentmemory export missing" "$TL_OUT" "FAIL: agentmemory-export — export root missing — mkdir -p .agentmemory/memory"
assert_contains "agentmemory MCP not wired" "$TL_OUT" "WARN: agentmemory-platform — MCP not wired for claude"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_AM_HEALTH=1 STUB_AM_EXPORT=1 STUB_AM_PLAT=1
assert_contains "agentmemory server healthy" "$TL_OUT" "PASS: agentmemory-server — health check OK"
assert_contains "agentmemory export present" "$TL_OUT" "PASS: agentmemory-export — .agentmemory/ export root present"
assert_contains "agentmemory MCP wired" "$TL_OUT" "PASS: agentmemory-platform — MCP wired ($ST/.am-claude, host=claude)"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_UNDEF="sb_agentmemory_server_healthy sb_agentmemory_export_exists sb_agentmemory_platform_artifact_present"
assert_not_contains "no server check without the helper" "$TL_OUT" "agentmemory-server"
assert_not_contains "no export check without the helper" "$TL_OUT" "agentmemory-export"
assert_not_contains "no platform check without the helper" "$TL_OUT" "agentmemory-platform"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_UNDEF="sb_runtime_host"
assert_not_contains "no platform check without sb_runtime_host" "$TL_OUT" "agentmemory-platform"
am_off
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_SUSP_agentmemory=1
assert_contains "agentmemory install failed" "$TL_OUT" "WARN: agentmemory — opted in but install failed — enforcement suspended"
run_diag $C STUB_CONSENT_agentmemory=enabled
assert_contains "agentmemory missing but opted in" "$TL_OUT" "FAIL: agentmemory-cli — not on PATH — user opted in; install: npm install -g @agentmemory/agentmemory"

# ---------- stack optimization ----------
gf_off; am_off
run_diag $C STUB_CONSENT_graphify=enabled STUB_SCORE=85
assert_contains "optimize score passes" "$TL_OUT" "PASS: optimize-score — stack optimization 85/100"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_SCORE=59
assert_contains "optimize score below 60 warns" "$TL_OUT" "WARN: optimize-score — stack optimization 59/100 — run sb-optimize-stack.sh --apply"
run_diag $C STUB_CONSENT_agentmemory=enabled STUB_SCORE=90 STUB_FAILS=3
assert_contains "optimize critical gaps fail" "$TL_OUT" "FAIL: optimize-score — stack optimization 90/100 with 3 critical gap(s)"
run_diag $C STUB_UNDEF=sb_optimization_score STUB_CONSENT_graphify=enabled
assert_not_contains "no score without the helper" "$TL_OUT" "optimize-score"
run_diag $C
assert_not_contains "no score when nothing is opted in" "$TL_OUT" "optimize-score"
mv "$ST/.silver-bullet.json" "$ST/.silver-bullet.off"
run_diag $C STUB_CONSENT_graphify=enabled
assert_not_contains "no score without a project config" "$TL_OUT" "optimize-score"
mv "$ST/.silver-bullet.off" "$ST/.silver-bullet.json"

run_diag $C STUB_CONSENT_graphify=enabled
assert_contains "graphify hooks missing warn" "$TL_OUT" "WARN: optimize-graphify-hooks — git hooks missing"
run_diag $C STUB_CONSENT_graphify=enabled STUB_GF_HOOKS=1
assert_contains "graphify hooks installed" "$TL_OUT" "PASS: optimize-graphify-hooks — git hooks installed"
run_diag $C STUB_CONSENT_graphify=enabled STUB_UNDEF=sb_stack_graphify_hooks_installed
assert_contains "graphify hooks helper missing warns" "$TL_OUT" "WARN: optimize-graphify-hooks"
run_diag $C STUB_CONSENT_graphify=enabled STUB_SUSP_graphify=1
assert_not_contains "no hooks check when graphify suspended" "$TL_OUT" "optimize-graphify-hooks"

AMO="STUB_CONSENT_agentmemory=enabled"
am_on
run_diag $C $AMO
assert_contains "persistence missing warns" "$TL_OUT" "WARN: optimize-agentmemory-persistence — launchd/systemd not detected"
assert_contains "bridge missing warns" "$TL_OUT" "WARN: optimize-agentmemory-bridge — bridge not running"
assert_not_contains "no gitleaks check when not required" "$TL_OUT" "optimize-gitleaks"
run_diag $C $AMO STUB_PERSIST=1 STUB_BRIDGE=1 STUB_GL_REQ=1 STUB_GL_PATH=/opt/gitleaks
assert_contains "persistence ok" "$TL_OUT" "PASS: optimize-agentmemory-persistence — server persistence OK"
assert_contains "bridge running" "$TL_OUT" "PASS: optimize-agentmemory-bridge — bridge running"
assert_contains "gitleaks installed" "$TL_OUT" "PASS: optimize-gitleaks — gitleaks installed (/opt/gitleaks)"
run_diag $C $AMO STUB_GL_REQ=1
assert_contains "gitleaks required but missing" "$TL_OUT" "WARN: optimize-gitleaks — gitleaks required but missing"
assert_not_contains "missing gitleaks is not installed" "$TL_OUT" "PASS: optimize-gitleaks"
run_diag $C $AMO STUB_GL_REQ=1 STUB_UNDEF=sb_stack_gitleaks_path
assert_not_contains "no gitleaks check without the path helper" "$TL_OUT" "optimize-gitleaks"
run_diag $C $AMO STUB_UNDEF="sb_stack_server_persistence_ok sb_stack_bridge_running"
assert_contains "persistence helper missing warns" "$TL_OUT" "WARN: optimize-agentmemory-persistence"
assert_contains "bridge helper missing warns" "$TL_OUT" "WARN: optimize-agentmemory-bridge"
run_diag $C $AMO STUB_SUSP_agentmemory=1
assert_not_contains "no persistence check when suspended" "$TL_OUT" "optimize-agentmemory-persistence"
am_off

BOTH="STUB_CONSENT_graphify=enabled STUB_CONSENT_agentmemory=enabled"
run_diag $C $BOTH
assert_contains "synergy index missing fails" "$TL_OUT" "FAIL: optimize-synergy-index — graph missing .agentmemory refs"
run_diag $C $BOTH STUB_SYN=1
assert_contains "synergy index present" "$TL_OUT" "PASS: optimize-synergy-index — graph indexes .agentmemory"
run_diag $C $BOTH STUB_UNDEF=sb_stack_graph_has_agentmemory_refs
assert_contains "synergy helper missing fails" "$TL_OUT" "FAIL: optimize-synergy-index"

# smoke mode downgrades tool failures to warnings, other failures stay
echo '{"hooks":"silver-bullet"}' >"$HOME/.claude/settings.json"
run_diag $C STUB_CONSENT_graphify=enabled SB_DIAG_SMOKE=1
assert_contains "smoke: first warning counted" "$TL_OUT" "WARN: graphify-cli — not on PATH — user opted in"
run_diag $C $BOTH SB_DIAG_SMOKE=1
assert_contains "smoke: optimize fail becomes warn" "$TL_OUT" "WARN: optimize-synergy-index — graph missing .agentmemory refs"
assert_contains "smoke: graphify fail becomes warn" "$TL_OUT" "WARN: graphify-cli — not on PATH — user opted in"
assert_not_contains "smoke: no tool failure remains" "$TL_OUT" "FAIL:"
assert_eq "smoke exits 0" "0" "$TL_STATUS"
echo '{}' >"$HOME/.claude/settings.json"

# ---------- rtk ----------
run_diag $C STUB_RTK_PATH=/x/rtk
assert_contains "wrong rtk binary" "$TL_OUT" "WARN: rtk-wrong-binary — wrong rtk on PATH"
run_diag $C STUB_RTK_AVAIL=1
assert_contains "rtk pending consent" "$TL_OUT" "PASS: rtk-cli — CLI available (consent: pending)"
run_diag $C STUB_RTK_AVAIL=1 STUB_CONSENT_rtk=enabled STUB_SUSP_rtk=1
assert_contains "rtk suspended with CLI" "$TL_OUT" "PASS: rtk-cli — CLI available (consent: enabled)"
run_diag $C STUB_RTK_AVAIL=1 STUB_CONSENT_rtk=enabled
assert_contains "rtk opted in" "$TL_OUT" "PASS: rtk-cli — CLI available (opted in)"
assert_contains "rtk version old" "$TL_OUT" "FAIL: rtk-version — version too old"
assert_contains "rtk hook missing" "$TL_OUT" "FAIL: rtk-hook — host hook missing — run rtk init for claude"
run_diag $C STUB_RTK_AVAIL=1 STUB_CONSENT_rtk=enabled STUB_RTK_VER=1 STUB_RTK_HOOK=1
assert_contains "rtk version ok" "$TL_OUT" "PASS: rtk-version — version OK"
assert_contains "rtk hook wired" "$TL_OUT" "PASS: rtk-hook — host hook wired (host=claude)"
run_diag $C STUB_CONSENT_rtk=enabled STUB_SUSP_rtk=1
assert_contains "rtk install failed" "$TL_OUT" "WARN: rtk — opted in but install failed — enforcement suspended"
run_diag $C STUB_CONSENT_rtk=enabled
assert_contains "rtk missing but opted in" "$TL_OUT" "FAIL: rtk-cli — not on PATH — user opted in; see docs/RTK.md"
run_diag $C STUB_UNDEF=sb_rtk_cli_available STUB_CONSENT_rtk=enabled
assert_not_contains "no rtk checks without the helper" "$TL_OUT" "rtk"

# ---------- context mode ----------
run_diag $C STUB_CM_AVAIL=1
assert_contains "context-mode pending with CLI" "$TL_OUT" "PASS: context-mode-cli — CLI available (consent: pending)"
run_diag $C STUB_CONSENT_context_mode=enabled STUB_SUSP_context_mode=1
assert_contains "context-mode install failed" "$TL_OUT" "WARN: context-mode — opted in but install failed — enforcement suspended"
run_diag $C STUB_CONSENT_context_mode=enabled STUB_CM_NODE=0 STUB_CM_AVAIL=1
assert_contains "context-mode node too old" "$TL_OUT" "FAIL: context-mode-node — Node < 22.5"
run_diag $C STUB_CONSENT_context_mode=enabled
assert_contains "context-mode not installed" "$TL_OUT" "FAIL: context-mode-cli — not installed — npm install -g context-mode"
run_diag $C STUB_CONSENT_context_mode=enabled STUB_CM_AVAIL=1
assert_contains "context-mode opted in" "$TL_OUT" "PASS: context-mode-cli — CLI or plugin present (opted in)"
assert_contains "context-mode MCP not wired" "$TL_OUT" "FAIL: context-mode-mcp — MCP/plugin not wired"
assert_contains "context-mode fragment missing" "$TL_OUT" "WARN: context-mode-fragment — hint fragment missing"
run_diag $C STUB_CONSENT_context_mode=enabled STUB_CM_AVAIL=1 STUB_CM_MCP=1 STUB_CM_FRAG=1
assert_contains "context-mode MCP wired" "$TL_OUT" "PASS: context-mode-mcp — platform wired (host=claude)"
assert_contains "context-mode fragment present" "$TL_OUT" "PASS: context-mode-fragment — instruction fragment present"
run_diag $C STUB_CONSENT_context_mode=enabled STUB_CM_AVAIL=1 STUB_UNDEF=sb_context_mode_node_ok
assert_contains "context-mode without node helper" "$TL_OUT" "PASS: context-mode-cli — CLI or plugin present (opted in)"
run_diag $C STUB_UNDEF=sb_context_mode_cli_available STUB_CONSENT_context_mode=enabled
assert_not_contains "no context-mode checks without the helper" "$TL_OUT" "context-mode"

# ---------- cursor install identity ----------
CH="$HOME/.cursor"
V=9.9.9
mk_cursor() {
  rm -rf "$CH/plugins"
  local cache="$CH/plugins/cache/alo-labs/silver-bullet" gp sha
  mkdir -p "$cache/$V/commands" "$cache/$V/.cursor-plugin" "$CH/plugins/local/silver-bullet/.cursor-plugin" \
    "$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin"
  printf -- '---\nname: sb\n---\nbody\n' >"$cache/$V/commands/sb.md"
  printf '{"version":"%s"}\n' "$V" >"$cache/$V/.cursor-plugin/plugin.json"
  printf '{"version":"%s"}\n' "$V" >"$CH/plugins/local/silver-bullet/.cursor-plugin/plugin.json"
  ln -s "$cache/$V" "$cache/current"
  SHA_DIR="$TL_TMP/shasrc"; rm -rf "$SHA_DIR"; tl_git_repo "$SHA_DIR"
  sha="$(git -C "$SHA_DIR" rev-parse HEAD)"
  SHA="$sha"
  gp="$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet"
  mkdir -p "$gp"; mv "$SHA_DIR" "$gp/$sha"
  mkdir -p "$gp/$sha/commands" "$gp/$sha/.cursor-plugin"
  echo x >"$gp/$sha/commands/sb.md"
  echo '{"commands":"./commands"}' >"$gp/$sha/.cursor-plugin/plugin.json"
  mkdir -p "$CH/plugins/cache/alo-labs-cursor/silver-bullet"
  ln -s "$(cd "$cache/current" && pwd -P)" "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$sha"
  printf '{"plugins":{"silver-bullet@alo-labs":[{"version":"%s","installPath":"%s","enabled":true,"gitCommitSha":"%s"}]}}\n' "$V" "$cache/$V" "$sha" >"$CH/plugins/installed_plugins.json"
  printf '{"plugins":[{"name":"silver-bullet","version":"%s","source":{"sha":"%s"}}]}\n' "$V" "$sha" >"$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
}
CU='SILVER_BULLET_RUNTIME=cursor'
run_diag $CU
assert_contains "cursor without cache symlink warns" "$TL_OUT" "WARN: cursor-plugin — silver-bullet current symlink missing"

mk_cursor
run_diag $CU
assert_eq "healthy cursor install exits 0" "0" "$TL_STATUS"
assert_contains "cursor commands present" "$TL_OUT" "PASS: cursor-commands — plugin cache has composer command stubs"
assert_contains "cursor filenames safe" "$TL_OUT" "PASS: cursor-command-filenames — all command filenames are desktop-safe"
assert_contains "cursor identity" "$TL_OUT" "PASS: cursor-install-identity — registry/cache/current/local all match 9.9.9"
assert_contains "cursor enablement" "$TL_OUT" "PASS: cursor-marketplace-enablement"
assert_contains "cursor pin" "$TL_OUT" "PASS: cursor-marketplace-pin — marketplace manifest matches 9.9.9/${SHA:0:8}"
assert_contains "cursor gitpath" "$TL_OUT" "PASS: cursor-gitpath — marketplace gitPath ready with commands (${SHA:0:8})"

CACHE="$CH/plugins/cache/alo-labs/silver-bullet/$V"
rm -f "$CACHE/commands/sb.md"
run_diag $CU
assert_contains "cursor commands missing" "$TL_OUT" "FAIL: cursor-commands — commands/ missing — run: bash scripts/install-cursor.sh"
mk_cursor; printf -- '---\nname: other\n---\n' >"$CACHE/commands/sb.md"
run_diag $CU
assert_contains "cursor command name must be sb" "$TL_OUT" "FAIL: cursor-commands"
mk_cursor; printf 'no front matter\n' >"$CACHE/commands/sb.md"
run_diag $CU
assert_contains "cursor command without front matter" "$TL_OUT" "FAIL: cursor-commands"
mk_cursor; printf -- '---\ndescription: d\n---\n' >"$CACHE/commands/sb.md"
run_diag $CU
assert_contains "cursor command front matter without name" "$TL_OUT" "FAIL: cursor-commands"
mk_cursor; echo x >"$CACHE/commands/bad:name.md"
run_diag $CU
assert_contains "cursor colon filenames" "$TL_OUT" "FAIL: cursor-command-filenames — 1 command filenames contain ':'"
mk_cursor; mkdir "$CACHE/commands/dir.md"
run_diag $CU
assert_contains "cursor ignores non-file entries" "$TL_OUT" "PASS: cursor-command-filenames"
mk_cursor; printf '{"version":"1.0.0"}\n' >"$CH/plugins/local/silver-bullet/.cursor-plugin/plugin.json"
run_diag $CU
assert_contains "cursor identity mismatch" "$TL_OUT" "FAIL: cursor-install-identity — registry/cache/current/local version mismatch"
mk_cursor; jq '.plugins["silver-bullet@alo-labs"][0].enabled = false' "$CH/plugins/installed_plugins.json" >"$TL_TMP/r.json"; mv "$TL_TMP/r.json" "$CH/plugins/installed_plugins.json"
run_diag $CU
assert_contains "cursor enablement missing" "$TL_OUT" "FAIL: cursor-marketplace-enablement"
mk_cursor; jq 'del(.plugins["silver-bullet@alo-labs"][0].gitCommitSha)' "$CH/plugins/installed_plugins.json" >"$TL_TMP/r.json"; mv "$TL_TMP/r.json" "$CH/plugins/installed_plugins.json"
run_diag $CU
assert_contains "cursor registry without sha" "$TL_OUT" "WARN: cursor-gitpath — installed_plugins.json missing gitCommitSha"
mk_cursor; rm -f "$CH/plugins/installed_plugins.json"
run_diag $CU
assert_not_contains "cursor without registry skips sha checks" "$TL_OUT" "cursor-marketplace-pin"
mk_cursor; printf '{"plugins":[{"name":"silver-bullet","version":"0.0.1","source":{"sha":"abc"}}]}\n' >"$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
run_diag $CU
assert_contains "cursor marketplace pin mismatch" "$TL_OUT" "FAIL: cursor-marketplace-pin — marketplace manifest version/SHA mismatch"
mk_cursor; rm -f "$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet/$SHA/commands/sb.md"
run_diag $CU
assert_contains "cursor gitpath without commands" "$TL_OUT" "FAIL: cursor-gitpath — gitPath exists but commands surface missing"
mk_cursor; rm -f "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SHA"
run_diag $CU
assert_contains "cursor gitpath without cache symlink" "$TL_OUT" "FAIL: cursor-gitpath — gitPath exists but commands surface missing"
mk_cursor; rm -rf "$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet/$SHA/.git"
run_diag $CU
assert_contains "cursor gitpath missing" "$TL_OUT" "FAIL: cursor-gitpath — gitPath/cache symlink missing for ${SHA:0:8}"
mk_cursor; echo '{"commands":"./other"}' >"$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet/$SHA/.cursor-plugin/plugin.json"
run_diag $CU
assert_contains "cursor plugin.json commands mismatch" "$TL_OUT" "FAIL: cursor-gitpath — gitPath exists but commands surface missing"

# unreadable / absent metadata files make the version probes empty, never abort
mk_cursor; rm -f "$ST/package.json"
run_diag $CU
assert_contains "cursor without package.json cannot match identity" "$TL_OUT" "FAIL: cursor-install-identity"
printf '{"version":"9.9.9"}\n' >"$ST/package.json"
mk_cursor; rm -rf "$CH/plugins/cache/alo-labs/silver-bullet/$V"
run_diag $CU
assert_contains "cursor dangling current symlink" "$TL_OUT" "FAIL: cursor-commands"
mk_cursor; echo 'garbage' >"$CACHE/.cursor-plugin/plugin.json"
run_diag $CU
assert_contains "cursor invalid cache plugin.json" "$TL_OUT" "FAIL: cursor-install-identity"
mk_cursor; rm -f "$CH/plugins/local/silver-bullet/.cursor-plugin/plugin.json"
run_diag $CU
assert_contains "cursor missing local plugin.json" "$TL_OUT" "FAIL: cursor-install-identity"
mk_cursor; echo 'garbage' >"$CH/plugins/installed_plugins.json"
run_diag $CU
assert_contains "cursor corrupt registry" "$TL_OUT" "FAIL: cursor-install-identity"
assert_contains "cursor corrupt registry has no enablement" "$TL_OUT" "FAIL: cursor-marketplace-enablement"
assert_contains "cursor corrupt registry has no sha" "$TL_OUT" "WARN: cursor-gitpath — installed_plugins.json missing gitCommitSha"
mk_cursor; rm -f "$CH/plugins/marketplaces/alo-labs-cursor/.cursor-plugin/marketplace.json"
run_diag $CU
assert_contains "cursor missing marketplace manifest" "$TL_OUT" "FAIL: cursor-marketplace-pin"
mk_cursor; rm -f "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SHA"; ln -s /nonexistent/a/b "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SHA"
run_diag $CU
assert_contains "cursor unresolvable gitpath cache link" "$TL_OUT" "FAIL: cursor-gitpath — gitPath exists but commands surface missing"

# smoke mode keeps non-tool failures
run_diag $CU SB_DIAG_SMOKE=1
mk_cursor; rm -f "$CACHE/commands/sb.md"
run_diag $CU SB_DIAG_SMOKE=1
assert_contains "smoke keeps cursor failures" "$TL_OUT" "FAIL: cursor-commands"
assert_eq "smoke cursor failure exits 1" "1" "$TL_STATUS"

# ---------- package version ----------
run_diag $C
mkdir -p "$ST/.codex-plugin" "$ST/plugins/silver-bullet/.codex-plugin"
echo '{"version":"2.0.0"}' >"$ST/plugins/silver-bullet/.codex-plugin/plugin.json"
run_diag $C
assert_contains "nested codex plugin version" "$TL_OUT" "PASS: package-version — 2.0.0"
echo '{"version":"3.1.4"}' >"$ST/.codex-plugin/plugin.json"
run_diag $C
assert_contains "root codex plugin version" "$TL_OUT" "PASS: package-version — 3.1.4"
echo '{}' >"$ST/.codex-plugin/plugin.json"
run_diag $C
assert_contains "plugin.json without version" "$TL_OUT" "PASS: package-version — unknown"
echo 'not json' >"$ST/.codex-plugin/plugin.json"
run_diag $C
assert_contains "invalid plugin.json" "$TL_OUT" "PASS: package-version — unknown"
rm -rf "$ST/.codex-plugin"; echo 'not json' >"$ST/plugins/silver-bullet/.codex-plugin/plugin.json"
run_diag $C
assert_contains "invalid nested plugin.json" "$TL_OUT" "PASS: package-version — unknown"

# ---------- JSON format ----------
run_diag $C SB_DIAG_FORMAT=json
assert_eq "json exits 0" "0" "$TL_STATUS"
assert_eq "json is a single document with a tier" "state-tracked" "$(jq -r '.capability_tier' <<<"$TL_OUT")"
assert_eq "json counts" "4,0" "$(jq -r '"\(.passed),\(.failures)"' <<<"$TL_OUT")"
assert_eq "json runtime home" "$HOME/.claude" "$(jq -r '.runtime_home' <<<"$TL_OUT")"
assert_not_contains "json suppresses check lines" "$TL_OUT" "PASS:"
run_diag $C SB_DIAG_FORMAT=json STUB_CONSENT_graphify=enabled
assert_eq "json failures exit 1" "1" "$TL_STATUS"
assert_eq "json failure count" "true" "$(jq -r '.failures > 0' <<<"$TL_OUT")"

# jq missing: reported as a failure and the text summary replaces JSON
NJ="$(hr_path_without jq)"
tl_run env PATH="$NJ" SILVER_BULLET_RUNTIME=claude SB_DIAG_FORMAT=json bash "$D"
assert_eq "no jq exits 1" "1" "$TL_STATUS"
assert_not_contains "no jq output is text, not json" "$TL_OUT" "capability_tier"
tl_run env PATH="$NJ" SILVER_BULLET_RUNTIME=claude bash "$D"
assert_contains "jq missing failure" "$TL_OUT" "FAIL: jq — missing — SB hooks fail-open without jq"
assert_contains "text summary without jq" "$TL_OUT" "Results: "

tl_results
