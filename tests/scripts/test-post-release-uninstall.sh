#!/usr/bin/env bash
# scripts/lib/post-release-uninstall.sh: SB-only uninstall per host in a
# sandboxed HOME, with stubbed claude/codex CLIs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

LIB="$TL_REPO_ROOT/scripts/lib/post-release-uninstall.sh"
export SB_POST_RELEASE_REPO_ROOT="$TL_REPO_ROOT"
export REPO_ROOT="$TL_REPO_ROOT"
export CLAUDE_HOME="$HOME/.claude"
unset CODEX_HOME_ROOT CLAUDE_BIN

# Each case runs in a fresh bash that sources the library.
uninstall() { tl_run bash -c 'source "$1"; shift; sb_post_release_uninstall_host "$@"' _ "$LIB" "$@"; }

# ---- dispatcher
uninstall bogus
assert_eq "unknown host exits 2" 2 "$TL_STATUS"
assert_contains "unknown host named" "$TL_ERR" "ERROR: unknown host bogus"

# ---- double sourcing is a no-op
tl_run bash -c 'source "$1"; source "$1"; declare -F sb_post_release_uninstall_claude >/dev/null && echo loaded' _ "$LIB"
assert_eq "second source returns cleanly" "loaded" "$TL_OUT"

# ---- the already-loaded guard also holds when the file is executed
tl_run env _SB_POST_RELEASE_UNINSTALL_LOADED=1 bash "$LIB"
assert_eq "already-loaded guard exits 0 when executed" 0 "$TL_STATUS"

# ---- cursor is no longer a host
uninstall cursor
assert_eq "cursor is rejected as an unknown host" 2 "$TL_STATUS"
assert_contains "cursor named" "$TL_ERR" "ERROR: unknown host cursor"

# removal failures are tolerated (rm unavailable)
REAL_RM="$(command -v rm)"
mkdir -p "$CLAUDE_HOME/plugins/cache/alo-labs/silver-bullet"
tl_stub rm 'exit 1'
uninstall claude
assert_eq "claude uninstall tolerates failing rm" 0 "$TL_STATUS"
"$REAL_RM" -f "$TL_BIN/rm"

# ---- codex
CX="$HOME/.codex"
mkdir -p "$CX/skills/silver-quality-gates" "$CX/skills/unrelated-skill" "$HOME/.agents/skills/silver-plan" \
  "$CX/plugins/cache/alo-labs-codex/silver-bullet/1.0" "$CX/plugins/cache/silver-bullet-local/silver-bullet/1.0" "$CX/plugins/cache/alo-labs-codex/other"
cat >"$CX/hooks.json" <<JSON
{"hooks":{"PreToolUse":[{"hooks":[{"command":"$CX/plugins/cache/alo-labs-codex/silver-bullet/1.0/hooks/a.sh"},{"command":"/usr/bin/keep"}]}],"Stop":[{"hooks":[{"command":"$CX/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/b.sh"}]}]}}
JSON
printf '[model]\nname = "x"\n\n[hooks.state."silver-bullet@alo-labs-codex:a"]\ntrusted = true\n\n[other]\nk = 1\n' >"$CX/config.toml"
uninstall codex
assert_eq "codex uninstall exits 0 without a codex CLI" 0 "$TL_STATUS"
assert_contains "codex uninstall reports" "$TL_OUT" "uninstall: codex SB cache, skills, hooks stripped"
assert_contains "legacy skill removal reported" "$TL_OUT" "Removed legacy skill: $CX/skills/silver-quality-gates"
assert_file_absent "standalone SB skill removed" "$CX/skills/silver-quality-gates"
assert_file_absent "agents SB skill removed" "$HOME/.agents/skills/silver-plan"
assert_file_exists "unrelated skill preserved" "$CX/skills/unrelated-skill"
assert_file_absent "codex plugin cache removed" "$CX/plugins/cache/alo-labs-codex/silver-bullet"
assert_file_absent "local codex plugin cache removed" "$CX/plugins/cache/silver-bullet-local/silver-bullet"
assert_file_exists "foreign codex cache preserved" "$CX/plugins/cache/alo-labs-codex/other"
assert_eq "SB hooks stripped, foreign kept" '["/usr/bin/keep"]' "$(jq -c '[.. | .command? // empty]' "$CX/hooks.json")"
assert_not_contains "hook state stripped from config" "$(<"$CX/config.toml")" "hooks.state"
assert_contains "other config tables preserved" "$(<"$CX/config.toml")" "[other]"
# SB's own duplicated trust tables (older installers) must not stop the uninstall: it repairs first
DUP="$TL_TMP/dup"; mkdir -p "$DUP/.codex"
printf '[model]\nname = "x"\n\n[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:a"\n\n[hooks.state]\n\n[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:b"\n\n[other]\nk = 1\n' >"$DUP/.codex/config.toml"
tl_run env CODEX_HOME_ROOT="$DUP" bash -c 'set -euo pipefail; source "$1"; sb_post_release_uninstall_codex' _ "$LIB"
assert_eq "uninstall over duplicated SB trust tables exits 0" 0 "$TL_STATUS"
assert_not_contains "duplicated SB trust tables removed" "$(<"$DUP/.codex/config.toml")" "silver-bullet@"
assert_contains "user config kept after the repair" "$(<"$DUP/.codex/config.toml")" "[other]"
# Every config.toml write in one uninstall run keeps the pre-run original in .sb-backup, however long the
# purge starts after the repair (the run start is exported once at entry, not guessed from a 2 s margin)
SLOW="$TL_TMP/slow"; mkdir -p "$SLOW/.codex" "$SLOW/bin"
printf '[model]\nname = "x"\n\n[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:a"\n\n[hooks.state]\n\n[hooks.state."silver-bullet@alo-labs-codex:hooks/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:b"\n\n[other]\nk = 1\n' >"$SLOW/.codex/config.toml"
cp "$SLOW/.codex/config.toml" "$SLOW/original.toml"
REAL_PY="$(command -v python3)"
printf '#!/bin/bash\nif [[ -e "%s/seen" ]]; then sleep 3; fi\n: >"%s/seen"\nexec "%s" "$@"\n' "$SLOW" "$SLOW" "$REAL_PY" >"$SLOW/bin/python3"
chmod +x "$SLOW/bin/python3"
tl_run env -u SB_INSTALL_RUN_START CODEX_HOME_ROOT="$SLOW" PATH="$SLOW/bin:$PATH" bash -c 'source "$1"; sb_post_release_uninstall_codex' _ "$LIB"
assert_eq "slow two-writer uninstall exits 0" 0 "$TL_STATUS"
assert_not_contains "slow uninstall removed SB tables" "$(<"$SLOW/.codex/config.toml")" "silver-bullet@"
assert_eq ".sb-backup keeps the pre-run original after two writes" "$(<"$SLOW/original.toml")" "$(<"$SLOW/.codex/config.toml.sb-backup")"
# CODEX_HOME_ROOT is honoured
mkdir -p "$TL_TMP/alt/.codex/plugins/cache/alo-labs-codex/silver-bullet"
tl_run env CODEX_HOME_ROOT="$TL_TMP/alt" bash -c 'source "$1"; sb_post_release_uninstall_codex' _ "$LIB"
assert_file_absent "alternate codex home cache removed" "$TL_TMP/alt/.codex/plugins/cache/alo-labs-codex/silver-bullet"

# codex CLI present: remove, then uninstall fallback when remove fails
tl_stub codex 'echo "codex $*" >>"'"$TL_TMP"'/codex.log"; [[ "$2" == remove ]] && exit 1; exit 0'
uninstall codex
assert_eq "codex uninstall with CLI exits 0" 0 "$TL_STATUS"
CODEX_LOG="$(<"$TL_TMP/codex.log")"
assert_contains "plugin remove attempted" "$CODEX_LOG" "codex plugin remove silver-bullet@alo-labs-codex"
assert_contains "plugin uninstall used as fallback" "$CODEX_LOG" "codex plugin uninstall silver-bullet@alo-labs-codex"
tl_stub codex 'exit 1'
uninstall codex
assert_eq "failing codex CLI tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/codex"

# ---- claude
CL="$HOME/.claude/plugins/cache"
mkdir -p "$CL/alo-labs/silver-bullet/1.0" "$CL/alo-labs-claude/silver-bullet" "$CL/alo-labs/other"
jq -n --arg sb "\"$CL/alo-labs/silver-bullet/current/hooks/stop-check.sh\"" --arg user 'node "$HOME/.claude/hooks/mine.js"' \
  '{theme: "dark", enabledPlugins: {"silver-bullet@alo-labs": true, "other@m": true},
    hooks: {Stop: [{hooks: [{type: "command", command: $sb}]}], PreToolUse: [{matcher: "Bash", hooks: [{type: "command", command: $sb}, {type: "command", command: $user}]}]}}' \
  >"$HOME/.claude/settings.json"
printf '{"plugins":{"silver-bullet@alo-labs":[{}],"other@m":[{}]}}\n' >"$HOME/.claude/plugins/installed_plugins.json"
uninstall claude
assert_eq "claude uninstall exits 0 without a CLI" 0 "$TL_STATUS"
assert_contains "claude uninstall reports" "$TL_OUT" "uninstall: claude SB plugin + cache removed"
# R7-23: hooks an earlier /sb:init merged, and SB's own records, do not outlive the plugin
assert_eq "SB settings hooks removed, the user's kept" '{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node \"$HOME/.claude/hooks/mine.js\""}]}]}' \
  "$(jq -c .hooks "$HOME/.claude/settings.json")"
assert_eq "only SB's enablement removed" '{"other@m":true}' "$(jq -c .enabledPlugins "$HOME/.claude/settings.json")"
assert_eq "other settings kept" '"dark"' "$(jq -c .theme "$HOME/.claude/settings.json")"
assert_eq "only SB's registry record removed" '["other@m"]' "$(jq -c '.plugins | keys' "$HOME/.claude/plugins/installed_plugins.json")"
printf '{"hooks":' >"$HOME/.claude/settings.json"
uninstall claude
assert_eq "an unparseable Claude settings file fails the uninstall" 1 "$TL_STATUS"
assert_eq "and is left byte-identical" '{"hooks":' "$(<"$HOME/.claude/settings.json")"
printf '{"plugins": {' >"$HOME/.claude/plugins/installed_plugins.json"
printf '{}\n' >"$HOME/.claude/settings.json"
uninstall claude
assert_eq "an unparseable Claude registry fails the uninstall" 1 "$TL_STATUS"
assert_eq "and is left byte-identical" '{"plugins": {' "$(<"$HOME/.claude/plugins/installed_plugins.json")"
rm -f "$HOME/.claude/settings.json" "$HOME/.claude/plugins/installed_plugins.json"
uninstall claude
assert_file_absent "claude cache removed" "$CL/alo-labs/silver-bullet"
assert_file_absent "claude-alias cache removed" "$CL/alo-labs-claude/silver-bullet"
assert_file_exists "foreign claude plugin preserved" "$CL/alo-labs/other"
tl_stub claude 'echo "claude $*" >>"'"$TL_TMP"'/claude.log"; exit 1'
uninstall claude
assert_eq "failing claude CLI tolerated" 0 "$TL_STATUS"
CLAUDE_LOG="$(<"$TL_TMP/claude.log")"
for id in silver-bullet@alo-labs silver-bullet@alo-labs-claude; do
  for scope in user project local; do
    assert_contains "uninstall $id --scope $scope" "$CLAUDE_LOG" "claude plugin uninstall $id --scope $scope"
  done
done

tl_results
