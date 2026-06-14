#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle]"
    (( FAIL++ )) || true
  fi
}

assert_line_count() {
  local desc="$1" expected="$2" file="$3"
  local actual=0
  if [[ -f "$file" ]]; then
    actual="$(wc -l < "$file" | tr -d ' ')"
  fi
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — expected $expected line(s), got $actual"
    (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/post-release-refresh.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLAUDE_STUB="$TMP/install-claude.sh"
CODEX_STUB="$TMP/install-codex.sh"
CURSOR_STUB="$TMP/install-cursor.sh"
CLAUDE_LOG="$TMP/claude.log"
CODEX_LOG="$TMP/codex.log"
CURSOR_LOG="$TMP/cursor.log"

cat > "$CLAUDE_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${CLAUDE_LOG_FILE:?missing CLAUDE_LOG_FILE}"
EOF
chmod +x "$CLAUDE_STUB"

cat > "$CODEX_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${CODEX_LOG_FILE:?missing CODEX_LOG_FILE}"
EOF
chmod +x "$CODEX_STUB"

cat > "$CURSOR_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${CURSOR_LOG_FILE:?missing CURSOR_LOG_FILE}"
EOF
chmod +x "$CURSOR_STUB"

SB_POST_RELEASE_CLAUDE_INSTALL_SCRIPT="$CLAUDE_STUB" \
SB_POST_RELEASE_CODEX_INSTALL_SCRIPT="$CODEX_STUB" \
SB_POST_RELEASE_CURSOR_INSTALL_SCRIPT="$CURSOR_STUB" \
CLAUDE_LOG_FILE="$CLAUDE_LOG" \
CODEX_LOG_FILE="$CODEX_LOG" \
CURSOR_LOG_FILE="$CURSOR_LOG" \
  bash "$SCRIPT" >/dev/null

assert_line_count "Claude refresh script invoked exactly once" 1 "$CLAUDE_LOG"
assert_line_count "Codex refresh script invoked exactly once" 1 "$CODEX_LOG"
assert_line_count "Cursor refresh script invoked exactly once" 1 "$CURSOR_LOG"
assert_contains "Claude refresh uses purge reinstall flag" "--purge-legacy-plugins" "$(cat "$CLAUDE_LOG")"
assert_contains "Codex refresh uses purge reinstall flag" "--purge-legacy-skills" "$(cat "$CODEX_LOG")"
assert_contains "Cursor refresh uses public marketplace flag" "--public-release" "$(cat "$CURSOR_LOG")"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
