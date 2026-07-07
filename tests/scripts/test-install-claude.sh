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
# shellcheck source=scripts/lib/plugin-cache-version.sh
source "${REPO_ROOT}/scripts/lib/plugin-cache-version.sh"
HOME_DIR="$TMP/home"
mkdir -p "$HOME_DIR"

HOME="$HOME_DIR" "$CLAUDE_BIN" plugin marketplace add https://github.com/anthropics/claude-plugins-official >/dev/null
HOME="$HOME_DIR" "$CLAUDE_BIN" plugin install data-engineering@claude-plugins-official >/dev/null
HOME="$HOME_DIR" "$CLAUDE_BIN" plugin install frontend-design@claude-plugins-official >/dev/null

OLD_SB_CACHE_DIR="$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/0.27.1"
CURRENT_CODEX_SB_CACHE_DIR="$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
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
          },
          {
            "type": "command",
            "command": "\"${CURRENT_CODEX_SB_CACHE_DIR}/hooks/session-start\"",
            "timeout": 15,
            "async": false
          },
          {
            "type": "command",
            "command": "\"\${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "timeout": 15,
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

if jq -e 'has("knowledge-work-plugins") | not' "$HOME_DIR/.claude/plugins/known_marketplaces.json" >/dev/null 2>&1; then
  echo "PASS: knowledge-work marketplace not added by default"
  (( PASS++ )) || true
else
  echo "FAIL: knowledge-work marketplace should not be added by default"
  (( FAIL++ )) || true
fi

CURRENT_SB_CACHE_DIR="$(sb_plugin_cache_latest_version_dir "$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet" 2>/dev/null || true)"
STABLE_SB_CACHE_DIR="$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/current"
if [[ -n "$CURRENT_SB_CACHE_DIR" ]] && grep -qF "$STABLE_SB_CACHE_DIR" "$HOME_DIR/.claude/settings.json" && ! grep -qF "$OLD_SB_CACHE_DIR" "$HOME_DIR/.claude/settings.json"; then
  echo "PASS: Silver Bullet hook paths refreshed to stable alias in Claude settings"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet hook paths refreshed to stable alias in Claude settings"
  (( FAIL++ )) || true
fi

assert_not_contains "Codex-root Silver Bullet hook path removed from Claude settings" "$CURRENT_CODEX_SB_CACHE_DIR/hooks/session-start" "$HOME_DIR/.claude/settings.json"
assert_not_contains "Placeholder Silver Bullet hook path removed from Claude settings" "\${CLAUDE_PLUGIN_ROOT}/hooks/session-start" "$HOME_DIR/.claude/settings.json"

assert_file_exists "Silver Bullet stable alias exposes hook cache" "$STABLE_SB_CACHE_DIR/hooks/session-start"

assert_file_exists "Silver Bullet Claude agent bundle rendered in repo" "$REPO_ROOT/agents/claude/silver:init/SKILL.md"
assert_file_exists "Silver Bullet Claude agent bundle materialized in cache" "$CURRENT_SB_CACHE_DIR/agents/claude/silver:init/SKILL.md"
assert_file_exists "Silver Bullet skills alias remains available in cache" "$CURRENT_SB_CACHE_DIR/skills/silver:init/SKILL.md"

assert_file_absent "Silver Bullet Claude cache does not ship duplicate commands surface" "$CURRENT_SB_CACHE_DIR/commands"

if [[ -L "$CURRENT_SB_CACHE_DIR/skills" ]] && [[ "$(readlink "$CURRENT_SB_CACHE_DIR/skills")" == "agents/claude" ]]; then
  echo "PASS: Silver Bullet skills alias targets agents/claude"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet skills alias targets agents/claude"
  (( FAIL++ )) || true
fi

if [[ -n "$CURRENT_SB_CACHE_DIR" ]] && grep -qF '"hookEventName":"SessionStart"' "$CURRENT_SB_CACHE_DIR/hooks/spec-session-record.sh"; then
  echo "PASS: Silver Bullet session-start hook emits hookEventName"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet session-start hook emits hookEventName"
  (( FAIL++ )) || true
fi

if [[ -n "$CURRENT_SB_CACHE_DIR" ]] \
  && grep -qF 'name: silver:init' "$CURRENT_SB_CACHE_DIR/agents/claude/silver:init/SKILL.md" \
  && grep -qF 'name: silver:feature' "$CURRENT_SB_CACHE_DIR/agents/claude/silver:feature/SKILL.md" \
  && grep -qF 'name: silver' "$CURRENT_SB_CACHE_DIR/agents/claude/silver/SKILL.md"; then
  echo "PASS: Silver Bullet skill names rewritten for Claude picker"
  (( PASS++ )) || true
else
  echo "FAIL: Silver Bullet skill names rewritten for Claude picker"
  (( FAIL++ )) || true
fi

HOME="$HOME_DIR" "$CLAUDE_BIN" plugin list --json | jq -e '
  any(.[]; .id == "silver-bullet@alo-labs" and .scope == "user")
  and all(.[]; .id != "superpowers@superpowers-marketplace")
  and all(.[]; .id != "engineering@knowledge-work-plugins")
  and all(.[]; .id != "design@knowledge-work-plugins")
  and all(.[]; .id != "product-management@knowledge-work-plugins")
  and all(.[]; .id != "data-engineering@claude-plugins-official")
  and all(.[]; .id != "frontend-design@claude-plugins-official")
  and all(.[]; .id != "product-tracking-skills@claude-plugins-official")
' >/dev/null

echo "PASS: exact Claude plugin set installed"
(( PASS++ )) || true

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
