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

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/sync-release-marketplace-versions.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLAUDE_STUB="$TMP/sync-marketplace-version.sh"
CODEX_STUB="$TMP/sync-codex-marketplace-version.sh"
CURSOR_STUB="$TMP/sync-cursor-marketplace-version.sh"
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

if SB_SKIP_PRE_RELEASE_GATE=1 \
  SB_SYNC_MARKETPLACE_VERSION_SCRIPT="$CLAUDE_STUB" \
  SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT="$CODEX_STUB" \
  SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT="$CURSOR_STUB" \
  CLAUDE_LOG_FILE="$CLAUDE_LOG" \
  CODEX_LOG_FILE="$CODEX_LOG" \
  CURSOR_LOG_FILE="$CURSOR_LOG" \
  bash "$SCRIPT" >/dev/null 2>&1; then
  echo "FAIL: wrapper should require an explicit release version"
  FAIL=$((FAIL + 1))
else
  echo "PASS: wrapper rejects missing release version"
  PASS=$((PASS + 1))
fi

SB_SKIP_PRE_RELEASE_GATE=1 \
SB_SYNC_MARKETPLACE_VERSION_SCRIPT="$CLAUDE_STUB" \
SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT="$CODEX_STUB" \
SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT="$CURSOR_STUB" \
CLAUDE_LOG_FILE="$CLAUDE_LOG" \
CODEX_LOG_FILE="$CODEX_LOG" \
CURSOR_LOG_FILE="$CURSOR_LOG" \
  bash "$SCRIPT" v0.37.2 >/dev/null

assert_line_count "Claude marketplace helper invoked exactly once" 1 "$CLAUDE_LOG"
assert_line_count "Codex marketplace helper invoked exactly once" 1 "$CODEX_LOG"
assert_line_count "Cursor marketplace helper invoked exactly once" 1 "$CURSOR_LOG"
assert_contains "Claude marketplace helper receives normalized version" "0.37.2" "$(cat "$CLAUDE_LOG")"
assert_contains "Codex marketplace helper receives normalized version" "0.37.2" "$(cat "$CODEX_LOG")"
assert_contains "Cursor marketplace helper receives normalized version" "0.37.2" "$(cat "$CURSOR_LOG")"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
