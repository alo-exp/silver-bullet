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

# ---- R8-17: package-manager layouts are judged by what the binary is, not its name
mkver() { printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && echo "codex-cli 0.50.0"\nexit 0\n' >"$1"; chmod +x "$1"; }
NPM="$TL_TMP/npm-prefix"
PKG="$NPM/lib/node_modules/@openai/codex"
mkdir -p "$NPM/bin" "$PKG/bin" "$PKG/vendor/aarch64-apple-darwin/codex" "$PKG/vendor/x86_64-unknown-linux-musl/codex"
mkver "$PKG/bin/codex.js"
printf '#!/usr/bin/env bash\nexit 126\n' >"$PKG/vendor/aarch64-apple-darwin/codex/codex"   # other arch: does not run here
chmod +x "$PKG/vendor/aarch64-apple-darwin/codex/codex"
mkver "$PKG/vendor/x86_64-unknown-linux-musl/codex/codex"
ln -s ../lib/node_modules/@openai/codex/bin/codex.js "$NPM/bin/codex"
assert_eq "npm install (codex -> codex.js) resolves to the vendored native binary" \
  "$PKG/vendor/x86_64-unknown-linux-musl/codex/codex" "$(PATH="$NPM/bin:$NOCODEX_PATH" resolve_native_codex_cli_path)"
rm -rf "$PKG/vendor"
assert_eq "npm shim without a runnable vendored binary is used when it reports a Codex version" \
  "$NPM/bin/codex" "$(PATH="$NPM/bin:$NOCODEX_PATH" resolve_native_codex_cli_path)"
# a .js shim from some other package is not the Codex npm layout
OTHERPKG="$TL_TMP/other-pkg/node_modules/some-tool"
mkdir -p "$OTHERPKG/bin"
printf '#!/usr/bin/env bash\necho "some-tool 1.0"\n' >"$OTHERPKG/bin/tool.js"; chmod +x "$OTHERPKG/bin/tool.js"
ln -s "$OTHERPKG/bin/tool.js" "$TL_TMP/other-pkg/codex"
rc=0; PATH="$TL_TMP/other-pkg:$NOCODEX_PATH" resolve_native_codex_cli_path >/dev/null || rc=$?
assert_eq "a .js binary outside @openai/codex that is not Codex is rejected" 1 "$rc"
BREW="$TL_TMP/brew"
mkdir -p "$BREW/bin" "$BREW/cask/codex/0.50.0"
mkver "$BREW/cask/codex/0.50.0/codex-aarch64-apple-darwin"
ln -s ../cask/codex/0.50.0/codex-aarch64-apple-darwin "$BREW/bin/codex"
assert_eq "symlink to an arch-suffixed native binary that reports a Codex version" \
  "$BREW/bin/codex" "$(PATH="$BREW/bin:$NOCODEX_PATH" resolve_native_codex_cli_path)"
assert_eq "explicit CODEX_BIN with another name is accepted when it reports a Codex version" \
  "$BREW/cask/codex/0.50.0/codex-aarch64-apple-darwin" \
  "$(CODEX_BIN="$BREW/cask/codex/0.50.0/codex-aarch64-apple-darwin" PATH="$NOCODEX_PATH" resolve_native_codex_cli_path)"
mkdir -p "$TL_TMP/dir/codex"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path "$TL_TMP/dir/codex" >/dev/null || rc=$?
assert_eq "a directory named codex is never a CLI" 1 "$rc"
printf '#!/usr/bin/env bash\necho "ollama version 1.0"\n' >"$TL_TMP/other/wrong-product"
chmod +x "$TL_TMP/other/wrong-product"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path "$TL_TMP/other/wrong-product" >/dev/null || rc=$?
assert_eq "a binary reporting another product is rejected" 1 "$rc"
printf '#!/usr/bin/env bash\nexit 3\n' >"$TL_TMP/other/failing"
chmod +x "$TL_TMP/other/failing"
rc=0; PATH="$NOCODEX_PATH" resolve_native_codex_cli_path "$TL_TMP/other/failing" >/dev/null || rc=$?
assert_eq "a binary whose --version fails is rejected" 1 "$rc"

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
