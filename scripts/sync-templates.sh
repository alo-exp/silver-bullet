#!/usr/bin/env bash
# Copy canonical templates/ into plugins/silver-bullet/templates/ (physical mirror).
#
# The mirror is byte-identical and host-neutral: its templates keep the
# ${SB_RUNTIME_*} placeholders like templates/ itself (what Claude ships). The
# Codex installer expands them for Codex in the copy it installs (scripts/lib/install-codex/cache.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${REPO_ROOT}/templates"
DST="${REPO_ROOT}/plugins/silver-bullet/templates"

if [[ ! -d "$SRC" ]]; then
  printf 'ERROR: missing source templates at %s\n' "$SRC" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  printf 'ERROR: rsync is required by sync-templates.sh but is not in PATH.\n' >&2
  exit 1
fi

mkdir -p "$DST"
rsync -a --delete "${SRC}/" "${DST}/"

printf 'Synced %s -> %s (%s files)\n' "$SRC" "$DST" "$(find "$SRC" -type f | wc -l | tr -d ' ')"
