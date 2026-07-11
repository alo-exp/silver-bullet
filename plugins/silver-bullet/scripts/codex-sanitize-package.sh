#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: %s <package-root> [<package-root> ...]\n' "${0##*/}" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for root in "$@"; do
  python3 "${SCRIPT_DIR}/render-agent-bundle.py" sanitize --agent codex --root "$root"
done
