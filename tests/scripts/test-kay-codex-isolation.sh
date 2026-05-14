#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected [$expected], got [$actual]"
    (( FAIL++ )) || true
  fi
}

assert_file_contains() {
  local desc="$1" path="$2" needle="$3"
  if grep -qF "$needle" "$path"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $path"
    (( FAIL++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_HOME="$TMP/original-home"
FAKE_BIN="$TMP/bin/kay"
mkdir -p "$ORIGINAL_HOME/.kay" "$(dirname "$FAKE_BIN")"

cat > "$ORIGINAL_HOME/.kay/kay.toml" <<'EOF'
[provider]
default_model = "MiniMax-M2.1"

[provider.minimax]
api_key = "test-minimax-key"
endpoint = "https://api.minimax.io/v1/text/chatcompletion_v2"
EOF

cat > "$FAKE_BIN" <<'EOF'
#!/usr/bin/env bash
printf 'kay 0.9.1\n'
EOF
chmod +x "$FAKE_BIN"

export HOME="$ORIGINAL_HOME"
export CODE_HOME="$TMP/original-code-home"
export CODEX_HOME="$TMP/original-codex-home"
export CODEX_BIN="$FAKE_BIN"
unset MINIMAX_API_KEY SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR SB_LIVE_ORIGINAL_HOME

# shellcheck source=tests/live/lib/kay-codex-isolation.sh
source "$REPO_ROOT/tests/live/lib/kay-codex-isolation.sh"
setup_kay_codex_isolation

assert_eq "HOME is redirected to isolated test home" "${SB_LIVE_CODEX_ISOLATION_DIR}/home" "$HOME"
assert_eq "CODE_HOME is redirected to isolated Kay config root" "${SB_LIVE_CODEX_ISOLATION_DIR}/code-home" "$CODE_HOME"
assert_eq "CODEX_HOME is redirected under isolated home" "${HOME}/.codex" "$CODEX_HOME"
assert_eq "MiniMax key is sourced from original Kay config" "test-minimax-key" "$MINIMAX_API_KEY"
assert_eq "Kay/Codex binary is preserved" "$FAKE_BIN" "$CODEX_BIN"
assert_file_contains "Isolated Kay config pins MiniMax provider" "$CODE_HOME/config.toml" 'model_provider = "minimax"'
assert_file_contains "Isolated Kay config pins MiniMax M2.7" "$CODE_HOME/config.toml" 'model = "MiniMax-M2.7"'

isolated_root="$SB_LIVE_CODEX_ISOLATION_DIR"
teardown_kay_codex_isolation

assert_eq "HOME restored after teardown" "$ORIGINAL_HOME" "$HOME"
assert_eq "CODE_HOME restored after teardown" "$TMP/original-code-home" "$CODE_HOME"
assert_eq "CODEX_HOME restored after teardown" "$TMP/original-codex-home" "$CODEX_HOME"
if [[ ! -e "$isolated_root" ]]; then
  echo "PASS: isolated runtime directory cleaned up"
  (( PASS++ )) || true
else
  echo "FAIL: isolated runtime directory still exists: $isolated_root"
  (( FAIL++ )) || true
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
