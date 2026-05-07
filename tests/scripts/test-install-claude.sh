#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_file_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qF "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — unexpected [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
if [[ -z "$CLAUDE_BIN" ]] || [[ ! -x "$CLAUDE_BIN" ]]; then
  echo "SKIP: claude CLI not available in PATH"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/install-claude.sh"
HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"

HOME="$HOME_DIR" "$CLAUDE_BIN" plugin marketplace add https://github.com/anthropics/claude-plugins-official >/dev/null
HOME="$HOME_DIR" "$CLAUDE_BIN" plugin install data-engineering@claude-plugins-official >/dev/null
HOME="$HOME_DIR" "$CLAUDE_BIN" plugin install frontend-design@claude-plugins-official >/dev/null
HOME="$HOME_DIR" "$CLAUDE_BIN" plugin install product-tracking-skills@claude-plugins-official >/dev/null

OLD_SB_CACHE_DIR="$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/0.27.1"
mkdir -p "$(dirname "$OLD_SB_CACHE_DIR")"
cat > "$HOME_DIR/.claude/settings.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${OLD_SB_CACHE_DIR}/hooks/session-start\"",
            "timeout": 15,
            "async": false
          },
          {
            "type": "command",
            "command": "\"${OLD_SB_CACHE_DIR}/hooks/spec-session-record.sh\"",
            "timeout": 10,
            "async": false
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "\"${OLD_SB_CACHE_DIR}/hooks/semantic-compress.sh\"",
            "timeout": 30,
            "async": false
          }
        ]
      }
    ]
  }
}
EOF

HOME="$HOME_DIR" bash "$SCRIPT" --purge-legacy-plugins >/dev/null

if grep -qF 'git@github.com:' "$HOME_DIR/.gitconfig" && grep -qF 'ssh://git@github.com/' "$HOME_DIR/.gitconfig"; then
  echo "PASS: git HTTPS rewrite configured"
  (( PASS++ )) || true
else
  echo "FAIL: git HTTPS rewrite configured"
  (( FAIL++ )) || true
fi

if jq -e 'has("knowledge-work-plugins")' "$HOME_DIR/.claude/plugins/known_marketplaces.json" >/dev/null 2>&1; then
  echo "PASS: knowledge-work marketplace added"
  (( PASS++ )) || true
else
  echo "FAIL: knowledge-work marketplace added — missing knowledge-work-plugins entry"
  (( FAIL++ )) || true
fi

CURRENT_SB_CACHE_DIR="$(find "$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
if [[ -n "$CURRENT_SB_CACHE_DIR" ]] && grep -qF "$CURRENT_SB_CACHE_DIR" "$HOME_DIR/.claude/settings.json" && ! grep -qF "$OLD_SB_CACHE_DIR" "$HOME_DIR/.claude/settings.json"; then
  echo "PASS: Silver Bullet hook paths refreshed in Claude settings"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet hook paths refreshed in Claude settings"
  (( FAIL++ )) || true
fi

if [[ -n "$CURRENT_SB_CACHE_DIR" ]] && grep -qF '"hookEventName":"SessionStart"' "$CURRENT_SB_CACHE_DIR/hooks/spec-session-record.sh"; then
  echo "PASS: Silver Bullet session-start hook emits hookEventName"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet session-start hook emits hookEventName"
  (( FAIL++ )) || true
fi

HOME="$HOME_DIR" "$CLAUDE_BIN" plugin list --json | jq -e '
  any(.[]; .id == "silver-bullet@alo-labs" and .scope == "user")
  and any(.[]; .id == "superpowers@superpowers-marketplace" and .scope == "user")
  and any(.[]; .id == "engineering@knowledge-work-plugins" and .scope == "user")
  and any(.[]; .id == "design@knowledge-work-plugins" and .scope == "user")
  and any(.[]; .id == "product-management@knowledge-work-plugins" and .scope == "user")
  and all(.[]; .id != "data-engineering@claude-plugins-official")
  and all(.[]; .id != "frontend-design@claude-plugins-official")
  and all(.[]; .id != "product-tracking-skills@claude-plugins-official")
' >/dev/null

echo "PASS: exact Claude plugin set installed"
(( PASS++ )) || true

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
