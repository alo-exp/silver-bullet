#!/usr/bin/env bash
# sb-doctor.sh --fix repair dispatch (host installers, stack mutex, Cursor agents) against
# a staged repo (tests/lib/h-doctor-stage.sh). Validators and installers are logging stubs.
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

MUTEX="$SB_RUNTIME_STATE_DIR/stack-compression-mutex"

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
