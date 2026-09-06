#!/usr/bin/env bash
# Historical helper: Cursor desktop rejects colon-bearing command filenames.
# Prefer scripts/generate-plugin-commands.sh which emits filesystem-safe
# silver-<route>.md stubs while keeping name: "sb:<route>" in frontmatter.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

printf 'WARN: %s is obsolete — regenerating desktop-safe command stubs via generate-plugin-commands.sh\n' \
  "$(basename "$0")" >&2
exec bash "${REPO_ROOT}/scripts/generate-plugin-commands.sh"
