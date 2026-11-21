#!/usr/bin/env bash
# scripts/lib/claude-matrix-auth.sh: settings discovery, conflict detection, strip/restore, env export.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# shellcheck source=../../scripts/lib/claude-matrix-auth.sh
source "$TL_REPO_ROOT/scripts/lib/claude-matrix-auth.sh"
set +e
unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_SETTINGS_FILE CLAUDE_CONFIG_DIR \
  SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT CLAUDE_PRINT_SKIP_SETTINGS_EXPORT CLAUDE_BIN

rc() { if "$@" >/dev/null 2>&1; then echo 0; else echo 1; fi; }
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
put() { printf '%s\n' "$1" >"$SETTINGS"; }

# --- claude_matrix_settings_path ---------------------------------------------------------
assert_eq "path: default under HOME" "$SETTINGS" "$(claude_matrix_settings_path)"
echo '{}' >"$TL_TMP/explicit.json"
assert_eq "path: CLAUDE_SETTINGS_FILE wins" "$TL_TMP/explicit.json" "$(CLAUDE_SETTINGS_FILE="$TL_TMP/explicit.json" claude_matrix_settings_path)"
assert_eq "path: missing CLAUDE_SETTINGS_FILE ignored" "$SETTINGS" "$(CLAUDE_SETTINGS_FILE="$TL_TMP/absent.json" claude_matrix_settings_path)"
mkdir -p "$TL_TMP/cfgdir"; echo '{}' >"$TL_TMP/cfgdir/settings.json"
assert_eq "path: CLAUDE_CONFIG_DIR" "$TL_TMP/cfgdir/settings.json" "$(CLAUDE_CONFIG_DIR="$TL_TMP/cfgdir" claude_matrix_settings_path)"
assert_eq "path: CLAUDE_CONFIG_DIR without settings ignored" "$SETTINGS" "$(CLAUDE_CONFIG_DIR="$TL_TMP/nocfg" claude_matrix_settings_path)"

# --- api key / proxy detection -------------------------------------------------------------------
assert_eq "api_key_env: missing file" 1 "$(rc claude_matrix_auth_has_api_key_env "$TL_TMP/absent.json")"
put '{"env":{"ANTHROPIC_API_KEY":"k"}}'; assert_eq "api_key_env: key" 0 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"
put '{"env":{"ANTHROPIC_AUTH_TOKEN":"t"}}'; assert_eq "api_key_env: token" 0 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"
put '{"env":{"ANTHROPIC_BASE_URL":"u"}}'; assert_eq "api_key_env: base url" 0 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"
put '{"env":{"OTHER":"x"}}'; assert_eq "api_key_env: none" 1 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"
put '{}'; assert_eq "api_key_env: no env" 1 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"
echo '{bad' >"$SETTINGS"; assert_eq "api_key_env: invalid json" 1 "$(rc claude_matrix_auth_has_api_key_env "$SETTINGS")"

assert_eq "proxy_env: missing file" 1 "$(rc claude_matrix_settings_has_proxy_env "$TL_TMP/absent.json")"
put '{"env":{"ANTHROPIC_BASE_URL":"https://x"}}'; assert_eq "proxy_env: base url" 0 "$(rc claude_matrix_settings_has_proxy_env "$SETTINGS")"
put '{"env":{"ANTHROPIC_API_KEY":"my-Proxy-key"}}'; assert_eq "proxy_env: PROXY key (case-insens)" 0 "$(rc claude_matrix_settings_has_proxy_env "$SETTINGS")"
put '{"env":{"ANTHROPIC_API_KEY":"plain"}}'; assert_eq "proxy_env: plain key" 1 "$(rc claude_matrix_settings_has_proxy_env "$SETTINGS")"

# --- conflict detection via CLAUDE_BIN ------------------------------------------------------------------
mkbin() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$TL_TMP/$1"; chmod +x "$TL_TMP/$1"; }
mkbin claude-conflict 'echo "{\"authMethod\":\"claude.ai\",\"apiKeySource\":\"ANTHROPIC_API_KEY\"}"'
mkbin claude-oauth 'echo "{\"authMethod\":\"claude.ai\",\"apiKeySource\":\"none\"}"'
mkbin claude-fail 'echo oops >&2; exit 3'
assert_eq "conflict: oauth + api key source" 0 "$(CLAUDE_BIN="$TL_TMP/claude-conflict" rc claude_matrix_auth_has_conflict)"
assert_eq "conflict: oauth only" 1 "$(CLAUDE_BIN="$TL_TMP/claude-oauth" rc claude_matrix_auth_has_conflict)"
assert_eq "conflict: failing cli" 1 "$(CLAUDE_BIN="$TL_TMP/claude-fail" rc claude_matrix_auth_has_conflict)"
assert_eq "conflict: no claude installed" 1 "$(rc claude_matrix_auth_has_conflict)"
tl_stub claude 'echo "{\"authMethod\":\"claude.ai\",\"apiKeySource\":\"ANTHROPIC_API_KEY\"}"'
hash -r
assert_eq "conflict: claude resolved from PATH" 0 "$(rc claude_matrix_auth_has_conflict)"
rm -f "$TL_BIN/claude"; hash -r

# --- should_strip --------------------------------------------------------------------------------------------
put '{"env":{"ANTHROPIC_API_KEY":"plain"}}'
export CLAUDE_BIN="$TL_TMP/claude-oauth"
assert_eq "strip?: no conflict, no skip flag" 1 "$(rc claude_matrix_auth_should_strip_settings)"
assert_eq "strip?: skip flag but no proxy" 1 "$(SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 rc claude_matrix_auth_should_strip_settings)"
put '{"env":{"ANTHROPIC_BASE_URL":"https://proxy"}}'
assert_eq "strip?: skip flag + proxy" 0 "$(SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 rc claude_matrix_auth_should_strip_settings)"
assert_eq "strip?: proxy but no skip flag" 1 "$(rc claude_matrix_auth_should_strip_settings)"
assert_eq "strip?: conflict" 0 "$(CLAUDE_BIN="$TL_TMP/claude-conflict" rc claude_matrix_auth_should_strip_settings)"

# --- prepare / restore -------------------------------------------------------------------------------------------
ORIG='{"env":{"ANTHROPIC_API_KEY":"k","ANTHROPIC_AUTH_TOKEN":"t","ANTHROPIC_BASE_URL":"u","ANTHROPIC_DEFAULT_OPUS_MODEL":"o","ANTHROPIC_DEFAULT_SONNET_MODEL_NAME":"s","CUSTOM":"keep"},"theme":"dark"}'
put "$ORIG"
CLAUDE_BIN="$TL_TMP/claude-oauth" claude_matrix_auth_prepare
assert_eq "prepare: no conflict leaves settings alone" "$(jq -c . <<<"$ORIG")" "$(jq -c . "$SETTINGS")"
assert_eq "prepare: not marked prepared" 0 "$_claude_matrix_auth_prepared"
put '{"env":{"CUSTOM":"keep"}}'
CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare
assert_eq "prepare: conflict but no api-key env leaves settings alone" '{"env":{"CUSTOM":"keep"}}' "$(jq -c . "$SETTINGS")"

put "$ORIG"
# jq reported missing (checked only after the key detection already used jq): warn and keep settings
command() { if [[ "${1:-}" == -v && "${2:-}" == jq && "${SB_T_NOJQ:-}" == 1 ]]; then return 1; fi; builtin command "$@"; }
SB_T_NOJQ=1 CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare 2>"$TL_TMP/warn"
unset -f command
assert_contains "prepare: warns when jq missing" "$(cat "$TL_TMP/warn")" "WARN: jq required to strip Claude settings API keys"
assert_eq "prepare: settings untouched without jq" "$(jq -c . <<<"$ORIG")" "$(jq -c . "$SETTINGS")"

CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare
assert_eq "prepare: provider keys stripped, others kept" '{"env":{"CUSTOM":"keep"},"theme":"dark"}' "$(jq -c . "$SETTINGS")"
assert_eq "prepare: marked prepared" 1 "$_claude_matrix_auth_prepared"
assert_file_exists "prepare: backup kept" "$_claude_matrix_auth_backup"
assert_file_absent "prepare: temp file moved" "$SETTINGS.matrix-auth.tmp"
backup="$_claude_matrix_auth_backup"
claude_matrix_auth_restore
assert_eq "restore: original settings back" "$(jq -c . <<<"$ORIG")" "$(jq -c . "$SETTINGS")"
assert_file_absent "restore: backup removed" "$backup"
assert_eq "restore: state reset (backup)" "" "$_claude_matrix_auth_backup"
assert_eq "restore: state reset (prepared)" 0 "$_claude_matrix_auth_prepared"
put '{"changed":true}'
claude_matrix_auth_restore
assert_eq "restore: no-op when not prepared" '{"changed":true}' "$(jq -c . "$SETTINGS")"
# prepared but backup lost: nothing copied, state still reset
_claude_matrix_auth_prepared=1; _claude_matrix_auth_backup="$TL_TMP/lost-backup"
claude_matrix_auth_restore
assert_eq "restore: lost backup leaves settings" '{"changed":true}' "$(jq -c . "$SETTINGS")"
assert_eq "restore: lost backup resets state" 0 "$_claude_matrix_auth_prepared"

# --- R14-04: the operator's settings keep their mode and survive an interrupted run ---------------------------------
put "$ORIG"; chmod 600 "$SETTINGS"
before_sum="$(cksum <"$SETTINGS")"
CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare
assert_eq "mode: stripped copy keeps the 0600 mode" 600 "$(stat -c %a "$SETTINGS")"
assert_eq "mode: stripped settings really lack the keys" '{"env":{"CUSTOM":"keep"},"theme":"dark"}' "$(jq -c . "$SETTINGS")"
leftovers=("$HOME/.claude"/settings.json.matrix-auth.*)
assert_eq "mode: no temp file left beside the settings" 0 "$([[ -e "${leftovers[0]}" ]] && echo "${#leftovers[@]}" || echo 0)"
claude_matrix_auth_restore
assert_eq "mode: restore keeps the 0600 mode" 600 "$(stat -c %a "$SETTINGS")"
assert_eq "mode: restore is byte-identical" "$before_sum" "$(cksum <"$SETTINGS")"
assert_file_absent "mode: backup consumed by the restore" "$SETTINGS.sb-matrix-backup"

# a killed run (SIGKILL cannot be trapped) leaves the backup beside the settings; the next prepare puts it back
put "$ORIG"; chmod 600 "$SETTINGS"
CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare
_claude_matrix_auth_prepared=0; _claude_matrix_auth_backup=""   # simulate a fresh process after the kill
CLAUDE_BIN="$TL_TMP/claude-oauth" claude_matrix_auth_prepare
assert_eq "stale backup: restored by the next prepare" "$(jq -c . <<<"$ORIG")" "$(jq -c . "$SETTINGS")"
assert_file_absent "stale backup: consumed" "$SETTINGS.sb-matrix-backup"

# SIGTERM/SIGINT inside the stripped window restore the file before the process dies
for sig in TERM INT; do
  put "$ORIG"; chmod 600 "$SETTINGS"
  (
    source "$TL_REPO_ROOT/scripts/lib/claude-matrix-auth.sh"
    CLAUDE_BIN="$TL_TMP/claude-conflict" claude_matrix_auth_prepare
    kill -s "$sig" "$BASHPID"
    sleep 5
  ) >/dev/null 2>&1
  assert_eq "signal $sig: settings restored" "$(jq -c . <<<"$ORIG")" "$(jq -c . "$SETTINGS")"
  assert_eq "signal $sig: mode restored" 600 "$(stat -c %a "$SETTINGS")"
done

# BSD stat fallback and the 600 default when no stat answers
put "$ORIG"; chmod 640 "$SETTINGS"
tl_stub stat 'if [[ "$1" == "-c" ]]; then exit 1; fi; if [[ "$1" == "-f" ]]; then echo 640; exit 0; fi; exit 1'
assert_eq "file mode: BSD stat -f %Lp fallback" 640 "$(_claude_matrix_file_mode "$SETTINGS")"
tl_stub stat 'exit 1'
assert_eq "file mode: default 600 when stat is unusable" 600 "$(_claude_matrix_file_mode "$SETTINGS")"
rm -f "$TL_BIN/stat"

# --- should_export / env lines / export --------------------------------------------------------------------------------
put '{"env":{"ANTHROPIC_API_KEY":"k1","CUSTOM_FLAG":"on"}}'
export CLAUDE_BIN="$TL_TMP/claude-oauth"
assert_eq "export?: ok" 0 "$(rc claude_matrix_should_export_settings_env)"
assert_eq "export?: SB skip flag" 1 "$(SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 rc claude_matrix_should_export_settings_env)"
assert_eq "export?: print skip flag" 1 "$(CLAUDE_PRINT_SKIP_SETTINGS_EXPORT=1 rc claude_matrix_should_export_settings_env)"
assert_eq "export?: settings missing" 1 "$(CLAUDE_SETTINGS_FILE='' HOME="$TL_TMP/nohome" rc claude_matrix_should_export_settings_env)"
command() { if [[ "${1:-}" == -v && "${2:-}" == jq ]]; then return 1; fi; builtin command "$@"; }
assert_eq "export?: jq missing" 1 "$(rc claude_matrix_should_export_settings_env)"
unset -f command
put '{"env":{"OTHER":"x"}}'
assert_eq "export?: no api key env" 1 "$(rc claude_matrix_should_export_settings_env)"
put '{"env":{"ANTHROPIC_API_KEY":"k1","CUSTOM_FLAG":"on"}}'
assert_eq "export?: conflict" 1 "$(CLAUDE_BIN="$TL_TMP/claude-conflict" rc claude_matrix_should_export_settings_env)"

assert_eq "shell auth env: none" 1 "$(rc claude_matrix_shell_has_auth_env)"
assert_eq "shell auth env: key" 0 "$(ANTHROPIC_API_KEY=a rc claude_matrix_shell_has_auth_env)"
assert_eq "shell auth env: token" 0 "$(ANTHROPIC_AUTH_TOKEN=a rc claude_matrix_shell_has_auth_env)"
assert_eq "shell auth env: base url" 0 "$(ANTHROPIC_BASE_URL=a rc claude_matrix_shell_has_auth_env)"

assert_eq "env lines: from settings" "ANTHROPIC_API_KEY=k1
CUSTOM_FLAG=on" "$(claude_matrix_auth_env_lines)"
assert_eq "env lines: shell pass-through when export skipped" "ANTHROPIC_API_KEY=sk
ANTHROPIC_BASE_URL=http://gw" "$(SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 ANTHROPIC_API_KEY=sk ANTHROPIC_BASE_URL=http://gw claude_matrix_auth_env_lines)"
assert_eq "env lines: nothing to pass" "" "$(SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 claude_matrix_auth_env_lines)"

( claude_matrix_export_settings_env; echo "exported:${ANTHROPIC_API_KEY:-}:${CUSTOM_FLAG:-}" ) >"$TL_TMP/exp.out"
assert_eq "export: settings env exported into shell" "exported:k1:on" "$(cat "$TL_TMP/exp.out")"
( SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1 claude_matrix_export_settings_env; echo "exported:${CUSTOM_FLAG:-none}" ) >"$TL_TMP/exp.out"
assert_eq "export: skipped when disabled" "exported:none" "$(cat "$TL_TMP/exp.out")"
# a multi-line value yields a blank line, which is skipped
put '{"env":{"ANTHROPIC_API_KEY":"first\n\nsecond"}}'
( claude_matrix_export_settings_env; echo "exported:${ANTHROPIC_API_KEY:-}" ) >"$TL_TMP/exp.out"
assert_eq "export: blank lines skipped" "exported:first" "$(cat "$TL_TMP/exp.out")"

tl_results
