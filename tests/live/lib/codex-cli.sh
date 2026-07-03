#!/usr/bin/env bash
# Re-export canonical Codex CLI resolution from scripts/lib.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/codex-cli.sh
source "${SCRIPT_DIR}/../../../scripts/lib/codex-cli.sh"
