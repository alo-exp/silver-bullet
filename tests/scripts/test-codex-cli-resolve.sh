#!/usr/bin/env bash
# scripts/lib/codex-cli.sh: native Codex CLI resolution, CODEX_BIN export and
# the MCP-stripped lightweight CODEX_HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

# shellcheck source=scripts/lib/codex-cli.sh
source "$TL_REPO_ROOT/scripts/lib/codex-cli.sh"
unset CODEX_BIN
# Hide any real codex install: the macOS app bundle search is redirected into the sandbox.
APPS="$TL_TMP/apps"
mkdir -p "$APPS/a" "$APPS/b" "$TL_TMP/real" "$TL_TMP/other"
export SB_CODEX_APP_CANDIDATES="$APPS/a/codex:$APPS/b/codex"
BASE_PATH="$PATH"

mkexe() { printf '#!/usr/bin/env bash\nexit 0\n' >"$1"; chmod +x "$1"; }
mkexe "$TL_TMP/real/codex"
mkexe "$TL_TMP/other/mycodex"
mkexe "$TL_TMP/other/not-codex"

# ---- requested value
assert_eq "requested absolute path named codex" "$TL_TMP/real/codex" "$(resolve_native_codex_cli_path "$TL_TMP/real/codex")"
PATH="$TL_TMP/real:$BASE_PATH" assert_eq "requested bare name found on PATH" "$TL_TMP/real/codex" "$(PATH="$TL_TMP/real:$BASE_PATH" resolve_native_codex_cli_path codex)"
assert_eq "CODEX_BIN is the default request" "$TL_TMP/real/codex" "$(CODEX_BIN="$TL_TMP/real/codex" resolve_native_codex_cli_path)"
# a request whose basename is not codex is ignored; nothing else available -> failure
NOCODEX_PATH="$(tl_path_without codex)"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path "$TL_TMP/other/mycodex" >/dev/null || rc=$?
assert_eq "non-codex basename request without fallbacks fails" 1 "$rc"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path "$TL_TMP/does/not/exist" >/dev/null || rc=$?
assert_eq "unresolvable request fails" 1 "$rc"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path >/dev/null || rc=$?
assert_eq "no request and nothing installed fails" 1 "$rc"

# ---- app bundle candidates (first usable wins; non-codex basenames are skipped)
mkexe "$APPS/b/codex"
assert_eq "app bundle candidate used" "$APPS/b/codex" "$(PATH="$NOCODEX_PATH" resolve_native_codex_cli_path)"
mkexe "$APPS/a/codex"
assert_eq "first app candidate wins" "$APPS/a/codex" "$(PATH="$NOCODEX_PATH" resolve_native_codex_cli_path)"
export SB_CODEX_APP_CANDIDATES="$TL_TMP/other/not-codex"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path >/dev/null || rc=$?
assert_eq "app candidate with a different basename skipped" 1 "$rc"
export SB_CODEX_APP_CANDIDATES="$APPS/a/codex:$APPS/b/codex"

# ---- PATH lookup: the real binary behind a symlink must be named codex
rm -f "$APPS/a/codex" "$APPS/b/codex"
ln -s "$TL_TMP/real/codex" "$TL_BIN/codex"
assert_eq "PATH codex symlinked to a codex binary" "$TL_BIN/codex" "$(resolve_native_codex_cli_path)"
rm -f "$TL_BIN/codex"
ln -s "$TL_TMP/other/not-codex" "$TL_BIN/codex"
rc=0; resolve_native_codex_cli_path >/dev/null || rc=$?
assert_eq "PATH codex wrapper around another binary rejected" 1 "$rc"
rm -f "$TL_BIN/codex"

# ---- agent_codex_export_bin
unset CODEX_BIN
rc=0; PATH="$NOCODEX_PATH" agent_codex_export_bin || rc=$?
assert_eq "export fails when no codex is found" 1 "$rc"
assert_eq "CODEX_BIN stays unset on failure" "" "${CODEX_BIN:-}"
CODEX_BIN="$TL_TMP/real/codex" agent_codex_export_bin
assert_eq "export keeps a valid CODEX_BIN" "$TL_TMP/real/codex" "$(CODEX_BIN="$TL_TMP/real/codex"; agent_codex_export_bin; printf '%s' "$CODEX_BIN")"
export CODEX_BIN="$TL_TMP/real/codex"
agent_codex_export_bin
assert_eq "CODEX_BIN exported" "$TL_TMP/real/codex" "$(bash -c 'printf %s "$CODEX_BIN"')"
unset CODEX_BIN

# ---- MCP stripping
SRC="$TL_TMP/config.toml"
cat >"$SRC" <<'TOML'
model = "gpt"

[features]
a = true

[mcp_servers.foo]
command = "x"

[mcp_servers.foo.env]
K = "v"

[projects."/p"]
trust = "trusted"
TOML
agent_codex_strip_mcp_config_toml "$SRC" "$TL_TMP/out/nested/config.toml"
OUT="$(<"$TL_TMP/out/nested/config.toml")"
assert_contains "top-level keys kept" "$OUT" 'model = "gpt"'
assert_contains "other tables kept" "$OUT" '[features]'
assert_contains "table after the MCP block kept" "$OUT" '[projects."/p"]'
assert_not_contains "mcp_servers table dropped" "$OUT" 'mcp_servers'
assert_not_contains "mcp server body dropped" "$OUT" 'command = "x"'
agent_codex_strip_mcp_config_toml "$TL_TMP/absent.toml" "$TL_TMP/out/empty.toml"
assert_eq "absent source yields an empty config" "" "$(<"$TL_TMP/out/empty.toml")"
rc=0; (agent_codex_strip_mcp_config_toml "$SRC") 2>/dev/null || rc=$?
assert_eq "target argument is required" 1 "$rc"

# ---- lightweight CODEX_HOME
HOME_SRC="$TL_TMP/src-home"
mkdir -p "$HOME_SRC"
printf 'secret' >"$HOME_SRC/auth.json"
printf 'iid' >"$HOME_SRC/installation_id"
cp "$SRC" "$HOME_SRC/config.toml"
agent_codex_prepare_lightweight_codex_home "$HOME_SRC" "$TL_TMP/light"
assert_eq "auth copied" "secret" "$(<"$TL_TMP/light/auth.json")"
assert_eq "installation id copied" "iid" "$(<"$TL_TMP/light/installation_id")"
assert_not_contains "config stripped of MCP" "$(<"$TL_TMP/light/config.toml")" "mcp_servers"
mkdir -p "$TL_TMP/bare-src"
agent_codex_prepare_lightweight_codex_home "$TL_TMP/bare-src" "$TL_TMP/light2"
assert_file_absent "no auth copied when absent" "$TL_TMP/light2/auth.json"
assert_file_absent "no installation id copied when absent" "$TL_TMP/light2/installation_id"
assert_file_exists "config still produced" "$TL_TMP/light2/config.toml"
mkdir -p "$HOME/.codex"
printf 'k = 1\n' >"$HOME/.codex/config.toml"
agent_codex_prepare_lightweight_codex_home "" "$TL_TMP/light3" 2>/dev/null || true
agent_codex_prepare_lightweight_codex_home "$HOME/.codex" "$TL_TMP/light4"
assert_eq "plain config copied through" "k = 1" "$(<"$TL_TMP/light4/config.toml")"

tl_results
