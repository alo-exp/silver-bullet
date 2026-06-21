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
printf 'Synced %s -> %s (%s files)\n' "$SRC" "$DST" "$(find "$SRC" -type f | wc -l | tr -d ' ')"
