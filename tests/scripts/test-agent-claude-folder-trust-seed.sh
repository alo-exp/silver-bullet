#!/usr/bin/env bash
# agent-claude ephemeral CLAUDE_CONFIG_DIR folder trust seeding.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/agent-claude/lib.sh
source "${REPO_ROOT}/scripts/agent-claude/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

WORK="${TMP}/workspace"
mkdir -p "$WORK"
export HOME="${TMP}/home"
mkdir -p "$HOME"
export CLAUDE_CONFIG_DIR="${TMP}/config"
export SB_AGENT_CLAUDE_SEED_FOLDER_TRUST=1
export SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1

agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR"

python3 - "$CLAUDE_CONFIG_DIR/.claude.json" "$HOME/.codex.json" "$WORK" <<'PY'
import json
import pathlib
import sys

for path_str in sys.argv[1:3]:
    path = pathlib.Path(path_str)
    work = pathlib.Path(sys.argv[3]).resolve()
    data = json.loads(path.read_text())
    ok = False
    for key in (str(work), sys.argv[3]):
        if data.get("projects", {}).get(key, {}).get("hasTrustDialogAccepted") is True:
            ok = True
            break
    if not ok:
        raise SystemExit(f"missing hasTrustDialogAccepted in {path_str}")
print("OK: hasTrustDialogAccepted seeded in isolated + global claude.json")
PY

echo "PASS: test-agent-claude-folder-trust-seed.sh"
