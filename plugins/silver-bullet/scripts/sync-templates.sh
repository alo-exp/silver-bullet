#!/usr/bin/env bash
# Copy canonical templates/ into plugins/silver-bullet/templates/ (physical mirror).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO_ROOT}/templates"
DST="${REPO_ROOT}/plugins/silver-bullet/templates"

if [[ ! -d "$SRC" ]]; then
  printf 'ERROR: missing source templates at %s\n' "$SRC" >&2
  exit 1
fi

mkdir -p "$DST"
rsync -a --delete "${SRC}/" "${DST}/"

# Codex plugin mirror expands runtime placeholders for packaged installs.
SANITIZER="${REPO_ROOT}/scripts/codex-sanitize-package.sh"
if [[ -x "$SANITIZER" ]]; then
  "$SANITIZER" "$DST"
else
  printf 'ERROR: missing Codex sanitizer at %s\n' "$SANITIZER" >&2
  exit 1
fi

printf 'Synced %s -> %s (%s files)\n' "$SRC" "$DST" "$(find "$SRC" -type f | wc -l | tr -d ' ')"
