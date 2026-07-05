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
export CLAUDE_CONFIG_DIR="${TMP}/config"
export SB_AGENT_CLAUDE_SEED_FOLDER_TRUST=1

agent_claude_seed_folder_trust "$WORK" "$CLAUDE_CONFIG_DIR"

python3 - "$CLAUDE_CONFIG_DIR/.claude.json" "$WORK" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
work = pathlib.Path(sys.argv[2]).resolve()
data = json.loads(path.read_text())
projects = data.get("projects", {})
accepted = False
for key in (str(work), sys.argv[2]):
    entry = projects.get(key, {})
    if entry.get("hasTrustDialogAccepted") is True:
        accepted = True
        break
if not accepted:
    raise SystemExit("missing hasTrustDialogAccepted for workspace")
print("OK: hasTrustDialogAccepted seeded")
PY

echo "PASS: test-agent-claude-folder-trust-seed.sh"
