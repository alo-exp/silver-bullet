#!/usr/bin/env bash
# sb-bootstrap.sh — one-command Silver Bullet onboarding probe and next steps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$PWD}"

echo "Silver Bullet bootstrap"
echo "======================="
echo

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required."
  echo "  macOS: brew install jq"
  echo "  Linux: sudo apt install jq"
  exit 1
fi
echo "PASS: jq installed"

if [[ -x "${SCRIPT_DIR}/sb-diagnostics.sh" ]]; then
  echo
  bash "${SCRIPT_DIR}/sb-diagnostics.sh" || true
else
  echo "WARN: sb-diagnostics.sh not found"
fi

echo
if [[ -f "$TARGET/.silver-bullet.json" ]]; then
  echo "Project: Silver Bullet already initialized in $TARGET"
  echo "  Next: run /silver in your coding agent, or /silver:handoff to resume."
else
  echo "Project: not initialized"
  echo "  1. Install the plugin in your host agent:"
  echo "       Claude: /plugin install alo-exp/silver-bullet"
  echo "       Codex:  install silver-bullet from the alo-labs-codex marketplace"
  echo "  2. In this repo, run: /silver:init"
  echo "  3. Optional: uv tool install graphifyy  (tier-1 code intelligence)"
fi

echo
echo "Zuvo / AS1 migrator quickstart"
echo "  - Parity ledger: docs/sb-vs-as1.md"
echo "  - Runtime tiers: docs/RUNTIME-COMPATIBILITY.md"
echo "  - Entry route:   /silver (explicit router — by design)"
echo "  - UI state:      .planning/interface/STATE.md (stamped on init for frontend stacks)"
echo "  - Diagnostics:   bash scripts/sb-diagnostics.sh"
