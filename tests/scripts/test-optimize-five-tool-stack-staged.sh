#!/usr/bin/env bash
# scripts/optimize-five-tool-stack.sh orchestration, run from a staged copy whose
# sibling helper scripts (leanctx installer, RTK+CM optimizer, synergy optimizer,
# cursor rules installer, MCP patcher) are logging stubs. Nothing is installed,
# no host config is touched: every write lands in the sandboxed HOME / temp dirs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

STAGE="$TL_TMP/repo"
OPT="$STAGE/scripts/optimize-five-tool-stack.sh"
LOG="$TL_TMP/calls.log"
export LOG

mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/hooks" "$STAGE/templates"
cp "$TL_REPO_ROOT/scripts/optimize-five-tool-stack.sh" "$OPT"
ln -s "$TL_REPO_ROOT/hooks/lib" "$STAGE/hooks/lib"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$STAGE/templates/"
for s in install-leanctx-sb optimize-rtk-context-mode sb-optimize-stack install-recommended-tools-cursor; do
  cat >"$STAGE/scripts/$s.sh" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$s" "\$*" >>"\$LOG"
exit "\${STUB_RC_${s//-/_}:-0}"
EOF
done
# the MCP patcher is python: log argv plus the RT_* environment it was given
cat >"$STAGE/scripts/lib/global-toolstack/patch-mcp.py" <<'EOF'
import os, sys
env = " ".join("%s=%s" % (k, os.environ[k]) for k in sorted(os.environ) if k.startswith("RT_") or k == "TOOLSTACK_REPO_ROOT")
open(os.environ["LOG"], "a").write("patch-mcp %s %s\n" % (" ".join(sys.argv), env))
EOF

PROJ="$TL_TMP/proj"
mkdir -p "$PROJ"
write_cfg() { printf '%s\n' "$1" >"$PROJ/.silver-bullet.json"; }
run_opt() { : >"$LOG"; tl_run bash "$OPT" "$@"; }
calls() { cat "$LOG"; }

write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'

# ---- argument handling
run_opt --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help usage" "$TL_OUT" "Usage: bash scripts/optimize-five-tool-stack.sh [options]"
run_opt -h
assert_eq "-h exits 0" "0" "$TL_STATUS"
run_opt --wat
assert_eq "unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "Unknown arg: --wat"
run_opt --project-root "$PROJ"
assert_eq "missing host exits 2" "2" "$TL_STATUS"
assert_contains "missing host message" "$TL_ERR" "ERROR: --host is required"
run_opt --host cursor
assert_eq "missing project root exits 2" "2" "$TL_STATUS"
assert_contains "missing project root message" "$TL_ERR" "ERROR: --project-root is required"
run_opt --host emacs --project-root "$PROJ"
assert_eq "invalid host exits 2" "2" "$TL_STATUS"
assert_contains "invalid host message" "$TL_ERR" "Invalid --host: emacs"
assert_eq "invalid host runs no helper" "" "$(calls)"

# ---- not opted in: nothing runs unless forced
for cfg in '{}' '{"recommended_tools":{"leanctx":{"enabled_by_user":false}}}' 'not json'; do
  write_cfg "$cfg"
  run_opt --host claude --project-root "$PROJ"
  assert_eq "not opted in ($cfg) exits 0" "0" "$TL_STATUS"
  assert_contains "not opted in ($cfg) message" "$TL_OUT" "leanctx not opted in"
  assert_eq "not opted in ($cfg) runs nothing" "" "$(calls)"
done
rm -f "$PROJ/.silver-bullet.json"
run_opt --host claude --project-root "$PROJ"
assert_contains "missing project config falls back to the repo/template config" "$TL_OUT" "leanctx not opted in"
cp "$STAGE/templates/silver-bullet.config.json.default" "$STAGE/.silver-bullet.json"
run_opt --host claude --project-root "$PROJ"
assert_contains "repo config consulted next" "$TL_OUT" "leanctx not opted in"
rm -f "$STAGE/.silver-bullet.json"
rm -f "$STAGE/templates/silver-bullet.config.json.default"
run_opt --host claude --project-root "$PROJ"
assert_contains "no config at all means not opted in" "$TL_OUT" "leanctx not opted in"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$STAGE/templates/"

# ---- real run for one host: helpers called in order, profile stamped
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
run_opt --host claude --project-root "$PROJ"
assert_eq "claude run exits 0" "0" "$TL_STATUS"
expected="install-leanctx-sb --host claude --project-root ${PROJ}
optimize-rtk-context-mode --host claude --project-root ${PROJ} --skip-cm-doctor
patch-mcp ${STAGE}/scripts/lib/global-toolstack/patch-mcp.py RT_HOST=claude RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_GRAPHIFY=1 RT_PATCH_LEANCTX=1 TOOLSTACK_REPO_ROOT=${STAGE}
sb-optimize-stack --apply --host claude"
assert_eq "claude: helper sequence and arguments" "$expected" "$(calls)"
assert_contains "profile stamped announcement" "$TL_OUT" "OK: five_tool_routed profile metadata applied to .silver-bullet.json"
assert_eq "profile stamped: name" "five_tool_routed" "$(jq -r '.recommended_tools.leanctx.optimization_profile' "$PROJ/.silver-bullet.json")"
assert_eq "profile stamped: stack mode" "parallel_routed" "$(jq -r '.recommended_tools.leanctx.stack_mode' "$PROJ/.silver-bullet.json")"
assert_eq "profile stamped: primary fts" "context_mode" "$(jq -r '.recommended_tools.leanctx.primary_fts' "$PROJ/.silver-bullet.json")"
assert_eq "profile stamped: route table" "rtk" "$(jq -r '.optimization_profiles.five_tool_routed.routes.sb_shell' "$PROJ/.silver-bullet.json")"
assert_eq "profile stamping keeps the opt-in" "true" "$(jq -r '.recommended_tools.leanctx.enabled_by_user' "$PROJ/.silver-bullet.json")"
assert_contains "active profile reported" "$TL_OUT" "Profile: five_tool_routed (primary_fts=context_mode, parallel_routed)"
assert_contains "completion banner" "$TL_OUT" "=== Five-tool optimization complete ==="
assert_not_contains "no cursor rules for claude" "$(calls)" "install-recommended-tools-cursor"

# a pre-existing custom five_tool_routed profile is preserved, not overwritten
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}},"optimization_profiles":{"five_tool_routed":{"custom":1}}}'
run_opt --host claude --project-root "$PROJ"
assert_eq "existing profile body preserved" "1" "$(jq -r '.optimization_profiles.five_tool_routed.custom' "$PROJ/.silver-bullet.json")"
assert_eq "existing profile has no injected routes" "null" "$(jq -r '.optimization_profiles.five_tool_routed.routes' "$PROJ/.silver-bullet.json")"

# ---- cursor: rules installer (real run vs dry-run --global), skip flags
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
run_opt --host cursor --project-root "$PROJ" --skip-synergy
assert_contains "cursor: rules installer without --global" "$(calls)" "install-recommended-tools-cursor "
assert_not_contains "cursor real run: no --global" "$(calls)" "install-recommended-tools-cursor --global"
assert_contains "cursor skip-synergy: graphify and agentmemory patches off" "$(calls)" "RT_PATCH_AGENTMEMORY=0 RT_PATCH_CONTEXT_MODE=1 RT_PATCH_GRAPHIFY=0 RT_PATCH_LEANCTX=1"
assert_not_contains "cursor skip-synergy: synergy optimizer not run" "$(calls)" "sb-optimize-stack"
assert_contains "skip-synergy announced" "$TL_OUT" "SKIP: sb-optimize-stack.sh (Graphify + agentmemory)"

run_opt --host codex --project-root "$PROJ" --skip-rtcm
assert_contains "skip-rtcm announced" "$TL_OUT" "SKIP: optimize-rtk-context-mode.sh"
assert_not_contains "skip-rtcm: helper not run" "$(calls)" "optimize-rtk-context-mode"
assert_contains "skip-rtcm: context-mode and leanctx patches off" "$(calls)" "RT_PATCH_AGENTMEMORY=1 RT_PATCH_CONTEXT_MODE=0 RT_PATCH_GRAPHIFY=1 RT_PATCH_LEANCTX=0"

run_opt --host pi --project-root "$PROJ" --skip-rtcm --skip-synergy
assert_not_contains "both skips: no MCP patching" "$(calls)" "patch-mcp"
assert_eq "both skips: only the leanctx installer runs" "install-leanctx-sb --host pi --project-root ${PROJ}" "$(calls)"

# ---- dry run
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
run_opt --host cursor --project-root "$PROJ" --dry-run
assert_eq "dry-run exits 0" "0" "$TL_STATUS"
assert_eq "dry-run runs no helper" "" "$(calls)"
assert_contains "dry-run leanctx" "$TL_OUT" "DRY-RUN: bash ${STAGE}/scripts/install-leanctx-sb.sh --host cursor --project-root ${PROJ} --dry-run"
assert_contains "dry-run rtcm" "$TL_OUT" "DRY-RUN: bash ${STAGE}/scripts/optimize-rtk-context-mode.sh --host cursor --project-root ${PROJ} --skip-cm-doctor --dry-run"
assert_contains "dry-run cursor rules use --global" "$TL_OUT" "DRY-RUN: bash ${STAGE}/scripts/install-recommended-tools-cursor.sh --global"
assert_contains "dry-run patch" "$TL_OUT" "DRY-RUN: env RT_HOST=cursor TOOLSTACK_REPO_ROOT=${STAGE} RT_PATCH_GRAPHIFY=1"
assert_contains "dry-run synergy" "$TL_OUT" "DRY-RUN: bash ${STAGE}/scripts/sb-optimize-stack.sh --apply --dry-run --host cursor"
assert_contains "dry-run metadata" "$TL_OUT" "DRY-RUN: stamp optimization_profiles.five_tool_routed metadata"
assert_eq "dry-run does not modify the config" "null" "$(jq -r '.recommended_tools.leanctx.optimization_profile' "$PROJ/.silver-bullet.json")"
assert_contains "dry-run reports the default profile as active" "$TL_OUT" "Profile: five_tool_routed"

# ---- all hosts, --force, and a config that is not opted in
run_opt --host all --project-root "$PROJ" --skip-rtcm --skip-synergy
for h in cursor claude codex opencode pi; do
  assert_contains "all: leanctx for $h" "$(calls)" "install-leanctx-sb --host $h --project-root ${PROJ}"
done
assert_not_contains "all: synergy host flag omitted" "$(calls)" "sb-optimize-stack"
run_opt --host all --project-root "$PROJ" --skip-rtcm
assert_contains "all: synergy without --host" "$(calls)" "sb-optimize-stack --apply"
assert_not_contains "all: synergy not pinned to a host" "$(calls)" "sb-optimize-stack --apply --host"

write_cfg '{}'
run_opt --host opencode --project-root "$PROJ" --force --skip-rtcm --skip-synergy
assert_eq "--force runs even when not opted in" "install-leanctx-sb --host opencode --project-root ${PROJ}" "$(calls)"
assert_eq "--force stamps the profile into a bare config" "five_tool_routed" "$(jq -r '.recommended_tools.leanctx.optimization_profile' "$PROJ/.silver-bullet.json")"

# ---- profile not active -> warning (a dry run does not stamp the profile)
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true,"optimization_profile":"synergy_max"}}}'
run_opt --host claude --project-root "$PROJ" --dry-run --skip-rtcm --skip-synergy
assert_eq "inactive profile does not fail the run" "0" "$TL_STATUS"
assert_contains "inactive profile warns" "$TL_ERR" "WARN: five_tool_routed profile not active in config"
assert_not_contains "inactive profile is not reported as active" "$TL_OUT" "Profile: five_tool_routed"
assert_eq "dry run leaves the other profile in place" "synergy_max" "$(jq -r '.recommended_tools.leanctx.optimization_profile' "$PROJ/.silver-bullet.json")"

# a failing helper aborts the run (set -e) before later stages
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
: >"$LOG"
tl_run env STUB_RC_install_leanctx_sb=7 bash "$OPT" --host claude --project-root "$PROJ"
assert_eq "failing leanctx installer aborts with its status" "7" "$TL_STATUS"
assert_not_contains "no later stage after the failure" "$(calls)" "optimize-rtk-context-mode"

# ---- host auto-detection
detect() {
  tl_run env -u CURSOR_PLUGIN_ROOT -u CODEX_HOME -u PI_CODING_AGENT_DIR -u RT_HOST "$@" bash -c '
    source <(sed -n "/^detect_host()/,/^}/p" "$1"); detect_host' _ "$OPT"
}
rm -rf "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude" "$HOME/.pi" "$HOME/.config"
detect; assert_eq "detect: nothing found falls back to cursor" "cursor" "$TL_OUT"
detect RT_HOST=pi; assert_eq "detect: RT_HOST wins" "pi" "$TL_OUT"
mkdir -p "$HOME/.cursor"; detect; assert_eq "detect: ~/.cursor" "cursor" "$TL_OUT"
rmdir "$HOME/.cursor"
detect CURSOR_PLUGIN_ROOT=/x; assert_eq "detect: CURSOR_PLUGIN_ROOT" "cursor" "$TL_OUT"
detect CODEX_HOME=/c; assert_eq "detect: CODEX_HOME" "codex" "$TL_OUT"
mkdir -p "$HOME/.codex"; detect; assert_eq "detect: ~/.codex" "codex" "$TL_OUT"
rmdir "$HOME/.codex"
mkdir -p "$HOME/.config/opencode"; detect; assert_eq "detect: opencode config dir" "opencode" "$TL_OUT"
rm -rf "$HOME/.config"
detect PI_CODING_AGENT_DIR=/p; assert_eq "detect: PI_CODING_AGENT_DIR" "pi" "$TL_OUT"
mkdir -p "$HOME/.pi/agent"; detect; assert_eq "detect: ~/.pi/agent" "pi" "$TL_OUT"
rm -rf "$HOME/.pi"
mkdir -p "$HOME/.claude"; detect; assert_eq "detect: ~/.claude" "claude" "$TL_OUT"
rm -rf "$HOME/.claude"

# --host auto resolves through detect_host before the opt-in check
mkdir -p "$HOME/.codex"
write_cfg '{"recommended_tools":{"leanctx":{"enabled_by_user":true}}}'
run_opt --host auto --project-root "$PROJ" --skip-rtcm --skip-synergy
assert_contains "auto host resolves to the detected host" "$TL_OUT" "=== SB five-tool stack optimization (host=codex) ==="
assert_contains "auto host drives the helpers" "$(calls)" "install-leanctx-sb --host codex"

tl_results
