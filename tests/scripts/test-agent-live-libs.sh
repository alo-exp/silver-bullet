#!/usr/bin/env bash
# agent-{claude,codex,opencode,pi}/lib.sh helper functions: runtime env defaults, delegate env,
# folder-trust seeding, ephemeral config dir lifecycle, settings sanitising and plugin-cache checks.
# Each case runs in a fresh bash with the delegation-related variables unset and the sandbox HOME;
# no host CLI is launched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPTS="$TL_REPO_ROOT/scripts"
mkdir -p "$TL_TMP/tmp"

# lib_run LIB SCRIPT [ENV=VAL...]: run SCRIPT after sourcing LIB in a clean environment.
# (Not `env -i`: the coverage tracer is injected through BASH_ENV and must reach the child.)
lib_run() {
  local lib="$1" script="$2" name
  shift 2
  local -a unset_args=()
  while IFS= read -r name; do
    unset_args+=(-u "$name")
  done < <(compgen -e | grep -E '^(SB_|SILVER_BULLET_|CLAUDE_|CODEX_|OPENCODE_|PI_|RTK_|AGENT_)' || true)
  tl_run env "${unset_args[@]}" HOME="$HOME" PATH="${LIB_PATH:-$PATH}" TMPDIR="$TL_TMP/tmp" "$@" \
    bash -c "source '$lib'; $script"
}

# ===================================================================== claude
CL="$SCRIPTS/agent-claude/lib.sh"

lib_run "$CL" 'agent_claude_script_dir; agent_claude_repo_root'
assert_eq "claude lib resolves its script dir and repo root" "$SCRIPTS/agent-claude
$TL_REPO_ROOT" "$TL_OUT"

lib_run "$CL" 'agent_claude_apply_runtime_env; printf "%s|%s|%s|%s|%s" "$RTK_DISABLED" "$CLAUDE_INTERACTIVE_READY_TIMEOUT" "$CLAUDE_INTERACTIVE_IDLE_TIMEOUT" "$CLAUDE_INTERACTIVE_QUIET_TIMEOUT" "$CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY"'
assert_eq "claude runtime env defaults" "1|120|3600|120|arrow" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_runtime_env; printf "%s" "$CLAUDE_INTERACTIVE_READY_TIMEOUT"' SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT=77
assert_eq "claude ready timeout from SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT" "77" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_runtime_env; printf "%s|%s" "$CLAUDE_INTERACTIVE_READY_TIMEOUT" "$RTK_DISABLED"' \
  SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT=77 CLAUDE_INTERACTIVE_READY_TIMEOUT=5 RTK_DISABLED=0
assert_eq "claude explicit env wins over defaults" "5|0" "$TL_OUT"

lib_run "$CL" 'agent_claude_apply_delegate_env; printf "%s|%s|%s|%s|%s|[%s]" "$SB_AGENT_CLAUDE_DELEGATE" "$SB_AGENT_CLAUDE_LIGHTWEIGHT" "$SB_ORCHESTRATOR_WORKER" "$SB_ORCHESTRATOR_PARENT" "$CLAUDE_USE_INTERACTIVE" "${SB_AGENT_CERT_RUN-unset}"'
assert_eq "claude delegate env defaults" "1|1|1|0|1|[unset]" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_delegate_env; printf "[%s]" "${SB_AGENT_CERT_RUN-unset}"' SB_AGENT_CERT_RUN=true
assert_eq "claude delegate env normalises cert run true to 1" "[1]" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_delegate_env; printf "[%s]" "${SB_AGENT_CERT_RUN-unset}"' SB_AGENT_CERT_RUN=1
assert_eq "claude delegate env keeps cert run 1" "[1]" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_delegate_env; printf "[%s]" "${SB_AGENT_CERT_RUN-unset}"' SB_AGENT_CERT_RUN=yes
assert_eq "claude delegate env does not export cert run for other values" "[yes]" "$TL_OUT"
lib_run "$CL" 'agent_claude_apply_delegate_env; printf "%s|%s|[%s]" "$SB_ORCHESTRATOR_PARENT" "$CLAUDE_USE_INTERACTIVE" "${SB_E2E_ENTERPRISE_MATRIX-unset}"' \
  SB_ORCHESTRATOR_PARENT=1 CLAUDE_USE_INTERACTIVE=0 SB_E2E_ENTERPRISE_MATRIX=1
assert_eq "claude delegate env keeps explicit values and clears matrix env" "1|0|[unset]" "$TL_OUT"

lib_run "$CL" 'agent_claude_delegate_env_names | wc -l | tr -d " "; agent_claude_delegate_env_names | head -1'
assert_eq "claude delegate env names" "10
SB_AGENT_CLAUDE_DELEGATE" "$TL_OUT"

# tree without the shared delegate helpers: _source_common reports failure
NOCOMMON="$TL_TMP/claude-nocommon"
mkdir -p "$NOCOMMON/scripts/agent-claude"
cp "$CL" "$NOCOMMON/scripts/agent-claude/lib.sh"
lib_run "$NOCOMMON/scripts/agent-claude/lib.sh" '_agent_claude_source_common; echo "rc=$?"'
assert_eq "claude _source_common fails without the shared helper" "rc=1" "$TL_OUT"

# ---- folder trust
seed() { # seed ARGS-SCRIPT [env...]
  local script="$1"
  shift
  lib_run "$CL" "$script" "$@"
}
W="$TL_TMP/work-trust"
mkdir -p "$W"
CFG="$TL_TMP/cfg-trust"

rm -rf "$HOME/.claude.json" "$CFG"
seed 'agent_claude_seed_folder_trust "" ""; echo "rc=$?"'
assert_eq "folder trust without a work dir is a no-op" "rc=0" "$TL_OUT"
assert_file_absent "folder trust without a work dir writes nothing" "$HOME/.claude.json"

seed "agent_claude_seed_folder_trust '$W' '$CFG'; echo rc=\$?" SB_AGENT_CLAUDE_SEED_FOLDER_TRUST=0
assert_eq "folder trust can be disabled" "rc=0" "$TL_OUT"
assert_file_absent "disabled folder trust writes no global file" "$HOME/.claude.json"
assert_file_absent "disabled folder trust writes no config file" "$CFG/.claude.json"

NOPY="$(tl_path_without python3)"
LIB_PATH="$NOPY" seed "agent_claude_seed_folder_trust '$W' '$CFG'; echo rc=\$?"
assert_eq "folder trust without python3 is a no-op" "rc=0" "$TL_OUT"
assert_file_absent "folder trust without python3 writes nothing" "$CFG/.claude.json"

seed "agent_claude_seed_folder_trust '$W' '$CFG'"
assert_eq "folder trust seeding exits 0" "0" "$TL_STATUS"
assert_eq "folder trust seeded in the config dir" "true" \
  "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$CFG/.claude.json")"
assert_eq "folder trust seeded in the global file" "true" \
  "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$HOME/.claude.json")"
assert_contains "folder trust says where it seeded" "$TL_ERR" "[agent-claude] seeded folder trust for $W in $CFG/.claude.json"

# user data in an existing file is preserved; other projects and keys survive
printf '{"userID":"u-1","projects":{"/other":{"allowedTools":["x"],"hasTrustDialogAccepted":false}}}\n' >"$HOME/.claude.json"
seed "agent_claude_seed_folder_trust '$W' ''"
assert_eq "folder trust keeps unrelated top-level keys" "u-1" "$(jq -r .userID "$HOME/.claude.json")"
assert_eq "folder trust keeps other projects untouched" '{"allowedTools":["x"],"hasTrustDialogAccepted":false}' \
  "$(jq -c '.projects["/other"]' "$HOME/.claude.json")"
assert_eq "folder trust adds the work dir" "true" "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$HOME/.claude.json")"

# invalid JSON is replaced, not fatal
printf '{broken\n' >"$HOME/.claude.json"
seed "agent_claude_seed_folder_trust '$W' ''"
assert_eq "folder trust recovers from invalid JSON" "true" "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$HOME/.claude.json")"

# a symlinked work dir records both the given and the resolved path
REAL="$TL_TMP/real-work"
LINK="$TL_TMP/link-work"
mkdir -p "$REAL"
ln -s "$REAL" "$LINK"
rm -f "$HOME/.claude.json"
seed "agent_claude_seed_folder_trust '$LINK' ''"
assert_eq "folder trust records the symlink and its target" "2" "$(jq '.projects | length' "$HOME/.claude.json")"
assert_eq "folder trust records the resolved path" "true" "$(jq -r --arg w "$REAL" '.projects[$w].hasTrustDialogAccepted' "$HOME/.claude.json")"

# global seeding can be switched off, and needs a HOME
rm -rf "$HOME/.claude.json" "$CFG"
seed "agent_claude_seed_folder_trust '$W' '$CFG'" SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=0
assert_file_exists "folder trust still seeds the config dir with global off" "$CFG/.claude.json"
assert_file_absent "folder trust global off writes no HOME file" "$HOME/.claude.json"
rm -f "$HOME/.claude.json"
tl_run env -u HOME bash -c "source '$CL'; agent_claude_seed_folder_trust '$W' ''; echo rc=\$?"
assert_eq "folder trust without HOME and config dir is a no-op" "rc=0" "$TL_OUT"
assert_file_absent "folder trust without HOME writes nothing" "$HOME/.claude.json"

# the work dir and config dir default from the environment
rm -rf "$HOME/.claude.json" "$CFG"
seed "agent_claude_seed_folder_trust" CLAUDE_WORK_DIR="$W" CLAUDE_CONFIG_DIR="$CFG"
assert_eq "folder trust defaults to CLAUDE_WORK_DIR / CLAUDE_CONFIG_DIR" "true" \
  "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$CFG/.claude.json")"
rm -rf "$HOME/.claude.json" "$CFG"
seed "agent_claude_seed_folder_trust" WORK_DIR="$W" CLAUDE_CONFIG_DIR="$CFG"
assert_eq "folder trust falls back to WORK_DIR" "true" \
  "$(jq -r --arg w "$W" '.projects[$w].hasTrustDialogAccepted' "$CFG/.claude.json")"

# ---- ephemeral config dir lifecycle
rm -rf "$HOME/.claude.json" "$HOME/.claude"
ORIG="$TL_TMP/user-config"
mkdir -p "$ORIG" "$HOME/.claude"
printf '{"theme":"dark"}\n' >"$HOME/.claude/settings.json"
lib_run "$CL" "
export CLAUDE_CONFIG_DIR='$ORIG'
export CLAUDE_WORK_DIR='$W'
agent_claude_prepare_lightweight_config_dir
echo \"dir=\$CLAUDE_CONFIG_DIR\"
echo \"restore=\$SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE\"
echo \"isolated=\$SB_E2E_ISOLATED_CLAUDE_CONFIG\"
echo \"state=\$SB_RUNTIME_STATE_DIR\"
first=\"\$CLAUDE_CONFIG_DIR\"
agent_claude_prepare_lightweight_config_dir
echo \"second_call_reuses=\$([ \"\$first\" = \"\$CLAUDE_CONFIG_DIR\" ] && echo yes || echo no)\"
echo \"trust=\$(jq -r --arg w '$W' '.projects[\$w].hasTrustDialogAccepted' \"\$CLAUDE_CONFIG_DIR/.claude.json\")\"
echo \"theme=\$(jq -r .theme \"\$CLAUDE_CONFIG_DIR/settings.json\")\"
echo \"statedir=\$([ -d \"\$SB_RUNTIME_STATE_DIR\" ] && echo yes || echo no)\"
agent_claude_cleanup_lightweight_config_dir
echo \"after_dir=\$CLAUDE_CONFIG_DIR\"
echo \"after_restore=[\${SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE-unset}] isolated=[\${SB_E2E_ISOLATED_CLAUDE_CONFIG-unset}]\"
echo \"first_gone=\$([ -e \"\$first\" ] && echo no || echo yes)\"
"
assert_eq "prepare lightweight config dir exits 0" "0" "$TL_STATUS"
assert_match "ephemeral config dir is under TMPDIR" "dir=$TL_TMP/tmp/agent-claude-config-[A-Za-z0-9]+" "$TL_OUT"
assert_contains "ephemeral dir remembers the original" "$TL_OUT" "restore=$ORIG"
assert_contains "ephemeral dir marks isolation" "$TL_OUT" "isolated=1"
assert_match "runtime state dir lives in the ephemeral dir" "state=$TL_TMP/tmp/agent-claude-config-[A-Za-z0-9]+/.silver-bullet-state" "$TL_OUT"
assert_contains "a second prepare keeps the same dir" "$TL_OUT" "second_call_reuses=yes"
assert_contains "ephemeral dir has folder trust" "$TL_OUT" "trust=true"
assert_contains "ephemeral dir has the sanitised global settings" "$TL_OUT" "theme=dark"
assert_contains "ephemeral dir has a state dir" "$TL_OUT" "statedir=yes"
assert_contains "cleanup restores the original config dir" "$TL_OUT" "after_dir=$ORIG"
assert_contains "cleanup clears the lifecycle markers" "$TL_OUT" "after_restore=[unset] isolated=[unset]"
assert_contains "cleanup removes the ephemeral dir" "$TL_OUT" "first_gone=yes"
assert_contains "prepare announces the dir on stderr" "$TL_ERR" "[agent-claude] lightweight CLAUDE_CONFIG_DIR:"
assert_file_exists "cleanup leaves the original config dir alone" "$ORIG"

# no original config dir: cleanup unsets the variable again
lib_run "$CL" "
unset CLAUDE_CONFIG_DIR CLAUDE_WORK_DIR WORK_DIR
agent_claude_prepare_lightweight_config_dir
d=\"\$CLAUDE_CONFIG_DIR\"
agent_claude_cleanup_lightweight_config_dir
echo \"cfg=[\${CLAUDE_CONFIG_DIR-unset}] gone=\$([ -e \"\$d\" ] && echo no || echo yes)\"
"
assert_eq "cleanup unsets CLAUDE_CONFIG_DIR when there was none" "cfg=[unset] gone=yes" "$TL_OUT"

# cleanup without a prior prepare must never delete a user-owned config dir
mkdir -p "$TL_TMP/user-owned"
: >"$TL_TMP/user-owned/keep"
lib_run "$CL" "agent_claude_cleanup_lightweight_config_dir; echo cfg=\$CLAUDE_CONFIG_DIR" CLAUDE_CONFIG_DIR="$TL_TMP/user-owned"
assert_eq "cleanup without prepare leaves CLAUDE_CONFIG_DIR" "cfg=$TL_TMP/user-owned" "$TL_OUT"
assert_file_exists "cleanup without prepare keeps user data" "$TL_TMP/user-owned/keep"
# restore marker set but directory already gone / empty variable: still restores, never errors
lib_run "$CL" "
SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE='$ORIG'
export CLAUDE_CONFIG_DIR='$TL_TMP/already-gone'
agent_claude_cleanup_lightweight_config_dir
echo cfg=\$CLAUDE_CONFIG_DIR
SB_AGENT_CLAUDE_CONFIG_DIR_RESTORE=''
CLAUDE_CONFIG_DIR=''
agent_claude_cleanup_lightweight_config_dir
echo cfg2=[\${CLAUDE_CONFIG_DIR-unset}]
"
assert_eq "cleanup tolerates a missing or empty ephemeral dir" "cfg=$ORIG
cfg2=[unset]" "$TL_OUT"

# ---- settings sanitising
SETTINGS_DEST="$TL_TMP/dest-cfg"
REALHOOK="$TL_TMP/real-hook.sh"
printf '#!/bin/sh\n' >"$REALHOOK"
mkdir -p "$HOME/.claude"
cat >"$HOME/.claude/settings.json" <<EOF
{
  "theme": "dark",
  "env": {"A": "1"},
  "hooks": {
    "PreToolUse": [
      {"matcher": "x", "hooks": [
        {"command": "bash /home/me/gsd-session-state.sh"},
        {"command": "bash \"/nonexistent/dir/hook.sh\""},
        {"command": "bash '$REALHOOK'"},
        {"command": "echo plain"},
        {"command": 5},
        null
      ]},
      {"hooks": [{"command": "/x/gsd-foo.sh"}]},
      "bare-string-entry"
    ],
    "Stop": [{"hooks": null}],
    "Odd": "not-a-list"
  }
}
EOF
lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'; echo rc=\$?"
assert_eq "settings seeding exits 0" "rc=0" "$TL_OUT"
OUT_JSON="$SETTINGS_DEST/settings.json"
assert_eq "settings keep unrelated keys" "dark" "$(jq -r .theme "$OUT_JSON")"
assert_eq "settings keep env" '{"A":"1"}' "$(jq -c .env "$OUT_JSON")"
assert_eq "settings drop gsd and missing-script hooks, keep the rest" \
  '["bash '"'$REALHOOK'"'","echo plain",5,null]' \
  "$(jq -c '[.hooks.PreToolUse[0].hooks[] | if type == "object" then .command else . end]' "$OUT_JSON")"
assert_eq "settings drop entries whose hooks are all broken but keep non-dict entries" "2" "$(jq '.hooks.PreToolUse | length' "$OUT_JSON")"
assert_eq "settings keep a bare string entry" '"bare-string-entry"' "$(jq -c '.hooks.PreToolUse[1]' "$OUT_JSON")"
assert_eq "settings drop entries with no hooks list" "[]" "$(jq -c '.hooks.Stop' "$OUT_JSON")"
assert_eq "settings leave a non-list event alone" '"not-a-list"' "$(jq -c '.hooks.Odd' "$OUT_JSON")"
assert_not_contains "settings do not carry cert env without a cert run" "$(jq -c .env "$OUT_JSON")" "SB_AGENT_CERT_RUN"

lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'" SB_AGENT_CERT_RUN=true
assert_eq "cert run is recorded in the settings env alongside existing env" '{"A":"1","SB_AGENT_CERT_RUN":"1"}' "$(jq -c .env "$OUT_JSON")"
lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'" SB_AGENT_CERT_RUN=1
assert_eq "cert run 1 is recorded too" "1" "$(jq -r .env.SB_AGENT_CERT_RUN "$OUT_JSON")"

# hooks that is not an object is left as-is
printf '{"hooks":["a"]}\n' >"$HOME/.claude/settings.json"
lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'"
assert_eq "settings leave a non-object hooks value alone" '["a"]' "$(jq -c .hooks "$OUT_JSON")"
# invalid or missing source: empty document
printf '{oops\n' >"$HOME/.claude/settings.json"
lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'"
assert_eq "settings from invalid JSON is an empty document" "{}" "$(jq -c . "$OUT_JSON")"
rm -f "$HOME/.claude/settings.json" "$OUT_JSON"
lib_run "$CL" "agent_claude_seed_lightweight_settings '$SETTINGS_DEST'"
assert_eq "settings without a source is an empty document" "{}" "$(jq -c . "$OUT_JSON")"
# the destination directory is created on demand; default dir comes from CLAUDE_CONFIG_DIR
rm -rf "$TL_TMP/deep"
lib_run "$CL" "agent_claude_seed_lightweight_settings" CLAUDE_CONFIG_DIR="$TL_TMP/deep/er"
assert_file_exists "settings default to CLAUDE_CONFIG_DIR and create it" "$TL_TMP/deep/er/settings.json"
rm -rf "$TL_TMP/deep"
lib_run "$CL" "agent_claude_seed_lightweight_settings; echo rc=\$?"
assert_eq "settings without any config dir is a no-op" "rc=0" "$TL_OUT"
LIB_PATH="$NOPY" lib_run "$CL" "agent_claude_seed_lightweight_settings '$TL_TMP/deep'; echo rc=\$?"
assert_eq "settings without python3 is a no-op" "rc=0" "$TL_OUT"
assert_file_absent "settings without python3 write nothing" "$TL_TMP/deep"

# ---- plugin cache
SBR="$TL_TMP/sb-cache"
mkdir -p "$SBR/scripts/lib"
cat >"$SBR/scripts/lib/plugin-cache-version.sh" <<EOF
sb_claude_ensure_plugin_cache_ready() {
  printf '%s\n' "\$1" >>"$SBR/calls"
  return "\${CACHE_RC:-0}"
}
EOF
lib_run "$CL" "agent_claude_ensure_plugin_cache '$SBR'; echo rc=\$?"
assert_eq "plugin cache ready returns 0" "rc=0" "$TL_OUT"
assert_contains "plugin cache ready is announced" "$TL_ERR" "OK: Claude plugin cache ready (current alias + hooks)"
assert_eq "plugin cache check got the root" "$SBR" "$(tail -1 "$SBR/calls")"
lib_run "$CL" "agent_claude_ensure_plugin_cache '$SBR'; echo rc=\$?" CACHE_RC=1
assert_eq "plugin cache not ready returns 1" "rc=1" "$TL_OUT"
assert_contains "plugin cache not ready message" "$TL_ERR" "Claude plugin cache not ready"
lib_run "$CL" "agent_claude_ensure_plugin_cache '$TL_TMP/no-such-root'; echo rc=\$?"
assert_eq "plugin cache helper missing returns 1" "rc=1" "$TL_OUT"
assert_contains "plugin cache helper missing warns" "$TL_ERR" "plugin-cache-version helper missing"
lib_run "$CL" "agent_claude_ensure_plugin_cache; echo rc=\$?" SB_ROOT="$SBR"
assert_eq "plugin cache root defaults to SB_ROOT" "rc=0" "$TL_OUT"
# without SB_ROOT the repo root of the lib itself is used (staged tree with the stub helper)
STAGED="$TL_TMP/staged-claude"
mkdir -p "$STAGED/scripts/agent-claude" "$STAGED/scripts/lib"
cp "$CL" "$STAGED/scripts/agent-claude/lib.sh"
cp "$SBR/scripts/lib/plugin-cache-version.sh" "$STAGED/scripts/lib/"
lib_run "$STAGED/scripts/agent-claude/lib.sh" "agent_claude_ensure_plugin_cache; echo rc=\$?"
assert_eq "plugin cache root defaults to the lib's repo root" "rc=0" "$TL_OUT"
assert_eq "plugin cache check used the staged repo root" "$STAGED" "$(tail -1 "$SBR/calls")"

# ===================================================================== codex
CX="$SCRIPTS/agent-codex/lib.sh"
lib_run "$CX" 'agent_codex_script_dir; agent_codex_repo_root'
assert_eq "codex lib resolves its script dir and repo root" "$SCRIPTS/agent-codex
$TL_REPO_ROOT" "$TL_OUT"
lib_run "$CX" 'agent_codex_apply_runtime_env; printf "%s|%s|%s|%s" "$RTK_DISABLED" "$CODEX_INTERACTIVE_READY_TIMEOUT" "$CODEX_INTERACTIVE_IDLE_TIMEOUT" "$CODEX_EXEC_TAIL_IDLE_TIMEOUT"'
assert_eq "codex runtime env defaults" "1|120|3600|45" "$TL_OUT"
lib_run "$CX" 'agent_codex_apply_runtime_env; printf "%s" "$CODEX_INTERACTIVE_READY_TIMEOUT"' SB_AGENT_CODEX_MODEL_READY_TIMEOUT=33
assert_eq "codex ready timeout from SB_AGENT_CODEX_MODEL_READY_TIMEOUT" "33" "$TL_OUT"

mkdir -p "$TL_TMP/codexbin"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TL_TMP/codexbin/codex"
chmod +x "$TL_TMP/codexbin/codex"
lib_run "$CX" 'agent_codex_apply_delegate_env; printf "%s|%s|%s|%s|%s|%s|[%s]" "$SB_AGENT_CODEX_DELEGATE" "$SB_AGENT_CODEX_LIGHTWEIGHT" "$SB_ORCHESTRATOR_WORKER" "$SB_ORCHESTRATOR_PARENT" "$CODEX_AUTO_TRUST_HOOKS" "$CODEX_BYPASS_HOOK_TRUST" "${CODEX_BIN-unset}"'
assert_eq "codex delegate env defaults (no codex CLI is fine)" "1|1|1|0|1|1|[unset]" "$TL_OUT"
lib_run "$CX" 'agent_codex_apply_delegate_env; printf "[%s]" "${CODEX_BIN-unset}"' CODEX_BIN="$TL_TMP/codexbin/codex"
assert_eq "codex delegate env resolves and exports CODEX_BIN" "[$TL_TMP/codexbin/codex]" "$TL_OUT"
lib_run "$CX" 'agent_codex_apply_delegate_env; printf "%s|[%s]" "$CODEX_AUTO_TRUST_HOOKS" "${SB_E2E_ENTERPRISE_MATRIX-unset}"' CODEX_AUTO_TRUST_HOOKS=0 SB_E2E_ENTERPRISE_MATRIX=1
assert_eq "codex delegate env keeps explicit values and clears matrix env" "0|[unset]" "$TL_OUT"
lib_run "$CX" 'agent_codex_delegate_env_names | wc -l | tr -d " "'
assert_eq "codex delegate env names" "11" "$TL_OUT"
NOCOMMON="$TL_TMP/codex-nocommon"
mkdir -p "$NOCOMMON/scripts/agent-codex"
cp "$CX" "$NOCOMMON/scripts/agent-codex/lib.sh"
lib_run "$NOCOMMON/scripts/agent-codex/lib.sh" '_agent_codex_source_common; echo "rc=$?"'
assert_eq "codex _source_common fails without the shared helper" "rc=1" "$TL_OUT"

# ===================================================================== opencode
OC="$SCRIPTS/agent-opencode/lib.sh"
lib_run "$OC" 'agent_opencode_script_dir; agent_opencode_repo_root'
assert_eq "opencode lib resolves its script dir and repo root" "$SCRIPTS/agent-opencode
$TL_REPO_ROOT" "$TL_OUT"
lib_run "$OC" 'agent_opencode_apply_runtime_env; printf "%s|%s|%s|%s" "$RTK_DISABLED" "$OPENCODE_RUN_TIMEOUT" "$OPENCODE_RUN_TAIL_IDLE_TIMEOUT" "$OPENCODE_MODEL"'
assert_eq "opencode runtime env defaults" "1|900|45|mimo-v2.5" "$TL_OUT"
lib_run "$OC" 'agent_opencode_apply_runtime_env; echo "rc=$?"' OPENCODE_MODEL=other
assert_eq "opencode runtime env propagates a model-policy failure" "rc=2" "$TL_OUT"
assert_contains "opencode model-policy failure message" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5"
lib_run "$OC" 'agent_opencode_apply_runtime_env && echo "after=$RTK_DISABLED"' OPENCODE_MODEL=other
assert_not_contains "opencode runtime env stops before exporting on failure" "$TL_OUT" "after="
lib_run "$OC" 'agent_opencode_apply_delegate_env; printf "%s|%s|%s|%s|[%s][%s]" "$SB_AGENT_OPENCODE_DELEGATE" "$SB_AGENT_OPENCODE_LIGHTWEIGHT" "$SB_ORCHESTRATOR_WORKER" "$SB_ORCHESTRATOR_PARENT" "${SB_MULTI_AI_OCG_PROFILE-unset}" "${SB_AGENT_OPENCODE_DELEGATION_MODE-unset}"' \
  SB_MULTI_AI_OCG_PROFILE=forged SB_AGENT_OPENCODE_DELEGATION_MODE=multi-ai-worker-v1
assert_eq "opencode delegate env drops inherited multi-ai markers" "1|1|1|0|[unset][unset]" "$TL_OUT"
lib_run "$OC" 'agent_opencode_delegate_env_names | wc -l | tr -d " "'
assert_eq "opencode delegate env names" "10" "$TL_OUT"
NOCOMMON="$TL_TMP/opencode-nocommon"
mkdir -p "$NOCOMMON/scripts/agent-opencode"
cp "$OC" "$NOCOMMON/scripts/agent-opencode/lib.sh"
lib_run "$NOCOMMON/scripts/agent-opencode/lib.sh" '_agent_opencode_source_common; echo "common rc=$?"; _agent_opencode_source_cli; echo "cli rc=$?"'
assert_eq "opencode source helpers fail without their libraries" "common rc=1
cli rc=1" "$TL_OUT"

# ===================================================================== pi
PI="$SCRIPTS/agent-pi/lib.sh"
lib_run "$PI" 'agent_pi_script_dir; agent_pi_repo_root'
assert_eq "pi lib resolves its script dir and repo root" "$SCRIPTS/agent-pi
$TL_REPO_ROOT" "$TL_OUT"
lib_run "$PI" 'agent_pi_apply_runtime_env; printf "%s|%s|%s|%s|%s" "$RTK_DISABLED" "$PI_RUN_TIMEOUT" "$PI_RUN_TAIL_IDLE_TIMEOUT" "$PI_PROVIDER" "$PI_MODEL"'
assert_eq "pi runtime env defaults" "1|900|45|opencode-go|mimo-v2.5" "$TL_OUT"
lib_run "$PI" 'agent_pi_apply_runtime_env; echo "rc=$?"' PI_MODEL=other
assert_eq "pi runtime env propagates a model-policy failure" "rc=2" "$TL_OUT"
lib_run "$PI" 'agent_pi_apply_runtime_env && echo "after=$RTK_DISABLED"' PI_PROVIDER=other
assert_not_contains "pi runtime env stops before exporting on failure" "$TL_OUT" "after="
lib_run "$PI" 'agent_pi_apply_delegate_env; printf "%s|%s|%s|%s" "$SB_AGENT_PI_DELEGATE" "$SB_AGENT_PI_LIGHTWEIGHT" "$SB_ORCHESTRATOR_WORKER" "$SB_ORCHESTRATOR_PARENT"'
assert_eq "pi delegate env defaults" "1|1|1|0" "$TL_OUT"
lib_run "$PI" 'agent_pi_delegate_env_names | wc -l | tr -d " "'
assert_eq "pi delegate env names" "9" "$TL_OUT"
NOCOMMON="$TL_TMP/pi-nocommon"
mkdir -p "$NOCOMMON/scripts/agent-pi"
cp "$PI" "$NOCOMMON/scripts/agent-pi/lib.sh"
lib_run "$NOCOMMON/scripts/agent-pi/lib.sh" '_agent_pi_source_common; echo "common rc=$?"; _agent_pi_source_cli; echo "cli rc=$?"'
assert_eq "pi source helpers fail without their libraries" "common rc=1
cli rc=1" "$TL_OUT"

assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results
