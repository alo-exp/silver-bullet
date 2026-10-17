#!/usr/bin/env bash
# Behavior tests for hooks/lib/rtk-gate.sh, rtk-compat.sh and rtk-cm-global.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
unset RTK_DISABLED SILVER_BULLET SB_RTK_COMPAT_MODE SB_RTK_COMPAT_ENABLED SB_RTK_HOOK_ARTIFACT SB_GLOBAL_TOOLSTACK_MANIFEST SB_GLOBAL_TOOLSTACK_HOME

# shellcheck source=../../hooks/lib/rtk-gate.sh
source "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"

CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }

# ---------- rtk-gate: required / min_version ----------
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"min_version":"1.2.3"}}}'
yes_t "rtk required" sb_rtk_required "$CFG"
assert_eq "min_version from config" "1.2.3" "$(sb_rtk_min_version "$CFG")"
assert_eq "min_version default without config" "0.42.0" "$(sb_rtk_min_version)"
assert_eq "min_version default for missing file" "0.42.0" "$(sb_rtk_min_version "$TL_TMP/none.json")"
w '{"recommended_tools":{}}'
assert_eq "min_version default when key absent" "0.42.0" "$(sb_rtk_min_version "$CFG")"
w 'not json'
assert_eq "min_version default on invalid json" "0.42.0" "$(sb_rtk_min_version "$CFG")"

# ---------- cli path ----------
rm -rf "$TL_BIN"/rtk
PATH_NO_RTK="$(tl_path_without rtk)"
no_t "cli_path none" env PATH="$PATH_NO_RTK" bash -c 'source "$1"; sb_rtk_cli_path' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/rtk"; chmod +x "$HOME/.local/bin/rtk"
assert_eq "cli_path from ~/.local/bin" "$HOME/.local/bin/rtk" "$(PATH="$PATH_NO_RTK" sb_rtk_cli_path)"
rm -f "$HOME/.local/bin/rtk"
# rtk-stub behavior driven by env
tl_stub rtk 'case "$1" in
  gain) exit "${RTK_STUB_GAIN:-0}" ;;
  --help) printf "%s\n" "${RTK_STUB_HELP:-rtk help}" ;;
  --version) printf "%s\n" "${RTK_STUB_VERSION:-rtk 0.42.1}" ;;
esac'
hash -r
assert_eq "cli_path from PATH" "$TL_BIN/rtk" "$(sb_rtk_cli_path)"
# manifest wins over PATH
OTHER="$TL_TMP/manifest-rtk"; printf '#!/bin/sh\nexit 0\n' >"$OTHER"; chmod +x "$OTHER"
export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/manifest.json"
jq -n --arg c "$OTHER" '{tools:{rtk:{command:$c}}}' >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
assert_eq "cli_path from manifest" "$OTHER" "$(sb_rtk_cli_path)"
unset SB_GLOBAL_TOOLSTACK_MANIFEST

# ---------- wrong binary / availability ----------
no_t "wrong_binary empty arg" sb_rtk_is_wrong_binary ""
yes_t "cli_available good binary" sb_rtk_cli_available
RTK_STUB_GAIN=1; export RTK_STUB_GAIN
yes_t "wrong_binary when gain fails" sb_rtk_is_wrong_binary "$TL_BIN/rtk"
no_t "cli_available false when gain fails" sb_rtk_cli_available
RTK_STUB_GAIN=0
RTK_STUB_HELP="Rust Type Kit - checks"; export RTK_STUB_HELP
yes_t "wrong_binary by help text" sb_rtk_is_wrong_binary "$TL_BIN/rtk"
RTK_STUB_HELP="RTK token killer"
no_t "right binary not wrong" sb_rtk_is_wrong_binary "$TL_BIN/rtk"
no_t "cli_available none on PATH" env PATH="$PATH_NO_RTK" bash -c 'source "$1"; sb_rtk_cli_available' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"

# ---------- version ----------
RTK_STUB_VERSION="rtk 0.42.1"; export RTK_STUB_VERSION
assert_eq "version_string" "rtk 0.42.1" "$(sb_rtk_version_string)"
no_t "version_string without rtk" env PATH="$PATH_NO_RTK" bash -c 'source "$1"; sb_rtk_version_string' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"
no_t "version_ok without rtk" env PATH="$PATH_NO_RTK" bash -c 'source "$1"; sb_rtk_version_ok' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"
yes_t "version 0.4x accepted outright" sb_rtk_version_ok "$CFG"
vcase() { # name version min expect(0|1)
  RTK_STUB_VERSION="$2"
  printf '{"recommended_tools":{"rtk":{"min_version":"%s"}}}' "$3" >"$CFG"
  if sb_rtk_version_ok "$CFG"; then got=0; else got=1; fi
  assert_eq "version_ok $1" "$4" "$got"
}
vcase "major greater" "rtk 2.0.0" "1.9.9" 0
vcase "major lower" "rtk 1.9.9" "2.0.0" 1
vcase "minor greater" "rtk 1.5.0" "1.2.9" 0
vcase "minor lower" "rtk 1.1.9" "1.2.0" 1
vcase "patch equal" "rtk 1.2.3" "1.2.3" 0
vcase "patch greater" "rtk 1.2.4" "1.2.3" 0
vcase "patch lower" "rtk 1.2.2" "1.2.3" 1
vcase "unparseable version" "rtk dev" "1.2.3" 1

# ---------- hook artifact / presence ----------
PR="$TL_TMP/proj"; mkdir -p "$PR"
assert_eq "artifact override" "/ovr/file" "$(SB_RTK_HOOK_ARTIFACT=/ovr/file sb_rtk_platform_hook_artifact_path "$PR" claude)"
assert_eq "artifact cursor" "$HOME/.cursor/hooks.json" "$(sb_rtk_platform_hook_artifact_path "$PR" cursor)"
assert_eq "artifact codex default (current layout: <CODEX_HOME>/.codex/AGENTS.md)" "$HOME/.codex/.codex/AGENTS.md" "$(env -u CODEX_HOME bash -c 'source "$1"; sb_rtk_platform_hook_artifact_path /x codex' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh")"
assert_eq "artifact codex CODEX_HOME (current layout)" "/ch/.codex/AGENTS.md" "$(CODEX_HOME=/ch sb_rtk_platform_hook_artifact_path "$PR" codex)"
assert_eq "artifact claude" "$HOME/.claude/settings.json" "$(sb_rtk_platform_hook_artifact_path "$PR" claude)"
assert_eq "artifact opencode" "$HOME/.config/opencode/plugins/rtk.ts" "$(sb_rtk_platform_hook_artifact_path "$PR" opencode)"
assert_eq "artifact pi env" "/pd/extensions/silver-bullet-five-tool-stack/config.json" "$(PI_CODING_AGENT_DIR=/pd sb_rtk_platform_hook_artifact_path "$PR" pi)"
assert_eq "artifact pi home" "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json" "$(env -u PI_CODING_AGENT_DIR bash -c 'source "$1"; sb_rtk_platform_hook_artifact_path /x pi' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh")"
assert_eq "artifact unknown host" "$HOME/.claude/settings.json" "$(sb_rtk_platform_hook_artifact_path "$PR" hermes)"
assert_eq "artifact default host" "$HOME/.claude/settings.json" "$(SILVER_BULLET_RUNTIME=claude sb_rtk_platform_hook_artifact_path "$PR")"

A="$TL_TMP/artifact"
export SB_RTK_HOOK_ARTIFACT="$A"
no_t "hook_present missing artifact" sb_rtk_platform_hook_present "$PR" claude
printf 'nothing here' >"$A"
for h in cursor codex opencode pi claude hermes; do no_t "hook_present $h no marker" sb_rtk_platform_hook_present "$PR" "$h"; done
printf '{"cmd":"rtk hook cursor"}' >"$A"
yes_t "hook_present cursor" sb_rtk_platform_hook_present "$PR" cursor
printf 'Rust Token Killer notes' >"$A"
yes_t "hook_present codex (case-insensitive)" sb_rtk_platform_hook_present "$PR" codex
printf 'plugin rtk' >"$A"
yes_t "hook_present opencode" sb_rtk_platform_hook_present "$PR" opencode
yes_t "hook_present pi" sb_rtk_platform_hook_present "$PR" pi
yes_t "hook_present claude" sb_rtk_platform_hook_present "$PR" claude
yes_t "hook_present default host" env SILVER_BULLET_RUNTIME=claude SB_RTK_HOOK_ARTIFACT="$A" bash -c 'source "$1"; sb_rtk_platform_hook_present /x' _ "$TL_REPO_ROOT/hooks/lib/rtk-gate.sh"
rm -f "$A"; ln -s "$TL_TMP/real-art" "$A"; printf 'rtk' >"$TL_TMP/real-art"
no_t "hook_present refuses symlink" sb_rtk_platform_hook_present "$PR" claude
unset SB_RTK_HOOK_ARTIFACT

# ---------- exemptions ----------
no_t "edit exempt empty path" sb_rtk_edit_path_is_exempt ""
for p in /p/.silver-bullet.json /p/SETUP_REPORT.md /p/silver-bullet.md /p/CLAUDE.md /p/AGENTS.md /p/.silver-bullet/state /h/.cursor/hooks.json /h/.claude/settings.json; do
  yes_t "edit exempt $p" sb_rtk_edit_path_is_exempt "$p" "$CFG"
done
no_t "edit not exempt src" sb_rtk_edit_path_is_exempt /p/src/app.py "$CFG"
yes_t "cmd exempt empty" sb_rtk_command_is_exempt ""
yes_t "cmd exempt rtk word" sb_rtk_command_is_exempt "rtk git status"
yes_t "cmd exempt path rtk" sb_rtk_command_is_exempt "/usr/bin/rtk gain"
yes_t "cmd exempt enable script" sb_rtk_command_is_exempt "bash enable-rtk-context-mode.sh"
yes_t "cmd exempt brew" sb_rtk_command_is_exempt "brew install foo"
yes_t "cmd exempt cat" sb_rtk_command_is_exempt "cat file"
no_t "cmd not exempt git commit" sb_rtk_command_is_exempt "git commit -m x"
no_t "cmd not exempt artisan (rtk substring)" sb_rtk_command_is_exempt "xrtkx do"

# ---------- messages ----------
w '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
m="$(SILVER_BULLET_RUNTIME=claude sb_rtk_block_message_no_cli "$CFG")"
assert_contains "no_cli message" "$m" "RTK REQUIRED"
assert_contains "no_cli lists install" "$m" "brew tap rtk-ai/rtk"
assert_contains "no_cli host" "$m" "host: claude"
m="$(sb_rtk_block_message_wrong_binary)"
assert_contains "wrong binary message" "$m" "RTK WRONG BINARY"
m="$(SILVER_BULLET_RUNTIME=claude sb_rtk_block_message_no_hook "$CFG")"
assert_contains "no_hook message" "$m" "RTK HOOK NOT WIRED"
assert_contains "no_hook artifact" "$m" "$HOME/.claude/settings.json"
assert_contains "no_hook commands" "$m" "rtk init -g"

# dependency failures inside the message builders are tolerated
(
  sb_recommended_tool_full_install_lines() { return 1; }
  m="$(SILVER_BULLET_RUNTIME=claude sb_rtk_block_message_no_cli "$CFG")"
  [[ "$m" == *"RTK REQUIRED"* && "$m" == *"host: claude"* ]]
) && tl_pass "no_cli message survives install-lines failure" || tl_fail "no_cli message survives install-lines failure"
(
  sb_recommended_tool_platform_pre_index_commands() { return 1; }
  m="$(SILVER_BULLET_RUNTIME=claude sb_rtk_block_message_no_hook "$CFG")"
  [[ "$m" == *"RTK HOOK NOT WIRED"* ]]
) && tl_pass "no_hook message survives command-lookup failure" || tl_fail "no_hook message survives command-lookup failure"

# ---------- prompt reminder ----------
w '{}'
assert_contains "reminder pending" "$(sb_rtk_prompt_reminder_line "$CFG")" "consent pending"
w '{"recommended_tools":{"rtk":{"enabled_by_user":false}}}'
assert_contains "reminder disabled" "$(sb_rtk_prompt_reminder_line "$CFG")" "opted out"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true,"enforcement_suspended":true}}}'
assert_contains "reminder suspended" "$(sb_rtk_prompt_reminder_line "$CFG")" "enforcement suspended"
w '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
RTK_STUB_GAIN=1
assert_contains "reminder cli missing" "$(sb_rtk_prompt_reminder_line "$CFG")" "CLI missing or wrong binary"
RTK_STUB_GAIN=0 RTK_STUB_HELP="RTK" RTK_STUB_VERSION="rtk 0.1.0"
assert_contains "reminder old version" "$(sb_rtk_prompt_reminder_line "$CFG")" "version too old"
RTK_STUB_VERSION="rtk 0.42.1"
assert_contains "reminder hook not wired" "$(sb_rtk_prompt_reminder_line "$CFG")" "host hook not wired"
mkdir -p "$HOME/.claude"; printf 'rtk' >"$HOME/.claude/settings.json"
assert_contains "reminder all good" "$(SILVER_BULLET_RUNTIME=claude sb_rtk_prompt_reminder_line "$CFG")" "installed and wired"

# ---------- rtk-compat ----------
COMPAT="$TL_REPO_ROOT/hooks/lib/rtk-compat.sh"
compat_env() { # dir ; extra env assignments via env(1); prints "RTK_DISABLED=<v> SILVER_BULLET=<v>"
  local dir="$1"; shift
  ( cd "$dir" && env -u RTK_DISABLED -u SB_RTK_COMPAT_ENABLED -u SB_RTK_COMPAT_MODE -u SILVER_BULLET_PROJECT_ROOT "$@" \
      bash -c 'source "$1"; printf "RTK_DISABLED=%s SILVER_BULLET=%s ENABLED=%s" "${RTK_DISABLED-unset}" "${SILVER_BULLET-unset}" "${SB_RTK_COMPAT_ENABLED-unset}"' _ "$COMPAT" )
}
OPTED="$TL_TMP/opted"; OUT="$TL_TMP/outside"; mkdir -p "$OPTED" "$OUT"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}' >"$OPTED/.silver-bullet.json"; : >"$OPTED/silver-bullet.md"
git -C "$OUT" init -q
# the project-root cache must not leak into the "outside" case
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
assert_eq "compat outside project disables RTK" "RTK_DISABLED=1 SILVER_BULLET=1 ENABLED=1" "$(compat_env "$OUT")"
assert_eq "compat opted-in project leaves RTK on" "RTK_DISABLED=unset SILVER_BULLET=1 ENABLED=1" "$(compat_env "$OPTED")"
assert_eq "compat verbatim mode forces disable" "RTK_DISABLED=1 SILVER_BULLET=1 ENABLED=1" "$(compat_env "$OPTED" SB_RTK_COMPAT_MODE=verbatim)"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":false}}}' >"$OPTED/.silver-bullet.json"
assert_eq "compat opted-out project disables RTK" "RTK_DISABLED=1 SILVER_BULLET=1 ENABLED=1" "$(compat_env "$OPTED")"
printf '{"recommended_tools":{"rtk":{"enabled_by_user":true}}}' >"$OPTED/.silver-bullet.json"
# readonly RTK_DISABLED: unset fails but compat tolerates it
got="$( cd "$OPTED" && env -u SB_RTK_COMPAT_ENABLED -u SB_RTK_COMPAT_MODE bash -c 'readonly RTK_DISABLED=7; source "$1" && printf "survived=%s" "$RTK_DISABLED"' _ "$COMPAT" )"
assert_eq "compat tolerates readonly RTK_DISABLED" "survived=7" "$got"
# already enabled: sourcing again does not re-run
got="$( cd "$OPTED" && env -u RTK_DISABLED SB_RTK_COMPAT_ENABLED=1 bash -c 'source "$1"; printf "%s" "${SILVER_BULLET-unset}"' _ "$COMPAT" )"
assert_eq "compat idempotent when already enabled" "unset" "$got"
got="$( cd "$OPTED" && env -u RTK_DISABLED -u SB_RTK_COMPAT_ENABLED bash -c 'source "$1"; sb_rtk_compat_verbatim; printf "%s %s" "$SB_RTK_COMPAT_MODE" "$RTK_DISABLED"' _ "$COMPAT" )"
assert_eq "compat_verbatim helper" "verbatim 1" "$got"

# ---------- rtk-cm-global ----------
# shellcheck source=../../hooks/lib/rtk-cm-global.sh
source "$TL_REPO_ROOT/hooks/lib/rtk-cm-global.sh"
unset RTCM_DRY_RUN
no_t "dry_run off" rtcm_dry_run
export RTCM_DRY_RUN=1
yes_t "dry_run on" rtcm_dry_run
export RTCM_DRY_RUN=0
for h in claude codex cursor opencode pi hermes goose; do yes_t "validate_host $h" rtcm_validate_host "$h"; done
no_t "validate_host unknown" rtcm_validate_host nope
no_t "validate_host empty" rtcm_validate_host ""
assert_eq "host_status goose" "unsupported" "$(rtcm_host_status goose)"
assert_eq "host_status hermes" "partial" "$(rtcm_host_status hermes)"
assert_eq "host_status claude" "supported" "$(rtcm_host_status claude)"
F="$TL_TMP/cfgfile"
rtcm_backup_file "$TL_TMP/absent"; assert_file_absent "backup of absent file is a no-op" "$TL_TMP/absent.bak"
printf 'data' >"$F"
export RTCM_DRY_RUN=1
assert_eq "backup dry-run message" "DRY-RUN: backup $F -> $F.bak" "$(rtcm_backup_file "$F")"
assert_file_absent "backup dry-run writes nothing" "$F.bak"
export RTCM_DRY_RUN=0
rtcm_backup_file "$F"
assert_file_exists "backup written" "$F.bak"
assert_eq "backup content" "data" "$(cat "$F.bak")"

# host config detection in a clean HOME
rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor" "$HOME/.config" "$HOME/.pi" "$HOME/.hermes"
unset PI_CODING_AGENT_DIR
for h in claude codex cursor opencode pi hermes goose nope; do no_t "no config $h" rtcm_host_config_present "$h"; done
assert_eq "detect none" "" "$(rtcm_detect_configured_hosts)"
mkdir -p "$HOME/.claude" "$HOME/.cursor" "$HOME/.hermes"
yes_t "config claude" rtcm_host_config_present claude
yes_t "config cursor" rtcm_host_config_present cursor
yes_t "config hermes" rtcm_host_config_present hermes
assert_eq "detect configured" "claude cursor hermes" "$(rtcm_detect_configured_hosts | tr '\n' ' ' | sed 's/ $//')"
rm -rf "$HOME/.claude" "$HOME/.cursor" "$HOME/.hermes"
mkdir -p "$HOME/.codex"; yes_t "config codex dir" rtcm_host_config_present codex
rm -rf "$HOME/.codex"; mkdir -p "$HOME/.config/opencode"; yes_t "config opencode dir" rtcm_host_config_present opencode
rm -rf "$HOME/.config"; mkdir -p "$TL_TMP/pidir"; export PI_CODING_AGENT_DIR="$TL_TMP/pidir"
yes_t "config pi dir via env" rtcm_host_config_present pi
unset PI_CODING_AGENT_DIR
mkdir -p "$HOME/.pi/agent"; yes_t "config pi default dir" rtcm_host_config_present pi
yes_t "config goose via .pi/agent" rtcm_host_config_present goose
rm -rf "$HOME/.pi"; mkdir -p "$HOME/.config/goose"; : >"$HOME/.config/goose/config.yaml"
yes_t "config goose yaml" rtcm_host_config_present goose

assert_eq "doctor claude" "claude" "$(rtcm_doctor_platform claude)"
assert_eq "doctor opencode" "opencode" "$(rtcm_doctor_platform opencode)"
assert_eq "doctor pi" "" "$(rtcm_doctor_platform pi)"
assert_eq "doctor goose" "" "$(rtcm_doctor_platform goose)"
assert_eq "doctor hermes" "" "$(rtcm_doctor_platform hermes)"
assert_eq "doctor unknown" "cursor" "$(rtcm_doctor_platform zzz)"
assert_contains "log unsupported" "$(rtcm_log_unsupported goose)" "SKIP: goose"
assert_contains "log unsupported path" "$(rtcm_log_unsupported goose)" "goose-verify-rtk-cm.md"

tl_results
