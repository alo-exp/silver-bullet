#!/usr/bin/env bash
# agent-claude folder trust seeding: ephemeral CLAUDE_CONFIG_DIR by default; the
# global ~/.claude.json only on opt-in, atomically, never over unparsable JSON (R4-11, R8-15).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/agent-claude/lib.sh
source "${REPO_ROOT}/scripts/agent-claude/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

WORK="${TMP}/workspace"
mkdir -p "$WORK"
export HOME="${TMP}/home"
mkdir -p "$HOME"
export CLAUDE_CONFIG_DIR="${TMP}/config"
export SB_AGENT_CLAUDE_SEED_FOLDER_TRUST=1
unset SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL

trusted() {
  python3 - "$1" "$WORK" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
work = sys.argv[2]
projects = data.get("projects", {})
sys.exit(0 if any(projects.get(k, {}).get("hasTrustDialogAccepted") is True
                  for k in (work, str(pathlib.Path(work).resolve()))) else 1)
PY
}

# 1. default: ephemeral seeded, global file not created or touched
printf '{"oauthAccount":{"id":"keep"}}\n' >"$HOME/.claude.json"
before="$(cksum <"$HOME/.claude.json")"
agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
trusted "$CLAUDE_CONFIG_DIR/.claude.json" && ok "ephemeral config seeded" || bad "ephemeral config seeded"
[[ "$(cksum <"$HOME/.claude.json")" == "$before" ]] && ok "global untouched by default" || bad "global untouched by default"
[[ ! -e "$HOME/.claude.json.sb-backup" ]] && ok "no backup without opt-in" || bad "no backup without opt-in"

# 2. opt-in: global seeded atomically, other keys kept, backup made, mode kept
chmod 600 "$HOME/.claude.json"
SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
trusted "$HOME/.claude.json" && ok "opt-in seeds global" || bad "opt-in seeds global"
grep -q '"keep"' "$HOME/.claude.json" && ok "opt-in keeps other keys" || bad "opt-in keeps other keys"
[[ -f "$HOME/.claude.json.sb-backup" ]] && grep -q '"keep"' "$HOME/.claude.json.sb-backup" && ok "backup holds the original" || bad "backup holds the original"
mode="$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$HOME/.claude.json")"
[[ "$mode" == "0o600" ]] && ok "mode preserved" || bad "mode preserved ($mode)"
ls "$HOME"/.claude.json.*.tmp >/dev/null 2>&1 && bad "no temp file left" || ok "no temp file left"

# 3. opt-in over unparsable JSON: byte-identical, error reported, ephemeral still seeded
printf '{"projects": {"/x": {"a": 1},}' >"$HOME/.claude.json"
rm -f "$HOME/.claude.json.sb-backup"
before="$(cksum <"$HOME/.claude.json")"
err="$(SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>&1 >/dev/null)"
[[ "$(cksum <"$HOME/.claude.json")" == "$before" ]] && ok "corrupt global byte-identical" || bad "corrupt global byte-identical"
[[ "$err" == *"does not parse"* ]] && ok "corrupt global reports error" || bad "corrupt global reports error"

# 4. non-object top level and non-object projects are also left alone
printf '[1,2]\n' >"$HOME/.claude.json"
before="$(cksum <"$HOME/.claude.json")"
SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
[[ "$(cksum <"$HOME/.claude.json")" == "$before" ]] && ok "array top level untouched" || bad "array top level untouched"
printf '{"projects": 5}\n' >"$HOME/.claude.json"
before="$(cksum <"$HOME/.claude.json")"
SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
[[ "$(cksum <"$HOME/.claude.json")" == "$before" ]] && ok "non-object projects untouched" || bad "non-object projects untouched"

# 5. opt-in with no global file: created
rm -f "$HOME/.claude.json" "$HOME/.claude.json.sb-backup"
SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
trusted "$HOME/.claude.json" && ok "opt-in creates missing global" || bad "opt-in creates missing global"

# 6. seeding disabled entirely
rm -rf "$CLAUDE_CONFIG_DIR"
SB_AGENT_CLAUDE_SEED_FOLDER_TRUST=0 agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR" 2>/dev/null
[[ ! -e "$CLAUDE_CONFIG_DIR/.claude.json" ]] && ok "SEED_FOLDER_TRUST=0 skips" || bad "SEED_FOLDER_TRUST=0 skips"

printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
