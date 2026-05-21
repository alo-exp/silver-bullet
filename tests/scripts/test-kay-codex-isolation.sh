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

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$path]"
    (( FAIL++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_HOME="$TMP/original-home"
FAKE_BIN="$TMP/bin/kay"
mkdir -p "$ORIGINAL_HOME/.kay" "$(dirname "$FAKE_BIN")"
mkdir -p "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion"

cat > "$ORIGINAL_HOME/.kay/auth.json" <<'EOF'
{
  "provider_credentials": {
    "opencode-go": {
      "api_key": "test-opencode-go-key"
    }
  }
}
EOF

cat > "$FAKE_BIN" <<'EOF'
#!/usr/bin/env bash
printf 'kay 0.9.6\n'
EOF
chmod +x "$FAKE_BIN"
cat > "$ORIGINAL_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion/SKILL.md" <<'EOF'
---
name: verification-before-completion
---
EOF

export HOME="$ORIGINAL_HOME"
export CODEX_BIN="$FAKE_BIN"
unset MINIMAX_API_KEY OPENCODE_GO_API_KEY SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR SB_LIVE_ORIGINAL_HOME
unset KAY_HOME KAY_SB_TEST_HOME

# shellcheck source=tests/live/lib/kay-codex-isolation.sh
source "$REPO_ROOT/tests/live/lib/kay-codex-isolation.sh"
setup_kay_codex_isolation

assert_eq "KAY_HOME is redirected to isolated test root" "$SB_LIVE_CODEX_ISOLATION_DIR" "$KAY_HOME"
assert_eq "KAY_SB_TEST_HOME mirrors KAY_HOME" "$KAY_HOME" "$KAY_SB_TEST_HOME"
assert_eq "OpenCode-Go key is sourced from original Kay auth" "test-opencode-go-key" "$OPENCODE_GO_API_KEY"
assert_eq "MiniMax key stays unset for Kay OCG runs" "" "${MINIMAX_API_KEY:-}"
assert_eq "Kay/Codex binary is preserved" "$FAKE_BIN" "$CODEX_BIN"
assert_file_contains "Isolated Kay config pins OpenCode-Go provider" "$KAY_HOME/.kay/config.toml" 'model_provider = "opencode-go"'
assert_file_contains "Isolated Kay config pins MiniMax M2.7" "$KAY_HOME/.kay/config.toml" 'model = "MiniMax-M2.7"'
assert_file_exists "Isolated Kay cache copies dependency plugin versions" "$KAY_HOME/.codex/plugins/cache/superpowers-marketplace/superpowers/5.1.0/skills/verification-before-completion/SKILL.md"
assert_file_exists "Isolated Kay state root exists under .kay" "$KAY_HOME/.kay/.silver-bullet"
case "$SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD" in
  *"opencode-go"*"MiniMax-M2.7"*"Do not call agent"*"split argv array"*)
    echo "PASS: isolated Kay prompt guard constrains provider, model, agents, and command arrays"
    (( PASS++ )) || true
    ;;
  *)
    echo "FAIL: isolated Kay prompt guard missing expected constraints"
    (( FAIL++ )) || true
    ;;
esac

isolated_root="$SB_LIVE_CODEX_ISOLATION_DIR"
teardown_kay_codex_isolation

if [[ -z "${KAY_HOME:-}" ]]; then
  echo "PASS: KAY_HOME unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: KAY_HOME still set after teardown: $KAY_HOME"
  (( FAIL++ )) || true
fi
if [[ -z "${KAY_SB_TEST_HOME:-}" ]]; then
  echo "PASS: KAY_SB_TEST_HOME unset after teardown"
  (( PASS++ )) || true
else
  echo "FAIL: KAY_SB_TEST_HOME still set after teardown: $KAY_SB_TEST_HOME"
  (( FAIL++ )) || true
fi
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
