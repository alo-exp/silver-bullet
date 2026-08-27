#!/usr/bin/env bash
# Thin alias to agent-codex-delegate.sh (D7). Flags including --skip-preflight pass through.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DELEGATE="${REPO_ROOT}/scripts/agent-codex-delegate.sh"

[[ -x "$DELEGATE" ]] || { printf 'ERROR: missing delegate: %s\n' "$DELEGATE" >&2; exit 1; }
exec bash "$DELEGATE" "$@"
