#!/usr/bin/env bash
# scripts/lib/recommended-tools/{probe-context-mode,probe-alumnium,probe-search_cli}.sh:
# decision tables, per-host wiring readers, vendor doctor selection and repairs.
# node, npm, brew, search, alumnium, context-mode are stubs; nothing is installed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/common.sh"
rt_init_paths
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-context-mode.sh"
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-alumnium.sh"
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-search_cli.sh"
export RT_HOST=cursor RT_SKIP_VENDOR_DOCTOR=1 RT_MODE=verify RT_VENDOR_DOCTOR_TIMEOUT=10
hr_bin sleep 'exit 0'
H() { RT_HOST="$1"; }
vdr() { local rc=0; : >"$HR_LOG"; "$@" >/dev/null 2>&1 || rc=$?; printf '%s' "$rc"; }

PI_DIR="$HOME/.pi/agent"
CODEX_HOME_DIR="$(sb_runtime_codex_home)"
mkdir -p "$HOME/.cursor" "$CODEX_HOME_DIR" "$HOME/.config/opencode" "$PI_DIR/extensions/silver-bullet-five-tool-stack" "$HOME/.claude"

# ============================================================== context mode mcp
rm -f "$HOME/.cursor/mcp.json"
assert_eq "cm mcp (cursor): no config" "1" "$(rc_of rt_probe_context_mode_mcp)"
echo '{"mcpServers":{"context-mode":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "cm mcp (cursor): context-mode" "0" "$(rc_of rt_probe_context_mode_mcp)"
echo '{"mcpServers":{"user-context-mode":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "cm mcp (cursor): user-context-mode" "0" "$(rc_of rt_probe_context_mode_mcp)"
echo '{"mcpServers":{}}' >"$HOME/.cursor/mcp.json"
assert_eq "cm mcp (cursor): absent" "1" "$(rc_of rt_probe_context_mode_mcp)"
H claude
assert_eq "cm mcp (claude): nothing" "1" "$(rc_of rt_probe_context_mode_mcp)"
mkdir -p "$HOME/.claude/plugins/context-mode"
assert_eq "cm mcp (claude): plugin dir" "0" "$(rc_of rt_probe_context_mode_mcp)"
rm -rf "$HOME/.claude/plugins"
echo '{"mcpServers":{"context-mode":{}}}' >"$HOME/.claude.json"
assert_eq "cm mcp (claude): mcp entry" "0" "$(rc_of rt_probe_context_mode_mcp)"
H codex; printf '[mcp_servers.context-mode]\n' >"$CODEX_HOME_DIR/config.toml"
assert_eq "cm mcp (codex)" "0" "$(rc_of rt_probe_context_mode_mcp)"
H opencode; echo '{"plugin":["context-mode"]}' >"$HOME/.config/opencode/opencode.json"
assert_eq "cm mcp (opencode)" "0" "$(rc_of rt_probe_context_mode_mcp)"
H pi; echo '{"servers":{"context_mode":{"enabled":true}}}' >"$PI_DIR/extensions/silver-bullet-five-tool-stack/config.json"
assert_eq "cm mcp (pi)" "0" "$(rc_of rt_probe_context_mode_mcp)"
H goose; assert_eq "cm mcp: other hosts" "1" "$(rc_of rt_probe_context_mode_mcp)"
H cursor

# vendor doctor
unset RT_SKIP_VENDOR_DOCTOR
hr_bin context-mode 'echo "context-mode $* platform=${CONTEXT_MODE_PLATFORM:-}" >>"$HR_LOG"; exit "${CM_RC:-0}"'
assert_eq "cm doctor: explicit command" "0" "$(RT_CONTEXT_MODE_DOCTOR_CMD="true" vdr rt_probe_context_mode_vendor_doctor)"
assert_eq "cm doctor: explicit command fails" "1" "$(RT_CONTEXT_MODE_DOCTOR_CMD="false" vdr rt_probe_context_mode_vendor_doctor)"
assert_eq "cm doctor: real binary passes" "0" "$(vdr rt_probe_context_mode_vendor_doctor)"
assert_contains "cm doctor: platform follows the host" "$(cat "$HR_LOG")" "context-mode doctor platform=cursor"
assert_eq "cm doctor: failing" "1" "$(CM_RC=1 vdr rt_probe_context_mode_vendor_doctor)"
assert_eq "cm doctor: no binary -> skip" "2" "$(PATH="$(hr_path_without context-mode)" vdr rt_probe_context_mode_vendor_doctor)"
export RT_SKIP_VENDOR_DOCTOR=1

# probe table
hr_bin node 'echo "v${NODE_VER:-22.9.0}"'
hr_bin context-mode 'exit "${CM_RC:-0}"'
pcm() { hr_state "$(rt_probe_context_mode)"; }
H goose; assert_eq "cm: unsupported host" "unsupported|none||false" "$(pcm)"; H cursor
hr_consent context_mode=disabled; assert_eq "cm: disabled" "disabled|none||false" "$(pcm)"
hr_consent; assert_eq "cm: pending" "pending|none||false" "$(pcm)"
hr_consent context_mode=suspended; assert_eq "cm: suspended" "suspended|none||false" "$(pcm)"
hr_consent context_mode=enabled
assert_eq "cm: node too old" "failed|none|node_version,min_version|true" "$(NODE_VER=18.1.0 pcm)"
assert_eq "cm: node missing" "failed|none|node_version,min_version|true" "$(PATH="$(hr_path_without node)" pcm)"
assert_eq "cm: cli missing" "repairable|none|cli_missing|true" "$(PATH="$(hr_path_without context-mode)" pcm)"
echo '{"mcpServers":{}}' >"$HOME/.cursor/mcp.json"
assert_eq "cm: mcp not configured" "repairable|partial|mcp_not_configured|true" "$(pcm)"
echo '{"mcpServers":{"context-mode":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "cm: instruction fragment missing" "repairable|none|instruction_fragment_missing|true" "$(pcm)"
printf '<!-- BEGIN context-mode hint (do not edit) -->\nuse ctx_execute\n<!-- END context-mode hint (do not edit) -->\n' >"$HR_PROJ/silver-bullet.md"
assert_eq "cm: ready (doctor skipped by flag)" "ready|full|vendor_skip|false" "$(pcm)"
unset RT_SKIP_VENDOR_DOCTOR
assert_eq "cm: ready (doctor passes)" "ready|full||false" "$(pcm)"
assert_eq "cm: doctor failing" "repairable|none|vendor_doctor_failed|true" "$(CM_RC=1 pcm)"
assert_eq "cm: doctor unavailable (no binary on PATH, plugin present)" "ready|full|vendor_skip|false" \
  "$(mkdir -p "$HOME/.claude/plugins/context-mode"; PATH="$(hr_path_without context-mode)" pcm)"
rm -rf "$HOME/.claude/plugins"
export RT_SKIP_VENDOR_DOCTOR=1

# repair
hr_bin npm 'echo "npm $*" >>"$HR_LOG"; exit "${NPM_RC:-0}"'
RT_MODE=verify
assert_eq "cm repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_context_mode)"
export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all
: >"$HR_LOG"
out="$(rt_repair_context_mode 2>/dev/null)"
assert_eq "cm repair: optimizer ran" '{"actions":["optimize_rtk_context_mode"],"failures":[],"restart_required":true}' "$(jq -c . <<<"$out")"
assert_contains "cm repair: optimizer arguments" "$(cat "$HR_LOG")" "optimize-rtk-context-mode --host cursor --project-root $HR_PROJ | batch= progress="
assert_not_contains "cm repair: cli present -> no npm" "$(cat "$HR_LOG")" "npm install"
: >"$HR_LOG"
out="$(RT_CROSS_TOOL_BATCH=1 rt_repair_context_mode 2>/dev/null)"
assert_contains "cm repair (batch): rtk init and doctor skipped, nested installer guarded" "$(cat "$HR_LOG")" "--skip-rtk-init --skip-cm-doctor | batch=1 progress=1"
out="$(HR_SH_RC_optimize_rtk_context_mode=1 rt_repair_context_mode 2>/dev/null)"
assert_eq "cm repair: optimizer failure" '{"actions":[],"failures":["optimize_failed"],"restart_required":true}' "$(jq -c . <<<"$out")"
out="$(HR_SH_RC_optimize_rtk_context_mode=1 RT_CROSS_TOOL_BATCH=1 rt_repair_context_mode 2>/dev/null)"
assert_contains "cm repair (batch): optimizer failure" "$(jq -c . <<<"$out")" '"optimize_failed"'
out="$(PATH="$(hr_path_without context-mode)" rt_repair_context_mode 2>/dev/null)"
assert_contains "cm repair: npm install when the cli is missing" "$(jq -c . <<<"$out")" '"npm_install_context_mode"'
out="$(NPM_RC=1 PATH="$(hr_path_without context-mode)" rt_repair_context_mode 2>/dev/null)"
assert_contains "cm repair: npm failure" "$(jq -c . <<<"$out")" '"npm_install_failed"'
mv "$HR_STAGE/scripts/optimize-rtk-context-mode.sh" "$HR_STAGE/scripts/opt.off"
assert_eq "cm repair: no optimizer" '{"actions":[],"failures":[],"restart_required":false}' "$(rt_repair_context_mode 2>/dev/null | jq -c .)"
mv "$HR_STAGE/scripts/opt.off" "$HR_STAGE/scripts/optimize-rtk-context-mode.sh"
RT_MODE=verify

# ==================================================================== alumnium
rm -f "$HOME/.cursor/mcp.json"
assert_eq "alumnium cli: missing" "1" "$(PATH="$(hr_path_without alumnium)" rc_of rt_probe_alumnium_cli)"
hr_bin alumnium 'exit 0'
assert_eq "alumnium cli: present" "0" "$(rc_of rt_probe_alumnium_cli)"
assert_eq "alumnium mcp (cursor): no config" "1" "$(rc_of rt_probe_alumnium_mcp)"
echo '{"mcpServers":{"alumnium":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "alumnium mcp (cursor): alumnium" "0" "$(rc_of rt_probe_alumnium_mcp)"
echo '{"mcpServers":{"user-alumnium":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "alumnium mcp (cursor): user-alumnium" "0" "$(rc_of rt_probe_alumnium_mcp)"
echo '{"mcpServers":{}}' >"$HOME/.cursor/mcp.json"
assert_eq "alumnium mcp (cursor): absent" "1" "$(rc_of rt_probe_alumnium_mcp)"
H claude; echo '{"mcpServers":{"alumnium":{}}}' >"$HOME/.claude.json"
assert_eq "alumnium mcp (claude)" "0" "$(rc_of rt_probe_alumnium_mcp)"
H codex; printf '[mcp_servers.alumnium]\n' >"$CODEX_HOME_DIR/config.toml"
assert_eq "alumnium mcp (codex)" "0" "$(rc_of rt_probe_alumnium_mcp)"
H opencode; assert_eq "alumnium mcp: unsupported hosts" "1" "$(rc_of rt_probe_alumnium_mcp)"
H cursor

unset RT_SKIP_VENDOR_DOCTOR
hr_bin alumnium 'case "$*" in
  "doctor --help") echo "${AL_HELP:-usage: alumnium doctor}" ;;
  doctor*) echo "alumnium $*" >>"$HR_LOG"; exit "${AL_RC:-0}" ;;
esac'
assert_eq "alumnium doctor: skip flag" "2" "$(RT_SKIP_VENDOR_DOCTOR=1 vdr rt_probe_alumnium_vendor_doctor)"
assert_eq "alumnium doctor: explicit command" "0" "$(RT_ALUMNIUM_DOCTOR_CMD="true" vdr rt_probe_alumnium_vendor_doctor)"
assert_eq "alumnium doctor: explicit command fails" "1" "$(RT_ALUMNIUM_DOCTOR_CMD="false" vdr rt_probe_alumnium_vendor_doctor)"
assert_eq "alumnium doctor: plain" "0" "$(vdr rt_probe_alumnium_vendor_doctor)"
assert_contains "alumnium doctor: plain argv" "$(cat "$HR_LOG")" "alumnium doctor"
AL_HELP="--non-interactive" vdr rt_probe_alumnium_vendor_doctor >/dev/null
assert_contains "alumnium doctor: --non-interactive" "$(cat "$HR_LOG")" "alumnium doctor --non-interactive"
AL_HELP="--yes" vdr rt_probe_alumnium_vendor_doctor >/dev/null
assert_contains "alumnium doctor: --yes" "$(cat "$HR_LOG")" "alumnium doctor --yes"
assert_eq "alumnium doctor: failing" "1" "$(AL_RC=1 vdr rt_probe_alumnium_vendor_doctor)"
assert_eq "alumnium doctor: no binary" "2" "$(PATH="$(hr_path_without alumnium)" vdr rt_probe_alumnium_vendor_doctor)"
hr_bin alumnium 'case "$*" in "doctor --help") echo "unknown command"; exit 1;; esac'
assert_eq "alumnium doctor: subcommand not usable" "2" "$(vdr rt_probe_alumnium_vendor_doctor)"
export RT_SKIP_VENDOR_DOCTOR=1

hr_bin alumnium 'exit 0'
pal() { hr_state "$(rt_probe_alumnium)"; }
H goose; assert_eq "alumnium: unsupported host" "unsupported|none||false" "$(pal)"; H cursor
hr_consent alumnium=disabled; assert_eq "alumnium: disabled" "disabled|none||false" "$(pal)"
hr_consent; assert_eq "alumnium: pending" "pending|none||false" "$(pal)"
hr_consent alumnium=suspended; assert_eq "alumnium: suspended" "suspended|none||false" "$(pal)"
hr_consent alumnium=enabled
assert_eq "alumnium: cli missing" "failed|none|cli_missing|true" "$(PATH="$(hr_path_without alumnium)" pal)"
echo '{"mcpServers":{}}' >"$HOME/.cursor/mcp.json"
assert_eq "alumnium: mcp not configured" "repairable|partial|mcp_not_configured|true" "$(pal)"
echo '{"mcpServers":{"alumnium":{}}}' >"$HOME/.cursor/mcp.json"
assert_eq "alumnium: ready (doctor skipped)" "ready|full|vendor_skip|false" "$(pal)"
unset RT_SKIP_VENDOR_DOCTOR
hr_bin alumnium 'case "$*" in "doctor --help") echo usage;; doctor*) exit "${AL_RC:-0}";; esac'
assert_eq "alumnium: ready (doctor passes)" "ready|full||false" "$(pal)"
assert_eq "alumnium: doctor failing" "repairable|none|vendor_doctor_failed|true" "$(AL_RC=1 pal)"
export RT_SKIP_VENDOR_DOCTOR=1
assert_eq "alumnium repair is never automatic" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_alumnium)"

# ================================================================== search-cli
assert_eq "search pin version" "0.9.0" "$(rt_search_cli_pin_version)"
assert_eq "search pin argv" "brew tap paperfoot/tap && brew install paperfoot/tap/search-cli" "$(rt_search_cli_pin_argv)"
assert_eq "search pin version falls back without the registry" "0.9.0" "$( (unset -f sb_recommended_tool_install_pin; rt_search_cli_pin_version) )"
assert_eq "search pin argv empty without the registry" "" "$( (unset -f sb_recommended_tool_install_pin; rt_search_cli_pin_argv) )"
assert_eq "parse version" "1.2.3" "$(rt_search_cli_parse_version "search v1.2.3 (abc)")"
assert_eq "parse version (two parts)" "0.9" "$(rt_search_cli_parse_version "search 0.9")"
assert_eq "parse version: none" "" "$(rt_search_cli_parse_version "garbage")"
assert_eq "parse version: empty" "" "$(rt_search_cli_parse_version)"
assert_eq "version int" "1002003" "$(rt_search_cli_version_int 1.2.3)"
assert_eq "version int (suffix)" "1002000" "$(rt_search_cli_version_int 1.2-rc1)"
assert_eq "version int (major only)" "5000000" "$(rt_search_cli_version_int 5)"

hr_bin brew 'exit 0'
hr_bin uname 'echo "${FAKE_UNAME:-Darwin}"'
assert_eq "package manager: forced unsupported" "1" "$(RT_SEARCH_CLI_FORCE_UNSUPPORTED=1 rc_of rt_search_cli_package_manager_supported)"
assert_eq "package manager: macOS with brew" "0" "$(rc_of rt_search_cli_package_manager_supported)"
assert_eq "package manager: not macOS" "1" "$(FAKE_UNAME=Linux rc_of rt_search_cli_package_manager_supported)"
assert_eq "package manager: no brew" "1" "$(PATH="$(hr_path_without brew)" rc_of rt_search_cli_package_manager_supported)"
hr_nobin uname

hr_bin search 'case "$*" in
  --version) echo "search ${SEARCH_VER:-0.9.0}" ;;
  "config check") echo "${SEARCH_PROVIDERS:-exa: set}" ;;
esac'
assert_eq "search cli: present" "0" "$(rc_of rt_probe_search_cli_cli)"
assert_eq "search cli: missing" "1" "$(PATH="$(hr_path_without search)" rc_of rt_probe_search_cli_cli)"
assert_eq "search version" "0.9.0" "$(rt_probe_search_cli_version)"
assert_eq "search providers: set" "0" "$(rc_of rt_probe_search_cli_providers)"
assert_eq "search providers: ok marker" "0" "$(SEARCH_PROVIDERS="brave ok" rc_of rt_probe_search_cli_providers)"
assert_eq "search providers: configured marker" "0" "$(SEARCH_PROVIDERS="2 providers configured" rc_of rt_probe_search_cli_providers)"
assert_eq "search providers: none" "1" "$(SEARCH_PROVIDERS="exa: missing" rc_of rt_probe_search_cli_providers)"
hr_bin search 'exit 3'
assert_eq "search version: failing --version yields nothing" "" "$(rt_probe_search_cli_version)"
assert_eq "search providers: failing config check" "1" "$(rc_of rt_probe_search_cli_providers)"
hr_bin search 'case "$*" in --version) echo "search ${SEARCH_VER:-0.9.0}" ;; "config check") echo "${SEARCH_PROVIDERS:-exa: set}" ;; esac'

hr_project '{"sb_initiated":true,"recommended_tools":{"search_cli":{"enabled_by_user":true,"install_commands":["brew tap x","brew install y"]}}}'
assert_eq "search project install commands" "brew tap x && brew install y" "$(rt_search_cli_project_install_commands)"
assert_eq "search project install commands: none configured" "" "$(hr_consent search_cli=enabled; rt_search_cli_project_install_commands)"
assert_eq "search project install commands: no project" "" "$(RT_PROJECT_ROOT="$TL_TMP/nocfg" rt_search_cli_project_install_commands)"

hr_bin uname 'echo "${FAKE_UNAME:-Darwin}"'
psc() { hr_state "$(rt_probe_search_cli)"; }
hr_consent search_cli=disabled; assert_eq "search: disabled" "disabled|none||false" "$(psc)"
hr_consent; assert_eq "search: pending" "pending|none||false" "$(psc)"
hr_consent search_cli=suspended; assert_eq "search: suspended" "suspended|none||false" "$(psc)"
hr_consent search_cli=enabled
assert_eq "search: missing cli, brew available" "repairable|none|missing_cli|true" "$(PATH="$(hr_path_without search)" psc)"
assert_eq "search: missing cli, no brew" "failed|none|missing_cli,unsupported_package_manager|false" "$(FAKE_UNAME=Linux PATH="$(hr_path_without search)" psc)"
assert_eq "search: version unproved" "failed|none|version_unproved|false" "$(hr_bin search 'exit 0'; psc)"
hr_bin search 'case "$*" in --version) echo "search ${SEARCH_VER:-0.9.0}" ;; "config check") echo "${SEARCH_PROVIDERS:-exa: set}" ;; esac'
assert_eq "search: ready at the pinned version" "ready|full||false" "$(psc)"
assert_eq "search: older than the pin (repairable with brew)" "ready|full|version_drift|true" "$(SEARCH_VER=0.8.0 psc)"
assert_eq "search: older than the pin (no brew)" "ready|full|version_drift,unsupported_package_manager|false" "$(FAKE_UNAME=Linux SEARCH_VER=0.8.0 psc)"
assert_eq "search: newer than the pin" "ready|full|version_drift|false" "$(SEARCH_VER=1.0.0 psc)"
assert_eq "search: provider missing" "ready|full|provider_missing|false" "$(SEARCH_PROVIDERS="exa: missing" psc)"
assert_eq "search: no package manager noted once" "ready|full|unsupported_package_manager|false" "$(FAKE_UNAME=Linux psc)"

# repair
RT_MODE=verify
assert_eq "search repair: not authorized" '{"actions":[],"failures":["mutation_not_authorized"],"restart_required":false}' "$(rt_repair_search_cli)"
export RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all
# the pinned install runs through `bash -lc`; intercept it with a function (a PATH stub named bash would recurse)
bash() { echo "bash $*" >>"$HR_LOG"; return "${BASH_RC:-0}"; }
hr_project '{"sb_initiated":true,"recommended_tools":{"search_cli":{"enabled_by_user":true,"install_commands":["rm -rf /"]}}}'
assert_eq "search repair: project install commands that differ from the pin are refused" '{"actions":[],"failures":["install_pin_mismatch"],"restart_required":false}' "$(rt_repair_search_cli | jq -c .)"
hr_consent search_cli=enabled
hr_bin search 'case "$*" in --version) echo "search 1.0.0";; esac'
assert_eq "search repair: newer than the pin -> nothing to do" '{"actions":[],"failures":[],"restart_required":false}' "$(rt_repair_search_cli | jq -c .)"
hr_bin search 'case "$*" in --version) echo "search 0.8.0";; esac'
assert_eq "search repair: unsupported package manager" '{"actions":[],"failures":["unsupported_package_manager"],"restart_required":false}' "$(FAKE_UNAME=Linux rt_repair_search_cli | jq -c .)"
assert_eq "search repair: missing pin argv" '{"actions":[],"failures":["install_pin_missing"],"restart_required":false}' "$( (rt_search_cli_pin_argv() { :; }; rt_repair_search_cli) | jq -c .)"
: >"$HR_LOG"
assert_eq "search repair: pinned install" '{"actions":["brew_install_search_cli_pin"],"failures":[],"restart_required":false}' "$(rt_repair_search_cli 2>/dev/null | jq -c .)"
assert_contains "search repair: pin argv executed through a login shell" "$(cat "$HR_LOG")" "bash -lc brew tap paperfoot/tap && brew install paperfoot/tap/search-cli"
assert_eq "search repair: install failure" '{"actions":[],"failures":["brew_install_failed"],"restart_required":false}' "$(BASH_RC=1 rt_repair_search_cli 2>/dev/null | jq -c .)"
hr_project '{"sb_initiated":true,"recommended_tools":{"search_cli":{"enabled_by_user":true,"install_commands":["brew tap paperfoot/tap","brew install paperfoot/tap/search-cli"]}}}'
assert_eq "search repair: project commands equal to the pin (split over several entries) are accepted" '{"actions":["brew_install_search_cli_pin"],"failures":[],"restart_required":false}' "$(rt_repair_search_cli 2>/dev/null | jq -c .)"

unset -f bash
tl_results
