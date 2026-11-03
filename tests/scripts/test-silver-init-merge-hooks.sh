#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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

assert_symlink() {
  local desc="$1" path="$2"
  if [[ -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — not a symlink: $path"
    (( FAIL++ )) || true
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/lib/install-claude/merge-hooks.py"
HOME_DIR="$TMP/home"
INSTALL_PATH="$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/0.32.4"
SETTINGS_FILE="$HOME_DIR/.claude/settings.json"

mkdir -p "$HOME_DIR/.claude" "$INSTALL_PATH/hooks"
rsync -a "$REPO_ROOT/hooks/" "$INSTALL_PATH/hooks/"

cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${HOME_DIR}/.claude/plugins/cache/alo-labs/silver-bullet/0.31.0/hooks/session-start\"",
            "timeout": 15,
            "async": false
          },
          {
            "type": "command",
            "command": "\"${HOME_DIR}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/hooks/session-start\"",
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
    ]
  }
}
EOF

HOME="$HOME_DIR" python3 "$SCRIPT" "$INSTALL_PATH" >/dev/null

STABLE_ALIAS="$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/current"

assert_symlink "stable alias created for versioned SB install" "$STABLE_ALIAS"
assert_file_exists "stable alias exposes hook surface" "$STABLE_ALIAS/hooks/session-start"
assert_contains "settings rewritten to stable alias" "$STABLE_ALIAS/hooks/session-start" "$SETTINGS_FILE"
assert_not_contains "old versioned hook path removed" "$HOME_DIR/.claude/plugins/cache/alo-labs/silver-bullet/0.31.0/hooks/session-start" "$SETTINGS_FILE"
assert_not_contains "Codex-root hook path removed" "$HOME_DIR/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/hooks/session-start" "$SETTINGS_FILE"
assert_not_contains "Placeholder hook path removed" "\${CLAUDE_PLUGIN_ROOT}/hooks/session-start" "$SETTINGS_FILE"
assert_contains "new session-start hook registered" "$STABLE_ALIAS/hooks/spec-session-record.sh" "$SETTINGS_FILE"
assert_contains "new prompt hook registered" "$STABLE_ALIAS/hooks/prompt-reminder.sh" "$SETTINGS_FILE"

# Phase 3.7.5 documentation matches merge-hooks.py: removal only, registry only, no current/ fallback.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for f in skills/silver-init/SKILL.md skills/silver-init/references/scaffold-steps.md skills/silver-doctor/SKILL.md skills/silver-migrate/SKILL.md skills/silver-update/SKILL.md; do
  for stale in 'Register SB hooks in the host hooks manifest' 'Re-register/refresh SB hooks' 're-register or refresh SB hooks' 'Re-register SB hooks' 're-register host hooks' 'or `${SB_RUNTIME_HOME_ROOT}/plugins/cache/alo-labs/silver-bullet/current`' 'update §3.7.5 |' 'Could not auto-register hooks' 'add hooks manually from'; do
    if grep -qF -- "$stale" "$REPO/$f"; then echo "FAIL: $f still says: $stale"; (( FAIL++ )) || true; else echo "PASS: $f has no stale 3.7.5 wording: $stale"; (( PASS++ )) || true; fi
  done
done

# The failure warning must not tell users to add hooks by hand (a registered plugin would run them twice)
for f in skills/silver-init/references/scaffold-steps.md agents/claude/sb:init/references/scaffold-steps.md host-bundles/codex/sb-init/references/scaffold-steps.md plugins/silver-bullet/skill-source/sb-init/references/scaffold-steps.md; do
  if grep -qF 'Do not add hooks by hand' "$REPO/$f"; then echo "PASS: $f warns against hand-added hooks"; (( PASS++ )) || true; else echo "FAIL: $f lacks the do-not-add-by-hand warning"; (( FAIL++ )) || true; fi
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
