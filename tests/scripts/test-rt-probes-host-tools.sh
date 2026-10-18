#!/usr/bin/env bash
# scripts/lib/recommended-tools/{probe-rtk,probe-leanctx}.sh: decision tables,
# per-host config readers, vendor `doctor` flag selection and repair flows.
# CLIs (rtk, lean-ctx, node) and installers are stubs; nothing is installed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/common.sh"
rt_init_paths
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-rtk.sh"
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-leanctx.sh"
export RT_HOST=cursor RT_SKIP_VENDOR_DOCTOR=1
hr_bin sleep 'exit 0'

PI_DIR="$HOME/.pi/agent"
CODEX_HOME_DIR="$(sb_runtime_codex_home)"
mkdir -p "$HOME/.cursor" "$HOME/.claude" "$CODEX_HOME_DIR" "$HOME/.config/opencode/plugins" "$PI_DIR/extensions/silver-bullet-five-tool-stack" "$PI_DIR/extensions/pi-lean-ctx"
CURSOR_HOOKS="$HOME/.cursor/hooks.json"
H() { RT_HOST="$1"; }

# ===================================================================== RTK
# shell owner per host
rm -f "$CURSOR_HOOKS"
assert_eq "rtk owner cursor: no hooks.json" "1" "$(rc_of rt_probe_rtk_shell_owner)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk owner cursor: hook present" "0" "$(rc_of rt_probe_rtk_shell_owner)"
echo '{}' >"$CURSOR_HOOKS"
assert_eq "rtk owner cursor: hook absent" "1" "$(rc_of rt_probe_rtk_shell_owner)"
H claude
assert_eq "rtk owner claude: no settings" "1" "$(rc_of rt_probe_rtk_shell_owner)"
echo '{"hooks":"rtk hook claude"}' >"$HOME/.claude/settings.json"
assert_eq "rtk owner claude: hook present" "0" "$(rc_of rt_probe_rtk_shell_owner)"
echo '{}' >"$HOME/.claude/settings.json"
assert_eq "rtk owner claude: hook absent" "1" "$(rc_of rt_probe_rtk_shell_owner)"
H codex
assert_eq "rtk owner codex: no AGENTS.md" "1" "$(rc_of rt_probe_rtk_shell_owner)"
echo 'use Rust Token Killer' >"$CODEX_HOME_DIR/AGENTS.md"
assert_eq "rtk owner codex: instructions present" "0" "$(rc_of rt_probe_rtk_shell_owner)"
echo 'nothing' >"$CODEX_HOME_DIR/AGENTS.md"
assert_eq "rtk owner codex: instructions absent" "1" "$(rc_of rt_probe_rtk_shell_owner)"
assert_eq "rtk owner codex: falls back to ~/.codex without the runtime helper" "1" "$(unset -f sb_runtime_codex_home; rc_of rt_probe_rtk_shell_owner)"
H opencode
assert_eq "rtk owner opencode: no plugin" "1" "$(rc_of rt_probe_rtk_shell_owner)"
echo 'rtk plugin' >"$HOME/.config/opencode/plugins/rtk.ts"
assert_eq "rtk owner opencode: plugin present" "0" "$(rc_of rt_probe_rtk_shell_owner)"
H pi
echo '{"rtk":true}' >"$PI_DIR/extensions/silver-bullet-five-tool-stack/config.json"
assert_eq "rtk owner pi: config mentions rtk" "0" "$(rc_of rt_probe_rtk_shell_owner)"
H goose
assert_eq "rtk owner: other hosts" "1" "$(rc_of rt_probe_rtk_shell_owner)"

# lean-ctx rewrite absent
H cursor; rm -f "$CURSOR_HOOKS"
assert_eq "rewrite absent: cursor without hooks.json" "0" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
echo '{"hooks":{"preToolUse":[{"command":"lean-ctx hook rewrite"}]}}' >"$CURSOR_HOOKS"
assert_eq "rewrite present: cursor" "1" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
echo '{}' >"$CURSOR_HOOKS"
assert_eq "rewrite absent: cursor clean" "0" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
H opencode; rm -f "$HOME/.config/opencode/plugins/rtk.ts"
assert_eq "rewrite absent: opencode without artifact" "0" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
echo 'rtk and lean-ctx rewrite' >"$HOME/.config/opencode/plugins/rtk.ts"
assert_eq "rewrite present: opencode" "1" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
echo 'rtk only' >"$HOME/.config/opencode/plugins/rtk.ts"
assert_eq "rewrite absent: opencode clean" "0" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"
H claude
assert_eq "rewrite absent: other hosts" "0" "$(rc_of rt_probe_rtk_leanctx_rewrite_absent)"

# hook order
H opencode
assert_eq "rtk before cm: opencode plugin present" "0" "$(rc_of rt_probe_rtk_before_cm)"
rm -f "$HOME/.config/opencode/plugins/rtk.ts"
assert_eq "rtk before cm: opencode plugin absent" "1" "$(rc_of rt_probe_rtk_before_cm)"
H pi; PI_LEAN="$PI_DIR/extensions/pi-lean-ctx/config.json"
rm -f "$PI_LEAN"
assert_eq "rtk before cm: pi without config" "1" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"routeShell":true,"disableTools":["ctx_shell"]}' >"$PI_LEAN"
assert_eq "rtk before cm: pi still routes the shell" "1" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"routeShell":false,"disableTools":[]}' >"$PI_LEAN"
assert_eq "rtk before cm: pi without ctx_shell disabled" "1" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"routeShell":false,"disableTools":["ctx_shell"]}' >"$PI_LEAN"
assert_eq "rtk before cm: pi ok" "0" "$(rc_of rt_probe_rtk_before_cm)"
H claude; assert_eq "rtk before cm: hosts without ordering" "0" "$(rc_of rt_probe_rtk_before_cm)"
H cursor
rm -f "$CURSOR_HOOKS"
assert_eq "rtk before cm: cursor without hooks.json" "1" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"hooks":{"preToolUse":[{"command":"x rtk hook cursor"},{"command":"context-mode hook cursor pretooluse"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk before cm: rtk first" "0" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse"},{"command":"rtk hook cursor"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk before cm: rtk after context-mode" "1" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk before cm: only rtk" "0" "$(rc_of rt_probe_rtk_before_cm)"
echo '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk before cm: only context-mode" "1" "$(rc_of rt_probe_rtk_before_cm)"

# vendor doctor
unset RT_SKIP_VENDOR_DOCTOR
export RT_MODE=verify RT_VENDOR_DOCTOR_TIMEOUT=10
hr_bin rtk 'case "$*" in
  "gain --help") exit 0 ;;
  --version) echo "rtk 0.42.5" ;;
  help) echo "Commands:"; echo "  doctor   run checks"; echo "  gain"; exit 0 ;;
  "doctor --help") echo "${RTK_DOC_HELP:-usage: rtk doctor}"; exit 0 ;;
  doctor*) echo "rtk $*" >>"$HR_LOG"; exit "${RTK_DOC_RC:-0}" ;;
  *) exit 0 ;;
esac'
vdr() { local rc=0; : >"$HR_LOG"; "$@" >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }
assert_eq "rtk doctor: skip flag" "2" "$(RT_SKIP_VENDOR_DOCTOR=1 vdr rt_probe_rtk_vendor_doctor)"
assert_eq "rtk doctor: explicit command (pass)" "0" "$(RT_RTK_DOCTOR_CMD="true" vdr rt_probe_rtk_vendor_doctor)"
assert_eq "rtk doctor: explicit command (fail)" "1" "$(RT_RTK_DOCTOR_CMD="false" vdr rt_probe_rtk_vendor_doctor)"
assert_eq "rtk doctor: plain run passes" "0" "$(vdr rt_probe_rtk_vendor_doctor)"
assert_contains "rtk doctor: invoked without extra flags" "$(cat "$HR_LOG")" "rtk doctor"
assert_eq "rtk doctor: non-interactive flag" "0" "$(RTK_DOC_HELP="  --non-interactive" vdr rt_probe_rtk_vendor_doctor)"
assert_contains "rtk doctor: non-interactive flag passed" "$(cat "$HR_LOG")" "rtk doctor --non-interactive"
RTK_DOC_HELP="  --yes" vdr rt_probe_rtk_vendor_doctor >/dev/null
assert_contains "rtk doctor: --yes flag passed" "$(cat "$HR_LOG")" "rtk doctor --yes"
assert_eq "rtk doctor: failing doctor" "1" "$(RTK_DOC_RC=3 vdr rt_probe_rtk_vendor_doctor)"
hr_bin rtk 'case "$*" in "gain --help") exit 0;; help) echo "Commands:"; echo "  gain";; *) exit 0;; esac'
assert_eq "rtk doctor: no doctor subcommand listed" "2" "$(vdr rt_probe_rtk_vendor_doctor)"
hr_bin rtk 'case "$*" in "gain --help") exit 0;; help) echo "  doctor";; "doctor --help") echo "unknown command doctor"; exit 1;; *) exit 0;; esac'
assert_eq "rtk doctor: subcommand not usable" "2" "$(vdr rt_probe_rtk_vendor_doctor)"
hr_nobin rtk
assert_eq "rtk doctor: no binary" "2" "$(PATH="$(hr_path_without rtk)" vdr rt_probe_rtk_vendor_doctor)"
export RT_SKIP_VENDOR_DOCTOR=1

# probe table
hr_bin rtk 'case "$*" in "gain --help") exit 0;; --version) echo "rtk ${RTK_VER:-0.42.5}";; *) exit 0;; esac'
prtk() { hr_state "$(rt_probe_rtk)"; }
H goose; assert_eq "rtk: unsupported host" "unsupported|none||false" "$(prtk)"; H cursor
hr_consent rtk=disabled; assert_eq "rtk: disabled" "disabled|none||false" "$(prtk)"
hr_consent; assert_eq "rtk: pending" "pending|none||false" "$(prtk)"
hr_consent rtk=suspended; assert_eq "rtk: suspended" "suspended|none||false" "$(prtk)"
hr_consent rtk=enabled
assert_eq "rtk: cli missing" "failed|none|cli_missing|true" "$(PATH="$(hr_path_without rtk)" prtk)"
assert_eq "rtk: version too old" "repairable|none|version_mismatch,min_version|true" "$(RTK_VER=0.30.0 prtk)"
rm -f "$CURSOR_HOOKS"
assert_eq "rtk: shell hook missing" "repairable|none|shell_hook_missing|true" "$(prtk)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"},{"command":"lean-ctx hook rewrite"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk: lean-ctx rewrite present" "repairable|none|leanctx_rewrite_present|true" "$(prtk)"
echo '{"hooks":{"preToolUse":[{"command":"context-mode hook cursor pretooluse"},{"command":"rtk hook cursor"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk: hook order wrong" "repairable|none|hook_order_wrong|true" "$(prtk)"
echo '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}' >"$CURSOR_HOOKS"
assert_eq "rtk: ready (vendor doctor skipped by flag)" "ready|full|vendor_skip|false" "$(prtk)"
unset RT_SKIP_VENDOR_DOCTOR
assert_eq "rtk: ready (doctor unavailable)" "ready|full|vendor_skip|false" "$(prtk)"
hr_bin rtk 'case "$*" in "gain --help") exit 0;; --version) echo "rtk 0.42.5";; help) echo "  doctor";; "doctor --help") echo usage;; doctor*) exit 0;; *) exit 0;; esac'
assert_eq "rtk: ready (doctor passes)" "ready|full||false" "$(prtk)"
hr_bin rtk 'case "$*" in "gain --help") exit 0;; --version) echo "rtk 0.42.5";; help) echo "  doctor";; "doctor --help") echo usage;; doctor*) exit 1;; *) exit 0;; esac'
assert_eq "rtk: doctor failing" "repairable|none|vendor_doctor_failed|true" "$(prtk)"
export RT_SKIP_VENDOR_DOCTOR=1

# repair
hr_bin rtk 'exit 0'
RT_MODE=verify
assert_eq "rtk repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_rtk)"
export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all
: >"$HR_LOG"
out="$(rt_repair_rtk 2>/dev/null)"
assert_eq "rtk repair (cursor): optimizer and hook patch" '{"actions":["optimize_rtk_context_mode","patch_hooks"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
assert_contains "rtk repair: optimizer arguments" "$(cat "$HR_LOG")" "optimize-rtk-context-mode --host cursor --project-root $HR_PROJ --skip-cm-doctor | batch= progress="
assert_contains "rtk repair: only rtk patched" "$(cat "$HR_LOG")" "RT_PATCH_RTK=1"
: >"$HR_LOG"
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_rtk 2>/dev/null)"
assert_eq "rtk repair (batch): optimizer only" '{"actions":["optimize_rtk_context_mode"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
assert_contains "rtk repair (batch): nested installer guarded and rtk init skipped" "$(cat "$HR_LOG")" "--skip-cm-doctor --skip-rtk-init | batch=1 progress=1"
out="$(HR_SH_RC_optimize_rtk_context_mode=1 HR_PY_RC_patch_hooks=1 rt_repair_rtk 2>/dev/null)"
assert_eq "rtk repair: failures recorded" '{"actions":[],"failures":["optimize_rtk_failed","patch_hooks_failed"],"restart_required":false}' "$(jq -c . <<<"$out")"
out="$(HR_SH_RC_optimize_rtk_context_mode=1 RT_CROSS_TOOL_BATCH=1 rt_repair_rtk 2>/dev/null)"
assert_eq "rtk repair (batch): optimizer failure" '{"actions":[],"failures":["optimize_rtk_failed"],"restart_required":false}' "$(jq -c . <<<"$out")"
H claude
out="$(rt_repair_rtk 2>/dev/null)"
assert_eq "rtk repair (claude): no cursor hook patch" '{"actions":["optimize_rtk_context_mode"],"failures":[],"restart_required":false}' "$(jq -c . <<<"$out")"
H cursor
mv "$HR_STAGE/scripts/optimize-rtk-context-mode.sh" "$HR_STAGE/scripts/opt.off"; mv "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.py" "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.off"
assert_eq "rtk repair: nothing to run without helper scripts" '{"actions":[],"failures":[],"restart_required":false}' "$(rt_repair_rtk 2>/dev/null | jq -c .)"
mv "$HR_STAGE/scripts/opt.off" "$HR_STAGE/scripts/optimize-rtk-context-mode.sh"; mv "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.off" "$HR_STAGE/scripts/lib/global-toolstack/patch-hooks.py"
RT_MODE=apply

# ================================================================== LeanCTX
write_leanctx() { # <host> <overlap=1|0> <prefix=1|0>
  local host="$1" ov="$2" pre="$3" env_json
  env_json="$(jq -nc --arg ov "$ov" --arg pre "$pre" '
    (if $pre == "1" then {LEANCTX_MCP_TOOL_PREFIX:"lctx_"} else {} end)
    + (if $ov == "1" then {LEANCTX_DISABLE_SHELL_MCP:"1",LEANCTX_DISABLE_SANDBOX_MCP:"1",LEANCTX_DISABLE_FETCH_MCP:"1",LEANCTX_DISABLE_FTS:"1"} else {} end)')"
  case "$host" in
    cursor) jq -n --argjson e "$env_json" '{mcpServers:{leanctx:{command:"lean-ctx",env:$e}}}' >"$HOME/.cursor/mcp.json" ;;
    claude) jq -n --argjson e "$env_json" '{mcpServers:{"lean-ctx":{command:"lean-ctx",env:$e}}}' >"$HOME/.claude.json" ;;
    opencode) jq -n --argjson e "$env_json" '{mcp:{leanctx:{environment:$e}}}' >"$HOME/.config/opencode/opencode.json" ;;
    codex)
      { echo '[mcp_servers.leanctx]'; echo 'command = "lean-ctx"'
        jq -r 'to_entries[] | "\(.key) = \"\(.value)\""' <<<"$env_json"; } >"$CODEX_HOME_DIR/config.toml" ;;
    pi)
      jq -n --argjson e "$env_json" '{env:$e,disableTools:["ctx_shell"]}' >"$PI_LEAN"
      echo '{"servers":{"leanctx":{"enabled":true}}}' >"$PI_DIR/extensions/silver-bullet-five-tool-stack/config.json" ;;
  esac
}
rm -f "$HOME/.cursor/mcp.json" "$HOME/.claude.json" "$CODEX_HOME_DIR/config.toml" "$HOME/.config/opencode/opencode.json" "$PI_LEAN"
for h in cursor claude codex opencode pi; do
  H "$h"
  assert_eq "leanctx mcp file ($h)" "$(rt_host_mcp_config_path "$h")" "$(rt_leanctx_mcp_file)"
  assert_eq "leanctx mcp ($h): not configured" "1" "$(rc_of rt_probe_leanctx_mcp)"
  assert_eq "leanctx prefix ($h): no config" "1" "$(rc_of rt_probe_leanctx_lctx_prefix)"
  assert_eq "leanctx overlaps ($h): no config" "1" "$(rc_of rt_probe_leanctx_overlaps_disabled)"
  assert_eq "leanctx env ($h): no config" "1" "$(rc_of rt_leanctx_mcp_env LEANCTX_X)"
  write_leanctx "$h" 1 1
  assert_eq "leanctx mcp ($h): configured" "0" "$(rc_of rt_probe_leanctx_mcp)"
  assert_eq "leanctx prefix ($h): lctx_" "0" "$(rc_of rt_probe_leanctx_lctx_prefix)"
  assert_eq "leanctx overlaps ($h): all disabled" "0" "$(rc_of rt_probe_leanctx_overlaps_disabled)"
  assert_eq "leanctx env ($h): value" "lctx_" "$(rt_leanctx_mcp_env LEANCTX_MCP_TOOL_PREFIX)"
  write_leanctx "$h" 0 0
  assert_eq "leanctx prefix ($h): missing" "1" "$(rc_of rt_probe_leanctx_lctx_prefix)"
  assert_eq "leanctx overlaps ($h): enabled" "1" "$(rc_of rt_probe_leanctx_overlaps_disabled)"
done
H cursor; assert_eq "leanctx env: empty key" "1" "$(rc_of rt_leanctx_mcp_env "")"
H pi; rm -f "$PI_LEAN"; assert_eq "leanctx env (pi): no extension config" "1" "$(rc_of rt_leanctx_mcp_env LEANCTX_X)"
H goose; assert_eq "leanctx mcp: other hosts" "1" "$(rc_of rt_probe_leanctx_mcp)"
H pi; write_leanctx pi 1 1
echo '{"env":{"LEANCTX_DISABLE_SHELL_MCP":"1","LEANCTX_DISABLE_SANDBOX_MCP":"1","LEANCTX_DISABLE_FETCH_MCP":"1","LEANCTX_DISABLE_FTS":"1"},"disableTools":[]}' >"$PI_LEAN"
assert_eq "leanctx overlaps (pi): ctx_shell must be disabled too" "1" "$(rc_of rt_probe_leanctx_overlaps_disabled)"
rm -f "$PI_LEAN"; assert_eq "leanctx overlaps (pi): no config" "1" "$(rc_of rt_probe_leanctx_overlaps_disabled)"

# duplicate mcp keys
dup() { rc_of rt_probe_leanctx_duplicate_mcp; }
H cursor; rm -f "$HOME/.cursor/mcp.json"; assert_eq "duplicates: no file" "1" "$(dup)"
echo '{"mcpServers":{"leanctx":{},"lean-ctx":{}}}' >"$HOME/.cursor/mcp.json"; assert_eq "duplicates (cursor): both keys" "0" "$(dup)"
echo '{"mcpServers":{"leanctx":{}}}' >"$HOME/.cursor/mcp.json"; assert_eq "duplicates (cursor): single key" "1" "$(dup)"
H codex; printf '[mcp_servers.leanctx]\n[mcp_servers.lean-ctx]\n' >"$CODEX_HOME_DIR/config.toml"; assert_eq "duplicates (codex): both tables" "0" "$(dup)"
printf '[mcp_servers.leanctx]\n' >"$CODEX_HOME_DIR/config.toml"; assert_eq "duplicates (codex): single table" "1" "$(dup)"
H opencode; echo '{"mcp":{"leanctx":{},"user-lean-ctx":{}}}' >"$HOME/.config/opencode/opencode.json"; assert_eq "duplicates (opencode): both keys" "0" "$(dup)"
echo '{"mcp":{"leanctx":{}}}' >"$HOME/.config/opencode/opencode.json"; assert_eq "duplicates (opencode): single key" "1" "$(dup)"
H pi; write_leanctx pi 1 1; assert_eq "duplicates (pi): never" "1" "$(dup)"

# version
hr_bin lean-ctx 'case "$1" in --version) echo "lean-ctx ${LC_VER:-3.12.0}";; esac; exit 0'
assert_eq "version int" "3012000" "$(rt_leanctx_version_int 3.12)"
assert_eq "version int with suffix" "3009009" "$(rt_leanctx_version_int 3.9.9-beta1)"
assert_eq "version int (single component)" "4000000" "$(rt_leanctx_version_int 4)"
assert_eq "version ok (default minimum)" "0" "$(rc_of rt_probe_leanctx_version_ok "")"
assert_eq "version too old" "1" "$(LC_VER=3.9.8 rc_of rt_probe_leanctx_version_ok "")"
printf '{"recommended_tools":{"leanctx":{"min_version":"3.13.0"}}}\n' >"$TL_TMP/lc-cfg.json"
assert_eq "version below configured minimum" "1" "$(rc_of rt_probe_leanctx_version_ok "$TL_TMP/lc-cfg.json")"
printf 'garbage' >"$TL_TMP/lc-bad.json"
assert_eq "invalid config falls back to the default minimum" "0" "$(rc_of rt_probe_leanctx_version_ok "$TL_TMP/lc-bad.json")"
hr_bin lean-ctx 'echo "no version here"'
assert_eq "unparsable version" "1" "$(rc_of rt_probe_leanctx_version_ok "")"
hr_bin lean-ctx 'exit 1'
assert_eq "failing --version" "1" "$(rc_of rt_probe_leanctx_version_ok "")"
assert_eq "no binary" "1" "$(PATH="$(hr_path_without lean-ctx)" rc_of rt_probe_leanctx_version_ok "")"
hr_bin lean-ctx 'case "$1" in --version) echo "lean-ctx 3.12.0";; esac; exit 0'

# vendor doctor
RT_MODE=verify
unset RT_SKIP_VENDOR_DOCTOR
hr_bin lean-ctx 'case "$*" in
  --version) echo "lean-ctx 3.12.0" ;;
  "doctor --help") echo "${LC_DOC_HELP:-usage: lean-ctx doctor}" ;;
  doctor*) echo "lean-ctx $*" >>"$HR_LOG"; exit "${LC_DOC_RC:-0}" ;;
esac'
cfg=""
assert_eq "leanctx doctor: skip flag" "2" "$(RT_SKIP_VENDOR_DOCTOR=1 vdr rt_probe_leanctx_vendor_doctor)"
assert_eq "leanctx doctor: explicit command" "0" "$(RT_LEANCTX_DOCTOR_CMD="true" vdr rt_probe_leanctx_vendor_doctor)"
assert_eq "leanctx doctor: explicit command fails" "1" "$(RT_LEANCTX_DOCTOR_CMD="false" vdr rt_probe_leanctx_vendor_doctor)"
assert_eq "leanctx doctor: plain" "0" "$(vdr rt_probe_leanctx_vendor_doctor)"
assert_contains "leanctx doctor: plain argv" "$(cat "$HR_LOG")" "lean-ctx doctor"
LC_DOC_HELP="--non-interactive" vdr rt_probe_leanctx_vendor_doctor >/dev/null
assert_contains "leanctx doctor: --non-interactive" "$(cat "$HR_LOG")" "lean-ctx doctor --non-interactive"
LC_DOC_HELP="--yes" vdr rt_probe_leanctx_vendor_doctor >/dev/null
assert_contains "leanctx doctor: --yes" "$(cat "$HR_LOG")" "lean-ctx doctor --yes"
assert_eq "leanctx doctor: failing" "1" "$(LC_DOC_RC=2 vdr rt_probe_leanctx_vendor_doctor)"
hr_bin lean-ctx 'case "$*" in "doctor --help") echo "unknown command"; exit 1;; esac'
assert_eq "leanctx doctor: no doctor subcommand" "2" "$(vdr rt_probe_leanctx_vendor_doctor)"
# configured cli_command is honoured
hr_bin my-lc 'case "$*" in "doctor --help") echo usage;; doctor*) echo "my-lc $*" >>"$HR_LOG";; esac'
printf '{"recommended_tools":{"leanctx":{"cli_command":"my-lc"}}}\n' >"$TL_TMP/lc-cli.json"
cfg="$TL_TMP/lc-cli.json"; : >"$HR_LOG"
rt_probe_leanctx_vendor_doctor || true
assert_contains "leanctx doctor: custom cli command" "$(cat "$HR_LOG")" "my-lc doctor"
cfg=""
# without the gate helpers there is no binary to find
assert_eq "leanctx doctor: gate helpers unavailable -> default binary name" "0" "$( (unset -f sb_leanctx_cli_command sb_leanctx_cli_path; hr_bin lean-ctx 'case "$*" in "doctor --help") echo usage;; esac'; rc_of rt_probe_leanctx_vendor_doctor) )"
assert_eq "leanctx doctor: unresolvable binary -> skip" "2" "$( (sb_leanctx_cli_path() { return 1; }; vdr rt_probe_leanctx_vendor_doctor) )"
export RT_SKIP_VENDOR_DOCTOR=1

# probe table
RT_MODE=verify
hr_bin lean-ctx 'case "$1" in --version) echo "lean-ctx ${LC_VER:-3.12.0}";; esac; exit 0'
plc() { hr_state "$(rt_probe_leanctx)"; }
H goose; assert_eq "leanctx: unsupported host" "unsupported|none||false" "$(plc)"; H cursor
hr_consent leanctx=disabled; assert_eq "leanctx: disabled" "disabled|none||false" "$(plc)"
hr_consent; assert_eq "leanctx: pending" "pending|none||false" "$(plc)"
hr_consent leanctx=suspended; assert_eq "leanctx: suspended" "suspended|none||false" "$(plc)"
hr_consent leanctx=enabled
assert_eq "leanctx: cli missing" "failed|none|cli_missing|true" "$(PATH="$(hr_path_without lean-ctx)" plc)"
echo '{"mcpServers":{"leanctx":{},"lean-ctx":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "leanctx: duplicate keys" "failed|none|duplicate_mcp_keys,duplicate_key|true" "$(plc)"
write_leanctx cursor 1 1
assert_eq "leanctx: version too old" "repairable|none|min_version|true" "$(LC_VER=3.1.0 plc)"
rm -f "$HOME/.cursor/mcp.json"
assert_eq "leanctx: mcp not configured" "repairable|partial|mcp_not_configured|true" "$(plc)"
write_leanctx cursor 1 0
assert_eq "leanctx: prefix missing" "repairable|none|lctx_prefix_missing|true" "$(plc)"
write_leanctx cursor 0 1
assert_eq "leanctx: overlaps enabled" "repairable|none|overlap_surfaces_enabled|true" "$(plc)"
write_leanctx cursor 1 1
assert_eq "leanctx: ready (doctor skipped by flag)" "ready|full|vendor_skip|false" "$(plc)"
unset RT_SKIP_VENDOR_DOCTOR
hr_bin lean-ctx 'case "$*" in --version) echo "lean-ctx 3.12.0";; "doctor --help") echo usage;; doctor*) exit "${LC_DOC_RC:-0}";; esac'
assert_eq "leanctx: ready (doctor passes)" "ready|full||false" "$(plc)"
assert_eq "leanctx: doctor failing" "repairable|none|vendor_doctor_failed|true" "$(LC_DOC_RC=1 plc)"
hr_bin lean-ctx 'case "$*" in --version) echo "lean-ctx 3.12.0";; "doctor --help") echo "unknown command"; exit 1;; esac'
assert_eq "leanctx: doctor unavailable" "ready|full|vendor_skip|false" "$(plc)"
export RT_SKIP_VENDOR_DOCTOR=1

# repair
hr_bin lean-ctx 'exit 0'
RT_MODE=verify
assert_eq "leanctx repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_leanctx)"
export RT_MODE=apply
: >"$HR_LOG"
out="$(rt_repair_leanctx 2>/dev/null)"
assert_eq "leanctx repair: installer ran" '{"actions":["install_leanctx_sb"],"failures":[],"restart_required":true}' "$(jq -c . <<<"$out")"
assert_contains "leanctx repair: installer arguments" "$(cat "$HR_LOG")" "install-leanctx-sb --host cursor --project-root $HR_PROJ |"
: >"$HR_LOG"; RT_CROSS_TOOL_BATCH=1 rt_repair_leanctx >/dev/null 2>&1
assert_contains "leanctx repair (batch): merge skipped" "$(cat "$HR_LOG")" "--skip-merge"
out="$(HR_SH_RC_install_leanctx_sb=1 rt_repair_leanctx 2>/dev/null)"
assert_eq "leanctx repair: installer failure" '{"actions":[],"failures":["install_leanctx_failed"],"restart_required":true}' "$(jq -c . <<<"$out")"
mv "$HR_STAGE/scripts/install-leanctx-sb.sh" "$HR_STAGE/scripts/install.off"
assert_eq "leanctx repair: no installer" '{"actions":[],"failures":[],"restart_required":false}' "$(rt_repair_leanctx 2>/dev/null | jq -c .)"
mv "$HR_STAGE/scripts/install.off" "$HR_STAGE/scripts/install-leanctx-sb.sh"

tl_results
