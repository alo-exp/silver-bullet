#!/usr/bin/env bash
# sb-doctor.sh D11 (hook smoke), D13-D22 (host surfaces, Cursor install, stack mutex,
# Cursor agents, LeanCTX duplicates) and the --fix repair dispatch, against a staged repo
# (tests/lib/h-doctor-stage.sh). Validators and installers are logging stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-doctor-stage.sh"
cd "$TL_TMP"
unset SB_DOCTOR_FIX SB_DOCTOR_FIX_SCOPE SB_DOCTOR_DEEP SB_DOCTOR_DRY_RUN SB_DOCTOR_FORMAT SB_DOCTOR_RECONCILER SB_DOCTOR_ASSUME_YES SB_DOCTOR_STUB_HOST_INSTALL
hd_stage
hd_happy claude
C='SILVER_BULLET_RUNTIME=claude'
run() { hd_run "$C" "$@"; }
CU='SILVER_BULLET_RUNTIME=cursor'
cu() { hd_run "$CU" "$@"; }
CX='SILVER_BULLET_RUNTIME=codex'
cx() { hd_run "$CX" "$@"; }
CACHE="$HOME/.claude/plugins/cache/alo-labs/silver-bullet"

# ---------- D11: hook smoke ----------
run -- "$HD_PROJ"
assert_contains "session-start smoke payload" "$(hd_logs)" "hook session-start 1 SessionStart"
assert_contains "outcomes-check smoke payload" "$(hd_logs)" "hook outcomes-check 1 UserPromptSubmit"
assert_contains "stop-check smoke payload" "$(hd_logs)" "hook stop-check 1 Stop"
run STUB_RC_HOOK=1 -- "$HD_PROJ"
assert_eq "failing smoke exits 1" "1" "$TL_STATUS"
assert_contains "session-start smoke failure" "$TL_OUT" "FAIL: D11 — session-start smoke failed"
assert_contains "stop-check smoke failure" "$TL_OUT" "FAIL: D11 — stop-check smoke failed"
mv "$HD_ST/hooks/stop-check" "$HD_ST/hooks/stop-check.sh"
run -- "$HD_PROJ"
assert_contains "hooks resolved with a .sh suffix" "$TL_OUT" "PASS: D11 — stop-check smoke exit 0"
rm -f -- "${HD_ST:?}/hooks/stop-check.sh"
run -- "$HD_PROJ"
assert_contains "missing hook" "$TL_OUT" "FAIL: D11 — stop-check not found under $HD_ST/hooks"
hd_stage
# without a source-tree session-start the smoke uses the active plugin cache
rm -f -- "${HD_ST:?}/hooks/session-start"
mkdir -p "$CACHE/$HD_VER/hooks"
for h in session-start outcomes-check stop-check; do
  printf '#!/usr/bin/env bash\necho "cachehook %s" >>"$HD_LOG"\n' "$h" >"$CACHE/$HD_VER/hooks/$h"
  chmod +x "$CACHE/$HD_VER/hooks/$h"
done
run -- "$HD_PROJ"
assert_contains "smoke runs the cached hooks" "$(hd_logs)" "cachehook session-start"
rm -f -- "${CACHE:?}/current"
run -- "$HD_PROJ"
assert_contains "no current link: the hooks are looked up under the dangling cache path" "$TL_OUT" "FAIL: D11 — session-start not found under $CACHE/current/hooks"
rm -rf -- "${HOME:?}/.claude/plugins"
run -- "$HD_PROJ"
assert_contains "no cache at all: the checkout hooks are searched" "$TL_OUT" "FAIL: D11 — session-start not found under $HD_ST/hooks"
hd_stage
hd_happy claude

# ---------- D13 / D14: cross-host contamination and cache surface ----------
echo '{"hooks":"silver-bullet","path":"/home/u/.codex/plugins/cache/x"}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "claude settings with a codex plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.claude/settings.json contains foreign host plugin paths"
echo '{"hooks":"silver-bullet","path":"/home/u/.claude/plugins/cache/x"}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "own plugin path is not contamination" "$TL_OUT" "PASS: D13 — no cross-host plugin paths in Claude settings"
rm -rf -- "${CACHE:?}/$HD_VER/agents"
run -- "$HD_PROJ"
assert_contains "agent bundle missing from the cache" "$TL_OUT" "FAIL: D13 — agents/claude/ missing in active plugin cache ($CACHE/current)"
run STUB_RC_SURFACE_CACHE=1 -- "$HD_PROJ"
assert_contains "cache surface bleed" "$TL_OUT" "FAIL: D14 — plugin cache cross-host bleed — run: bash scripts/install-claude.sh"
assert_contains "cache surface arguments" "$(hd_logs)" "surface --cache-root $CACHE/$HD_VER --host claude"
rm -f -- "${CACHE:?}/current"
run -- "$HD_PROJ"
assert_contains "no active install: surface check skipped" "$TL_OUT" "WARN: D14 — plugin cache surface check skipped (no active install)"
hd_happy claude
rm -f -- "${HD_ST:?}/scripts/validate-host-install-surface.sh"
run -- "$HD_PROJ"
assert_contains "surface validator missing: D14" "$TL_OUT" "WARN: D14 — plugin cache surface check skipped"
assert_contains "surface validator missing: D16" "$TL_OUT" "WARN: D16 — validate-host-install-surface.sh not found; skipped"
hd_stage

hd_happy codex
echo '[plugins."silver-bullet@alo-labs-codex"] # /home/u/.cursor/plugins/x' >"$HOME/.codex/config.toml"
cx -- "$HD_PROJ"
assert_contains "codex config with a cursor plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.codex/config.toml contains foreign host plugin paths"
echo '[plugins."silver-bullet@alo-labs-codex"]' >"$HOME/.codex/config.toml"
cx -- "$HD_PROJ"
assert_contains "codex config is clean" "$TL_OUT" "PASS: D13 — no cross-host plugin paths in Codex config"
assert_contains "codex agent bundle in the cache" "$TL_OUT" "PASS: D13 — active install has skill-source/"
assert_contains "token budget N/A on codex" "$TL_OUT" "PASS: D15 — Claude token budget N/A (host=codex)"
hd_happy cursor
echo '{"silver-bullet":"cursor-hook-bridge.sh","p":"/home/u/.claude/plugins/x"}' >"$HOME/.cursor/hooks.json"
cu -- "$HD_PROJ"
assert_contains "cursor hooks with a claude plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.cursor/hooks.json contains foreign host plugin paths"

# ---------- D15 / D16 / D17: validators ----------
hd_happy claude
run STUB_RC_TOKENS=1 -- "$HD_PROJ"
assert_contains "token budget exceeded" "$TL_OUT" "FAIL: D15 — Claude agent descriptions exceed token budget"
rm -f -- "${HD_ST:?}/scripts/validate-claude-agent-token-budget.sh"
run -- "$HD_PROJ"
assert_contains "token budget script missing" "$TL_OUT" "WARN: D15 — validate-claude-agent-token-budget.sh not found; skipped"
run STUB_RC_SURFACE_REPO=1 -- "$HD_PROJ"
assert_contains "repo install surface bleed" "$TL_OUT" "FAIL: D16 — repo install surface bleed — run: bash scripts/install-claude.sh"
assert_contains "repo surface arguments" "$(hd_logs)" "surface --repo-root $HD_ST --host claude"
run STUB_RC_AGNOSTIC=1 -- "$HD_PROJ"
assert_contains "host-specific bleed in core" "$TL_OUT" "FAIL: D17 — host-specific bleed in SB core — run: bash scripts/validate-host-agnostic-core.sh"
rm -f -- "${HD_ST:?}/scripts/validate-host-agnostic-core.sh"
run -- "$HD_PROJ"
assert_contains "agnostic validator missing" "$TL_OUT" "WARN: D17 — validate-host-agnostic-core.sh not found; skipped"
hd_stage

# ---------- D18 / D19: Cursor marketplace gitPath ----------
hd_happy cursor
CH="$HOME/.cursor"
GP_BASE="$CH/plugins/marketplaces/github.com/alo-exp/silver-bullet"
SRC="$TL_TMP/gitsrc"; tl_git_repo "$SRC"
SHA="$(git -C "$SRC" rev-parse HEAD)"
mkdir -p "$GP_BASE"; mv "$SRC" "$GP_BASE/$SHA"
CURCACHE="$CH/plugins/cache/alo-labs/silver-bullet"
set_sha() {
  printf '{"plugins":{"silver-bullet@alo-labs":[{"version":"%s","installPath":"%s","gitCommitSha":"%s"}]}}\n' "$HD_VER" "$CURCACHE/$HD_VER" "$1" >"$CH/plugins/installed_plugins.json"
}
cu -- "$HD_PROJ"
assert_contains "no gitCommitSha" "$TL_OUT" "WARN: D18 — no gitCommitSha in installed_plugins.json — run: bash scripts/install-cursor.sh"
set_sha "null"
cu -- "$HD_PROJ"
assert_contains "null gitCommitSha" "$TL_OUT" "WARN: D18 — no gitCommitSha"
set_sha "$SHA"
cu -- "$HD_PROJ"
assert_contains "no cache symlink for the gitPath" "$TL_OUT" "FAIL: D18 — missing alo-labs-cursor cache symlink for ${SHA:0:8}"
mkdir -p "$CH/plugins/cache/alo-labs-cursor/silver-bullet"
ln -s "$(cd "$CURCACHE/$HD_VER" && pwd -P)" "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SHA"
cu -- "$HD_PROJ"
assert_contains "no materialized backend cache" "$TL_OUT" "FAIL: D18 — missing alo-labs-agent-plugins materialized cache for ${SHA:0:8}"
BC="$CH/plugins/cache/alo-labs-agent-plugins/silver-bullet/$SHA"
mkdir -p "$BC/commands"; touch "$BC/.cache-complete" "$BC/commands/sb.md"
cu -- "$HD_PROJ"
assert_contains "backend cache and gitPath ready" "$TL_OUT" "PASS: D18 — Cursor backend cache + gitPath ready (${SHA:0:8})"
assert_contains "command stubs present" "$TL_OUT" "PASS: D19 — composer /sb:* command stubs present in plugin cache"
rm -f -- "${BC:?}/.cache-complete"
cu -- "$HD_PROJ"
assert_contains "incomplete backend cache" "$TL_OUT" "FAIL: D18 — missing alo-labs-agent-plugins materialized cache"
rm -rf -- "${GP_BASE:?}/$SHA/.git"
cu -- "$HD_PROJ"
assert_contains "gitPath without a repository" "$TL_OUT" "FAIL: D18 — missing Cursor gitPath for ${SHA:0:8} — /sb commands fail to load — run: bash scripts/install-cursor.sh"
# the SHA Cursor itself logged wins over the registry's
mkdir -p "$HOME/Library/Application Support/Cursor/logs/20260101"
printf 'x Adding enabled plugin: silver-bullet from %s y\n' "$(printf 'a%.0s' $(seq 1 40))" >"$HOME/Library/Application Support/Cursor/logs/20260101/Cursor Plugins.log"
cu -- "$HD_PROJ"
assert_contains "backend sha taken from the Cursor log" "$TL_OUT" "FAIL: D18 — missing Cursor gitPath for aaaaaaaa"
rm -f -- "${CURCACHE:?}/$HD_VER/commands/sb.md"
cu -- "$HD_PROJ"
assert_contains "command stubs missing" "$TL_OUT" "FAIL: D19 — commands/ missing from plugin cache — slash menu will be empty"

# an unresolvable cache link and cache symlink are tolerated
rm -rf -- "${HOME:?}/Library"
hd_happy cursor
mkdir -p "$GP_BASE"
SRC2="$TL_TMP/gitsrc2"; tl_git_repo "$SRC2"
SHA2="$(git -C "$SRC2" rev-parse HEAD)"
mv "$SRC2" "$GP_BASE/$SHA2"
set_sha "$SHA2"
mkdir -p "$CH/plugins/cache/alo-labs-cursor/silver-bullet"
ln -s /nonexistent/a/b "$CH/plugins/cache/alo-labs-cursor/silver-bullet/$SHA2"
cu -- "$HD_PROJ"
assert_contains "unresolvable marketplace cache link" "$TL_OUT" "FAIL: D18 — missing alo-labs-cursor cache symlink for ${SHA2:0:8}"
rm -f -- "${CURCACHE:?}/current"
ln -s /nonexistent/a/b "$CURCACHE/current"
cu -- "$HD_PROJ"
assert_contains "unresolvable current link: D3" "$TL_OUT" "FAIL: D3 — broken or missing current symlink"
assert_contains "unresolvable current link: D19" "$TL_OUT" "FAIL: D19 — commands/ missing from plugin cache"

# ---------- D20: stack compression mutex ----------
hd_happy claude
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true}}}"
run -- "$HD_PROJ"
assert_contains "clean mutex" "$TL_OUT" "PASS: D20 — stack compression mutex clean"
MUTEX="$SB_RUNTIME_STATE_DIR/stack-compression-mutex"
echo '{"violations":["double"]}' >"$MUTEX"
run -- "$HD_PROJ"
assert_contains "dirty mutex" "$TL_OUT" "FAIL: D20 — stack compression mutex dirty — run: bash scripts/sb-doctor.sh --fix"
rm -f -- "${MUTEX:?}"
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\"}"
run -- "$HD_PROJ"
assert_contains "coordinator not needed" "$TL_OUT" "PASS: D20 — stack coordinator N/A (five-tool not active)"
rm -f -- "${HD_PROJ:?}/.silver-bullet.json"
run -- "$HD_PROJ"
assert_contains "no project config: coordinator N/A" "$TL_OUT" "PASS: D20 — stack coordinator N/A"
rm -f -- "${HD_ST:?}/hooks/lib"
mkdir -p "$HD_ST/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do
  [[ "${f##*/}" == stack-compression-coordinator.sh ]] || ln -s "$f" "$HD_ST/hooks/lib/${f##*/}"
done
hd_happy claude
run -- "$HD_PROJ"
assert_contains "coordinator library missing" "$TL_OUT" "WARN: D20 — stack-compression-coordinator lib missing; skipped"
hd_stage

# ---------- D21: Cursor SB subagents ----------
hd_happy cursor
agents_cfg() { hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"cursor_sb_agents\":$1}"; }
cu -- "$HD_PROJ"
assert_contains "no cursor_sb_agents config" "$TL_OUT" "PASS: D21 — cursor_sb_agents not enabled (N/A)"
agents_cfg '{"enabled":true}'
cu -- "$HD_PROJ"
assert_contains "agents match (global)" "$TL_OUT" "PASS: D21 — SB custom subagents (global): managed set matches config"
assert_contains "global agents dir probed" "$(hd_logs)" "probe-agents --agents-dir $HOME/.cursor/agents --repo-root $HD_PROJ --quiet"
agents_cfg '{"enabled_by_user":true,"agents_install_scope":"project"}'
cu STUB_RC_AGENTS=1 -- "$HD_PROJ"
assert_contains "stale agents (project scope)" "$TL_OUT" "FAIL: D21 — SB custom subagents missing or stale — run: bash scripts/install-cursor-sb-agents.sh --fix"
assert_contains "project agents dir probed" "$(hd_logs)" "probe-agents --agents-dir $HD_PROJ/.cursor/agents"
agents_cfg '{"enabled_by_user":true,"enforcement_suspended":true}'
cu -- "$HD_PROJ"
assert_contains "suspended agents are N/A" "$TL_OUT" "PASS: D21 — cursor_sb_agents not enabled (N/A)"
agents_cfg '{"enabled_by_user":false}'
cu -- "$HD_PROJ"
assert_contains "declined agents are N/A" "$TL_OUT" "PASS: D21 — cursor_sb_agents not enabled (N/A)"
agents_cfg '{"enabled":false}'
cu -- "$HD_PROJ"
assert_contains "explicitly disabled agents are N/A" "$TL_OUT" "PASS: D21 — cursor_sb_agents not enabled (N/A)"
agents_cfg '{"enabled":true}'
chmod -x "$HD_ST/scripts/lib/cursor-sb-agents/probe-global-agents.sh"
cu -- "$HD_PROJ"
assert_contains "probe not executable" "$TL_OUT" "WARN: D21 — probe-global-agents.sh missing; skipped"
echo 'not json' >"$HD_PROJ/.silver-bullet.json"
cu -- "$HD_PROJ"
assert_contains "unreadable config: audit continues to D21" "$TL_OUT" "PASS: D21 — cursor_sb_agents not enabled (N/A)"
assert_contains "unreadable config is reported by D6" "$TL_OUT" "FAIL: D6 — project config is not valid JSON ($HD_PROJ/.silver-bullet.json)"
assert_contains "unreadable config is reported by D5" "$TL_OUT" "FAIL: D5 — sb_initiated is not true"
hd_stage

# ---------- D22: duplicate LeanCTX servers ----------
hd_happy cursor
cu -- "$HD_PROJ"
assert_contains "no mcp.json" "$TL_OUT" "PASS: D22 — no duplicate LeanCTX MCP servers"
echo '{"mcpServers":{"lean-ctx":{},"leanctx":{}}}' >"$HOME/.cursor/mcp.json"
cu -- "$HD_PROJ"
assert_contains "duplicate LeanCTX servers" "$TL_OUT" "WARN: D22 — duplicate LeanCTX MCP servers (lean-ctx + leanctx)"
echo '{"mcpServers":{"leanctx":{}}}' >"$HOME/.cursor/mcp.json"
cu -- "$HD_PROJ"
assert_contains "single LeanCTX server" "$TL_OUT" "PASS: D22 — no duplicate LeanCTX MCP servers"

# ---------- --fix dispatch ----------
fixlog() { hd_logs; }
hd_happy claude
rm -f -- "${HD_PROJ:?}/silver-bullet.md"
mv "$HD_ST/scripts/reconcile-recommended-tools.sh" "$HD_ST/scripts/reconcile-recommended-tools.off"
run SB_DOCTOR_ASSUME_YES=1 -- --fix "$HD_PROJ"
assert_contains "a failing audit without a reconciler is not repaired for D5" "$TL_OUT" "FAIL: D5"
assert_eq "nothing was fixed, nothing re-run" "0" "$(grep -c 're-running checks' <<<"$TL_OUT" || true)"
hd_happy claude
run SB_DOCTOR_ASSUME_YES=1 -- --fix "$HD_PROJ"
assert_eq "a clean audit without a reconciler needs no fix" "0" "$TL_STATUS"
assert_not_contains "no repair when everything passes" "$TL_ERR" "--fix running"
mv "$HD_ST/scripts/reconcile-recommended-tools.off" "$HD_ST/scripts/reconcile-recommended-tools.sh"

# host install scripts run for D13/D14/D16/D18/D19 failures (claude)
hd_happy claude
rm -rf -- "${CACHE:?}/$HD_VER/agents"
run STUB_RC_SURFACE_CACHE=1 STUB_RC_SURFACE_REPO=1 -- --fix "$HD_PROJ"
assert_contains "host install script announced" "$TL_ERR" "sb-doctor: --fix running $HD_ST/scripts/install-claude.sh for D13"
assert_contains "host install script ran" "$(hd_logs)" "install-claude "
assert_contains "the audit is re-run after the repair" "$TL_OUT" "sb-doctor: re-running checks after --fix"
run STUB_RC_SURFACE_CACHE=1 -- --fix=local "$HD_PROJ"
assert_not_contains "local scope skips host installs" "$(hd_logs)" "install-claude"
# a failing install script does not stop the repair
run STUB_RC_SURFACE_CACHE=1 STUB_RC_INSTALL=1 -- --fix "$HD_PROJ"
assert_contains "failing install script is tolerated" "$TL_OUT" "sb-doctor: re-running checks after --fix"
# unknown host: no installer to run
hd_run SILVER_BULLET_RUNTIME=opencode -- --fix "$HD_PROJ"
assert_not_contains "no installer for an unknown host" "$(hd_logs)" "install-"
# installer not executable
chmod -x "$HD_ST/scripts/install-claude.sh"
run STUB_RC_SURFACE_CACHE=1 -- --fix "$HD_PROJ"
assert_not_contains "non-executable installer is skipped" "$(hd_logs)" "install-claude "
chmod +x "$HD_ST/scripts/install-claude.sh"

# a Cursor install problem outside D4 runs the full Cursor installer
hd_happy cursor
rm -f -- "${HOME:?}/.cursor/plugins/cache/alo-labs/silver-bullet/$HD_VER/commands/sb.md"
cu -- --fix "$HD_PROJ"
assert_contains "cursor installer announced for D19" "$TL_ERR" "sb-doctor: --fix running $HD_ST/scripts/install-cursor.sh for D19"
assert_contains "cursor installer ran without arguments" "$(hd_logs)" "install-cursor "

# D4: cursor merges hooks; other hosts run their installer
hd_happy cursor
rm -f -- "${HOME:?}/.cursor/hooks.json"
cu -- --fix "$HD_PROJ"
assert_contains "cursor D4 merges hooks only" "$(hd_logs)" "install-cursor --merge-hooks-only"
hd_happy claude
echo '{}' >"$HOME/.claude/settings.json"
run -- --fix "$HD_PROJ"
assert_contains "claude D4 runs the claude installer" "$(hd_logs)" "install-claude "
hd_happy codex
rm -f -- "${HOME:?}/.codex/config.toml"
cx -- --fix "$HD_PROJ"
assert_contains "codex D4 runs the codex installer" "$(hd_logs)" "install-codex "
hd_happy claude
echo '{}' >"$HOME/.claude/settings.json"
chmod -x "$HD_ST/scripts/install-claude.sh"
run -- --fix "$HD_PROJ"
assert_contains "D4 without an executable installer still re-runs" "$TL_OUT" "re-running checks after --fix"
chmod +x "$HD_ST/scripts/install-claude.sh"
hd_run SILVER_BULLET_RUNTIME=opencode -- --fix "$HD_PROJ"
assert_contains "D4 on an unknown host re-runs without installing" "$TL_OUT" "re-running checks after --fix"

# the test seam records instead of installing
hd_happy claude
rm -rf -- "${CACHE:?}/$HD_VER/agents"
echo '{}' >"$HOME/.claude/settings.json"
run SB_DOCTOR_STUB_HOST_INSTALL="$TL_TMP/host-install.txt" -- --fix "$HD_PROJ"
assert_eq "failing host checks recorded by the seam" "D4,D13" "$(paste -sd, "$TL_TMP/host-install.txt" | cut -d, -f1-2)"
assert_not_contains "seam: no installer ran" "$(hd_logs)" "install-claude"
run SB_DOCTOR_STUB_HOST_INSTALL="$TL_TMP/host-install2.txt" -- --fix=local "$HD_PROJ"
assert_file_absent "local scope skips the seam" "$TL_TMP/host-install2.txt"

# failing installers never abort the repair
hd_happy cursor
rm -f -- "${HOME:?}/.cursor/hooks.json"
cu STUB_RC_INSTALL=1 -- --fix "$HD_PROJ"
assert_contains "failing cursor hooks merge is tolerated" "$TL_OUT" "re-running checks after --fix"
hd_happy claude
echo '{}' >"$HOME/.claude/settings.json"
run STUB_RC_INSTALL=1 -- --fix "$HD_PROJ"
assert_contains "failing D4 installer is tolerated" "$TL_OUT" "re-running checks after --fix"
hd_run SILVER_BULLET_RUNTIME=opencode STUB_RC_SURFACE_REPO=1 -- --fix "$HD_PROJ"
assert_contains "D16 on an unknown host has no installer" "$TL_OUT" "FAIL: D16"
assert_not_contains "no installer for the unknown host" "$(hd_logs)" "install-"

# D15: advice only
hd_happy claude
run STUB_RC_TOKENS=1 -- --fix "$HD_PROJ"
assert_contains "D15 cannot be auto-fixed" "$TL_ERR" "sb-doctor: --fix D15 requires shortening Claude agent descriptions"

# D20: clears the mutex and scaffolds the agentmemory export root
hd_happy claude
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true},\"agentmemory\":{\"enabled_by_user\":true}}}"
echo '{"violations":["double"]}' >"$MUTEX"
run -- --fix "$HD_PROJ"
assert_file_absent "mutex violations cleared" "$MUTEX"
assert_contains "mutex clean after the fix" "$TL_OUT" "PASS: D20 — stack compression mutex clean"
assert_eq "agentmemory export root scaffolded" "yes" "$([[ -d "$HD_PROJ/.agentmemory/memory" ]] && echo yes || echo no)"
# an export root that cannot be created is tolerated
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true},\"agentmemory\":{\"enabled_by_user\":true}}}"
rm -rf -- "${HD_PROJ:?}/.agentmemory"
: >"$HD_PROJ/.agentmemory"
echo '{"violations":["double"]}' >"$MUTEX"
run -- --fix "$HD_PROJ"
assert_contains "unusable export root does not abort the repair" "$TL_OUT" "re-running checks after --fix"
rm -f -- "${HD_PROJ:?}/.agentmemory"
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true}}}"
echo '{"violations":["double"]}' >"$MUTEX"
run -- --fix "$HD_PROJ"
assert_eq "no scaffold without agentmemory" "no" "$([[ -d "$HD_PROJ/.agentmemory" ]] && echo yes || echo no)"
rm -f -- "${HD_PROJ:?}/.silver-bullet.json"
echo '{"violations":["double"]}' >"$MUTEX"
rm -f -- "${HD_ST:?}/hooks/lib"
mkdir -p "$HD_ST/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do
  [[ "${f##*/}" == agentmemory-gate.sh ]] || ln -s "$f" "$HD_ST/hooks/lib/${f##*/}"
done
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true}}}"
echo '{"violations":["double"]}' >"$MUTEX"
run -- --fix "$HD_PROJ"
assert_contains "D20 repair without the agentmemory library" "$TL_OUT" "re-running checks after --fix"
hd_stage

# D21: the agents installer targets the doctored project
hd_happy cursor
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"cursor_sb_agents\":{\"enabled\":true}}"
cu STUB_RC_AGENTS=1 -- --fix "$HD_PROJ"
assert_contains "agents fix announced" "$TL_ERR" "sb-doctor: --fix running install-cursor-sb-agents.sh for D21"
assert_contains "global agents installer flags and root" "$(hd_logs)" "install-cursor-sb-agents --fix --global repo=$HD_PROJ"
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"cursor_sb_agents\":{\"enabled\":true,\"agents_install_scope\":\"project\"}}"
cu STUB_RC_AGENTS=1 -- --fix "$HD_PROJ"
assert_contains "project agents installer flags" "$(hd_logs)" "install-cursor-sb-agents --fix --project repo=$HD_PROJ"
cu STUB_RC_AGENTS=1 STUB_RC_CSBA=1 -- --fix "$HD_PROJ"
assert_contains "failing agents installer is tolerated" "$TL_OUT" "re-running checks after --fix"
cu STUB_RC_AGENTS=1 -- --fix=local "$HD_PROJ"
assert_not_contains "local scope skips the agents installer" "$(hd_logs)" "install-cursor-sb-agents"
cu SB_DOCTOR_STUB_HOST_INSTALL="$TL_TMP/host-install3.txt" STUB_RC_AGENTS=1 -- --fix "$HD_PROJ"
assert_contains "seam records D21" "$(cat "$TL_TMP/host-install3.txt")" "D21"

tl_results
